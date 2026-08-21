// ChatBubble（聊天消息气泡）widget 测试
//
// 验证基于 WINCHAT Figma 设计稿的深色改造：
// 1. 对方气泡应为深色表面（原浅灰 #EEEEEE 在深色页面是刺眼亮块）
// 2. 对方气泡文字应为浅色（原 black87 在深色气泡上不可读）
// 3. 我方气泡应为品牌蓝（主题主色）
// 4. 我方气泡文字应为白色
// 5. 两种气泡的时间戳均应为浅色
//
// 背景：ChatDetailScreen 直接 pump 会触发 MQTT/SQLite 依赖，无法纯 UI 测试；
// 因此将气泡 UI 提取为独立 ChatBubble 组件，聚焦颜色/布局验证
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/theme/app_theme.dart';
import 'package:snow_chat/ui/widgets/chat_bubble.dart';

void main() {
  // 构造被测气泡：深色主题包裹，模拟真实运行环境
  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('ChatBubble 深色适配', () {
    testWidgets('对方气泡应为深色表面色（非浅灰亮块）', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: false, createTime: 1726000000000),
      ));

      // 气泡根节点是带 BoxDecoration 的 Container
      final container = tester.widget<Container>(
        find.byWidgetPredicate((w) {
          if (w is Container) {
            return w.decoration is BoxDecoration;
          }
          return false;
        }),
      );
      final decoration = container.decoration as BoxDecoration;
      // 对方气泡：深色表面 #1E1E1E（原 grey.shade200 亮度 0.85 是刺眼亮块）
      expect(decoration.color, AppTheme.surface);
    });

    testWidgets('对方气泡文字应为浅色（深色气泡上可读）', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: false, createTime: 1726000000000),
      ));

      final text = tester.widget<Text>(find.text('你好'));
      final color = text.style?.color;
      expect(color, isNotNull);
      // 原实现为 black87（亮度 0.03），在深色气泡上不可读
      expect(
        color!.computeLuminance() > 0.3,
        isTrue,
        reason: '文字颜色 $color 应为浅色，实际亮度 ${color.computeLuminance()}',
      );
    });

    testWidgets('我方气泡应为品牌蓝（主题主色）', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: true, createTime: 1726000000000),
      ));

      final container = tester.widget<Container>(
        find.byWidgetPredicate((w) {
          if (w is Container) {
            return w.decoration is BoxDecoration;
          }
          return false;
        }),
      );
      final decoration = container.decoration as BoxDecoration;
      // 我方气泡：品牌蓝 #3F8AE2
      expect(decoration.color, AppTheme.primary);
    });

    testWidgets('我方气泡文字应为白色', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: true, createTime: 1726000000000),
      ));

      final text = tester.widget<Text>(find.text('你好'));
      // 品牌蓝底上的文字保持纯白，对比度最高
      expect(text.style?.color, Colors.white);
    });

    testWidgets('时间戳文字两种气泡均应为浅色', (tester) async {
      // 对方气泡时间戳
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: false, createTime: 1726000000000),
      ));
      // 气泡内时间戳为 fontSize 10 的 Text（内容文本 fontSize 默认 14+）
      final timeText = tester.widget<Text>(
        find.byWidgetPredicate((w) {
          return w is Text && (w.style?.fontSize ?? 14) == 10;
        }),
      );
      var color = timeText.style?.color;
      expect(color, isNotNull);
      // 原实现为 grey.shade600（亮度 0.31），深色气泡上不可读
      expect(
        color!.computeLuminance() > 0.3,
        isTrue,
        reason: '对方时间戳 $color 应为浅色，实际亮度 ${color.computeLuminance()}',
      );

      // 我方气泡时间戳
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: true, createTime: 1726000000000),
      ));
      final myTimeText = tester.widget<Text>(
        find.byWidgetPredicate((w) {
          return w is Text && (w.style?.fontSize ?? 14) == 10;
        }),
      );
      color = myTimeText.style?.color;
      expect(color, isNotNull);
      expect(
        color!.computeLuminance() > 0.3,
        isTrue,
        reason: '我方时间戳 $color 应为浅色，实际亮度 ${color.computeLuminance()}',
      );
    });
  });
}
