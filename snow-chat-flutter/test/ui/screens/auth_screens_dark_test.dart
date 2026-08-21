// 登录/注册页深色适配 widget 测试
//
// 验证基于 WINCHAT Figma 设计稿的深色改造：
// 1. 背景渐变应为深色（原浅紫色 #F9F5FF 在深色模式下刺眼）
// 2. 输入框文字应为浅色（原 grey.shade700 在深色背景上不可读）
//
// 测试策略：使用 AppTheme.dark() 包裹页面，检查渲染树中的实际颜色值
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

  /// 从渲染树中提取页面背景渐变的颜色列表
  ///
  /// 返回 null 表示未找到带 LinearGradient 装饰的 Container
  List<Color>? findGradientColors(WidgetTester tester) {
    // 找到第一个带线性渐变装饰的 Container（即页面背景）
    final container = tester.widget<Container>(
      find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final decoration = widget.decoration;
          if (decoration is BoxDecoration && decoration.gradient is LinearGradient) {
            return true;
          }
        }
        return false;
      }),
    );
    final decoration = container.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    return gradient.colors;
  }

  /// 将带透明度的渐变色合成到页面深色背景上，得到实际视觉效果
  ///
  /// computeLuminance() 会忽略 alpha 通道，直接对半透明品牌蓝判断会误报；
  /// 渐变 Container 叠在深色 Scaffold 之上，视觉结果 = 前景色按 alpha 混入背景色
  Color compositeOverBackground(Color foreground) {
    const background = AppTheme.background;
    // alpha 归一化到 0~1（Color.a 为 0~255 的 double）
    final a = foreground.a / 255.0;
    return Color.fromARGB(
      255,
      (foreground.r * a + background.r * (1 - a)).round(),
      (foreground.g * a + background.g * (1 - a)).round(),
      (foreground.b * a + background.b * (1 - a)).round(),
    );
  }

  group('LoginScreen 深色适配', () {
    testWidgets('背景渐变应为深色（不含浅紫色）', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      final colors = findGradientColors(tester);
      expect(colors, isNotNull, reason: '应存在带渐变背景的 Container');

      // 每个渐变色合成到深色背景后都必须是深色：亮度低于 0.2（近黑/深蓝）
      // 原实现末尾为 #F9F5FF（亮度约 0.93），在深色模式下会刺眼
      for (final color in colors!) {
        final effective = compositeOverBackground(color);
        expect(
          effective.computeLuminance() < 0.2,
          isTrue,
          reason: '渐变色 $color 合成后 $effective 应为深色，实际亮度 ${effective.computeLuminance()}',
        );
      }
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
      // 原实现为 grey.shade700（亮度约 0.16），在深色背景上几乎不可见
      expect(
        textColor!.computeLuminance() > 0.5,
        isTrue,
        reason: '文字颜色 $textColor 应为浅色，实际亮度 ${textColor.computeLuminance()}',
      );
    });
  });

  group('RegisterScreen 深色适配', () {
    testWidgets('背景渐变应为深色（不含浅紫色）', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const RegisterScreen()));
      await tester.pumpAndSettle();

      final colors = findGradientColors(tester);
      expect(colors, isNotNull, reason: '应存在带渐变背景的 Container');

      // 与登录页相同：合成到深色背景后验证亮度
      for (final color in colors!) {
        final effective = compositeOverBackground(color);
        expect(
          effective.computeLuminance() < 0.2,
          isTrue,
          reason: '渐变色 $color 合成后 $effective 应为深色，实际亮度 ${effective.computeLuminance()}',
        );
      }
    });

    testWidgets('输入框文字应为浅色（深色背景下可读）', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const RegisterScreen()));
      await tester.pumpAndSettle();

      // 通过 EditableText 读取实际渲染的文字样式
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
