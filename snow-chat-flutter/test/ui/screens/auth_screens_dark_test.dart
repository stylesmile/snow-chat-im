// 登录/注册页深色适配 widget 测试
//
// 验证基于 WINCHAT Figma 设计稿的深色改造：
// 1. 背景应为深色（#0A0A0A 近黑色，不含浅紫色）
// 2. 输入框文字应为浅色（深色背景下可读）
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_chat/core/theme/app_theme.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/ui/screens/login_screen.dart';
import 'package:snow_chat/ui/screens/register_screen.dart';

void main() {
  late AuthProvider authProvider;

  setUp(() {
    // 初始化 SharedPreferences mock（AuthProvider 依赖）
    SharedPreferences.setMockInitialValues({});
    // 未登录状态的 AuthProvider，页面停留在登录/注册页
    authProvider = AuthProvider('http://localhost:8091');
  });

  /// 构造测试 widget 树：AuthProvider + 深色主题 MaterialApp + 目标页面
  Widget makeTestableWidget(Widget child) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp(
        // 使用 WINCHAT 深色主题，验证页面在深色模式下的表现
        theme: AppTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        home: child,
      ),
    );
  }

  /// 从 Scaffold 中读取背景色
  Color? findBackgroundColor(WidgetTester tester) {
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    return scaffold.backgroundColor;
  }

  group('LoginScreen 深色适配', () {
    testWidgets('背景应为深色（不含浅紫色）', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      final color = findBackgroundColor(tester);
      expect(color, isNotNull, reason: '应存在 Scaffold 背景色');
      // 背景亮度应低于 0.2（近黑）
      expect(
        color!.computeLuminance() < 0.2,
        isTrue,
        reason: '背景色 $color 亮度 ${color.computeLuminance()} 应为深色',
      );
    });

    testWidgets('输入框文字应为浅色（深色背景下可读）', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      // TextFormField 不暴露 style，通过其内部的 EditableText 读取实际渲染样式
      final editableText = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).first,
          matching: find.byType(EditableText),
        ),
      );
      final textColor = editableText.style.color;

      expect(textColor, isNotNull, reason: '输入框应显式指定文字颜色');
      // 文字颜色应为浅色：亮度高于 0.5
      expect(
        textColor!.computeLuminance() > 0.5,
        isTrue,
        reason: '文字颜色 $textColor 应为浅色，实际亮度 ${textColor.computeLuminance()}',
      );
    });
  });

  group('RegisterScreen 深色适配', () {
    testWidgets('背景应为深色（不含浅紫色）', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const RegisterScreen()));
      await tester.pumpAndSettle();

      final color = findBackgroundColor(tester);
      expect(color, isNotNull, reason: '应存在 Scaffold 背景色');
      expect(
        color!.computeLuminance() < 0.2,
        isTrue,
        reason: '背景色 $color 亮度 ${color.computeLuminance()} 应为深色',
      );
    });

    testWidgets('输入框文字应为浅色（深色背景下可读）', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const RegisterScreen()));
      await tester.pumpAndSettle();

      final editableText = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).first,
          matching: find.byType(EditableText),
        ),
      );
      final textColor = editableText.style.color;

      expect(textColor, isNotNull, reason: '输入框应显式指定文字颜色');
      expect(
        textColor!.computeLuminance() > 0.5,
        isTrue,
        reason: '文字颜色 $textColor 应为浅色，实际亮度 ${textColor.computeLuminance()}',
      );
    });
  });
}
