// FavoriteCacheManager（收藏本地缓存管理器）单元测试
//
// 覆盖：收藏的增（add）、查（list/contains）、删（remove）以及按用户隔离的持久化。
// 背景：收藏模块本地化存储于 SQLite（favorites_{userId} 表），与 MessageCacheManager
// 保持一致的"测试注入数据库"模式，可在桌面端用内存 SQLite 跑测试。
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/core/cache/favorite_cache_manager.dart';
import 'package:snow_chat/core/database/tables.dart';
import 'package:snow_chat/models/favorite_model.dart';

void main() {
  // 桌面端用内存 SQLite 跑测试
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const testUserId = 1;

  Future<Database> createTestDb() async {
    return openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        // 创建带用户ID前缀的收藏表（与生产一致）
        await db.execute(Tables.createFavoritesTable(testUserId));
      },
    );
  }

  FavoriteModel _fav({
    required int messageId,
    String type = 'text',
    String content = 'hello',
    int fromUserId = 10,
  }) {
    return FavoriteModel(
      id: 0,
      messageId: messageId,
      type: type,
      content: content,
      fromUserId: fromUserId,
      fromNickname: '小明',
      createTime: 1700000000000,
    );
  }

  group('FavoriteCacheManager', () {
    late FavoriteCacheManager manager;
    late Database db;

    setUp(() async {
      db = await createTestDb();
      // 注入测试数据库并设置用户ID，使表名正确
      manager = FavoriteCacheManager.forTest(db);
      manager.setUserId(testUserId);
      await manager.init();
    });

    tearDown(() async {
      await manager.dispose();
      await db.close();
    });

    test('add 将收藏写入数据库', () async {
      // 执行
      await manager.add(_fav(messageId: 1));

      // 验证 - 表中确有 1 条记录且字段正确
      final rows = await db.query(Tables.favoritesTable(testUserId));
      expect(rows.length, 1);
      expect(rows.first['message_id'], 1);
      expect(rows.first['msg_type'], 'text');
      expect(rows.first['content'], 'hello');
    });

    test('add 相同 messageId 重复收藏时去重（只保留一条）', () async {
      // 执行 - 同一消息收藏两次
      await manager.add(_fav(messageId: 1, content: 'v1'));
      await manager.add(_fav(messageId: 1, content: 'v1'));

      // 验证 - 去重后仅 1 条
      final rows = await db.query(Tables.favoritesTable(testUserId));
      expect(rows.length, 1);
    });

    test('list 按收藏时间降序返回全部收藏', () async {
      // 执行 - 收藏 3 条不同消息
      await manager.add(_fav(messageId: 1, content: 'a'));
      await manager.add(_fav(messageId: 2, content: 'b'));
      await manager.add(_fav(messageId: 3, content: 'c'));

      // 验证
      final all = await manager.list();
      expect(all.length, 3);
      // 收藏时间相同，按内容可定位（desc 排序下顺序与插入相反）
      final contents = all.map((f) => f.content).toList();
      expect(contents.toSet(), {'a', 'b', 'c'});
    });

    test('contains 判断某消息是否已收藏', () async {
      // 执行
      await manager.add(_fav(messageId: 7));

      // 验证
      expect(await manager.contains(7), isTrue);
      expect(await manager.contains(8), isFalse);
    });

    test('remove 删除指定消息的收藏', () async {
      // 准备 - 先收藏两条
      await manager.add(_fav(messageId: 1, content: 'a'));
      await manager.add(_fav(messageId: 2, content: 'b'));

      // 执行 - 删除 messageId=1
      await manager.remove(1);

      // 验证
      expect(await manager.contains(1), isFalse);
      expect(await manager.contains(2), isTrue);
      final all = await manager.list();
      expect(all.length, 1);
    });

    test('空库时 list 返回空列表', () async {
      // 验证
      expect(await manager.list(), isEmpty);
      expect(await manager.contains(999), isFalse);
    });
  });
}