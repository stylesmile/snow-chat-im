import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/core/cache/message_cache_manager.dart';
import 'package:snow_chat/core/database/tables.dart';
import 'package:snow_chat/models/message_model.dart';

void main() {
  // 在桌面端使用内存 SQLite 跑测试
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<Database> _createTestDb() async {
    return openDatabase(
      inMemoryDatabasePath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute(Tables.createMessagesTable);
        await db.execute(Tables.createMessagesSessionIndex);
      },
    );
  }

  group('MessageCacheManager', () {
    late MessageCacheManager manager;
    late Database db;

    setUp(() async {
      db = await _createTestDb();
      manager = MessageCacheManager.forTest(db);
      await manager.init();
    });

    tearDown(() async {
      await manager.dispose();
      await db.close();
    });

    test('appendMessage writes message to database', () async {
      final msg = _message(id: 1, fromUserId: 10, toUserId: 42, createTime: 1000);
      await manager.appendMessage('u_10_42', msg);

      final rows = await db.query('local_messages');
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
      await _seedDb(db, 'u_10_42', [
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
  });
}

Future<void> _seedDb(Database db, String sessionId, List<MessageModel> messages) async {
  final batch = db.batch();
  for (final msg in messages) {
    batch.insert('local_messages', {
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
}) {
  return MessageModel(
    id: id,
    fromUserId: fromUserId,
    toUserId: toUserId,
    groupId: groupId,
    type: 'text',
    content: 'msg_$id',
    status: 'sent',
    createTime: createTime,
  );
}
