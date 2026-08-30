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

  /// 从 Provider 获取当前用户ID
  int _getUserId(BuildContext context) {
    return context.read<AuthProvider>().userId ?? 0;
  }

  /// 保存或更新会话记录（支持置顶/免打扰状态持久化）
  Future<void> saveSession({
    required BuildContext context,
    required int targetId,
    required String targetType,
    String lastMsg = '',
    int lastMsgTime = 0,
    int unreadCount = 0,
    bool isPinned = false,
    bool isMuted = false,
  }) async {
    final userId = _getUserId(context);
    final db = await _dbHelper.database;
    final table = Tables.sessionsTable(userId);
    final now = DateTime.now().millisecondsSinceEpoch;
    // 插入会话记录，冲突时整体替换（upsert），保留最新的置顶/免打扰标记
    await db.insert(
      table,
      {
        'user_id': userId,
        'target_id': targetId,
        'target_type': targetType,
        'last_msg': lastMsg,
        'last_msg_time': lastMsgTime,
        'unread_count': unreadCount,
        'is_muted': isMuted ? 1 : 0,
        'is_pinned': isPinned ? 1 : 0,
        'update_time': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 加载当前用户的所有会话，按最后消息时间倒序，去重（防止重复记录）
  Future<List<Conversation>> loadSessions(BuildContext context) async {
    final userId = _getUserId(context);
    final db = await _dbHelper.database;
    final table = Tables.sessionsTable(userId);
    // 使用 DISTINCT 防止同一 target_id+target_type 出现重复行
    final rows = await db.rawQuery('''
      SELECT target_id, target_type, last_msg, last_msg_time, unread_count, is_muted, is_pinned
      FROM $table
      WHERE user_id = ?
      GROUP BY target_id, target_type
      ORDER BY last_msg_time DESC
    ''', [userId]);
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
