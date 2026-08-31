import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/core/cache/message_cache_manager.dart';
import 'package:snow_chat/core/database/tables.dart';
import 'package:snow_chat/models/message_model.dart';

void main() {
  // 在桌面端使用内存 SQLite 跑测试
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const testUserId = 1;

  Future<Database> createTestDb() async {
    return openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        // 创建带用户ID前缀的表（与生产环境一致）
        await db.execute(Tables.createMessagesTable(testUserId));
        await db.execute(Tables.createMessagesSessionIndex(testUserId));
      },
    );
  }

  group('MessageCacheManager', () {
    late MessageCacheManager manager;
    late Database db;

    setUp(() async {
      db = await createTestDb();
      // 注入测试数据库，并设置用户ID使表名正确
      manager = MessageCacheManager.forTest(db);
      manager.setUserId(testUserId);
      await manager.init();
    });

    tearDown(() async {
      await manager.dispose();
      await db.close();
    });

    test('appendMessage writes message to database', () async {
      final msg = _message(id: 1, fromUserId: 10, toUserId: 42, createTime: 1000);
      await manager.appendMessage('u_10_42', msg);

      final table = Tables.messagesTable(testUserId);
      final rows = await db.query(table);
      expect(rows.length, 1);
      expect(rows.first['msg_id'], 1);
      expect(rows.first['session_id'], 'u_10_42');
    });

    test('recentMessages returns messages sorted ascending by createTime', () async {
      await manager.appendMessage('u_10_42', _message(id: 1, fromUserId: 10, toUserId: 42, createTime: 1000));
      await manager.appendMessage('u_10_42', _message(id: 2, fromUserId: 42, toUserId: 10, createTime: 2000));

      final recent = await manager.recentMessages('u_10_42', limit: 10);

      expect(recent.length, 2);
      expect(recent.first.createTime, 1000);
      expect(recent.last.createTime, 2000);
    });

    test('recentMessages loads from database when memory is empty', () async {
      await seedDb(db, 'u_10_42', [
        _message(id: 1, fromUserId: 10, toUserId: 42, createTime: 1000),
        _message(id: 2, fromUserId: 42, toUserId: 10, createTime: 2000),
      ]);
      manager.clearMemory();

      final recent = await manager.recentMessages('u_10_42', limit: 10);

      expect(recent.length, 2);
      expect(recent.first.id, 1);
      expect(recent.last.id, 2);
    });

    test('loadHistory returns older messages before given createTime', () async {
      final messages = [
        _message(id: 1, fromUserId: 10, toUserId: 42, createTime: 1000),
        _message(id: 2, fromUserId: 42, toUserId: 10, createTime: 2000),
        _message(id: 3, fromUserId: 42, toUserId: 10, createTime: 3000),
      ];
      for (final msg in messages) {
        await manager.appendMessage('u_10_42', msg);
      }

      final history = await manager.loadHistory('u_10_42', beforeTime: 3000, limit: 10);

      expect(history.length, 2);
      expect(history.map((m) => m.id).toList(), [1, 2]);
    });

    test('loadHistory returns empty when no older messages', () async {
      await manager.appendMessage('u_10_42', _message(id: 1, fromUserId: 10, toUserId: 42, createTime: 1000));

      final history = await manager.loadHistory('u_10_42', beforeTime: 500, limit: 10);

      expect(history, isEmpty);
    });

    test('appendMessage keeps recent messages in memory for fast access', () async {
      await manager.appendMessage('u_10_42', _message(id: 1, fromUserId: 10, toUserId: 42, createTime: 1000));

      // 不重新查 DB，直接读内存
      final recent = manager.recentMessagesSync('u_10_42');

      expect(recent.length, 1);
      expect(recent.first.id, 1);
    });

    group('clearSessionMessages', () {
      test('deletes all messages of the target session and keeps other sessions', () async {
        // 准备：目标会话两条 + 其它会话一条，用于验证定向删除
        await manager.appendMessage('u_10_42', _message(id: 1, fromUserId: 10, toUserId: 42, createTime: 1000));
        await manager.appendMessage('u_10_42', _message(id: 2, fromUserId: 42, toUserId: 10, createTime: 2000));
        await manager.appendMessage('u_10_55', _message(id: 3, fromUserId: 10, toUserId: 55, createTime: 3000));

        // 执行：清空目标会话
        await manager.clearSessionMessages('u_10_42');

        // 验证：目标会话记录清空
        final table = Tables.messagesTable(testUserId);
        final targetRows = await db.query(table, where: 'session_id = ?', whereArgs: ['u_10_42']);
        expect(targetRows, isEmpty);

        // 验证：其它会话的记录不受影响
        final otherRows = await db.query(table, where: 'session_id = ?', whereArgs: ['u_10_55']);
        expect(otherRows.length, 1);
      });

      test('clears the in-memory cache for the session', () async {
        // 准备：先写入使内存缓存中存在该会话
        await manager.appendMessage('u_10_42', _message(id: 1, fromUserId: 10, toUserId: 42, createTime: 1000));
        expect(manager.recentMessagesSync('u_10_42'), isNotEmpty);

        // 执行：清空会话
        await manager.clearSessionMessages('u_10_42');

        // 验证：内存缓存同步移除，读不到任何该会话消息
        expect(manager.recentMessagesSync('u_10_42'), isEmpty);
      });
    });

    group('searchMessages', () {
      test('returns matching messages across sessions ordered by latest first', () async {
        // 准备：两条命中（会话A、会话B）与一条不命中，验证跨会话 + 过滤
        await manager.appendMessage('u_10_42', _message(id: 1, fromUserId: 10, toUserId: 42, content: '你好 西瓜', createTime: 1000));
        await manager.appendMessage('u_10_55', _message(id: 2, fromUserId: 10, toUserId: 55, content: '晚上吃西瓜吗', createTime: 2000));
        await manager.appendMessage('u_10_66', _message(id: 3, fromUserId: 10, toUserId: 66, content: '完全无关的消息', createTime: 3000));

        // 执行：搜索关键词"西瓜"
        final hits = await manager.searchMessages('西瓜');

        // 验证：命中两条，按时间倒序（最新在前）
        expect(hits.length, 2);
        expect(hits.first.message.id, 2);
        expect(hits.first.sessionId, 'u_10_55');
        expect(hits.last.message.id, 1);
      });

      test('returns empty when no message matches', () async {
        // 准备：仅一条不含关键词的消息
        await manager.appendMessage('u_10_42', _message(id: 1, fromUserId: 10, toUserId: 42, content: '你好', createTime: 1000));

        // 执行：搜索不存在的关键词
        final hits = await manager.searchMessages('苹果');

        // 验证：无命中
        expect(hits, isEmpty);
      });
    });

    group('searchMessagesInSession', () {
      test('returns matching messages within the target session only', () async {
        // 准备：目标会话两条命中 + 其它会话一条命中，验证按会话隔离
        await manager.appendMessage('u_10_42', _message(id: 1, fromUserId: 10, toUserId: 42, content: '你好 西瓜', createTime: 1000));
        await manager.appendMessage('u_10_42', _message(id: 2, fromUserId: 42, toUserId: 10, content: '晚上吃西瓜吗', createTime: 2000));
        await manager.appendMessage('u_10_55', _message(id: 3, fromUserId: 10, toUserId: 55, content: '西瓜在这儿', createTime: 3000));

        // 执行：仅在会话 u_10_42 内搜索"西瓜"
        final hits = await manager.searchMessagesInSession('u_10_42', '西瓜');

        // 验证：仅返回目标会话的命中，且按时间倒序（最新在前）
        expect(hits.length, 2);
        expect(hits.first.message.id, 2);
        expect(hits.last.message.id, 1);
      });

      test('returns empty for a session with no matching content', () async {
        // 准备：目标会话中无关键词命中
        await manager.appendMessage('u_10_42', _message(id: 1, fromUserId: 10, toUserId: 42, content: '你好', createTime: 1000));

        // 执行：在会话内搜索不存在的关键词
        final hits = await manager.searchMessagesInSession('u_10_42', '苹果');

        // 验证：无命中
        expect(hits, isEmpty);
      });
    });
  });
}

Future<void> seedDb(Database db, String sessionId, List<MessageModel> messages) async {
  final table = Tables.messagesTable(1);
  final batch = db.batch();
  for (final msg in messages) {
    batch.insert(table, {
      'msg_id': msg.id,
      'session_id': sessionId,
      'from_user_id': msg.fromUserId,
      'to_user_id': msg.toUserId,
      'group_id': msg.groupId,
      'msg_type': msg.type,
      'content': msg.content,
      'status': msg.status,
      'create_time': msg.createTime,
      'update_time': DateTime.now().millisecondsSinceEpoch,
    });
  }
  await batch.commit(noResult: true);
}

MessageModel _message({
  required int id,
  required int fromUserId,
  int? toUserId,
  int? groupId,
  required int createTime,
  String? content,
}) {
  return MessageModel(
    id: id,
    fromUserId: fromUserId,
    toUserId: toUserId,
    groupId: groupId,
    type: 'text',
    content: content ?? 'msg_$id',
    status: 'sent',
    createTime: createTime,
  );
}
