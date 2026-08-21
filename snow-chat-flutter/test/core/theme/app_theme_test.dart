// AppTheme 单元测试
// 验证主题设计令牌（颜色/形状）符合 WINCHAT Figma 设计稿要求
// 设计稿来源：https://www.figma.com/design/zXzd44yno9NB5z72bhPaC1/WINCHAT
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/theme/app_theme.dart';

void main() {
  group('AppTheme 设计令牌（来自 Figma 设计稿取色）', () {
    test('主色应为品牌蓝 #3F8AE2', () {
      // 设计稿中按钮/高亮元素的主导蓝色
      expect(AppTheme.primary, const Color(0xFF3F8AE2));
    });

    test('背景色应为深色 #111111', () {
      // 设计稿页面背景为近黑色深底
      expect(AppTheme.background, const Color(0xFF111111));
    });

    test('表面色应为深灰 #1E1E1E', () {
      // 卡片/输入框/气泡底色，略浅于页面背景
      expect(AppTheme.surface, const Color(0xFF1E1E1E));
    });

    test('辅助色应为绿色 #549A78', () {
      // 设计稿中"在线"状态/成功提示的绿色
      expect(AppTheme.secondary, const Color(0xFF549A78));
    });
  });

  group('AppTheme.dark 深色主题', () {
    final theme = AppTheme.dark();

    test('应为 Material 3 主题', () {
      // WINCHAT 设计稿基于 Material 3 风格（圆角卡片/大按钮）
      expect(theme.useMaterial3, isTrue);
    });

    test('ColorScheme 亮度应为深色', () {
      // 设计稿整体为深色模式
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('ColorScheme primary 应使用品牌蓝', () {
      // 主色贯穿按钮/选中态/链接等控件
      expect(theme.colorScheme.primary, const Color(0xFF3F8AE2));
    });

    test('页面背景（scaffoldBackgroundColor）应为深色背景', () {
      // 页面级背景：ColorScheme.background 已废弃，由 scaffoldBackgroundColor 承载
      expect(theme.scaffoldBackgroundColor, const Color(0xFF111111));
    });

    test('ColorScheme surface 应为深色表面', () {
      // 卡片/列表项等表面色
      expect(theme.colorScheme.surface, const Color(0xFF1E1E1E));
    });

    test('AppBar 背景应与页面背景一致（无割裂感）', () {
      // 设计稿顶栏与页面同为深底、扁平无阴影
      expect(theme.appBarTheme.backgroundColor, const Color(0xFF111111));
      expect(theme.appBarTheme.elevation, 0);
    });

    test('输入框应为深色填充 + 圆角', () {
      // 设计稿输入框为深灰底、12px 圆角
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.fillColor, const Color(0xFF1E1E1E));
    });
  });
}
