import 'package:flutter/foundation.dart';
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
  /// 好友 userId -> 昵称 映射，从本地缓存加载（与通讯录保持一致）
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

    final contactService = ContactService(auth.apiClient);

    // 优先从后端 API 拉取好友列表（含 nickname），这是唯一可信的数据源
    final friends = await contactService.getFriends(auth.userId!);
    if (kDebugMode) {
      print('[ChatList] getFriends returned ${friends.length} friends: ${friends.map((f) => '\${f.userId}(\${f.nickname})').join(', ')}');
    }

    _friendNames
      ..clear()
      ..addAll({for (final f in friends) f.userId: f.nickname});

    // API 为空时，回退到本地 SQLite 缓存（与通讯录保持一致）
    if (_friendNames.isEmpty || _friendNames.values.every((n) => n.isEmpty)) {
      final localFriends = await contactService.getLocalFriends(context);
      if (kDebugMode) {
        print('[ChatList] API returned empty, fallback to local friends: ${localFriends.length}');
      }
      _friendNames
        ..clear()
        ..addAll({for (final f in localFriends) f.userId: f.nickname});
    }

    // 同时更新本地 SQLite 缓存
    if (friends.isNotEmpty) {
      await contactService.saveLocalFriends(context, friends);
    }

    final conversations = await ConversationService().loadSessions(context);

    if (!mounted) return;

    context.read<ChatProvider>().setConversations(conversations);
    setState(() => _isLoading = false);
  }

  /// 显示会话标题：从好友映射查昵称，查不到才显示用户ID
  String _displayName(Conversation conv) {
    if (conv.targetType == 'group') {
      return '群组 ${conv.targetId}';
    }
    final name = _friendNames[conv.targetId];
    return name != null && name.isNotEmpty ? name : '用户 ${conv.targetId}';
  }

  /// 构建带未读数角标的头像（类似微信）
  Widget _buildAvatar(Conversation conv) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          // 头像底色使用设计令牌：群组=品牌蓝，好友=辅助绿
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

  /// 格式化时间：今天显示时分，昨天显示昨天，更早显示日期
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
    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.conversations;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(l10n.noMessages, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final conv = conversations[index];
        return ListTile(
          leading: _buildAvatar(conv),
          title: Text(
            _displayName(conv),
            style: const TextStyle(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            conv.lastMsg.isNotEmpty ? conv.lastMsg : l10n.noMessages,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            _formatTime(conv.lastMsgTime),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
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
          onLongPress: () => _showConversationActions(conv),
        );
      },
    );
  }

  /// 长按会话弹出操作菜单：置顶/取消置顶、免打扰/取消免打扰、删除会话
  ///
  /// 每个操作都会更新内存状态（ChatProvider）并持久化到本地 SQLite
  Future<void> _showConversationActions(Conversation conv) async {
    final chatProvider = context.read<ChatProvider>();
    final conversationService = ConversationService();
    final isPinned = conv.isPinned;
    final isMuted = conv.isMuted;

    // 底部弹出操作面板，供用户选择针对当前会话的操作
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 面板标题：显示会话名称
              ListTile(
                title: Text(
                  _displayName(conv),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                dense: true,
              ),
              const Divider(height: 1),
              // 置顶/取消置顶
              ListTile(
                leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(isPinned ? '取消置顶' : '置顶会话'),
                onTap: () => Navigator.pop(ctx, 'pin'),
              ),
              // 免打扰/取消免打扰
              ListTile(
                leading: Icon(isMuted ? Icons.notifications_off_outlined : Icons.notifications_off),
                title: Text(isMuted ? '取消免打扰' : '消息免打扰'),
                onTap: () => Navigator.pop(ctx, 'mute'),
              ),
              // 删除会话
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除会话', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    // 面板关闭后，若组件已卸载则直接返回，避免使用失效的 context
    if (!mounted) return;

    // 根据用户选择执行对应操作
    switch (action) {
      case 'pin':
        // 切换置顶状态，并持久化到本地数据库
        chatProvider.togglePinned(conv.targetId, conv.targetType, pinned: !isPinned);
        await conversationService.updateSessionFlags(
          context: context,
          targetId: conv.targetId,
          targetType: conv.targetType,
          isPinned: !isPinned,
        );
        break;
      case 'mute':
        // 切换免打扰状态，并持久化到本地数据库
        chatProvider.toggleMuted(conv.targetId, conv.targetType, muted: !isMuted);
        await conversationService.updateSessionFlags(
          context: context,
          targetId: conv.targetId,
          targetType: conv.targetType,
          isMuted: !isMuted,
        );
        break;
      case 'delete':
        // 删除会话：先从数据库删除，再从内存列表移除
        await conversationService.deleteSession(
          context: context,
          targetId: conv.targetId,
          targetType: conv.targetType,
        );
        chatProvider.removeConversation(conv.targetId, conv.targetType);
        break;
    }
  }
}
