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

  /// 保存或更新会话记录
  Future<void> saveSession({
    required BuildContext context,
    required int targetId,
    required String targetType,
    String lastMsg = '',
    int lastMsgTime = 0,
    int unreadCount = 0,
  }) async {
    final userId = _getUserId(context);
    final db = await _dbHelper.database;
    final table = Tables.sessionsTable(userId);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      table,
      {
        'user_id': userId,
        'target_id': targetId,
        'target_type': targetType,
        'last_msg': lastMsg,
        'last_msg_time': lastMsgTime,
        'unread_count': unreadCount,
        'update_time': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 加载当前用户的所有会话，按最后消息时间倒序
  Future<List<Conversation>> loadSessions(BuildContext context) async {
    final userId = _getUserId(context);
    final db = await _dbHelper.database;
    final table = Tables.sessionsTable(userId);
    final rows = await db.query(
      table,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'last_msg_time DESC',
    );
    return rows.map((row) {
      return Conversation(
        targetId: row['target_id'] as int,
        targetType: row['target_type'] as String,
        lastMsg: row['last_msg'] as String? ?? '',
        lastMsgTime: row['last_msg_time'] as int? ?? 0,
        unreadCount: row['unread_count'] as int? ?? 0,
      );
    }).toList();
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
