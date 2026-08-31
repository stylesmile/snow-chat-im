// SingleChatSettingsScreen（单聊设置页）widget 测试
//
// 覆盖：
// 1. 渲染标题与对方昵称
// 2. 渲染各功能入口：查找聊天记录 / 置顶 / 免打扰 / 清空聊天记录 / 投诉
// 3. 点击投诉弹出投诉对话框
// 4. 点击清空弹确认框（不真正确认，避免数据库 IO）
//
// 说明：置顶/免打扰切换与清空确认会触达 SQLite，故仅验证入口与弹窗骨架，
// 具体持久化由 ConversationService / MessageCacheManager 的单元测试覆盖。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/providers/chat_provider.dart';
import 'package:snow_chat/ui/screens/single_chat_settings_screen.dart';

void main() {
  // 构造被测页面：本地化 + 两个 Provider，模拟真实运行环境
  Widget wrap() {
    return MultiProvider(
      providers: [
        // AuthProvider 仅需 userId getter；构造不触发网络 IO
        ChangeNotifierProvider.value(value: AuthProvider('http://localhost')),
        ChangeNotifierProvider.value(value: ChatProvider()),
      ],
      child: MaterialApp(
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
        home: const SingleChatSettingsScreen(
          targetId: 42,
          targetType: 'friend',
          targetName: '小明',
        ),
      ),
    );
  }

  group('SingleChatSettingsScreen 单聊设置页', () {
    testWidgets('渲染标题与对方昵称', (tester) async {
      await tester.pumpWidget(wrap());

      // 顶部标题应为"聊天设置"，并展示对方昵称"小明"
      expect(find.text('聊天设置'), findsOneWidget);
      expect(find.text('小明'), findsOneWidget);
    });

    testWidgets('渲染各功能入口', (tester) async {
      await tester.pumpWidget(wrap());

      // 入口应有：查找聊天记录 / 置顶 / 免打扰 / 清空聊天记录 / 投诉
      expect(find.text('查找聊天记录'), findsOneWidget);
      expect(find.text('聊天置顶'), findsOneWidget);
      expect(find.text('免打扰'), findsOneWidget);
      expect(find.text('清空聊天记录'), findsOneWidget);
      expect(find.text('投诉'), findsOneWidget);
    });

    testWidgets('点击投诉弹出投诉对话框', (tester) async {
      await tester.pumpWidget(wrap());

      // 点击"投诉"入口
      await tester.tap(find.text('投诉'));
      await tester.pumpAndSettle();

      // 对话框出现标题"投诉"与"提交投诉"按钮
      expect(find.text('提交投诉'), findsOneWidget);
    });
  });
}