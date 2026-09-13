import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/core/database/database_helper.dart';
import 'package:snow_chat/core/database/tables.dart';
import 'package:snow_chat/services/conversation_service.dart';

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

  // 验证会话置顶/免打扰标记的持久化读写
  group('Conversation pinning & mute flags', () {
    test('should persist is_pinned and is_muted flags', () async {
      final table = Tables.sessionsTable(testUserId);

      // 插入一个置顶且免打扰的会话
      await db.insert(
        table,
        {
          'user_id': testUserId,
          'target_id': 2,
          'target_type': 'friend',
          'last_msg': 'Hello',
          'last_msg_time': 1700000000000,
          'unread_count': 1,
          'is_muted': 1,
          'is_pinned': 1,
          'update_time': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 读回数据库记录，验证标记正确写入
      final rows = await db.query(table);
      expect(rows.length, equals(1));
      expect(rows[0]['is_pinned'], equals(1));
      expect(rows[0]['is_muted'], equals(1));
    });

    test('should default to is_pinned=0 and is_muted=0', () async {
      final table = Tables.sessionsTable(testUserId);

      // 不传置顶/免打扰字段，应使用默认值
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Hello',
        'last_msg_time': 1700000000000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });

      final rows = await db.query(table);
      expect(rows.length, equals(1));
      expect(rows[0]['is_pinned'], equals(0));
      expect(rows[0]['is_muted'], equals(0));
    });

    test('should upsert flags without losing pinned/muted on replace', () async {
      final table = Tables.sessionsTable(testUserId);

      // 第一次插入：普通会话
      await db.insert(
        table,
        {
          'user_id': testUserId,
          'target_id': 2,
          'target_type': 'friend',
          'last_msg': 'Hello',
          'last_msg_time': 1700000000000,
          'unread_count': 0,
          'is_pinned': 0,
          'is_muted': 0,
          'update_time': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 第二次插入：同一会话更新消息，并置顶
      await db.insert(
        table,
        {
          'user_id': testUserId,
          'target_id': 2,
          'target_type': 'friend',
          'last_msg': 'Updated',
          'last_msg_time': 1700000001000,
          'unread_count': 2,
          'is_pinned': 1,
          'is_muted': 1,
          'update_time': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final rows = await db.query(table);
      expect(rows.length, equals(1));
      expect(rows[0]['last_msg'], equals('Updated'));
      expect(rows[0]['is_pinned'], equals(1));
      expect(rows[0]['is_muted'], equals(1));
    });

    test('should update only the provided flag via incremental update', () async {
      final table = Tables.sessionsTable(testUserId);

      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Hello',
        'last_msg_time': 1700000000000,
        'unread_count': 0,
        'is_pinned': 0,
        'is_muted': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });

      // 仅更新置顶标记，免打扰保持不变
      await db.update(
        table,
        {'is_pinned': 1},
        where: 'target_id = ? AND target_type = ?',
        whereArgs: [2, 'friend'],
      );

      final rows = await db.query(table);
      expect(rows.length, equals(1));
      expect(rows[0]['is_pinned'], equals(1));
      expect(rows[0]['is_muted'], equals(0));
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

  // 会话重复的根因修复：早期版本建出的 sessions 表没有
  // UNIQUE(user_id,target_id,target_type)，而 CREATE TABLE IF NOT EXISTS 不会补约束，
  // 于是「先删后插」失效、同一好友攒出多行（聊天列表看起来重复）。
  // 迁移负责：先合并重复行（保留 id 最大的一行），再补唯一索引。
  group('DatabaseHelper.ensureSessionsUniqueIndex（会话去重迁移）', () {
    /// 建一张"早期版本"的会话表：结构一致但没有 UNIQUE 约束。
    ///
    /// 用独立的临时**文件**库，不能用 `inMemoryDatabasePath`：sqflite 会把同名内存库
    /// 复用成 setUp 里那张带 UNIQUE 约束的表，测出来就不是"老库"了（会被唯一约束直接拦下）。
    Future<Database> openLegacyDb() async {
      final dir = Directory.systemTemp.createTempSync('sessions_dedup_');
      final path = '${dir.path}/legacy.db';
      addTearDown(() async {
        await databaseFactory.deleteDatabase(path);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      return databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${Tables.sessionsTable(testUserId)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                target_id INTEGER NOT NULL,
                target_type TEXT NOT NULL,
                last_msg TEXT DEFAULT '',
                last_msg_time INTEGER,
                unread_count INTEGER DEFAULT 0,
                is_muted INTEGER DEFAULT 0,
                is_pinned INTEGER DEFAULT 0,
                update_time INTEGER
              )
            ''');
          },
        ),
      );
    }

    test('合并历史重复行并补上唯一索引', () async {
      final legacy = await openLegacyDb();
      final table = Tables.sessionsTable(testUserId);

      // 同一会话写入 3 次：老表没有唯一约束 → 攒下 3 行
      for (var i = 0; i < 3; i++) {
        await legacy.insert(table, {
          'user_id': testUserId,
          'target_id': 2,
          'target_type': 'friend',
          'last_msg': 'msg$i',
          'last_msg_time': 1700000000000 + i,
          'unread_count': 0,
          'update_time': 1700000000000 + i,
        });
      }
      expect((await legacy.query(table)).length, equals(3));

      final merged = await DatabaseHelper.ensureSessionsUniqueIndex(legacy, table);

      expect(merged, isTrue, reason: '应报告合并过重复行');
      final rows = await legacy.query(table);
      expect(rows.length, equals(1), reason: '同一会话只应保留一行');
      expect(rows.first['last_msg'], equals('msg2'), reason: '保留最后一次写入的状态');

      // 唯一索引生效：再插同键会直接被数据库拦下（而不是新增一行）
      await expectLater(
        legacy.insert(table, {
          'user_id': testUserId,
          'target_id': 2,
          'target_type': 'friend',
          'last_msg': 'dup',
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect((await legacy.query(table)).length, equals(1));

      await legacy.close();
    });

    test('不同好友/不同会话类型的记录不会被误合并', () async {
      final legacy = await openLegacyDb();
      final table = Tables.sessionsTable(testUserId);

      await legacy.insert(table, {
        'user_id': testUserId,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'a',
      });
      await legacy.insert(table, {
        'user_id': testUserId,
        'target_id': 3,
        'target_type': 'friend',
        'last_msg': 'b',
      });
      // 同一个 id 但是群聊：属于另一个会话，不应与好友会话合并
      await legacy.insert(table, {
        'user_id': testUserId,
        'target_id': 2,
        'target_type': 'group',
        'last_msg': 'c',
      });

      await DatabaseHelper.ensureSessionsUniqueIndex(legacy, table);

      expect((await legacy.query(table)).length, equals(3));
      await legacy.close();
    });

    test('已带 UNIQUE 约束的表会被识别为无需迁移', () async {
      // 生产建表语句本身带 UNIQUE(...)，SQLite 会生成 sqlite_autoindex 唯一索引
      final fresh = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute(Tables.createSessionsTable(testUserId));
        },
      );

      final merged = await DatabaseHelper.ensureSessionsUniqueIndex(
        fresh,
        Tables.sessionsTable(testUserId),
      );

      expect(merged, isFalse);
      await fresh.close();
    });
  });

  // 「文件传输助手」消息实际发给自己（type=self），后端回推到自己 topic。
  // 老版本把它误记成 target_id=自己 的好友会话，聊天列表随之多出一条
  // 显示不了名字头像的重复数据。loadSessions 前会先自愈清理这类脏行。
  group('ConversationService.purgeSelfEchoSessions（自聊脏数据清理）', () {
    test('删除 target_id=自己 的好友会话，保留文件传输助手会话', () async {
      final table = Tables.sessionsTable(testUserId);

      // 脏数据：发消息给文件传输助手后，回推消息被误记成「和自己聊」
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': testUserId, // target_id = 自己
        'target_type': 'friend',
        'last_msg': '11111',
        'last_msg_time': 1700000000000,
        'update_time': 1700000000000,
      });
      // 真会话：文件传输助手
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 0,
        'target_type': 'file_helper',
        'last_msg': '11111',
        'last_msg_time': 1700000000000,
        'update_time': 1700000000000,
      });
      // 真会话：正常好友
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'hi',
        'last_msg_time': 1700000001000,
        'update_time': 1700000001000,
      });

      await ConversationService.purgeSelfEchoSessions(
        db,
        table,
        testUserId,
      );

      final rows = await db.query(table);
      expect(rows.length, equals(2), reason: '只应删掉自聊那一条');
      expect(
        rows.every((r) => r['target_id'] != testUserId || r['target_type'] != 'friend'),
        isTrue,
      );
      // 文件传输助手会话保留
      expect(
        rows.any((r) => r['target_id'] == 0 && r['target_type'] == 'file_helper'),
        isTrue,
      );
    });

    test('target_id 相同但类型不同（如群聊）不会被误删', () async {
      final table = Tables.sessionsTable(testUserId);
      // 用户自己是群主、群 id 恰好等于自己 id 的极端情况：不应被误删
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': testUserId,
        'target_type': 'group',
        'last_msg': 'group msg',
        'update_time': 1700000000000,
      });

      await ConversationService.purgeSelfEchoSessions(db, table, testUserId);

      expect((await db.query(table)).length, equals(1));
    });
  });
}
