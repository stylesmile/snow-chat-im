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
  MqttChatClient? _mqttClient;
  final ValueNotifier<int> _friendAcceptedNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 监听 TabController 变化，同步 BottomNavigationBar 高亮
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
        _friendRequestProvider?.startPolling(auth.userId!);
        _initMqtt(auth.userId!);
      }
    }
  }

  void _initMqtt(int userId) {
    _mqttClient = MqttChatClient(
      host: AppConfig.mqttHost,
      port: AppConfig.mqttPort,
      onConnected: () => _subscribeAllGroups(userId),
      // MQTT 自动重连成功后的回调：请求服务器补推所有会话的未送达消息
      // 触发时机：网络恢复 / MQTT broker 重启后客户端自动重连成功
      onReconnected: () {
        // 重连回调可能在 widget 已销毁后触发，需检查 mounted
        if (!mounted) return;
        // 从缓存的 ChatProvider 获取当前会话列表
        final conversations = _chatProvider?.conversations ?? [];
        // 空会话列表时跳过，避免无意义的网络请求
        if (conversations.isEmpty) return;
        // 将 Conversation 列表映射为 record，解耦服务层与 provider 层
        // record 类型 ({int targetId, String targetType}) 避免 ChatService 依赖 Conversation 类
        final conversationRecords = conversations
            .map((c) => (targetId: c.targetId, targetType: c.targetType))
            .toList();
        // 创建 ChatService 并批量请求补推（fire-and-forget，不阻塞 MQTT 线程）
        // ApiClient 从 AuthProvider 获取（didChangeDependencies 时已初始化）
        final apiClient = context.read<AuthProvider>().apiClient;
        ChatService(apiClient).syncAllConversations(userId, conversationRecords);
      },
      onMessage: (cmd, data) {
        if (!mounted) return;
        if (cmd == WsCmd.friendAccepted) {
          // 刷新好友请求列表
          _friendRequestProvider?.refresh();
          // 通知联系人 tab 刷新好友列表
          _friendAcceptedNotifier.value++;

          // 在聊天列表中创建与新好友的对话
          final fromUserId = MessageUtils.toNullableInt(data['fromUserId']);
          final toUserId = MessageUtils.toNullableInt(data['toUserId']);
          if (fromUserId != null && toUserId != null) {
            // 确定新好友的 ID（不是自己的那个）
            final friendId = fromUserId == userId ? toUserId : fromUserId;
            // 创建空对话，确保聊天列表中可见
            _chatProvider?.updateConversation(
              Conversation(
                targetId: friendId,
                targetType: 'friend',
                lastMsg: '',
                lastMsgTime: DateTime.now().millisecondsSinceEpoch,
                unreadCount: 0,
              ),
            );
            // 持久化到数据库
            ConversationService().saveSession(
              userId: userId,
              targetId: friendId,
              targetType: 'friend',
              lastMsg: '',
              lastMsgTime: DateTime.now().millisecondsSinceEpoch,
              unreadCount: 0,
            );
          }

          // 显示提示
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.friendRequestAccepted),
                // 提示条背景：品牌蓝（原紫色 #7C4DFF 已随主题切换弃用）
                backgroundColor: AppTheme.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (cmd == WsCmd.msgPush) {
          // 更新聊天列表：收到新消息时将会话置顶并增加未读数
          _handleIncomingMessage(data as Map<String, dynamic>? ?? {}, userId);
        } else if (cmd == WsCmd.msgReceiptAck) {
          // 服务器回执：消息已推送给对方（HomeScreen 只做日志记录，详细处理在 chat_detail_screen）
          debugPrint('[Home] msgReceiptAck: data=$data');
        } else if (cmd == WsCmd.fetchUndeliveredAck) {
          // 服务器推送未推送成功的消息（HomeScreen 只做日志记录，详细处理在 chat_detail_screen）
          final messages = (data as Map<String, dynamic>?)?['messages'] as List<dynamic>? ?? [];
          debugPrint('[Home] fetchUndeliveredAck: ${messages.length} messages');
        }
      },
    );
    // 连接 MQTT
    _mqttClient!.connect(
      userId: userId,
      username: AppConfig.mqttUsername,
      password: AppConfig.mqttPassword,
    );
  }

  /// 处理收到的消息，更新本地会话与内存列表
  void _handleIncomingMessage(Map<String, dynamic> data, int userId) {
    debugPrint('[Home] _handleIncomingMessage userId=$userId, data=$data');
    final fromUserId = MessageUtils.toNullableInt(data['fromUserId']);
    final toUserId = MessageUtils.toNullableInt(data['toUserId']);
    final groupId = MessageUtils.toNullableInt(data['groupId']);
    final content = data['content'] as String? ?? '';
    final createTime = MessageUtils.toInt(
      data['createTime'],
      DateTime.now().millisecondsSinceEpoch,
    );

    final int? groupIdValue = groupId;
    final bool isGroup = groupIdValue != null;
    final int targetId = isGroup
        ? groupIdValue
        : (fromUserId == userId ? (toUserId ?? 0) : (fromUserId ?? 0));
    final String targetType = isGroup ? 'group' : 'friend';
    debugPrint('[Home] resolved targetId=$targetId, targetType=$targetType, isGroup=$isGroup');

    // 查找或创建会话
    final existingIndex = _chatProvider?.conversations.indexWhere(
      (c) => c.targetId == targetId && c.targetType == targetType,
    );
    final Conversation existing;
    if (existingIndex != null && existingIndex >= 0) {
      existing = _chatProvider!.conversations[existingIndex];
    } else {
      existing = Conversation(targetId: targetId, targetType: targetType);
    }
    debugPrint('[Home] existing conversation found=$existingIndex, current unread=${existing.unreadCount}');

    final updated = Conversation(
      targetId: targetId,
      targetType: targetType,
      lastMsg: content,
      lastMsgTime: createTime,
      unreadCount: existing.unreadCount + 1,
    );
    debugPrint('[Home] updating conversation: targetId=$targetId, new unread=${updated.unreadCount}');
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

  /// MQTT 连接成功后，订阅用户所在的所有群主题
  Future<void> _subscribeAllGroups(int userId) async {
    // 确保 MQTT 已连接
    if (_mqttClient == null || !_mqttClient!.isConnected) {
      debugPrint('[Home] _subscribeAllGroups SKIPPED: MQTT not connected, state=${_mqttClient?.isConnected}');
      return;
    }
    try {
      final service = GroupService(context.read<AuthProvider>().apiClient);
      final groups = await service.getGroups(userId);
      debugPrint('[Home] _subscribeAllGroups: found ${groups.length} groups for userId=$userId');
      for (final group in groups) {
        _mqttClient?.subscribeGroup(group.id);
      }
    } catch (e) {
      debugPrint('[Home] failed to subscribe groups: $e');
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
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
    // 监听会话变化，获取总未读数用于导航栏角标
    final chatProvider = context.watch<ChatProvider>();
    final totalUnread = chatProvider.totalUnreadCount;

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
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        // 选中项：品牌蓝（主题主色）；未选中项：半透明白（深色模式标准）
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.white54,
        items: [
          BottomNavigationBarItem(
            icon: _buildCountBadge(
              image: 'assets/icons/chat/ic_chat_n.png',
              count: totalUnread,
            ),
            activeIcon: _buildCountBadge(
              image: 'assets/icons/chat/ic_chat_s.png',
              count: totalUnread,
            ),
            label: l10n.chat,
          ),
          BottomNavigationBarItem(
            icon: _buildBadgeIcon(
              image: 'assets/icons/contacts/ic_contacts_n.png',
              showBadge: hasFriendRequest,
            ),
            activeIcon: _buildBadgeIcon(
              image: 'assets/icons/contacts/ic_contacts_s.png',
              showBadge: hasFriendRequest,
            ),
            label: l10n.contacts,
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/profile/ic_mine_n.png', width: 24, height: 24, color: Colors.white54),
            activeIcon: Image.asset('assets/icons/profile/ic_mine_s.png', width: 24, height: 24),
            label: l10n.profile,
          ),
        ],
        onTap: (index) {
          _tabController.animateTo(index);
        },
      ),
    );
  }

  /// 带数字角标的图标（用于聊天 tab 显示未读数）
  Widget _buildCountBadge({required String image, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Image.asset(image, width: 24, height: 24),
        if (count > 0)
          Positioned(
            right: -6,
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
                count > 99 ? '99+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, height: 1),
              ),
            ),
          ),
      ],
    );
  }

  /// 带小红点的图标（用于通讯录 tab 显示好友请求）
  Widget _buildBadgeIcon({required String image, required bool showBadge}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Image.asset(image, width: 24, height: 24),
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
