import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_request_provider.dart';
import '../../services/conversation_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/ws_cmd.dart';
import '../../core/network/mqtt_client.dart';
import 'chat_list_tab.dart';
import 'contact_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FriendRequestProvider? _friendRequestProvider;
  ChatProvider? _chatProvider;
  bool _pollingStarted = false;
  MqttChatClient? _mqttClient;
  final ValueNotifier<int> _friendAcceptedNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _friendRequestProvider ??= context.read<FriendRequestProvider>();
    _chatProvider ??= context.read<ChatProvider>();
    if (!_pollingStarted) {
      _pollingStarted = true;
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        _friendRequestProvider?.startPolling(auth.userId!);
        _initMqtt(auth.userId!);
      }
    }
  }

  void _initMqtt(int userId) {
    _mqttClient = MqttChatClient(
      host: ApiConstants.mqttHost,
      port: ApiConstants.mqttPort,
      onMessage: (cmd, data) {
        if (!mounted) return;
        if (cmd == WsCmd.friendAccepted) {
          // 刷新好友请求列表
          _friendRequestProvider?.refresh();
          // 通知联系人 tab 刷新好友列表
          _friendAcceptedNotifier.value++;
          // 显示提示
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.friendRequestAccepted),
                backgroundColor: const Color(0xFF7C4DFF),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (cmd == WsCmd.msgPush) {
          // 更新聊天列表：收到新消息时将会话置顶并增加未读数
          _handleIncomingMessage(data as Map<String, dynamic>? ?? {}, userId);
        }
      },
    );
    _mqttClient!.connect(
      userId: userId,
      username: ApiConstants.mqttUsername,
      password: ApiConstants.mqttPassword,
    );
  }

  /// 处理收到的消息，更新本地会话与内存列表
  void _handleIncomingMessage(Map<String, dynamic> data, int userId) {
    final fromUserId = data['fromUserId'] as int?;
    final toUserId = data['toUserId'] as int?;
    final groupId = data['groupId'] as int?;
    final content = data['content'] as String? ?? '';
    final createTime = data['createTime'] is int
        ? data['createTime'] as int
        : DateTime.now().millisecondsSinceEpoch;

    final bool isGroup = groupId != null;
    final int targetId = isGroup ? groupId : (fromUserId == userId ? toUserId! : fromUserId!);
    final String targetType = isGroup ? 'group' : 'friend';

    final existing = _chatProvider?.conversations.firstWhere(
      (c) => c.targetId == targetId && c.targetType == targetType,
      orElse: () => Conversation(targetId: targetId, targetType: targetType),
    );
    if (existing == null) return;

    final updated = Conversation(
      targetId: targetId,
      targetType: targetType,
      lastMsg: content,
      lastMsgTime: createTime,
      unreadCount: existing.unreadCount + 1,
    );
    _chatProvider?.updateConversation(updated);

    ConversationService().saveSession(
      userId: userId,
      targetId: targetId,
      targetType: targetType,
      lastMsg: content,
      lastMsgTime: createTime,
      unreadCount: updated.unreadCount,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    // 停止好友请求轮询，使用缓存的引用，避免在 dispose 中访问 context
    // notify 设为 false，防止在 widget tree locked 时触发 notifyListeners
    _friendRequestProvider?.stopPolling(notify: false);
    _mqttClient?.disconnect();
    _friendAcceptedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final friendReqProvider = context.watch<FriendRequestProvider>();
    final hasFriendRequest = friendReqProvider.hasUnread;

    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: [
          const ChatListTab(),
          ContactTab(friendAcceptedNotifier: _friendAcceptedNotifier),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabController.index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            activeIcon: const Icon(Icons.chat),
            label: l10n.chat,
          ),
          BottomNavigationBarItem(
            icon: _buildBadgeIcon(
              icon: Icons.people_outline,
              showBadge: hasFriendRequest,
            ),
            activeIcon: _buildBadgeIcon(
              icon: Icons.people,
              showBadge: hasFriendRequest,
            ),
            label: l10n.contacts,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l10n.profile,
          ),
        ],
        onTap: (index) {
          _tabController.animateTo(index);
        },
      ),
    );
  }

  /// 带小红点的图标
  Widget _buildBadgeIcon({required IconData icon, required bool showBadge}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (showBadge)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
