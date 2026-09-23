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

  group('气泡箭头侧圆角几何（箭头必须与气泡连上）', () {
    // 固定尺寸便于精确断言；高度足够容纳 20dp 箭头跨度与大圆角
    const size = Size(200, 60);
    final w = size.width;
    final h = size.height;

    // 判定形状用 Path.contains 探针而非轮廓采样：
    // 采样点受弧长分布影响无法精确落在圆角端点，探针能稳定给出"该点是否在气泡内"。
    Path sentPath() => BubblePainter(isMe: true, color: AppTheme.bubbleSent).buildPath(size);
    Path receivedPath() =>
        BubblePainter(isMe: false, color: AppTheme.bubbleReceived).buildPath(size);

    testWidgets('我方气泡：箭头侧（右下角）为小圆角，底边贴近右下处仍是实心', (tester) async {
      // 右下角半径 5 → 距右边 10dp、距底边 1dp 处应仍在气泡内。
      // 若误用大圆角（20），该点会被圆角切掉而落在气泡外。
      expect(sentPath().contains(Offset(w - 10, h - 1)), isTrue,
          reason: '箭头侧应为 5dp 小圆角，底边右端不应被大圆角切掉');
    });

    testWidgets('对方气泡：箭头侧（左下角）为小圆角，底边贴近左下处仍是实心', (tester) async {
      // 左下角是箭头侧，须与我方右侧镜像：半径 5。
      // 修复前这里用大圆角 20，会把箭头基座所在区域切掉，视觉上表现为"箭头没连上"。
      expect(receivedPath().contains(Offset(10, h - 1)), isTrue,
          reason: '箭头侧应为 5dp 小圆角，底边左端不应被大圆角切掉');
    });

    testWidgets('对方气泡：箭头仍伸出并贴合气泡左下（箭头与气泡无断口）', (tester) async {
      final path = receivedPath();
      // 箭头向左侧伸出 10dp，其纵向中心处应有实心区域（箭头本体存在）
      expect(path.contains(Offset(-3, h - 14)), isTrue,
          reason: '箭头应伸出于气泡左侧直边');
      // 箭头基座与气泡小圆角衔接处（左下角附近）须为实心，否则出现断口
      expect(path.contains(Offset(3, h - 3)), isTrue,
          reason: '箭头基座与气泡应连为一体，不能出现断口');
    });

    test('对方气泡轮廓应与我方气泡关于中轴镜像对称', () {
      // 两侧气泡几何应完全镜像（含箭头位置与箭头侧小圆角）；
      // 修复前对方左下角是大圆角、我方右下角是小圆角，镜像关系被破坏。
      final sent = sentPath();
      final received = receivedPath();
      for (var x = 0.5; x < w; x += 4) {
        for (var y = 0.5; y < h; y += 4) {
          final inReceived = received.contains(Offset(x, y));
          final inSentMirrored = sent.contains(Offset(w - x, y));
          expect(inReceived, inSentMirrored,
              reason: '($x, $y) 处两侧气泡应镜像一致：'
                  '对方=$inReceived，我方镜像=$inSentMirrored');
        }
      }
    });
  });
}
