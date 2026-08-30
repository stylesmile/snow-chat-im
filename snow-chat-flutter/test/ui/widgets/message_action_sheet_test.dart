// MessageActionSheet（消息长按操作菜单）widget 测试
//
// 与 ChatBubble 相同的原因：ChatDetailScreen 直接 pump 会触发 MQTT/SQLite
// 依赖，无法纯 UI 测试。因此把消息长按操作菜单抽为独立组件，聚焦：
// 1. 长按后展示的操作项（复制/撤回/转发）
// 2. 点击某项通过 Navigator.pop 返回对应 MessageAction
// 3. 非本人消息 / 超时可撤回消息时，"撤回"项不应出现
//
// 背景：消息长按菜单是会话功能（复制/撤回/转发）的共用入口，
// 抽取为组件可单测，避免每个功能都要 pump 整个聊天页。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/ui/widgets/message_action_sheet.dart';

void main() {
  // 构造被测菜单：深色主题包裹 + 本地化委托，模拟真实运行环境
  Widget wrap(MessageActionSheet sheet) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      locale: const Locale('zh'),
      home: Scaffold(body: Center(child: sheet)),
    );
  }

  group('MessageActionSheet 长按操作菜单', () {
    testWidgets('本人可撤回消息：展示复制/撤回/转发三个操作', (tester) async {
      await tester.pumpWidget(wrap(
        const MessageActionSheet(canRecall: true, canForward: true),
      ));

      // 三个操作项均应展示（"撤回"文案为"撤回消息"）
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('撤回消息'), findsOneWidget);
      expect(find.text('转发'), findsOneWidget);
    });

    testWidgets('非本人或超时可撤回消息：不展示"撤回"操作', (tester) async {
      await tester.pumpWidget(wrap(
        const MessageActionSheet(canRecall: false, canForward: true),
      ));

      // 可撤回时才有"撤回"；不可撤回时不应展示
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('转发'), findsOneWidget);
      expect(find.text('撤回消息'), findsNothing);
    });

    testWidgets('点击"复制"通过 onAction 回调返回 copy', (tester) async {
      MessageAction? result;
      await tester.pumpWidget(wrap(
        MessageActionSheet(
          canRecall: true,
          canForward: true,
          onAction: (action) => result = action,
        ),
      ));

      await tester.tap(find.text('复制'));
      expect(result, MessageAction.copy);
    });

    testWidgets('点击"撤回"通过 onAction 回调返回 recall', (tester) async {
      MessageAction? result;
      await tester.pumpWidget(wrap(
        MessageActionSheet(
          canRecall: true,
          canForward: true,
          onAction: (action) => result = action,
        ),
      ));

      await tester.tap(find.text('撤回消息'));
      expect(result, MessageAction.recall);
    });

    testWidgets('点击"转发"通过 onAction 回调返回 forward', (tester) async {
      MessageAction? result;
      await tester.pumpWidget(wrap(
        MessageActionSheet(
          canRecall: true,
          canForward: true,
          onAction: (action) => result = action,
        ),
      ));

      await tester.tap(find.text('转发'));
      expect(result, MessageAction.forward);
    });
  });
}