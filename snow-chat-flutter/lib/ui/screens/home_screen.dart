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

  // ---------------------------------------------------------------------------
  // 底部导航图标资源路径
  //
  // 图标取自对标项目 win-chat-android（wkuikit 模块 mipmap 下的 ic_chat/ic_contacts/ic_mine），
  // 文件名后缀含义：_n = 未选中（描边）、_s = 选中（实心）。
  // 集中定义为常量，避免同一路径在 icon 与 activeIcon 两处重复书写而写歪。
  // ---------------------------------------------------------------------------

  /// 会话图标（未选中）：描边对话框
  static const String _navChatIcon = 'assets/images/navigation/chat.png';

  /// 会话图标（选中）：实心对话框
  static const String _navChatIconActive = 'assets/images/navigation/chat_s.png';

  /// 通讯录图标（未选中）：描边人像 + 列表线
  static const String _navContactsIcon = 'assets/images/navigation/contract.png';

  /// 通讯录图标（选中）：实心人像 + 列表线
  static const String _navContactsIconActive = 'assets/images/navigation/contract_s.png';

  /// 个人中心图标（未选中）：描边人像
  static const String _navProfileIcon = 'assets/images/navigation/my.png';

  /// 个人中心图标（选中）：实心人像
  static const String _navProfileIconActive = 'assets/images/navigation/my_s.png';

  /// 通讯录 tab 在底部导航中的索引
  ///
  /// ContactTab 自带 AppBar（标题「通讯录」+ 搜索/添加好友），若外层再叠加固定标题栏
  /// 就会出现两个标题栏，故该索引下外层让位给页面自己的 AppBar。
  static const int _contactsTabIndex = 1;

  /// 个人中心 tab 在底部导航中的索引
  ///
  /// 该页为沉浸式布局（对标项目 win-chat-android 的「我的」页同样不带标题栏），
  /// 外层标题栏在此让位，否则顶部会挂着一个与本页无关的「会话」标题。
  static const int _profileTabIndex = 2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  /// TabController 变化时同步当前索引（导航栏高亮与顶部标题栏都依赖它）
  void _onTabChanged() {
    // 不能只判断 indexIsChanging：点击切换时它为 true（此时 index 已是目标值），
    // 而滑动手势期间它为 false，要等拖动/动画结束后 index 才更新并再次触发本回调。
    // 用「与当前索引比较」的方式才能同时覆盖点击与滑动两种情况，
    // 否则滑动到通讯录时顶部标题栏不会让位，双标题栏会再次出现。
    if (_currentIndex == _tabController.index) return;
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
  /// 构建底部导航图标：以设计稿的 PNG 形状渲染，并按需叠加红色未读角标
  ///
  /// [assetPath] 图标资源路径。未选中态传入描边图（*_n），选中态传入实心图（*_s），
  ///   形状随之由「描边」切换为「实心」，与对标项目（win-chat-android）的交互一致。
  /// [color] 图标染色。资源本身自带颜色（灰/绿），这里用 [BlendMode.srcIn] 只取其
  ///   透明度通道，从而使同一份资源能适配任意主题色——不必为每种颜色单独导出图片。
  /// [hasBadge] 是否显示未读角标；[count] 为角标数字，超过 99 显示为 99+。
  ///   两者都为真时才渲染角标（仅提示"有新内容"但无具体数量时可不传 count）。
  Widget _buildNavItemIcon({
    required String assetPath,
    required Color color,
    bool hasBadge = false,
    int? count,
  }) {
    // 图标主体：24 逻辑像素见方，与 Flutter 底部导航的默认图标尺寸对齐
    final icon = Image.asset(
      assetPath,
      width: 24,
      height: 24,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      // 资源为高分辨率 PNG，显式指定高质量过滤可避免缩小渲染时描边发虚
      filterQuality: FilterQuality.high,
    );

    // 无需角标时直接返回图标本身，省掉一层 Stack 布局
    if (!hasBadge || count == null) {
      return icon;
    }

    // 有未读数量时叠加角标；选中与未选中两种状态都要显示，故调用方需分别传入
    return Stack(
      children: [
        icon,
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            // 角标为红底白字圆形，尺寸随文字自适应并保证最小 14x14 可点面积
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: Text(
              // 超过两位数的未读量收敛为 99+，避免角标横向撑开遮挡相邻图标
              count > 99 ? '99+' : '$count',
              style: const TextStyle(color: Colors.white, fontSize: 8),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建顶部标题栏（会话 / 通讯录 / 个人中心 三个 tab 共用）
  ///
  /// 通讯录 tab 返回 null，让位给 ContactTab 自带的 AppBar —— 该页的标题栏里
  /// 还有「搜索」与「添加好友」两个动作，外层若再画一个就会出现两个标题栏。
  /// 个人中心 tab 同样返回 null：该页是沉浸式布局，顶部不需要标题栏。
  PreferredSizeWidget? _buildAppBar(AppLocalizations l10n) {
    if (_currentIndex == _contactsTabIndex ||
        _currentIndex == _profileTabIndex) {
      return null;
    }

    return AppBar(
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
      // 顶部标题栏：通讯录与个人中心两个 tab 均返回 null ——
      // 前者由 ContactTab 自带的 AppBar 承担，后者是沉浸式页面
      appBar: _buildAppBar(l10n),
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
        // 选中态用强调金（与登录页主按钮同色），替换此前遗留的品牌蓝 token；
        // 该色同时作用于文字标签，必须与图标染色保持一致，否则会出现「金字蓝标」
        selectedItemColor: AppTheme.accent,
        // 未选中态用中灰，保证在近黑底（#111111）上仍可辨认
        unselectedItemColor: AppTheme.navUnselected,
        items: [
          // 会话：角标显示总未读数，选中/未选中两种状态都要带角标
          BottomNavigationBarItem(
            icon: _buildNavItemIcon(
              assetPath: _navChatIcon,
              color: AppTheme.navUnselected,
              hasBadge: totalUnread > 0,
              count: totalUnread,
            ),
            activeIcon: _buildNavItemIcon(
              assetPath: _navChatIconActive,
              color: AppTheme.accent,
              hasBadge: totalUnread > 0,
              count: totalUnread,
            ),
            label: l10n.chat,
          ),
          // 通讯录：角标仅提示"有新好友申请"，不带数量
          BottomNavigationBarItem(
            icon: _buildNavItemIcon(
              assetPath: _navContactsIcon,
              color: AppTheme.navUnselected,
              hasBadge: hasFriendRequest,
              count: null,
            ),
            activeIcon: _buildNavItemIcon(
              assetPath: _navContactsIconActive,
              color: AppTheme.accent,
              hasBadge: hasFriendRequest,
              count: null,
            ),
            label: l10n.contacts,
          ),
          // 个人中心：无未读概念，不渲染角标
          BottomNavigationBarItem(
            icon: _buildNavItemIcon(
              assetPath: _navProfileIcon,
              color: AppTheme.navUnselected,
            ),
            activeIcon: _buildNavItemIcon(
              assetPath: _navProfileIconActive,
              color: AppTheme.accent,
            ),
            label: l10n.profile,
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
