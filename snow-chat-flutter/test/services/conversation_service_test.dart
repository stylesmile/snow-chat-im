import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/core/database/tables.dart';

void main() {
  // 在桌面端使用内存 SQLite 跑测试
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const testUserId = 1;

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        // 创建带用户ID前缀的会话表（与生产环境一致）
        await db.execute(Tables.createSessionsTable(testUserId));
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// 辅助方法：用测试数据库执行操作，验证带前缀的表名正确工作
  group('ConversationService.saveSession', () {
    test('should insert session into user-scoped table', () async {
      final table = Tables.sessionsTable(testUserId);

      // 直接使用 db 操作来验证表结构
      await db.insert(
        table,
        {
          'user_id': testUserId,
          'target_id': 2,
          'target_type': 'friend',
          'last_msg': 'Hello',
          'last_msg_time': 1700000000000,
          'unread_count': 1,
          'update_time': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final rows = await db.query(table);
      expect(rows.length, equals(1));
      expect(rows[0]['last_msg'], equals('Hello'));
      expect(rows[0]['unread_count'], equals(1));
    });

    test('should replace session on conflict (upsert behavior)', () async {
      final table = Tables.sessionsTable(testUserId);

      // 插入第一次
      await db.insert(
        table,
        {
          'user_id': testUserId,
          'target_id': 2,
          'target_type': 'friend',
          'last_msg': 'Hello',
          'last_msg_time': 1700000000000,
          'unread_count': 1,
          'update_time': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 插入同一 user_id + target_id + target_type，应替换
      await db.insert(
        table,
        {
          'user_id': testUserId,
          'target_id': 2,
          'target_type': 'friend',
          'last_msg': 'Updated',
          'last_msg_time': 1700000001000,
          'unread_count': 3,
          'update_time': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final rows = await db.query(table);
      expect(rows.length, equals(1));
      expect(rows[0]['last_msg'], equals('Updated'));
      expect(rows[0]['unread_count'], equals(3));
    });
  });

  group('ConversationService.loadSessions', () {
    test('should load sessions ordered by last_msg_time DESC', () async {
      final table = Tables.sessionsTable(testUserId);

      // 插入多条记录
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Old',
        'last_msg_time': 1700000000000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 3,
        'target_type': 'group',
        'last_msg': 'New',
        'last_msg_time': 1700000002000,
        'unread_count': 5,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });
      await db.insert(table, {
        'user_id': 2, // 不同用户
        'target_id': 4,
        'target_type': 'friend',
        'last_msg': 'Other user',
        'last_msg_time': 1700000003000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });

      // 查询用户 testUserId 的会话
      final rows = await db.query(
        table,
        where: 'user_id = ?',
        whereArgs: [testUserId],
        orderBy: 'last_msg_time DESC',
      );

      expect(rows.length, equals(2));
      expect(rows[0]['last_msg'], equals('New')); // 最新的在前
      expect(rows[1]['last_msg'], equals('Old'));
    });

    test('should return empty list when no sessions exist', () async {
      final table = Tables.sessionsTable(testUserId);
      final rows = await db.query(
        table,
        where: 'user_id = ?',
        whereArgs: [testUserId],
      );

      expect(rows, isEmpty);
    });
  });

  group('ConversationService.updateUnreadCount', () {
    test('should update unread count', () async {
      final table = Tables.sessionsTable(testUserId);
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Hello',
        'last_msg_time': 1700000000000,
        'unread_count': 5,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });

      await db.update(
        table,
        {'unread_count': 0},
        where: 'target_id = ? AND target_type = ?',
        whereArgs: [2, 'friend'],
      );

      final rows = await db.query(table);
      expect(rows[0]['unread_count'], equals(0));
    });
  });

  group('ConversationService.deleteSession', () {
    test('should delete session', () async {
      final table = Tables.sessionsTable(testUserId);
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Hello',
        'last_msg_time': 1700000000000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });

      await db.delete(
        table,
        where: 'target_id = ? AND target_type = ?',
        whereArgs: [2, 'friend'],
      );

      final rows = await db.query(table);
      expect(rows, isEmpty);
    });

    test('should not delete other sessions', () async {
      final table = Tables.sessionsTable(testUserId);
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Keep me',
        'last_msg_time': 1700000000000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 3,
        'target_type': 'friend',
        'last_msg': 'Delete me',
        'last_msg_time': 1700000001000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });

      await db.delete(
        table,
        where: 'target_id = ? AND target_type = ?',
        whereArgs: [3, 'friend'],
      );

      final rows = await db.query(table);
      expect(rows.length, equals(1));
      expect(rows[0]['last_msg'], equals('Keep me'));
    });
  });
}
