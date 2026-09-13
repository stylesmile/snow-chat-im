import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/ui/screens/scan_screen.dart';

/// ScanScreen widget 测试
///
/// 通过 [ScanScreen.scannerBuilder] 注入伪扫描器，规避真实相机依赖：
/// - 渲染测试：确认标题「扫一扫」与伪扫描器按钮展示
/// - 无效二维码：注入非约定协议内容，验证弹出「无法识别的二维码」提示
/// - 有效码但拉取失败：注入约定协议但后端查无此人，验证提示「未找到该用户」
///
/// 测试环境默认屏蔽真网络（HTTP 返回 400），故有效码分支会走失败路径，
/// 从而无需真实后端即可验证扫码的错误分支逻辑。
void main() {
  // 初始化 sqflite FFI，满足 AuthProvider.init 对 SQLite 的需求
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AuthProvider auth;
  // 保存伪扫描器捕获到的 onCode 回调，用于从测试中注入二维码内容
  late void Function(String) capturedOnCode;

  setUp(() async {
    // 初始化 SharedPreferences mock，构造已登录状态
    SharedPreferences.setMockInitialValues({
      'userId': 1001,
      'username': 'alice',
      'nickname': 'Alice',
      'isLoggedIn': true,
      'token': 'mock-token',
    });
    auth = AuthProvider('http://localhost:8091');
    await auth.init();
    capturedOnCode = (code) {}; // 默认空回调
  });

  /// 构建注入伪扫描器的 ScanScreen
  ///
  /// 伪扫描器会捕获 [ScanScreen] 内部的 _handleCode 引用，便于测试直接触发。
  Widget buildScreen() {
    return ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        // 注入伪扫描器：把内部 onCode 保存到 capturedOnCode，并渲染一个占位按钮
        home: ScanScreen(
          scannerBuilder: (onCode) {
            capturedOnCode = onCode;
            return const Center(child: Text('fake-scan'));
          },
        ),
      ),
    );
  }

  testWidgets('渲染标题与伪扫描器', (tester) async {
    // 执行：渲染页面
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // 验证：标题「扫一扫」与伪扫描器占位存在
    expect(find.text('扫一扫'), findsOneWidget);
    expect(find.text('fake-scan'), findsOneWidget);
  });

  testWidgets('无效二维码弹出「无法识别的二维码」', (tester) async {
    // 执行：渲染页面，注入非约定协议的二维码内容
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    capturedOnCode('https://example.com/abc');
    await tester.pumpAndSettle();

    // 验证：弹出无效二维码提示
    expect(find.text('无法识别的二维码'), findsOneWidget);
  });

  testWidgets('有效码但拉取失败提示「未找到该用户」', (tester) async {
    // 执行：渲染页面，注入约定协议但后端查无此人（测试网络返回失败）
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    capturedOnCode('snowchat://user/99999');
    await tester.pumpAndSettle();

    // 验证：弹出未找到用户提示
    expect(find.text('未找到该用户'), findsOneWidget);
  });
}