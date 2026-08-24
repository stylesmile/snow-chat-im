import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_request_provider.dart';
import '../../services/chat_service.dart';
import '../../services/conversation_service.dart';
import '../../services/group_service.dart';
import '../../config/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/ws_cmd.dart';
import '../../core/network/mqtt_client.dart';
import '../../core/utils/message_utils.dart';
import 'chat_list_tab.dart';
import 'contact_tab.dart';
import 'profile_tab.dart';
import 'add_friend_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0; // 当前选中的导航索引，驱动 BottomNavigationBar 高亮
  FriendRequestProvider? _friendRequestProvider;
  ChatProvider? _chatProvider;
  bool _pollingStarted = false;
  // 登录后全局 MQTT 连接，用于推送聊天列表新消息、好友请求通知
  MqttChatClient? _mqttClient;
  final ValueNotifier<int> _friendAcceptedNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  /// TabController 变化时同步导航栏高亮（包括滑动切换和点击切换）
  void _onTabChanged() {
    // TabController.indexIsChanging 为 true 时表示动画进行中，跳过中间帧
    if (!_tabController.indexIsChanging) return;
    setState(() => _currentIndex = _tabController.index);
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
        // 启动好友请求轮询（REST 备用，MQTT 实时优先）
        _friendRequestProvider?.startPolling(auth.userId!);
        // 登录后连接全局 MQTT，接收新消息推送和好友请求通知
        // 已在登录时连接过则跳过（_mqttClient 已有实例）
        if (AppConfig.enableMqtt && _mqttClient == null) {
          _initMqtt(auth.userId!);
        } else if (!AppConfig.enableMqtt) {
          debugPrint('[Home] MQTT disabled by config, relying on REST polling');
        }
      }
    }
  }

  /// 初始化并连接全局 MQTT（登录时调用一次）
  void _initMqtt(int userId) {
    _mqttClient = MqttChatClient(
      host: AppConfig.mqttHost,
      port: AppConfig.mqttPort,
      onConnected: () => _subscribeAllGroups(userId),
      // 自动重连成功后补拉未送达消息
      onReconnected: () {
        if (!mounted) return;
        final conversations = _chatProvider?.conversations ?? [];
        if (conversations.isEmpty) return;
        final records = conversations
            .map((c) => (targetId: c.targetId, targetType: c.targetType))
            .toList();
        ChatService(context.read<AuthProvider>().apiClient)
            .syncAllConversations(userId, records);
      },
      onMessage: (cmd, data) {
        if (!mounted) return;
        if (cmd == WsCmd.friendAccepted) {
          // 好友请求被接受：刷新好友列表 + 创建新对话 + 提示
          _friendRequestProvider?.refresh();
          _friendAcceptedNotifier.value++;
          final fromUserId = MessageUtils.toNullableInt(data['fromUserId']);
          final toUserId = MessageUtils.toNullableInt(data['toUserId']);
          if (fromUserId != null && toUserId != null) {
            final friendId = fromUserId == userId ? toUserId : fromUserId;
            _chatProvider?.updateConversation(
              Conversation(targetId: friendId, targetType: 'friend'),
            );
            ConversationService().saveSession(
              context: context,
              targetId: friendId,
              targetType: 'friend',
              lastMsg: '',
              lastMsgTime: DateTime.now().millisecondsSinceEpoch,
              unreadCount: 0,
            );
          }
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.friendRequestAccepted),
                backgroundColor: AppTheme.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (cmd == WsCmd.friendReqNotify) {
          // 收到好友请求通知：刷新未读数量
          _friendRequestProvider?.refresh();
          debugPrint('[Home] friendReqNotify received, refreshing friend request count');
        } else if (cmd == WsCmd.msgPush) {
          // 收到新消息：更新聊天列表会话
          _handleIncomingMessage(data as Map<String, dynamic>? ?? {}, userId);
        } else if (cmd == WsCmd.msgReceiptAck) {
          debugPrint('[Home] msgReceiptAck: data=$data');
        } else if (cmd == WsCmd.fetchUndeliveredAck) {
          final messages = (data as Map<String, dynamic>?)?['messages'] as List<dynamic>? ?? [];
          debugPrint('[Home] fetchUndeliveredAck: ${messages.length} messages');
        }
      },
    );
    _mqttClient!.connect(
      userId: userId,
      username: AppConfig.mqttUsername,
      password: AppConfig.mqttPassword,
    );
  }

  /// 处理收到的新消息，更新聊天列表会话
  void _handleIncomingMessage(Map<String, dynamic> data, int userId) {
    final fromUserId = MessageUtils.toNullableInt(data['fromUserId']);
    final toUserId = MessageUtils.toNullableInt(data['toUserId']);
    final groupId = MessageUtils.toNullableInt(data['groupId']);
    final content = data['content'] as String? ?? '';
    final createTime = MessageUtils.toInt(data['createTime'], DateTime.now().millisecondsSinceEpoch);
    final int? groupIdValue = groupId;
    final bool isGroup = groupIdValue != null;
    final int targetId = isGroup
        ? groupIdValue!
        : (fromUserId == userId ? (toUserId ?? 0) : (fromUserId ?? 0));
    final String targetType = isGroup ? 'group' : 'friend';
    final existingIndex = _chatProvider?.conversations.indexWhere(
      (c) => c.targetId == targetId && c.targetType == targetType,
    );
    final existing = (existingIndex != null && existingIndex >= 0)
        ? _chatProvider!.conversations[existingIndex]
        : Conversation(targetId: targetId, targetType: targetType);
    final updated = Conversation(
      targetId: targetId,
      targetType: targetType,
      lastMsg: content,
      lastMsgTime: createTime,
      unreadCount: existing.unreadCount + 1,
    );
    _chatProvider?.updateConversation(updated);
    ConversationService().saveSession(
      context: context,
      targetId: targetId,
      targetType: targetType,
      lastMsg: content,
      lastMsgTime: createTime,
      unreadCount: updated.unreadCount,
    );
  }

  /// 订阅用户所在的所有群主题
  Future<void> _subscribeAllGroups(int userId) async {
    if (_mqttClient == null || !_mqttClient!.isConnected) return;
    try {
      final service = GroupService(context.read<AuthProvider>().apiClient);
      final groups = await service.getGroups(userId);
      for (final group in groups) {
        _mqttClient?.subscribeGroup(group.id);
      }
    } catch (e) {
      debugPrint('[Home] failed to subscribe groups: $e');
    }
  }

  /// 构建带角标的导航图标（未读数直接显示在图标右上角）
  Widget _buildNavItemIcon(IconData outlined, IconData filled, bool hasBadge, int? count) {
    return Stack(
      children: [
        Icon(hasBadge ? filled : outlined, color: Colors.white54),
        if (hasBadge && count != null)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 8),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
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
    // 监听会话变化，获取总未读数用于导航栏角标
    final chatProvider = context.watch<ChatProvider>();
    final totalUnread = chatProvider.totalUnreadCount;

    return Scaffold(
      // 顶部 TabBar 导航：会话 / 通讯录 / 个人中心
      appBar: AppBar(
        // 背景色与页面一致，保持深色主题连贯性
        backgroundColor: AppTheme.background,
        // 无阴影，扁平风格
        elevation: 0,
        title: Text(l10n.chat),
        centerTitle: false,
        actions: [
          // 添加联系人按钮
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: '添加联系人',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFriendScreen()),
              );
            },
          ),
          // 更多操作按钮
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: '更多',
            onPressed: () {},
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const ChatListTab(),
          ContactTab(friendAcceptedNotifier: _friendAcceptedNotifier),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: _buildNavItemIcon(Icons.chat_bubble_outline, Icons.chat_bubble, totalUnread > 0, totalUnread),
            label: l10n.chat,
          ),
          BottomNavigationBarItem(
            icon: _buildNavItemIcon(Icons.people_outline, Icons.people, hasFriendRequest, null),
            label: l10n.contacts,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '个人中心',
          ),
        ],
        onTap: (index) {
          // 切换 Tab 时更新当前索引并同步 TabController
          setState(() => _currentIndex = index);
          _tabController.animateTo(index);
        },
      ),
    );
  }
}
