import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_request_provider.dart';
import '../../services/conversation_service.dart';
import '../../services/group_service.dart';
import '../../services/chat_service.dart';
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
  MqttChatClient? _mqttClient; // 登录后全局 MQTT 连接，用于推送聊天列表新消息和好友请求
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
        // 启动好友请求轮询（REST 方式，无需 MQTT）
        _friendRequestProvider?.startPolling(auth.userId!);
      }
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
