// FavoritesScreen（我的收藏）widget 测试
//
// 覆盖四类场景：
// 1. 无收藏时显示空态文案"暂无收藏"
// 2. 有文本收藏时展示内容与来源昵称
// 3. 图片类型收藏以"图片"占位文案展示
// 4. 长按并确认取消收藏后，该条从列表移除并回到空态
//
// 关键实践：sqflite ffi 是真实 IO，在 widget 测试的 fake-async 时钟下无法自动完成，
// 因此所有涉及数据库读写的操作都包在 tester.runAsync 里执行，确保其真正 await 完成。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/core/cache/favorite_cache_manager.dart';
import 'package:snow_chat/core/database/tables.dart';
import 'package:snow_chat/models/favorite_model.dart';
import 'package:snow_chat/ui/screens/favorites_screen.dart';

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

  FavoriteModel favTest({
    required int messageId,
    String type = 'text',
    String content = 'hello',
    String nick = '小明',
  }) {
    return FavoriteModel(
      id: 0,
      messageId: messageId,
      type: type,
      content: content,
      fromUserId: 10,
      fromNickname: nick,
      createTime: 1700000000000,
    );
  }

  // 构造被测页面：深色主题 + 本地化委托，模拟真实运行环境
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      locale: const Locale('zh'),
      home: child,
    );
  }

  // 在 runAsync 内 pumpWidget 并真实等待，让 initState 触发的真实 SQLite IO 完成
  Future<void> pumpScreen(WidgetTester tester, FavoriteCacheManager cache) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(wrap(FavoritesScreen(cache: cache, userId: testUserId)));
      // 真实等待：让 cache.list() 的真实 IO 返回并触发 setState 刷新
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    // 退出 runAsync 后触发重建，展示加载结果（数据或空态）
    await tester.pump();
  }

  group('FavoritesScreen 我的收藏', () {
    testWidgets('空收藏时显示空态文案"暂无收藏"', (tester) async {
      final db = (await tester.runAsync(createTestDb))!;
      final cache = FavoriteCacheManager.forTest(db)..setUserId(testUserId);
      await tester.runAsync(() => cache.init());

      await pumpScreen(tester, cache);

      expect(find.text('暂无收藏'), findsOneWidget);
      await tester.runAsync(() => db.close());
    });

    testWidgets('有文本收藏时展示内容和来源昵称', (tester) async {
      final db = (await tester.runAsync(createTestDb))!;
      final cache = FavoriteCacheManager.forTest(db)..setUserId(testUserId);
      await tester.runAsync(() async {
        await cache.init();
        await cache.add(favTest(messageId: 1, content: '这是收藏的文本'));
      });

      await pumpScreen(tester, cache);

      expect(find.text('这是收藏的文本'), findsOneWidget);
      expect(find.textContaining('小明'), findsOneWidget);
      await tester.runAsync(() => db.close());
    });

    testWidgets('图片类型收藏以"图片"占位文案展示', (tester) async {
      final db = (await tester.runAsync(createTestDb))!;
      final cache = FavoriteCacheManager.forTest(db)..setUserId(testUserId);
      await tester.runAsync(() async {
        await cache.init();
        await cache.add(favTest(messageId: 2, type: 'image', content: 'http://host/img.png'));
      });

      await pumpScreen(tester, cache);

      // 图片类型标题处渲染"图片"文案
      expect(find.text('图片'), findsWidgets);
      await tester.runAsync(() => db.close());
    });

    testWidgets('长按并确认取消收藏后从列表移除并回到空态', (tester) async {
      final db = (await tester.runAsync(createTestDb))!;
      final cache = FavoriteCacheManager.forTest(db)..setUserId(testUserId);
      await tester.runAsync(() async {
        await cache.init();
        await cache.add(favTest(messageId: 1, content: '待删除的收藏'));
      });

      await pumpScreen(tester, cache);
      expect(find.text('待删除的收藏'), findsOneWidget);

      // 长按触发"取消收藏"确认框
      await tester.longPress(find.text('待删除的收藏'));
      await tester.pumpAndSettle();
      // 确认框出现"取消收藏"动作按钮
      expect(find.widgetWithText(TextButton, '取消收藏'), findsOneWidget);

      // 点击确认按钮执行删除：在同一 runAsync 区内同时推进帧（让 dialog pop 完成）
      // 并让出事件循环（让 removeById 真实 SQLite IO 完成）
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(TextButton, '取消收藏'));
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await Future<void>.delayed(Duration.zero);
        }
      });
      // 重建界面，展示删除后的空态
      await tester.pump();

      // 该项已移除并回到空态
      expect(find.text('待删除的收藏'), findsNothing);
      expect(find.text('暂无收藏'), findsOneWidget);
      await tester.runAsync(() => db.close());
    });
  });
}