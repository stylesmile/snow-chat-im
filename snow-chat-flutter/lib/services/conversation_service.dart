import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../providers/chat_provider.dart';

/// 本地会话（聊天列表）服务
class ConversationService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 保存或更新会话记录
  Future<void> saveSession({
    required int userId,
    required int targetId,
    required String targetType,
    String lastMsg = '',
    int lastMsgTime = 0,
    int unreadCount = 0,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'sessions',
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
  Future<List<Conversation>> loadSessions(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'sessions',
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
    required int userId,
    required int targetId,
    required String targetType,
    required int unreadCount,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'sessions',
      {'unread_count': unreadCount},
      where: 'user_id = ? AND target_id = ? AND target_type = ?',
      whereArgs: [userId, targetId, targetType],
    );
  }

  /// 删除会话
  Future<void> deleteSession({
    required int userId,
    required int targetId,
    required String targetType,
  }) async {
    final db = await _dbHelper.database;
    await db.delete(
      'sessions',
      where: 'user_id = ? AND target_id = ? AND target_type = ?',
      whereArgs: [userId, targetId, targetType],
    );
  }
}
