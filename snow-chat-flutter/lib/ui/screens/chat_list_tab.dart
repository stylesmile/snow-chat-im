import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/contact_service.dart';
import '../../services/conversation_service.dart';
import 'chat_detail_screen.dart';
import 'login_screen.dart';

class ChatListTab extends StatefulWidget {
  const ChatListTab({super.key});

  @override
  State<ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<ChatListTab> {
  bool _isLoading = true;
  /// 好友 userId -> 昵称 映射，用于聊天列表显示对方名称
  final Map<int, String> _friendNames = {};

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final conversations = await ConversationService().loadSessions(auth.userId!);

    // 从本地好友缓存查询昵称，用于展示会话标题
    final contactService = ContactService(auth.apiClient);
    final friends = await contactService.getLocalFriends();
    _friendNames
      ..clear()
      ..addAll({for (final f in friends) f.userId: f.nickname});

    if (!mounted) return;

    context.read<ChatProvider>().setConversations(conversations);
    setState(() => _isLoading = false);
  }

  /// 显示会话标题：好友显示昵称，群组暂用占位
  String _displayName(Conversation conv) {
    if (conv.targetType == 'group') {
      return '群组 ${conv.targetId}';
    }
    return _friendNames[conv.targetId] ?? '用户 ${conv.targetId}';
  }

  /// 构建带未读数角标的头像（类似微信）
  Widget _buildAvatar(Conversation conv) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          // 头像底色使用设计令牌：群组=品牌蓝，好友=辅助绿（替换 Material 默认色）
          backgroundColor: conv.targetType == 'group' ? AppTheme.primary : AppTheme.secondary,
          child: Text(conv.targetType == 'group' ? '群' : '友'),
        ),
        // 未读数角标：显示在头像右上角
        if (conv.unreadCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 10, height: 1),
              ),
            ),
          ),
      ],
    );
  }

  /// 格式化时间：今天显示时分，昨天显示"昨天"，更早显示日期
  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);

    if (messageDay == today) {
      // 今天：显示时分
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      // 昨天
      return '昨天';
    } else if (now.year == date.year) {
      // 今年：显示月日
      return '${date.month}/${date.day}';
    } else {
      // 更早：显示年月日
      return '${date.year}/${date.month}/${date.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatList),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: l10n.addFriend,
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(children: [const Icon(Icons.logout), const SizedBox(width: 12), Text(l10n.logout)]),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthProvider>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (_, chatProvider, __) {
          final conversations = chatProvider.conversations;

          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 空状态图标：深色背景下使用低透明度白，柔和且可见
                  const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  // 空状态文字：半透明白，保证深色背景上可读
                  Text(l10n.noMessages, style: const TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return Dismissible(
                key: ValueKey('${conv.targetType}_${conv.targetId}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.delete),
                      content: Text('${l10n.delete}?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: Text(l10n.confirm),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) async {
                  final auth = context.read<AuthProvider>();
                  if (auth.userId != null) {
                    await ConversationService().deleteSession(
                      userId: auth.userId!,
                      targetId: conv.targetId,
                      targetType: conv.targetType,
                    );
                  }
                  chatProvider.removeConversation(conv.targetId, conv.targetType);
                },
                child: ListTile(
                  leading: _buildAvatar(conv),
                  title: Text(_displayName(conv)),
                  subtitle: Text(conv.lastMsg.isNotEmpty ? conv.lastMsg : l10n.noMessages),
                  trailing: conv.lastMsgTime > 0
                      ? Text(
                          _formatTime(conv.lastMsgTime),
                          // 时间文字：半透明白，深色背景上保持弱化但可读
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        )
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          targetId: conv.targetId,
                          targetType: conv.targetType,
                          targetName: _displayName(conv),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
