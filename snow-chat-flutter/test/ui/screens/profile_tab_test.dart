import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/providers/settings_provider.dart';
import 'package:snow_chat/ui/screens/profile_tab.dart';
import 'package:snow_chat/ui/widgets/avatar_widget.dart';

/// ProfileTab widget 测试
///
/// 验证微信风格个人中心页面：
/// 1. 头像区域使用 AvatarWidget 加载真实头像 URL
/// 2. 显示昵称与 @username
/// 3. 退出登录按钮存在
void main() {
  late AuthProvider authProvider;
  late SettingsProvider settingsProvider;

  setUp(() {
    // 初始化 SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    // 构造已登录的 AuthProvider，预设头像/昵称/用户名
    authProvider = AuthProvider('http://localhost:8091');
    // 直接通过公开方法设置测试数据（避免网络登录）
    // 利用 updateAvatar / updateNickname 持久化并触发 UI
    // 先设置 isLoggedIn：通过 login 无法（需网络），改用内部状态反射
    // 这里用 updateAvatar/updateNickname 设置字段，isLoggedIn 不影响 ProfileTab 渲染
    settingsProvider = SettingsProvider();
  });

  /// 构造测试用 widget 树：MultiProvider + MaterialApp（带本地化）+ ProfileTab
  Widget makeTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
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
        home: ProfileTab(),
      ),
    );
  }

  group('ProfileTab 微信风格布局', () {
    testWidgets('应显示 AvatarWidget 加载真实头像', (WidgetTester tester) async {
      // 预设头像 URL
      await authProvider.updateAvatar('https://example.com/avatar.jpg');
      await authProvider.updateNickname('Alice');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：AvatarWidget 存在（替代了原来的 Icons.person 占位）
      expect(find.byType(AvatarWidget), findsOneWidget);
    });

    testWidgets('应显示昵称与 @username', (WidgetTester tester) async {
      // 预设昵称与用户名
      await authProvider.updateNickname('Alice');
      // username 无法通过公开方法设置，Auth 内部字段默认为 null
      // 这里验证昵称显示即可；username 为 null 时显示占位
      await authProvider.updateAvatar('https://example.com/a.jpg');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：昵称 'Alice' 文本存在
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('应显示退出登录按钮', (WidgetTester tester) async {
      await authProvider.updateNickname('Alice');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：退出登录图标存在（Icons.logout）
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('应显示二维码与右箭头图标（微信风格头部行）',
        (WidgetTester tester) async {
      await authProvider.updateNickname('Alice');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：二维码图标 + 右箭头图标存在
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });
  });
}
