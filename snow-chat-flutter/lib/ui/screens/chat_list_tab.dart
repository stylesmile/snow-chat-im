import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
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
    if (!mounted) return;

    context.read<ChatProvider>().setConversations(conversations);
    setState(() => _isLoading = false);
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
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(l10n.noMessages, style: TextStyle(color: Colors.grey.shade600)),
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
                  leading: CircleAvatar(
                    backgroundColor: conv.targetType == 'group' ? Colors.blue : Colors.green,
                    child: Text(conv.targetType == 'group' ? '群' : '友'),
                  ),
                  title: Text(conv.targetType == 'group' ? '群组 ${conv.targetId}' : '用户 ${conv.targetId}'),
                  subtitle: Text(conv.lastMsg.isNotEmpty ? conv.lastMsg : l10n.noMessages),
                  trailing: conv.unreadCount > 0
                      ? Badge(child: Text('${conv.unreadCount}'))
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(targetId: conv.targetId, targetType: conv.targetType),
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
