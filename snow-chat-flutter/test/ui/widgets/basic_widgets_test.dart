// Flutter 未测 widget 组件单测
// 覆盖 MessageBubble（按类型渲染文本/时间）、
// ChatBubble（气泡形状/颜色）、EmptyStateWidget；
// LoadingWidget 因依赖 AppLocalizations，使用 MaterialApp + 中文本地化兜底渲染
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/theme/app_theme.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/ui/widgets/chat_bubble.dart';
import 'package:snow_chat/ui/widgets/empty_state_widget.dart';
import 'package:snow_chat/ui/widgets/loading_widget.dart';
import 'package:snow_chat/ui/widgets/message_bubble.dart';

void main() {
  group('MessageBubble', () {
    testWidgets('render text content for plain text message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          localizationsDelegates: [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: MessageBubble(
              content: 'hello world',
              type: 'text',
              isMe: false,
            ),
          ),
        ),
      );
      expect(find.text('hello world'), findsOneWidget);
    });

    testWidgets('display time stamp when createTime provided', (tester) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          localizationsDelegates: [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: MessageBubble(
              content: 'time test',
              type: 'text',
              isMe: false,
              createTime: nowMs,
            ),
          ),
        ),
      );
      // 时间格式化：当天只显示 HH:mm
      final nowDt = DateTime.fromMillisecondsSinceEpoch(nowMs);
      final formatted =
          '${nowDt.hour.toString().padLeft(2, '0')}:${nowDt.minute.toString().padLeft(2, '0')}';
      expect(find.text(formatted), findsOneWidget);
    });
  });

  group('BubbleContainer', () {
    testWidgets('use sent color for own message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Material(
            child: BubbleContainer(
              isMe: true,
              child: Text('me'),
            ),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CustomPaint),
          matching: find.byType(Container),
        ),
      );
      // 自己发的消息使用发送色（AppTheme.bubbleSent）
      expect(container.color, equals(AppTheme.bubbleSent));
    });

    testWidgets('use received color for other message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Material(
            child: BubbleContainer(
              isMe: false,
              child: Text('other'),
            ),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CustomPaint),
          matching: find.byType(Container),
        ),
      );
      expect(container.color, equals(AppTheme.bubbleReceived));
    });
  });

  group('LoadingWidget', () {
    testWidgets('renders CircularProgressIndicator and default loading text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LoadingWidget()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // 中文资源中 loading 文案为"加载中..."
      expect(find.text('加载中...'), findsOneWidget);
    });

    testWidgets('renders custom message when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LoadingWidget(message: '正在同步...')),
        ),
      );
      expect(find.text('正在同步...'), findsOneWidget);
    });
  });

  group('EmptyStateWidget', () {
    testWidgets('render icon and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.chat_bubble_outline,
              message: '暂无消息',
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.text('暂无消息'), findsOneWidget);
    });
  });
}
