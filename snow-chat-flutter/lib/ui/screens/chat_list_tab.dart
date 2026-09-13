import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/friend_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/contact_service.dart';
import '../../services/conversation_service.dart';
import '../widgets/avatar_widget.dart';
import 'chat_detail_screen.dart';
import 'global_search_screen.dart';

class ChatListTab extends StatefulWidget {
  const ChatListTab({super.key});

  @override
  State<ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<ChatListTab> {
  bool _isLoading = true;
  /// 好友 userId -> 会话显示名（**备注优先，其次昵称**，与通讯录列表口径一致）
  final Map<int, String> _friendNames = {};
  /// 好友 userId -> 头像地址，用于在会话列表里展示真实头像
  final Map<int, String> _friendAvatars = {};

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  /// 好友的会话显示名：有备注用备注、否则用昵称（与 ContactTab 的列表一致）
  static String _displayNameOf(FriendModel friend) =>
      friend.remark.isNotEmpty ? friend.remark : friend.nickname;

  /// 拉取「好友目录」（userId → 显示名 / 头像）
  ///
  /// 会话本身只存了 `targetId`，列表上的名字和头像全靠这份目录翻译。
  /// 优先走后端（唯一可信数据源），拿不到时回退本地 SQLite 缓存 ——
  /// 否则后端未启动时会满屏「用户 1002」和清一色的占位头像。
  Future<void> _loadFriendDirectory() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final contactService = ContactService(auth.apiClient);

    var friends = await contactService.getFriends(auth.userId!);
    if (!mounted) return;
    if (friends.isEmpty) {
      // 后端不可用（或还没加过好友）时用上次同步的缓存兜底
      friends = await contactService.getLocalFriends(context);
    } else {
      // 顺带刷新本地缓存，供下次离线展示
      await contactService.saveLocalFriends(context, friends);
    }

    if (!mounted) return;
    setState(() {
      _friendNames
        ..clear()
        ..addAll({for (final f in friends) f.userId: _displayNameOf(f)});
      _friendAvatars
        ..clear()
        ..addAll({for (final f in friends) f.userId: f.avatar});
    });
  }

  Future<void> _loadConversations() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await _loadFriendDirectory();
    if (!mounted) return;

    final conversations = await ConversationService().loadSessions(context);
    if (!mounted) return;

    context.read<ChatProvider>().setConversations(conversations);
    setState(() => _isLoading = false);
  }

  /// 显示会话标题：按 targetId 查好友目录，查不到才回退带 id 的占位名
  String _displayName(Conversation conv) {
    if (conv.targetType == 'group') {
      return '群组 ${conv.targetId}';
    }
    final name = _friendNames[conv.targetId];
    return name != null && name.isNotEmpty ? name : '用户 ${conv.targetId}';
  }

  /// 构建带未读数角标的头像（类似微信）
  ///
  /// 好友用**真实头像**（无头像时退回名字首字占位），群聊仍用「群」字圆底。
  Widget _buildAvatar(Conversation conv) {
    final name = _displayName(conv);
    final avatar = _friendAvatars[conv.targetId] ?? '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (conv.targetType == 'group')
          const CircleAvatar(
            // 群聊头像底色使用设计令牌：品牌蓝
            backgroundColor: AppTheme.primary,
            child: Text('群'),
          )
        else
          AvatarWidget(
            imageUrl: avatar,
            // 没有头像图时显示名字首字，而不是一个与本人无关的「友」字
            initials: name.isNotEmpty ? name[0] : '?',
            size: 40,
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

  /// 顶部搜索入口；点击进入全局搜索页。
  Widget _buildSearchEntry(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: GestureDetector(
        onTap: () {
          // 跳转到全局搜索页，检索联系人/聊天记录
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
          );
        },
        child: TextField(
          // 仅作入口展示；不接收输入，点击整体跳转
          enabled: false,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            prefixIcon: const Icon(Icons.search),
            filled: true,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.conversations;

    // 顶部搜索入口，点击进入全局搜索页
    final Widget searchBar = _buildSearchEntry(l10n);
    Widget content;

    if (_isLoading) {
      // 会话列表加载中
      content = const Center(child: CircularProgressIndicator());
    } else if (conversations.isEmpty) {
      // 无会话时的空态引导
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(l10n.noMessages, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    } else {
      // 会话列表（支持下拉刷新：重新拉好友目录 + 重新读本地会话，
      // 后端恢复后不必重启 app 就能把「用户 1002」刷新成真实昵称与头像）
      content = RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView.separated(
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
        ),
      );
    }

    // 顶部搜索条 + 下方会话内容
    return Column(
      children: [searchBar, Expanded(child: content)],
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
