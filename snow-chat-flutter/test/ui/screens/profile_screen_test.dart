import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/services/profile_service.dart';
import 'package:snow_chat/ui/screens/profile_screen.dart';
import 'package:snow_chat/ui/screens/scan_screen.dart';
import 'package:snow_chat/ui/screens/my_qr_screen.dart';

/// ProfileScreen 个人中心测试（仅覆盖本次新增的扫一扫 / 我的二维码入口）
///
/// 验证：
/// 1. 性别下方出现「扫一扫」和「我的二维码」两个入口
/// 2. 点击「扫一扫」跳转到 ScanScreen
/// 3. 点击「我的二维码」跳转到 MyQrScreen
void main() {
  // 初始化 sqflite FFI，满足 AuthProvider.init 对 SQLite 的需求
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AuthProvider auth;

  setUp(() async {
    // 构造已登录用户
    SharedPreferences.setMockInitialValues({
      'userId': 1001,
      'username': 'alice',
      'nickname': 'Alice',
      'isLoggedIn': true,
      'token': 'mock-token',
    });
    auth = AuthProvider('http://localhost:8091');
    await auth.init();
  });

  Widget buildScreen() {
    return ChangeNotifierProvider.value(
      value: auth,
      child: Provider<ProfileService>.value(
        value: ProfileService(auth.apiClient),
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          locale: const Locale('zh'),
          home: const ProfileScreen(),
        ),
      ),
    );
  }

  testWidgets('性别下方显示扫一扫与我的二维码入口', (tester) async {
    // 执行：渲染个人中心
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // 验证：两个入口均渲染
    expect(find.text('扫一扫'), findsOneWidget);
    expect(find.text('我的二维码'), findsOneWidget);
  });

  testWidgets('点击扫一扫跳转到 ScanScreen', (tester) async {
    // 执行：渲染并点击「扫一扫」
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('扫一扫'));
    await tester.pumpAndSettle();

    // 验证：进入 ScanScreen（通过其唯一标识头部二维码提示判断）
    expect(find.byType(ScanScreen), findsOneWidget);
  });

  testWidgets('点击我的二维码跳转到 MyQrScreen', (tester) async {
    // 执行：渲染并点击「我的二维码」
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的二维码'));
    await tester.pumpAndSettle();

    // 验证：进入 MyQrScreen
    expect(find.byType(MyQrScreen), findsOneWidget);
  });

  testWidgets('点击头部二维码图标跳转到 MyQrScreen', (tester) async {
    // 执行：渲染并点击头部行最右侧的二维码图标
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.qr_code_2));
    await tester.pumpAndSettle();

    // 验证：进入 MyQrScreen
    expect(find.byType(MyQrScreen), findsOneWidget);
  });
}