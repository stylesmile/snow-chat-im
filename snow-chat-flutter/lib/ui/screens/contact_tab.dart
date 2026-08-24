import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_request_provider.dart';
import '../../services/contact_service.dart';
import '../../models/friend_model.dart';
import '../../core/utils/pinyin_helper.dart';
import '../widgets/avatar_widget.dart';
import 'add_friend_screen.dart';
import 'chat_detail_screen.dart';
import 'group_screen.dart';
import 'friend_request_screen.dart';

class ContactTab extends StatefulWidget {
  final ValueNotifier<int>? friendAcceptedNotifier;

  const ContactTab({super.key, this.friendAcceptedNotifier});

  @override
  State<ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<ContactTab> {
  bool _isLoading = true;
  List<FriendModel> _friends = [];
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};

  static const List<String> _indexLetters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.friendAcceptedNotifier?.addListener(_onFriendAccepted);
  }

  void _onFriendAccepted() {
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final service = ContactService(auth.apiClient);

    // 1. 先查 SQLite 本地缓存，立即显示
    final localFriends = await service.getLocalFriends(context);
    if (mounted && localFriends.isNotEmpty) {
      setState(() {
        _friends = localFriends;
        _isLoading = false;
      });
    }

    // 2. 后台调用接口同步最新好友列表
    final friends = await service.getFriends(auth.userId!);
    if (!mounted) return;

    // 3. 保存到 SQLite 供下次快速展示
    await service.saveLocalFriends(context, friends);

    // 4. 更新 UI 为服务端最新数据
    setState(() {
      _friends = friends;
      _isLoading = false;
    });
  }

  void _handleDeleteFriend(FriendModel friend) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.delete),
        content: Text('"${friend.nickname}" ${l10n.deleteFriend}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              final service = ContactService(auth.apiClient);
              final ok = await service.deleteFriend(auth.userId!, friend.userId);
              if (ok && mounted) {
                setState(() => _friends.remove(friend));
                // 同步更新本地缓存
                await service.saveLocalFriends(context, _friends);
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  /// 按拼音首字母分组
  Map<String, List<FriendModel>> _groupByLetter() {
    final Map<String, List<FriendModel>> grouped = {};
    for (final friend in _friends) {
      final name = friend.remark.isNotEmpty ? friend.remark : friend.nickname;
      final letter = PinyinHelper.getFirstLetter(name);
      grouped.putIfAbsent(letter, () => []);
      grouped[letter]!.add(friend);
    }
    // 每组内部按名称排序
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final nameA = a.remark.isNotEmpty ? a.remark : a.nickname;
        final nameB = b.remark.isNotEmpty ? b.remark : b.nickname;
        return nameA.compareTo(nameB);
      });
    }
    return grouped;
  }

  List<String> _getAvailableLetters(Map<String, List<FriendModel>> grouped) {
    final letters = grouped.keys.toList()..sort(PinyinHelper.compareLetter);
    return letters;
  }

  void _scrollToLetter(String letter) {
    final key = _sectionKeys[letter];
    if (key != null) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.0,
        );
      }
    }
  }

  void _onSearchTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFriendScreen()),
    );
  }

  void _onAddFriendTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFriendScreen()),
    );
  }

  /// 文件传输助手入口：点击直接打开与 fileId=0 的聊天窗口
  Widget _buildFileHelperItem(AppLocalizations l10n) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFF07C160),
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        child: const Icon(Icons.cloud_upload, color: Colors.white, size: 22),
      ),
      title: Text(l10n.fileHelper, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              targetId: 0,   // 固定 fileId=0 代表文件传输助手
              targetType: 'file_helper',
              targetName: l10n.fileHelper,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final friendReqProvider = context.watch<FriendRequestProvider>();
    final unreadCount = friendReqProvider.unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contacts),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _onSearchTap,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _onAddFriendTap,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildBody(l10n, unreadCount),
            ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, int unreadCount) {
    final grouped = _groupByLetter();
    final availableLetters = _getAvailableLetters(grouped);

    // 预创建 GlobalKey
    _sectionKeys.clear();
    for (final letter in availableLetters) {
      _sectionKeys[letter] = GlobalKey();
    }

    return Stack(
      children: [
        ListView(
          controller: _scrollController,
          children: [
            // --- 文件传输助手（固定入口，直接发起单聊）---
            _buildFileHelperItem(l10n),
            // --- 新的朋友 ---
            _buildFeatureItem(
              icon: Icons.person_add,
              iconColor: const Color(0xFFFFA726),
              title: l10n.newFriendRequest,
              badgeCount: unreadCount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendRequestScreen()),
                );
              },
            ),
            // --- 群聊 ---
            _buildFeatureItem(
              icon: Icons.groups,
              iconColor: const Color(0xFF43A047),
              title: l10n.myGroups,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupScreen()),
                );
              },
            ),
            // --- 按字母分组的好友列表 ---
            ..._buildAlphabeticalList(l10n, grouped, availableLetters),
            // 底部留白，避免被导航栏遮挡
            const SizedBox(height: 20),
          ],
        ),
        // 右侧字母索引条
        if (availableLetters.isNotEmpty)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 28,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _indexLetters.map((letter) {
                    final hasData = availableLetters.contains(letter);
                    return GestureDetector(
                      onTap: hasData ? () => _scrollToLetter(letter) : null,
                      child: Container(
                        width: 20,
                        height: 16,
                        alignment: Alignment.center,
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            // 深色模式索引条：有数据的字母更亮（white70），无数据的弱化（white24）
                            color: hasData
                                ? Colors.white70
                                : Colors.white24,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    VoidCallback? onTap,
    int badgeCount = 0,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 4),
          // 箭头图标：半透明白，深色背景下弱化视觉噪音
          const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  List<Widget> _buildAlphabeticalList(
    AppLocalizations l10n,
    Map<String, List<FriendModel>> grouped,
    List<String> sortedKeys,
  ) {
    if (_friends.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Text(
              l10n.noContacts,
              // 空状态文字：半透明白，保证深色背景上可读
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ),
        ),
      ];
    }

    final List<Widget> items = [];
    for (final key in sortedKeys) {
      // Section header with GlobalKey for scroll-to-letter
      items.add(
        Container(
          key: _sectionKeys[key],
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          // 分组标题条：深色表面色（原浅灰 #F5F5F5 在深色模式下是刺眼亮块）
          color: AppTheme.surface,
          child: Text(
            key,
            // 分组字母：半透明白，深色背景上可读
            style: const TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w500),
          ),
        ),
      );

      // Friends in this section
      final friends = grouped[key]!;
      for (int i = 0; i < friends.length; i++) {
        final friend = friends[i];
        final name = friend.remark.isNotEmpty ? friend.remark : friend.nickname;
        items.add(
          ListTile(
            leading: AvatarWidget(
              imageUrl: friend.avatar,
              initials: name.isNotEmpty ? name[0] : '?',
              size: 40,
            ),
            title: Text(name, style: const TextStyle(fontSize: 15)),
            trailing: friend.status == 'online'
                ? Container(
                    width: 8,
                    height: 8,
                    // 在线状态点：设计稿辅助绿（替换 Material 默认绿）
                    decoration: const BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle),
                  )
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(
                    targetId: friend.userId,
                    targetType: 'friend',
                    targetName: name,
                  ),
                ),
              );
            },
            onLongPress: () => _handleDeleteFriend(friend),
          ),
        );
      }
    }
    return items;
  }

  @override
  void dispose() {
    widget.friendAcceptedNotifier?.removeListener(_onFriendAccepted);
    _scrollController.dispose();
    super.dispose();
  }
}
