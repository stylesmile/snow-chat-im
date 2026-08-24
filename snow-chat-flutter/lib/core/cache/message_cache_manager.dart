import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/tables.dart';
import '../../models/message_model.dart';

/// 消息本地缓存管理器：SQLite 持久化 + 内存热缓存。
///
/// - 发送/收到消息时写入 DB，同时保留在内存。
/// - 进入聊天页先读内存，秒开；内存不足时从 DB 补满最近 N 条。
/// - 上翻页时从 DB 查询更早的消息。
/// - 表名按用户ID隔离：local_messages_{userId}
class MessageCacheManager {
  static final MessageCacheManager _instance = MessageCacheManager._internal();

  factory MessageCacheManager() => _instance;

  MessageCacheManager._internal();

  /// 测试注入用构造函数。
  MessageCacheManager.forTest(this._db);

  Database? _db;
  bool _initialized = false;
  int? _userId; // 当前登录用户ID，用于生成表名

  /// 按会话分桶的内存缓存，内部按 createTime 降序排列（最新在最前）。
  final Map<String, List<MessageModel>> _memory = {};

  static const int _defaultMemoryLimit = 100;

  /// 设置当前用户ID（登录时调用）
  void setUserId(int userId) {
    _userId = userId;
  }

  Future<void> init() async {
    if (_initialized) return;
    _db ??= await DatabaseHelper().database;
    _initialized = true;
  }

  Future<void> dispose() async {
    _memory.clear();
    _initialized = false;
  }

  /// 获取当前用户的消息表名
  String _messagesTable() {
    if (_userId == null) throw StateError('User ID not set. Call setUserId() first.');
    return Tables.messagesTable(_userId!);
  }

  /// 生成单聊会话 ID。
  static String sessionIdForPrivate(int userId, int peerId) {
    final a = userId < peerId ? userId : peerId;
    final b = userId < peerId ? peerId : userId;
    return 'u_${a}_$b';
  }

  /// 生成群聊会话 ID。
  static String sessionIdForGroup(int groupId) => 'g_$groupId';

  /// 保存/接收消息：写 DB + 更新内存。
  Future<void> appendMessage(String sessionId, MessageModel message) async {
    final db = _requireDb();
    await db.insert(
      _messagesTable(),
      _toMap(sessionId, message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _upsertMemory(sessionId, message);
  }

  /// 更新消息的推送状态（回执确认后调用）
  Future<void> updatePushStatus(String sessionId, int msgId, String pushStatus) async {
    final db = _requireDb();
    await db.update(
      _messagesTable(),
      {'push_status': pushStatus},
      where: 'msg_id = ? AND session_id = ?',
      whereArgs: [msgId, sessionId],
    );
    // 同步更新内存缓存
    final cache = _memory[sessionId];
    if (cache != null) {
      final idx = cache.indexWhere((m) => m.id == msgId);
      if (idx >= 0) {
        cache[idx] = MessageModel(
          id: cache[idx].id,
          fromUserId: cache[idx].fromUserId,
          toUserId: cache[idx].toUserId,
          groupId: cache[idx].groupId,
          type: cache[idx].type,
          content: cache[idx].content,
          status: cache[idx].status,
          pushStatus: pushStatus,
          createTime: cache[idx].createTime,
        );
      }
    }
  }

  /// 同步读取内存中的最近消息（createTime 升序，便于 UI 直接展示）。
  List<MessageModel> recentMessagesSync(String sessionId) {
    final cache = _memory[sessionId] ?? [];
    return List.unmodifiable(cache.reversed);
  }

  /// 读取最近 [limit] 条消息；内存不够时从 DB 补充。
  Future<List<MessageModel>> recentMessages(String sessionId, {int limit = 50}) async {
    if (_memory.containsKey(sessionId) && _memory[sessionId]!.length >= limit) {
      return recentMessagesSync(sessionId).take(limit).toList();
    }
    await _preloadFromDb(sessionId, limit);
    return recentMessagesSync(sessionId).take(limit).toList();
  }

  /// 上翻加载历史：查询 createTime < [beforeTime] 的更早消息，createTime 升序。
  Future<List<MessageModel>> loadHistory(
    String sessionId, {
    required int beforeTime,
    int limit = 20,
  }) async {
    final db = _requireDb();
    final rows = await db.query(
      _messagesTable(),
      where: 'session_id = ? AND create_time < ?',
      whereArgs: [sessionId, beforeTime],
      orderBy: 'create_time ASC',
      limit: limit,
    );
    return rows.map(_fromMap).toList();
  }

  /// 清空内存缓存（例如切换账号时调用）。
  void clearMemory() => _memory.clear();

  void _upsertMemory(String sessionId, MessageModel message) {
    final cache = _memory.putIfAbsent(sessionId, () => []);
    final index = cache.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      cache[index] = message;
    } else {
      cache.add(message);
    }
    cache.sort((a, b) => b.createTime.compareTo(a.createTime));
    if (cache.length > _defaultMemoryLimit) {
      cache.removeRange(_defaultMemoryLimit, cache.length);
    }
  }

  Future<void> _preloadFromDb(String sessionId, int limit) async {
    final db = _requireDb();
    final rows = await db.query(
      _messagesTable(),
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'create_time DESC',
      limit: limit,
    );
    final messages = rows.map(_fromMap).toList();
    _memory[sessionId] = messages..sort((a, b) => b.createTime.compareTo(a.createTime));
  }

  Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError('MessageCacheManager not initialized. Call init() first.');
    }
    return db;
  }

  Map<String, dynamic> _toMap(String sessionId, MessageModel message) {
    return {
      'msg_id': message.id,
      'session_id': sessionId,
      'from_user_id': message.fromUserId,
      'to_user_id': message.toUserId,
      'group_id': message.groupId,
      'msg_type': message.type,
      'content': message.content,
      'local_seq': message.createTime,
      'status': message.status,
      'push_status': message.pushStatus,
      'create_time': message.createTime,
      'update_time': DateTime.now().millisecondsSinceEpoch,
    };
  }

  MessageModel _fromMap(Map<String, dynamic> row) {
    return MessageModel(
      id: row['msg_id'] as int? ?? 0,
      fromUserId: row['from_user_id'] as int? ?? 0,
      toUserId: row['to_user_id'] as int?,
      groupId: row['group_id'] as int?,
      type: row['msg_type'] as String? ?? 'text',
      content: row['content'] as String? ?? '',
      status: row['status'] as String? ?? 'sent',
      pushStatus: row['push_status'] as String? ?? 'pending',
      createTime: row['create_time'] as int? ?? 0,
    );
  }
}
