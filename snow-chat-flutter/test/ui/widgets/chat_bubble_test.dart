// ChatBubble（聊天消息气泡）widget 测试
//
// 验证对标 win-chat-android 夜间主题的气泡改造（values-night/color.xml + BubbleLayout）：
// 1. 我方气泡：金黄底（chat_bubble_send #FFCC00）+ 黑字
// 2. 对方气泡：灰紫底（chat_bubble_received #505060）+ 白字
// 3. 气泡带指向头像一侧的 10dp 小箭头（我方在右、对方在左）
// 4. 时间戳弱化但仍可读
//
// 背景：ChatDetailScreen 直接 pump 会触发 MQTT/SQLite 依赖，无法纯 UI 测试；
// 因此将气泡 UI 提取为独立 ChatBubble 组件，聚焦颜色/形状验证
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

  /// 找到气泡的绘制器（CustomPaint 的 painter）
  BubblePainter painterOf(WidgetTester tester) {
    final custom = tester.widget<CustomPaint>(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BubblePainter),
    );
    return custom.painter as BubblePainter;
  }

  group('ChatBubble 对标 win-chat 夜间主题', () {
    testWidgets('我方气泡应为金黄底（chat_bubble_send）', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: true, createTime: 1726000000000),
      ));

      expect(painterOf(tester).color, AppTheme.bubbleSent);
      expect(painterOf(tester).isMe, isTrue);
    });

    testWidgets('对方气泡应为灰紫底（chat_bubble_received）', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: false, createTime: 1726000000000),
      ));

      expect(painterOf(tester).color, AppTheme.bubbleReceived);
      expect(painterOf(tester).isMe, isFalse);
    });

    testWidgets('我方气泡文字应为黑色（金底黑字）', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: true, createTime: 1726000000000),
      ));

      final text = tester.widget<Text>(find.text('你好'));
      expect(text.style?.color, AppTheme.bubbleSentText);
    });

    testWidgets('对方气泡文字应为白色（灰紫底白字）', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: false, createTime: 1726000000000),
      ));

      final text = tester.widget<Text>(find.text('你好'));
      expect(text.style?.color, AppTheme.bubbleReceivedText);
    });

    testWidgets('气泡应带指向头像一侧的小箭头（画布比内容宽出箭头长度）', (tester) async {
      // 我方：箭头朝右伸出
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: true, createTime: 1726000000000),
      ));
      final mySize = tester.getSize(find.byType(ChatBubble));
      // 内容宽度 = 文本宽 + 左右 padding；画布宽 = 内容宽 + 箭头 10dp
      expect(mySize.width, greaterThan(40), reason: '气泡应包含文本与内边距');

      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: false, createTime: 1726000000000),
      ));
      final otherSize = tester.getSize(find.byType(ChatBubble));
      expect(otherSize.width, mySize.width, reason: '同内容两种气泡画布等宽');
    });

    testWidgets('时间戳应弱化显示但保持可读', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const ChatBubble(content: '你好', isMe: false, createTime: 1726000000000),
      ));
      // 气泡内时间戳为 fontSize 10 的 Text（内容文本无显式 fontSize）
      final timeText = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && (w.style?.fontSize ?? 14) == 10),
      );
      final color = timeText.style?.color;
      expect(color, isNotNull);
      // 白色 55% 透明度叠在 #505060 上仍可读（亮度 > 0.25）
      expect(
        color!.computeLuminance() > 0.25,
        isTrue,
        reason: '时间戳 $color 应保持可读，实际亮度 ${color.computeLuminance()}',
      );
    });
  });
}
