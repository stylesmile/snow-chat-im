import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/core/database/database_helper.dart';
import 'package:snow_chat/core/database/tables.dart';

void main() {
  // 桌面端使用内存 SQLite 运行测试
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const testUserId = 1;

  /// 构造一个早期版本创建的会话表结构：缺 is_pinned 列
  /// 用于模拟存量用户本地库升级到支持置顶功能之前的老表
  String legacySessionsTable(int userId) => '''
    CREATE TABLE IF NOT EXISTS ${Tables.sessionsTable(userId)} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      target_id INTEGER NOT NULL,
      target_type TEXT NOT NULL,
      last_msg TEXT DEFAULT '',
      last_msg_time INTEGER,
      unread_count INTEGER DEFAULT 0,
      is_muted INTEGER DEFAULT 0,
      update_time INTEGER,
      UNIQUE(user_id, target_id, target_type)
    )
  ''';

  late Database db;

  setUp(() async {
    // 用最新建表 SQL 建库（含 is_pinned），供基线用例使用
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(Tables.createSessionsTable(testUserId));
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('DatabaseHelper.ensurePinnedColumn', () {
    test('应给缺失 is_pinned 的旧会话表补齐该列', () async {
      final table = Tables.sessionsTable(testUserId);
      // 先清掉 onCreate 建的表，手动重建为老结构（无 is_pinned）
      await db.execute('DROP TABLE $table');
      await db.execute(legacySessionsTable(testUserId));

      // 执行迁移：补齐 is_pinned 列
      await DatabaseHelper.ensurePinnedColumn(db, table);

      // 验证补充后能插入并读回 is_pinned 字段（补列成功则不会抛异常）
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 2,
        'target_type': 'friend',
        'last_msg': 'Hello',
        'last_msg_time': 1700000000000,
        'unread_count': 0,
        'is_pinned': 1,
        'is_muted': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });
      final rows = await db.query(table);
      expect(rows.length, equals(1));
      expect(rows[0]['is_pinned'], equals(1));
    });

    test('已含 is_pinned 的表再次迁移应保持幂等（不报错）', () async {
      final table = Tables.sessionsTable(testUserId);
      // 当前表已含 is_pinned，重复调用不应失败，也不应破坏数据
      await DatabaseHelper.ensurePinnedColumn(db, table);
      await DatabaseHelper.ensurePinnedColumn(db, table);

      // 数据仍可正常写入读取
      await db.insert(table, {
        'user_id': testUserId,
        'target_id': 3,
        'target_type': 'friend',
        'last_msg': 'Hi',
        'last_msg_time': 1700000000000,
        'unread_count': 0,
        'update_time': DateTime.now().millisecondsSinceEpoch,
      });
      final rows = await db.query(table);
      expect(rows.length, equals(1));
      expect(rows[0]['is_pinned'], equals(0)); // 默认值 0
    });
  });
}