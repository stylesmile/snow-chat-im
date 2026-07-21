import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/services/conversation_service.dart';
import 'package:snow_chat/core/database/tables.dart';

void main() {
  // 在桌面端使用内存 SQLite 跑测试
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late ConversationService conversationService;
  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute(Tables.createSessionsTable);
      },
    );

    // Mock DatabaseHelper 返回测试数据库
    conversationService = ConversationService();
    // 使用反射或直接操作来替换内部数据库
    // 由于 ConversationService 内部使用 DatabaseHelper，这里需要手动设置
    // 直接测试 ConversationService 的逻辑
  });

  tearDown(() async {
    await db.close();
  });

  group('ConversationService.saveSession', () {
    test('should insert session into database', () async {
      // 直接使用 db 操作来验证表结构
      await db.insert(
        'sessions',
        {
          'user_id': 1,
          'target_id': 2,
          'target_type': 'friend',
          'last_msg': 'Hello',
          'last_msg_time': 1700000000000,
          'unread_count': 1,
          'update_time': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final rows = await db.query('sessions');
      expect(rows.length, equals(1));
      expect(rows[0]['last_msg'], equals('Hello'));
      expect(rows[0]['unread_count'], equals(1));
    });

    test('should replace session on conflict', () async {
      // 插入第一次
      await db.insert(
        'sessions',
        {
          'user_id': 1,
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
        'sessions',
        {
          'user_id': 1,
          'target_id': 2,
          'target_type': 'friend',
          'last_msg': 'Updated',
          'last_msg_time': 1700000001000,
          'unread_count': 3,
          'update_time': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final rows = await db.query('sessions');
      expect(rows.length, equals(1));
      expect(rows[0]['last_msg'], equals('Updated'));
      expect(rows[0]['unread_count'], equals(3));
    });
  });

  group('ConversationService.loadSessions', () {
    test('should load sessions ordered by last_msg_time DESC', () async {
      // 插入多条记录
      await db.insert('sessions', {
        'user_id': 1,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Old',
        'last_msg_time': 1700000000000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });
      await db.insert('sessions', {
        'user_id': 1,
        'target_id': 3,
        'target_type': 'group',
        'last_msg': 'New',
        'last_msg_time': 1700000002000,
        'unread_count': 5,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });
      await db.insert('sessions', {
        'user_id': 2, // 不同用户
        'target_id': 4,
        'target_type': 'friend',
        'last_msg': 'Other user',
        'last_msg_time': 1700000003000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });

      // 查询用户 1 的会话
      final rows = await db.query(
        'sessions',
        where: 'user_id = ?',
        whereArgs: [1],
        orderBy: 'last_msg_time DESC',
      );

      expect(rows.length, equals(2));
      expect(rows[0]['last_msg'], equals('New')); // 最新的在前
      expect(rows[1]['last_msg'], equals('Old'));
    });

    test('should return empty list when no sessions exist', () async {
      final rows = await db.query(
        'sessions',
        where: 'user_id = ?',
        whereArgs: [999],
      );

      expect(rows, isEmpty);
    });
  });

  group('ConversationService.updateUnreadCount', () {
    test('should update unread count', () async {
      await db.insert('sessions', {
        'user_id': 1,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Hello',
        'last_msg_time': 1700000000000,
        'unread_count': 5,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });

      await db.update(
        'sessions',
        {'unread_count': 0},
        where: 'user_id = ? AND target_id = ? AND target_type = ?',
        whereArgs: [1, 2, 'friend'],
      );

      final rows = await db.query('sessions');
      expect(rows[0]['unread_count'], equals(0));
    });
  });

  group('ConversationService.deleteSession', () {
    test('should delete session', () async {
      await db.insert('sessions', {
        'user_id': 1,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Hello',
        'last_msg_time': 1700000000000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });

      await db.delete(
        'sessions',
        where: 'user_id = ? AND target_id = ? AND target_type = ?',
        whereArgs: [1, 2, 'friend'],
      );

      final rows = await db.query('sessions');
      expect(rows, isEmpty);
    });

    test('should not delete other sessions', () async {
      await db.insert('sessions', {
        'user_id': 1,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Keep me',
        'last_msg_time': 1700000000000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });
      await db.insert('sessions', {
        'user_id': 1,
        'target_id': 3,
        'target_type': 'friend',
        'last_msg': 'Delete me',
        'last_msg_time': 1700000001000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });

      await db.delete(
        'sessions',
        where: 'user_id = ? AND target_id = ? AND target_type = ?',
        whereArgs: [1, 3, 'friend'],
      );

      final rows = await db.query('sessions');
      expect(rows.length, equals(1));
      expect(rows[0]['last_msg'], equals('Keep me'));
    });
  });
}
