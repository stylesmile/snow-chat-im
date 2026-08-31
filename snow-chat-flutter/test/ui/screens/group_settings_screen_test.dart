// GroupSettingsScreen（群聊设置页）widget 测试
//
// 覆盖：
// 1. 渲染标题"群聊设置"与群名称
// 2. 渲染各功能入口：群聊信息 / 查找聊天记录 / 置顶 / 免打扰 / 清空聊天记录
// 3. 点击清空弹确认框（不真正确认，避免数据库 IO）
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
import 'package:snow_chat/ui/screens/group_settings_screen.dart';

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
        home: const GroupSettingsScreen(
          groupId: 7,
          targetType: 'group',
          targetName: '开发群',
        ),
      ),
    );
  }

  group('GroupSettingsScreen 群聊设置页', () {
    testWidgets('渲染标题与群名称', (tester) async {
      await tester.pumpWidget(wrap());

      // 顶部标题应为"群聊设置"，并展示群名称"开发群"
      expect(find.text('群聊设置'), findsOneWidget);
      expect(find.text('开发群'), findsOneWidget);
    });

    testWidgets('渲染各功能入口', (tester) async {
      await tester.pumpWidget(wrap());

      // 入口应有：群聊信息 / 查找聊天记录 / 置顶 / 免打扰 / 清空聊天记录
      expect(find.text('群聊信息'), findsOneWidget);
      expect(find.text('查找聊天记录'), findsOneWidget);
      expect(find.text('聊天置顶'), findsOneWidget);
      expect(find.text('免打扰'), findsOneWidget);
      expect(find.text('清空聊天记录'), findsOneWidget);
    });

    testWidgets('点击清空弹出确认对话框', (tester) async {
      await tester.pumpWidget(wrap());

      // 点击"清空聊天记录"入口
      await tester.tap(find.text('清空聊天记录'));
      await tester.pumpAndSettle();

      // 确认对话框出现标题"清空聊天记录"与按钮"确定"
      expect(find.text('确定'), findsWidgets);
    });
  });
}