// FavoriteCacheManager（收藏本地缓存管理器）
//
// 收藏模块的本地持久化层：把收藏的文本/图片消息保存到本地 SQLite。
//
// 设计（与 MessageCacheManager 一致）：
// - 表名按用户ID隔离：favorites_{userId}
// - 提供 forTest 测试注入，便于桌面端用内存 SQLite 跑单元测试
// - add 对同一 messageId 去重（表 UNIQUE 约束兜底）
//
// 方法：
// - add      : 收藏一条消息
// - list     : 按收藏时间降序返回全部收藏
// - contains : 判断某消息是否已收藏
// - remove   : 按 messageId 取消收藏
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/tables.dart';
import '../../models/favorite_model.dart';

class FavoriteCacheManager {
  static final FavoriteCacheManager _instance = FavoriteCacheManager._internal();

  factory FavoriteCacheManager() => _instance;

  FavoriteCacheManager._internal();

  /// 测试注入用构造函数
  FavoriteCacheManager.forTest(this._db);

  Database? _db;
  bool _initialized = false;
  int? _userId; // 当前登录用户ID，用于生成表名

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
    _initialized = false;
  }

  /// 获取当前用户的收藏表名
  String _favoritesTable() {
    if (_userId == null) throw StateError('User ID not set. Call setUserId() first.');
    return Tables.favoritesTable(_userId!);
  }

  /// 收藏一条消息；同一 messageId 重复收藏时以 REPLACE 去重
  Future<void> add(FavoriteModel favorite) async {
    final db = _requireDb();
    await db.insert(
      _favoritesTable(),
      _toMap(favorite),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 按收藏时间降序返回全部收藏
  Future<List<FavoriteModel>> list() async {
    final db = _requireDb();
    final rows = await db.query(
      _favoritesTable(),
      orderBy: 'create_time DESC, id DESC',
    );
    return rows.map(_fromMap).toList();
  }

  /// 判断某消息是否已收藏
  Future<bool> contains(int messageId) async {
    final db = _requireDb();
    final rows = await db.query(
      _favoritesTable(),
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 按 messageId 取消收藏
  Future<void> remove(int messageId) async {
    final db = _requireDb();
    await db.delete(
      _favoritesTable(),
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  /// 按收藏记录 id 删除（我的收藏列表里删除）
  Future<void> removeById(int id) async {
    final db = _requireDb();
    await db.delete(
      _favoritesTable(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError('FavoriteCacheManager not initialized. Call init() first.');
    }
    return db;
  }

  /// 模型 → DB 行
  Map<String, dynamic> _toMap(FavoriteModel f) {
    return {
      'message_id': f.messageId,
      'msg_type': f.type,
      'content': f.content,
      'from_user_id': f.fromUserId,
      'from_nickname': f.fromNickname,
      'create_time': f.createTime,
    };
  }

  /// DB 行 → 模型
  FavoriteModel _fromMap(Map<String, dynamic> row) {
    return FavoriteModel(
      id: row['id'] as int? ?? 0,
      messageId: row['message_id'] as int? ?? 0,
      type: row['msg_type'] as String? ?? 'text',
      content: row['content'] as String? ?? '',
      fromUserId: row['from_user_id'] as int? ?? 0,
      fromNickname: row['from_nickname'] as String? ?? '',
      createTime: row['create_time'] as int? ?? 0,
    );
  }
}