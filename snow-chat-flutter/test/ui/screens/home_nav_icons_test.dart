// 底部导航图标 widget 测试
//
// 背景：底部「聊天 / 通讯录 / 个人」三个 tab 的图标已改用对标项目
// win-chat-android（wkuikit 模块）的设计稿图形，替换原先的 Material 内置图标。
// 本测试锁定以下渲染契约，防止后续改动把图标换回内置图标或漏掉染色：
//
// 1. 未选中态使用描边图（chat / contract / my），染成中灰 navUnselected
// 2. 选中态使用实心图（chat_s / contract_s / my_s），染成强调金 accent
// 3. 红色未读角标在选中与未选中两种状态下都必须渲染
//
// 测试策略：
// - AuthProvider 未登录（userId == null）时，HomeScreen.didChangeDependencies
//   会跳过好友请求轮询与 MQTT 连接，从而绕开网络依赖
// - Flutter 的 BottomNavigationBar 内部只渲染「选中项用 activeIcon、其余用 icon」
//   （见 material/bottom_navigation_bar.dart 的 _TileIcon.build），
//   因此对两种状态的断言直接读取 BottomNavigationBar.items，而不依赖渲染树
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_chat/core/theme/app_theme.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/providers/chat_provider.dart';
import 'package:snow_chat/providers/friend_request_provider.dart';
import 'package:snow_chat/ui/screens/home_screen.dart';

