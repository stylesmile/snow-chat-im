import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// WINCHAT 全局主题定义
///
/// 设计令牌取自 Figma 设计稿（WINCHAT）像素取色：
/// - 主色（品牌蓝）：#3F8AE2 —— 按钮/选中态/高亮元素的主导色
/// - 背景：#111111 —— 页面级近黑色深底
/// - 表面：#1E1E1E —— 卡片/输入框/列表项，略浅于页面背景
/// - 辅助色（绿）：#549A78 —— 在线状态/成功提示
///
/// 设计稿链接：https://www.figma.com/design/zXzd44yno9NB5z72bhPaC1/WINCHAT
class AppTheme {
  // ---------------------------------------------------------------------------
  // 设计令牌（Design Tokens）
  // 集中定义颜色常量，供主题与页面直接引用，保证全应用颜色一致
  // ---------------------------------------------------------------------------

  /// 品牌蓝：主色，用于按钮/选中态/链接/发送气泡等强调元素
  static const Color primary = Color(0xFF3F8AE2);

  /// 页面背景：近黑色深底，所有页面的底色
  static const Color background = Color(0xFF111111);

  /// 表面色：卡片/输入框/列表项的底色，比背景略浅形成层次
  static const Color surface = Color(0xFF1E1E1E);

  /// 辅助绿：在线状态/成功提示等正向反馈色
  static const Color secondary = Color(0xFF549A78);

  /// 强调金：底部导航选中态、登录/注册主按钮所使用的金色
  ///
  /// 提升为设计令牌的原因：登录页与注册页此前各自以 `Color(0xFFFFC940)` 字面量
  /// 硬编码该色，旧版个人中心导航栏又写成了 `Color(0xFFFFB800)`，三处金色并不一致。
  /// 集中定义后统一引用，避免后续继续发散。
  static const Color accent = Color(0xFFFFC940);

  /// 底部导航未选中态：中灰，在 `background`（#111111）深底上仍有足够对比度
  ///
  /// 说明：对标项目的未选中色是 #434447，但该色在近黑背景上几乎不可见，
  /// 故改用中灰以保证可读性。
  static const Color navUnselected = Color(0xFF9E9E9E);

  // ---------------------------------------------------------------------------
  // 聊天页令牌（对标 win-chat-android 夜间主题 values-night/color.xml）
  // ---------------------------------------------------------------------------

  /// 我方气泡：金黄底（win-chat `chat_bubble_send` #FFCC00），黑字
  static const Color bubbleSent = Color(0xFFFFCC00);

  /// 我方气泡文字
  static const Color bubbleSentText = Color(0xFF000000);

  /// 对方气泡：灰紫底（win-chat `chat_bubble_received` #505060），白字
  static const Color bubbleReceived = Color(0xFF505060);

  /// 对方气泡文字
  static const Color bubbleReceivedText = Color(0xFFFFFFFF);

  /// 聊天输入栏容器/输入框底色（win-chat `chat_face_tab_bg` / `chat_edit_bg`）
  static const Color chatInputBar = Color(0xFF1A1A1A);

  /// 聊天页分隔线（win-chat `wechatLine`/`layoutColorSelected`）
  static const Color chatDivider = Color(0xFF2C2C2E);

  // ---------------------------------------------------------------------------
  // 主题构建
  // ---------------------------------------------------------------------------

  /// 构建深色主题
  ///
  /// [brightness] 参数为可选覆盖，默认深色；测试中可显式传入验证
  static ThemeData dark() {
    // 基于 Material 3 色彩方案生成完整色板
    // fromSeed 会派生出 onPrimary 等对比色，再用 copyWith 精确覆盖关键槽位
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      // 主色：精确使用设计稿品牌蓝，不使用派生色
      primary: primary,
      // 表面色：卡片/输入框底色
      surface: surface,
    );

    return ThemeData(
      // WINCHAT 设计稿基于 Material 3 风格（圆角卡片/大按钮）
      useMaterial3: true,
      colorScheme: colorScheme,
      // 顶栏与页面同为深底、扁平无阴影，避免割裂感
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        // 状态栏透明，图标为浅色（深色模式下状态栏文字需为白色）
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      // 输入框：深灰填充 + 圆角，对应设计稿的输入框样式
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          // 边框使用低对比度灰色，避免在深色背景上过于突兀
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          // 聚焦时边框高亮为品牌蓝，提供清晰的交互反馈
          borderSide: const BorderSide(color: primary),
        ),
      ),
      // 卡片：表面色 + 圆角，对应设计稿的卡片容器
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // 按钮：品牌蓝底 + 圆角，对应设计稿的大圆角主按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      // 列表/组件分隔线：低透明度白色，深色模式下更柔和
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        thickness: 0.5,
      ),
      // 脚手架背景统一为深底
      scaffoldBackgroundColor: background,
    );
  }
}
