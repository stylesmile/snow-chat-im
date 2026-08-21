// 主界面（聊天列表/通讯录/底部导航）深色适配 widget 测试
//
// 验证基于 WINCHAT Figma 设计稿的深色改造：
// 1. 空状态图标/文字应为浅色（原 grey.shade400/600 在深色背景上不可读）
// 2. 会话时间文字应为浅色（原 grey.shade500 在深色背景上不可读）
// 3. 头像应使用设计令牌色（群=品牌蓝 / 好友=辅助绿，替换 Material 默认色）
// 4. 无联系人提示文字应为浅色
//
// 测试策略：
// - AuthProvider 的 userId 为 null 时，各 tab 的数据加载会提前返回，
//   从而绕开 SQLite/网络依赖，widget 测试聚焦纯 UI 颜色
// - 会话数据通过真实 ChatProvider.setConversations 直接注入
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_chat/core/theme/app_theme.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/providers/chat_provider.dart';
import 'package:snow_chat/providers/friend_request_provider.dart';
import 'package:snow_chat/ui/screens/chat_list_tab.dart';
import 'package:snow_chat/ui/screens/contact_tab.dart';

void main() {
  late AuthProvider authProvider;
  late ChatProvider chatProvider;
  late FriendRequestProvider friendRequestProvider;

  setUp(() {
    // 初始化 SharedPreferences mock（AuthProvider 依赖）
    SharedPreferences.setMockInitialValues({});
    // 未登录状态：userId == null，数据加载提前返回，不触碰 SQLite/网络
    authProvider = AuthProvider('http://localhost:8091');
    chatProvider = ChatProvider();
    friendRequestProvider = FriendRequestProvider(authProvider.apiClient);
  });

  /// 构造测试 widget 树：注入所需 Provider + 深色主题 MaterialApp + 目标 tab
  Widget makeTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
        ChangeNotifierProvider<FriendRequestProvider>.value(value: friendRequestProvider),
      ],
      child: MaterialApp(
        // 使用 WINCHAT 深色主题，验证页面在深色模式下的表现
        theme: AppTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        home: child,
      ),
    );
  }

  group('ChatListTab 深色适配', () {
    testWidgets('空状态图标与文字应为浅色（深色背景下可读）', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const ChatListTab()));
      // userId == null → _isLoading 立即置 false，显示空状态
      await tester.pumpAndSettle();

      // 空状态气泡图标：原 grey.shade400（亮度 0.55）在深色背景上偏暗
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.chat_bubble_outline),
      );
      expect(icon.color, isNotNull);
      expect(
        icon.color!.computeLuminance() > 0.3,
        isTrue,
        reason: '图标颜色 ${icon.color} 应为浅色，实际亮度 ${icon.color!.computeLuminance()}',
      );

      // "暂无消息" 文字：原 grey.shade600（亮度 0.31）在深色背景上不可读
      final emptyText = tester.widget<Text>(
        find.text('暂无消息'),
      );
      final textColor = emptyText.style?.color;
      expect(textColor, isNotNull);
      expect(
        textColor!.computeLuminance() > 0.3,
        isTrue,
        reason: '文字颜色 $textColor 应为浅色，实际亮度 ${textColor.computeLuminance()}',
      );
    });

    testWidgets('会话时间文字应为浅色（深色背景下可读）', (tester) async {
      // 预注入一条带时间的会话，触发列表项渲染
      chatProvider.setConversations([
        Conversation(
          targetId: 100,
          targetType: 'friend',
          lastMsg: 'hello',
          lastMsgTime: DateTime.now().millisecondsSinceEpoch,
          unreadCount: 0,
        ),
      ]);
      await tester.pumpWidget(makeTestableWidget(const ChatListTab()));
      await tester.pumpAndSettle();

      // 找到列表项 trailing 的时间 Text（今天会渲染为 "HH:mm" 格式）
      final timeText = tester.widget<Text>(
        find.byWidgetPredicate((widget) {
          if (widget is Text) {
            final text = widget.data ?? '';
            // 匹配 HH:mm 格式（今天的时间戳）
            return RegExp(r'^\d{2}:\d{2}$').hasMatch(text);
          }
          return false;
        }),
      );
      final textColor = timeText.style?.color;
      expect(textColor, isNotNull, reason: '时间文字应显式指定颜色');
      // 原实现为 grey.shade500（亮度 0.43），深色背景下对比不足
      expect(
        textColor!.computeLuminance() > 0.4,
        isTrue,
        reason: '时间文字 $textColor 应为浅色，实际亮度 ${textColor.computeLuminance()}',
      );
    });

    testWidgets('头像应使用设计令牌色（好友=辅助绿）', (tester) async {
      // 注入一条好友会话，验证头像背景使用设计稿辅助绿而非 Material 默认绿
      chatProvider.setConversations([
        Conversation(
          targetId: 100,
          targetType: 'friend',
          lastMsg: 'hello',
          lastMsgTime: DateTime.now().millisecondsSinceEpoch,
          unreadCount: 0,
        ),
      ]);
      await tester.pumpWidget(makeTestableWidget(const ChatListTab()));
      await tester.pumpAndSettle();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
      // 好友会话头像：辅助绿 #549A78（设计稿"在线/成功"绿）
      expect(avatar.backgroundColor, AppTheme.secondary);
    });

    testWidgets('头像应使用设计令牌色（群组=品牌蓝）', (tester) async {
      // 注入一条群组会话，验证头像背景使用设计稿品牌蓝而非 Material 默认蓝
      chatProvider.setConversations([
        Conversation(
          targetId: 200,
          targetType: 'group',
          lastMsg: 'hello',
          lastMsgTime: DateTime.now().millisecondsSinceEpoch,
          unreadCount: 0,
        ),
      ]);
      await tester.pumpWidget(makeTestableWidget(const ChatListTab()));
      await tester.pumpAndSettle();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
      // 群组会话头像：品牌蓝 #3F8AE2（设计稿主色）
      expect(avatar.backgroundColor, AppTheme.primary);
    });
  });

  group('ContactTab 深色适配', () {
    testWidgets('无联系人提示文字应为浅色（深色背景下可读）', (tester) async {
      await tester.pumpWidget(makeTestableWidget(const ContactTab()));
      // userId == null → _loadData 提前返回，显示"无联系人"空状态
      await tester.pumpAndSettle();

      final emptyText = tester.widget<Text>(
        find.text('暂无联系人'),
      );
      final textColor = emptyText.style?.color;
      expect(textColor, isNotNull);
      // 原实现为 grey.shade600（亮度 0.31），深色背景下不可读
      expect(
        textColor!.computeLuminance() > 0.3,
        isTrue,
        reason: '文字颜色 $textColor 应为浅色，实际亮度 ${textColor.computeLuminance()}',
      );
    });
  });
}
