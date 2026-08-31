// ChatRecordSearchScreen（查找聊天记录页）widget 冒烟测试
//
// 该页的核心搜索逻辑已由 message_cache_manager_test 里的
// searchMessagesInSession 单元测试覆盖；这里仅验证页面能正确渲染骨架
// （标题、搜索框、初始引导态），确保 UI 不因改动而崩坏。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/ui/screens/chat_record_search_screen.dart';

void main() {
  // 构造被测页面：深色主题 + 本地化委托，模拟真实运行环境
  Widget wrap(Widget child) {
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
      home: child,
    );
  }

  // 构造被测页面实例：会话内查找记录
  ChatRecordSearchScreen buildScreen() {
    return const ChatRecordSearchScreen(
      sessionId: 'u_10_42',
      targetId: 42,
      targetType: 'friend',
      targetName: '小明',
    );
  }

  group('ChatRecordSearchScreen 查找聊天记录页', () {
    testWidgets('渲染标题与搜索输入框', (tester) async {
      await tester.pumpWidget(wrap(buildScreen()));

      // 顶部标题应显示"查找聊天记录"
      expect(find.text('查找聊天记录'), findsOneWidget);
      // 应存在一个搜索输入框（hint 为搜索提示）
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}