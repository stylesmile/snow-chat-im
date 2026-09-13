import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/ui/screens/my_qr_screen.dart';

/// MyQrScreen widget 冒烟测试
///
/// 验证：页面标题、用户名、用户ID、以及二维码控件均能渲染出来。
void main() {
  // 初始化 sqflite FFI，满足 AuthProvider.init 恢复登录态时对 SQLite 的需求
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AuthProvider auth;

  setUp(() async {
    // 初始化 SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    // 构造已登录的 AuthProvider（本机免网络，仅从 mock 存储恢复登录态）
    auth = AuthProvider('http://localhost:8091');
    SharedPreferences.setMockInitialValues({
      'userId': 1001,
      'username': 'alice',
      'nickname': 'Alice',
      'isLoggedIn': true,
      'token': 'mock-token',
    });
    await auth.init();
  });

  Widget buildScreen() {
    // 带本地化的 MaterialApp，包裹 AuthProvider 供页面 watch
    return ChangeNotifierProvider.value(
      value: auth,
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('zh'), Locale('en')],
        locale: Locale('zh'),
        home: MyQrScreen(),
      ),
    );
  }

  testWidgets('渲染页面标题、用户名与用户ID', (tester) async {
    // 执行：渲染页面
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // 验证：标题「我的二维码」
    expect(find.text('我的二维码'), findsOneWidget);
    // 验证：用户名 @alice
    expect(find.text('@alice'), findsOneWidget);
    // 验证：展示用户ID（含数值 1001）
    expect(find.textContaining('1001'), findsOneWidget);
  });

  testWidgets('渲染二维码控件（QrImageView）', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // qr_flutter 的 QrImageView 以自定义 RenderObject 渲染，按运行时类型查找
    final qrFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'QrImageView',
    );
    expect(qrFinder, findsOneWidget);
  });
}