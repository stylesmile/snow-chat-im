import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/providers/chat_provider.dart';
import 'package:snow_chat/providers/friend_request_provider.dart';
import 'package:snow_chat/ui/screens/chat_list_tab.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// ChatListTab 生命周期与好友目录刷新监听测试
///
/// 重点回归：ChatListTab 在 dispose 时必须解除对全局
/// [FriendRequestProvider.friendListVersion] 的监听。之前实现里 initState
/// 注册了两个监听（widget.friendAcceptedNotifier 与静态 friendListVersion），
/// dispose 却只移除前者，漏掉了 friendListVersion，导致「同意好友 → 广播
/// notifyFriendListChanged → 调用已卸载 State 的 _onFriendAccepted → 访问已失效
/// context」从而抛出 "This widget has been unmounted" 并卡死。
void main() {
  // 初始化 sqflite FFI，满足 AuthProvider.init 对 SQLite 表的使用需求
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AuthProvider auth;
  late FriendRequestProvider friendRequestProvider;

  setUp(() async {
    // 初始化 SharedPreferences mock，不要设置 userId，避免：
    // 1. didChangeDependencies 触发 startPolling（产生 30s 轮询 Timer）
    // 2. 测试结束后 timer 仍 pending，让 flutter_test 判定失败
    // 我们只验证 dispose 移除监听这件事，无需完整加载会话列表
    SharedPreferences.setMockInitialValues({
      'isLoggedIn': false,
    });
    auth = AuthProvider('http://localhost:8091');
    await auth.init();
    friendRequestProvider = FriendRequestProvider(auth.apiClient);
  });

  tearDown(() {
    // 清理轮询定时器，避免 widget 树卸载后仍残留 pending Timer
    friendRequestProvider.stopPolling(notify: false);
  });

  /// 构建仅含 ChatListTab 的最小 widget 树
  Widget buildScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ChangeNotifierProvider<FriendRequestProvider>.value(
          value: friendRequestProvider,
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('zh'), Locale('en')],
        locale: Locale('zh'),
        home: Scaffold(body: ChatListTab()),
      ),
    );
  }

  testWidgets('dispose 后应解除对 friendListVersion 的监听', (tester) async {
    // 执行：先挂载 ChatListTab
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    // 挂载时静态广播器应被该 tab 监听
    expect(FriendRequestProvider.friendListVersion.hasListeners, isTrue,
        reason: '挂载 ChatListTab 后 friendListVersion 应被监听');

    // 执行：卸载 ChatListTab（用空 widget 置换触发 dispose）
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // 验证：dispose 后全局广播器不再持有该 tab 的监听，
    // 避免触发已卸载 State 的回调导致 "unmounted context" 崩溃
    expect(FriendRequestProvider.friendListVersion.hasListeners, isFalse,
        reason: 'dispose 后 friendListVersion 不应残留监听');
  });

  testWidgets('切换 Tab 再切回不应重建 State（保持会话列表不重新渲染）', (tester) async {
    // 准备：用 TabBarView 承载 ChatListTab，模拟底部导航的左右切换
    final controller = TabController(length: 2, vsync: tester);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
          ChangeNotifierProvider<FriendRequestProvider>.value(
            value: friendRequestProvider,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: Scaffold(
            body: TabBarView(
              controller: controller,
              children: const [ChatListTab(), SizedBox()],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 记录当前（第一个 tab）ChatListTab 的 State 实例
    final stateBefore =
        tester.state<State<ChatListTab>>(find.byType(ChatListTab).first);

    // 执行：切到第二个 tab，再切回去
    controller.animateTo(1);
    await tester.pumpAndSettle();
    controller.animateTo(0);
    await tester.pumpAndSettle();

    // 验证：切回后仍是同一个 State（keep-alive），
    // 没有走 initState 重新加载会话（否则会出现 loading 闪屏）
    final stateAfter =
        tester.state<State<ChatListTab>>(find.byType(ChatListTab).first);
    expect(identical(stateBefore, stateAfter), isTrue,
        reason: '切换 Tab 后 ChatListTab 应保留原 State，避免重新渲染');
  });
}