void main() {
  late AuthProvider authProvider;
  late ChatProvider chatProvider;
  late FriendRequestProvider friendRequestProvider;

  // 图标资源路径：与 home_screen.dart 中 _nav*Icon 常量保持一致
  const chatIcon = 'assets/images/navigation/chat.png';
  const chatIconActive = 'assets/images/navigation/chat_s.png';
  const contactsIcon = 'assets/images/navigation/contract.png';
  const contactsIconActive = 'assets/images/navigation/contract_s.png';
  const profileIcon = 'assets/images/navigation/my.png';
  const profileIconActive = 'assets/images/navigation/my_s.png';

  setUp(() {
    // 初始化 SharedPreferences mock（AuthProvider 依赖）
    SharedPreferences.setMockInitialValues({});
    // 未登录状态：userId == null → 不启动轮询与 MQTT，不触碰网络/SQLite
    authProvider = AuthProvider('http://localhost:8091');
    chatProvider = ChatProvider();
    friendRequestProvider = FriendRequestProvider(authProvider.apiClient);
  });

  /// 构造测试 widget 树：注入 HomeScreen 所需的三个 Provider + 深色主题
  Widget makeTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
        ChangeNotifierProvider<FriendRequestProvider>.value(value: friendRequestProvider),
      ],
      child: MaterialApp(
        // 使用 WINCHAT 深色主题，验证图标在近黑底上的呈现
        theme: AppTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        home: const HomeScreen(),
      ),
    );
  }

  /// 从导航项图标控件中剥出 [Image]
  ///
  /// 有未读角标时 `_buildNavItemIcon` 返回 Stack（图标 + 角标），
  /// 无角标时直接返回 Image，这里统一取出其中的图标本体。
  Image extractIconImage(Widget widget) {
    if (widget is Image) {
      return widget;
    }
    if (widget is Stack) {
      return widget.children.whereType<Image>().single;
    }
    fail('底部导航图标应为 Image 或含 Image 的 Stack，实际为 ${widget.runtimeType}');
  }

  /// 读取 Image 所使用的资源名，并断言它来自打包资源（而非网络图片）
  String assetNameOf(Image image) {
    final provider = image.image;
    expect(provider, isA<AssetImage>(), reason: '导航图标应来自 assets 打包资源');
    return (provider as AssetImage).assetName;
  }

  /// 判断导航项图标是否叠加了未读角标
  ///
  /// `_buildNavItemIcon` 仅在需要角标时才返回 Stack，并以 Positioned 定位角标，
  /// 故「是 Stack 且含 Positioned」即等价于「渲染了角标」。
  bool rendersBadge(Widget widget) {
    return widget is Stack && widget.children.whereType<Positioned>().isNotEmpty;
  }

  /// 取出当前渲染树中 BottomNavigationBar 的 items，便于断言两种状态
  List<BottomNavigationBarItem> navItemsOf(WidgetTester tester) {
    return tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).items;
  }

  /// 取出图标上叠加的角标控件（Positioned），无角标时返回 null
  ///
  /// `_buildNavItemIcon` 需要角标时返回 Stack（图标 + Positioned 角标），
  /// 无角标时直接返回 Image。
  Positioned? badgeOf(Widget widget) {
    if (widget is! Stack) return null;
    return widget.children.whereType<Positioned>().firstOrNull;
  }

  /// 断言角标是微信风格的"纯红点"（红色圆形、不带数字文本）
  void expectWeChatStyleDot(Positioned? badge) {
    expect(badge, isNotNull, reason: '有未读好友申请时应渲染红点');
    final child = badge!.child;
    expect(child, isA<Container>(), reason: '红点应为 Container 绘制的圆形');
    final box = child as Container;
    final decoration = box.decoration as BoxDecoration?;
    expect(decoration?.color, Colors.red, reason: '红点应为红色（微信风格）');
    expect(decoration?.shape, BoxShape.circle, reason: '红点应为圆形');
    expect(box.child, isNull, reason: '纯红点不应带数字文本');
  }

  group('底部导航图标（设计稿图形）', () {
    testWidgets('三个 tab 均使用 assets/images/navigation 下的设计稿 PNG', (tester) async {
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      final items = navItemsOf(tester);
      expect(items.length, 3, reason: '底部导航应为 聊天/通讯录/个人 三项');

      // 未选中态：描边图
      expect(assetNameOf(extractIconImage(items[0].icon)), chatIcon, reason: '会话未选中应为描边图');
      expect(assetNameOf(extractIconImage(items[1].icon)), contactsIcon, reason: '通讯录未选中应为描边图');
      expect(assetNameOf(extractIconImage(items[2].icon)), profileIcon, reason: '个人中心未选中应为描边图');

      // 选中态：实心图
      expect(assetNameOf(extractIconImage(items[0].activeIcon)), chatIconActive, reason: '会话选中应为实心图');
      expect(
        assetNameOf(extractIconImage(items[1].activeIcon)),
        contactsIconActive,
        reason: '通讯录选中应为实心图',
      );
      expect(
        assetNameOf(extractIconImage(items[2].activeIcon)),
        profileIconActive,
        reason: '个人中心选中应为实心图',
      );
    });

    testWidgets('未选中图标染成中灰、选中图标染成强调金', (tester) async {
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      final items = navItemsOf(tester);
      for (final item in items) {
        // 未选中：中灰，保证在 #111111 深底上可辨认
        expect(
          extractIconImage(item.icon).color,
          AppTheme.navUnselected,
          reason: '未选中图标应使用 navUnselected 中灰',
        );
        // 选中：强调金，与登录页主按钮同色
        expect(
          extractIconImage(item.activeIcon).color,
          AppTheme.accent,
          reason: '选中图标应使用 accent 强调金',
        );
      }
    });

    testWidgets('默认选中第一个 tab 时应渲染实心的会话图标（金色）', (tester) async {
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 当前索引为 0（会话），BottomNavigationBar 应渲染 activeIcon
      final rendered = tester.widgetList<Image>(find.byType(Image)).toList();
      final activeChat = rendered.where((i) => assetNameOf(i) == chatIconActive).toList();
      expect(activeChat, hasLength(1), reason: '选中的会话 tab 应渲染 chat_s.png');
      expect(activeChat.single.color, AppTheme.accent, reason: '选中图标应为强调金');

      // 未选中的会话描边图不应出现在渲染树中
      expect(
        rendered.where((i) => assetNameOf(i) == chatIcon),
        isEmpty,
        reason: '选中态下不应同时渲染描边图',
      );
    });

    testWidgets('切换到通讯录 tab 后应渲染实心的通讯录图标（金色）', (tester) async {
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 点击底部导航的「通讯录」标签切换 tab
      await tester.tap(find.text('通讯录'));
      await tester.pumpAndSettle();

      final rendered = tester.widgetList<Image>(find.byType(Image)).toList();
      final activeContacts = rendered.where((i) => assetNameOf(i) == contactsIconActive).toList();
      expect(activeContacts, hasLength(1), reason: '选中的通讯录 tab 应渲染 contract_s.png');
      expect(activeContacts.single.color, AppTheme.accent, reason: '选中图标应为强调金');
    });
  });

  group('底部导航未读角标', () {
    testWidgets('有未读消息时，会话 tab 的选中与未选中图标都带角标', (tester) async {
      // 注入两条带未读的会话，使 ChatProvider.totalUnreadCount > 0
      chatProvider.setConversations([
        Conversation(
          targetId: 100,
          targetType: 'friend',
          lastMsg: 'hello',
          lastMsgTime: DateTime.now().millisecondsSinceEpoch,
          unreadCount: 2,
        ),
        Conversation(
          targetId: 200,
          targetType: 'friend',
          lastMsg: 'world',
          lastMsgTime: DateTime.now().millisecondsSinceEpoch,
          unreadCount: 3,
        ),
      ]);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      final chatItem = navItemsOf(tester)[0];
      expect(rendersBadge(chatItem.icon), isTrue, reason: '未选中态也应显示未读角标');
      expect(rendersBadge(chatItem.activeIcon), isTrue, reason: '选中态也应显示未读角标');

      // 角标数字为总未读数 2 + 3 = 5，且使用导航角标专属的小字号
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data == '5' && w.style?.fontSize == 8,
        ),
        findsOneWidget,
        reason: '角标应显示总未读数 5',
      );
    });

    testWidgets('无未读消息时不应渲染角标', (tester) async {
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      final items = navItemsOf(tester);
      expect(rendersBadge(items[0].icon), isFalse, reason: '无未读时会话 tab 不应有角标');
      expect(rendersBadge(items[2].icon), isFalse, reason: '个人中心永远不应有角标');
    });
  });

  group('通讯录 tab 好友申请红点', () {
    testWidgets('有未读好友申请时，通讯录图标显示微信风格的纯红点（无数字）', (tester) async {
      // 注入未读好友申请数（visibleForTesting，模拟轮询/MQTT 刷新后的状态）
      friendRequestProvider.forceUnread(2);

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      final contactsItem = navItemsOf(tester)[1];
      // 红点在选中与未选中两种状态下都必须渲染（tab 可能在任意状态下收到申请）
      expectWeChatStyleDot(badgeOf(contactsItem.icon));
      expectWeChatStyleDot(badgeOf(contactsItem.activeIcon));
    });

    testWidgets('无未读好友申请时，通讯录图标不渲染红点', (tester) async {
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      final contactsItem = navItemsOf(tester)[1];
      expect(badgeOf(contactsItem.icon), isNull, reason: '无申请时通讯录不应有红点');
      expect(badgeOf(contactsItem.activeIcon), isNull, reason: '无申请时通讯录不应有红点');
    });
  });
}
