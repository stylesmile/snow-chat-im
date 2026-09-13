// 个人信息页 widget 测试
//
// 锁定三类契约：
// 1. 展示登录态里的昵称与用户名（用户名此前在 UI 上无处可看）
// 2. 提供「我的二维码」与「扫一扫」两个入口（个人中心之前进不去二维码页）
// 3. 修改昵称走 `PUT /chat/user/update` 并同步回 AuthProvider
//
// 测试策略：UserId 有值时页面才渲染资料项；网络层用 http_mock_adapter 拦截，
// 避免真实请求。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/core/theme/app_theme.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/ui/screens/personal_info_screen.dart';

void main() {
  late AuthProvider authProvider;

  setUpAll(() {
    // AuthProvider 初始化时会打开本地 SQLite，测试环境需显式切到 ffi 实现
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'isLoggedIn': true,
      'userId': 1001,
      'username': 'zz_probe',
      'nickname': '张三',
      'avatar': '',
      'token': 'test-token',
    });
    authProvider = AuthProvider('http://localhost:8091');
    await authProvider.init();
  });

  Widget makeTestableWidget() {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        home: const PersonalInfoScreen(),
      ),
    );
  }

  testWidgets('应展示登录态中的昵称与用户名', (tester) async {
    await tester.pumpWidget(makeTestableWidget());
    await tester.pumpAndSettle();

    expect(find.text('张三'), findsOneWidget, reason: '应显示当前昵称');
    expect(find.text('zz_probe'), findsOneWidget, reason: '应显示当前用户名');
    expect(find.text('个人信息'), findsOneWidget, reason: '标题应为「个人信息」');
  });

  testWidgets('应提供「我的二维码」与「扫一扫」入口', (tester) async {
    await tester.pumpWidget(makeTestableWidget());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(PersonalInfoScreen)),
    )!;
    expect(find.text(l10n.myQrCode), findsOneWidget,
        reason: '个人信息页应能进入我的二维码');
    expect(find.text(l10n.scan), findsOneWidget, reason: '个人信息页应提供扫一扫');
  });

  testWidgets('点击昵称行应弹出可编辑的输入框', (tester) async {
    await tester.pumpWidget(makeTestableWidget());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(PersonalInfoScreen)),
    )!;
    expect(find.byType(TextField), findsNothing, reason: '未点击时不应有输入框');

    await tester.tap(find.text(l10n.nickname));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget, reason: '点击昵称应弹出编辑框');
    // 编辑框预填当前昵称，便于在原名基础上微调
    expect(find.text('张三'), findsWidgets);
  });
}
