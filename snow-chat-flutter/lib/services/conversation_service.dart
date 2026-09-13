import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/database/tables.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

/// 本地会话（聊天列表）服务
/// 表名按用户ID隔离：sessions_{userId}
class ConversationService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 自愈清理：删除「自聊」脏会话行。
  ///
  /// 历史上「文件传输助手」的回推消息（type=self，实际发给自己）曾被当成
  /// 普通好友消息记成 target_id=自己 的好友会话，在聊天列表里多出一条
  /// 显示不了名字头像的重复数据。好友 id 不可能等于自己，这类行一定是脏数据。
  ///
  /// 静态方法便于直接用测试数据库验证。
  static Future<void> purgeSelfEchoSessions(
    Database db,
    String table,
    int userId,
  ) async {
    await db.delete(
      table,
      where: 'user_id = ? AND target_type = ? AND target_id = ?',
      whereArgs: [userId, 'friend', userId],
    );
  }

  /// 从 Provider 获取当前用户ID
  int _getUserId(BuildContext context) {
    return context.read<AuthProvider>().userId ?? 0;
  }

  /// 保存或更新会话记录（支持置顶/免打扰状态持久化）
  ///
  /// [isPinned] / [isMuted] 为 **null 表示保持该会话已有的值**：进入聊天页、收到新消息
  /// 这类调用只关心「最后一条消息/时间/未读数」，不该顺手把用户设的置顶、免打扰清掉。
  Future<void> saveSession({
    required BuildContext context,
    required int targetId,
    required String targetType,
    String lastMsg = '',
    int lastMsgTime = 0,
    int unreadCount = 0,
    bool? isPinned,
    bool? isMuted,
  }) async {
    final userId = _getUserId(context);
    final db = await _dbHelper.database;
    final table = Tables.sessionsTable(userId);
    final now = DateTime.now().millisecondsSinceEpoch;

    // 调用方没传标记时沿用库里已有的值，避免一次普通写入把置顶/免打扰重置
    var pinned = isPinned;
    var muted = isMuted;
    if (pinned == null || muted == null) {
      final existing = await db.query(
        table,
        columns: ['is_pinned', 'is_muted'],
        where: 'user_id = ? AND target_id = ? AND target_type = ?',
        whereArgs: [userId, targetId, targetType],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        pinned ??= (existing.first['is_pinned'] as int? ?? 0) == 1;
        muted ??= (existing.first['is_muted'] as int? ?? 0) == 1;
      }
    }

    // 先删除同一会话的旧行再插入。
    // 不能只靠 ConflictAlgorithm.replace：它依赖唯一约束，而早期版本建出的
    // sessions 表没有 UNIQUE(user_id,target_id,target_type)，且 CREATE TABLE IF NOT
    // EXISTS 不会补约束 —— 那种库上 replace 等同于新增，于是「从通讯录再进一次同一好友」
    // 就会攒出一行重复会话。显式先删后插与约束无关，任何库上都是同键只留一行。
    await db.transaction((txn) async {
      await txn.delete(
        table,
        where: 'user_id = ? AND target_id = ? AND target_type = ?',
        whereArgs: [userId, targetId, targetType],
      );
      await txn.insert(table, {
        'user_id': userId,
        'target_id': targetId,
        'target_type': targetType,
        'last_msg': lastMsg,
        'last_msg_time': lastMsgTime,
        'unread_count': unreadCount,
        'is_muted': (muted ?? false) ? 1 : 0,
        'is_pinned': (pinned ?? false) ? 1 : 0,
        'update_time': now,
      });
    });
  }

  /// 加载当前用户的所有会话，按最后消息时间倒序，去重（防止重复记录）
  Future<List<Conversation>> loadSessions(BuildContext context) async {
    final userId = _getUserId(context);
    final db = await _dbHelper.database;
    final table = Tables.sessionsTable(userId);

    // 加载前先清掉历史脏数据（见 [purgeSelfEchoSessions]）
    await purgeSelfEchoSessions(db, table, userId);

    // 每个会话只取 id 最大的一行（最后一次写入的状态）：
    // 老库里同一会话可能残留多行（缺 UNIQUE 约束的历史数据），
    // 单纯 GROUP BY 会「随机」挑一行、拿不到最新状态，所以用 MAX(id) 精确定位。
    final rows = await db.rawQuery('''
      SELECT target_id, target_type, last_msg, last_msg_time, unread_count, is_muted, is_pinned
      FROM $table
      WHERE user_id = ?
        AND id IN (SELECT MAX(id) FROM $table WHERE user_id = ? GROUP BY target_id, target_type)
      ORDER BY last_msg_time DESC
    ''', [userId, userId]);
    return rows.map((row) {
      // 从数据库行还原会话对象，包含置顶/免打扰状态
      return Conversation(
        targetId: row['target_id'] as int,
        targetType: row['target_type'] as String,
        lastMsg: row['last_msg'] as String? ?? '',
        lastMsgTime: row['last_msg_time'] as int? ?? 0,
        unreadCount: row['unread_count'] as int? ?? 0,
        isMuted: (row['is_muted'] as int? ?? 0) == 1,
        isPinned: (row['is_pinned'] as int? ?? 0) == 1,
      );
    }).toList();
  }

  /// 更新指定会话的置顶/免打扰标记（增量更新，不改动其它字段）
  Future<void> updateSessionFlags({
    required BuildContext context,
    required int targetId,
    required String targetType,
    bool? isPinned,
    bool? isMuted,
  }) async {
    final userId = _getUserId(context);
    final db = await _dbHelper.database;
    final table = Tables.sessionsTable(userId);
    // 仅更新传入的非空标记，避免误覆盖其它字段
    final values = <String, Object>{};
    if (isPinned != null) values['is_pinned'] = isPinned ? 1 : 0;
    if (isMuted != null) values['is_muted'] = isMuted ? 1 : 0;
    if (values.isEmpty) return;
    await db.update(
      table,
      values,
      where: 'target_id = ? AND target_type = ?',
      whereArgs: [targetId, targetType],
    );
  }

  /// 更新会话未读数
  Future<void> updateUnreadCount({
    required BuildContext context,
    required int targetId,
    required String targetType,
    required int unreadCount,
  }) async {
    final userId = _getUserId(context);
    final db = await _dbHelper.database;
    final table = Tables.sessionsTable(userId);
    await db.update(
      table,
      {'unread_count': unreadCount},
      where: 'target_id = ? AND target_type = ?',
      whereArgs: [targetId, targetType],
    );
  }

  /// 进入会话时清零未读数。
  ///
  /// 与 [saveSession] 的区别：**会话不存在时什么都不做**，不会凭空造出一条空会话。
  /// 这样「从通讯录点进某人的聊天再返回」不会往聊天列表里多塞条目。
  Future<void> clearUnread({
    required BuildContext context,
    required int targetId,
    required String targetType,
  }) async {
    final userId = _getUserId(context);
    final db = await _dbHelper.database;
    final table = Tables.sessionsTable(userId);
    await db.update(
      table,
      {'unread_count': 0},
      where: 'user_id = ? AND target_id = ? AND target_type = ?',
      whereArgs: [userId, targetId, targetType],
    );
  }

  /// 删除会话
  Future<void> deleteSession({
    required BuildContext context,
    required int targetId,
    required String targetType,
  }) async {
    final userId = _getUserId(context);
    final db = await _dbHelper.database;
    final table = Tables.sessionsTable(userId);
    await db.delete(
      table,
      where: 'target_id = ? AND target_type = ?',
      whereArgs: [targetId, targetType],
    );
  }
}
