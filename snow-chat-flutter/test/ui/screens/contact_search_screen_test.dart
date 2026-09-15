// 通讯录搜索页 widget 测试
//
// 背景：通讯录标题栏的搜索按钮此前误跳「添加好友」页（与同排的 person_add
// 按钮功能重复），在通讯录里搜好友搜不到。改为打开只检索本机好友的
// ContactSearchScreen 后，本测试锁定以下契约：
//
// 1. 关键词为空时列出全部好友（进页即可点选，不是空白页）
// 2. 昵称、备注、拼音全拼、拼音首字母四种输入都能命中
// 3. 无命中显示「未找到相关内容」，通讯录为空显示「暂无联系人」（两态区分）
// 4. 展示名口径与通讯录列表一致：有备注优先用备注
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:snow_chat/core/theme/app_theme.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/models/friend_model.dart';
import 'package:snow_chat/ui/screens/contact_search_screen.dart';

void main() {
  /// 测试用好友：avatar 留空以避免网络图片请求
  final friends = <FriendModel>[
    FriendModel(userId: 1, nickname: '张三'),
    FriendModel(userId: 2, nickname: '李四'),
    FriendModel(userId: 3, nickname: 'wangwu', remark: '老王'),
  ];

  Widget makeTestableWidget(List<FriendModel> list) {
    return MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      locale: const Locale('zh'),
      home: ContactSearchScreen(friends: list),
    );
  }

  /// 输入关键词并等待界面刷新
  Future<void> search(WidgetTester tester, String keyword) async {
    await tester.enterText(find.byType(TextField), keyword);
    await tester.pump();
  }

  /// 只在结果条目里找文字。
  ///
  /// 不能直接 find.text：输入框（EditableText）里也是同样的字符串，
  /// 直接找会同时命中「输入框内容」和「结果条目标题」，导致计数翻倍。
  Finder tileText(String text) =>
      find.descendant(of: find.byType(ListTile), matching: find.text(text));

  testWidgets('关键词为空时列出全部好友', (tester) async {
    await tester.pumpWidget(makeTestableWidget(friends));
    await tester.pump();

    // 3 个好友各一条，无空态提示
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('未找到相关内容'), findsNothing);
  });

  testWidgets('按昵称匹配', (tester) async {
    await tester.pumpWidget(makeTestableWidget(friends));
    await search(tester, '李四');

    expect(tileText('李四'), findsOneWidget);
    expect(tileText('张三'), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('按备注匹配，且展示名优先用备注', (tester) async {
    await tester.pumpWidget(makeTestableWidget(friends));
    await search(tester, '老王');

    // 命中备注为「老王」的好友，标题显示备注、副标题显示原昵称
    expect(tileText('老王'), findsOneWidget);
    expect(tileText('wangwu'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('按拼音全拼匹配：zhangsan 命中 张三', (tester) async {
    await tester.pumpWidget(makeTestableWidget(friends));
    await search(tester, 'zhangsan');

    expect(tileText('张三'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('按拼音首字母匹配：zs 命中 张三', (tester) async {
    await tester.pumpWidget(makeTestableWidget(friends));
    await search(tester, 'zs');

    expect(tileText('张三'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('无命中时显示未找到相关内容', (tester) async {
    await tester.pumpWidget(makeTestableWidget(friends));
    await search(tester, '不存在的人');

    expect(find.text('未找到相关内容'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('通讯录为空时显示暂无联系人', (tester) async {
    await tester.pumpWidget(makeTestableWidget(const <FriendModel>[]));
    await tester.pump();

    expect(find.text('暂无联系人'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('清空按钮恢复全部好友', (tester) async {
    await tester.pumpWidget(makeTestableWidget(friends));
    await search(tester, 'zs');
    expect(find.byType(ListTile), findsOneWidget);

    // 输入非空时才出现清除按钮
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(find.byType(ListTile), findsNWidgets(3));
  });
}
