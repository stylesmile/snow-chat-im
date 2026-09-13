import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_request_provider.dart';
import '../../services/contact_service.dart';
import '../widgets/avatar_widget.dart';

/// 好友申请列表页（「新的朋友」）
///
/// 采用微信风格的卡片式布局：每张卡片承载一位申请人的头像、昵称、申请留言
/// 与接受/拒绝按钮；处理中显示 loading，处理完成后按钮原地变为「已添加」/「已拒绝」，
/// 不再把整条记录从列表里抽走导致列表跳动。
///
/// 进入页面即调用 [FriendRequestProvider.markAsRead] 清掉通讯录 tab 的红点。
class FriendRequestScreen extends StatefulWidget {
  const FriendRequestScreen({super.key});

  @override
  State<FriendRequestScreen> createState() => _FriendRequestScreenState();
}

class _FriendRequestScreenState extends State<FriendRequestScreen> {
  bool _isLoading = true;
  List<FriendRequest> _requests = [];
  /// 正在处理中的申请人 id，用于按钮 loading 态
  final Set<int> _handling = {};
  /// 已处理的申请人 id -> 是否接受，用于原地替换为结果文案
  final Map<int, bool> _handled = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    // 进入"新的朋友"页面，清除未读标记
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendRequestProvider>().markAsRead();
    });
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final service = ContactService(auth.apiClient);
    final requests = await service.getReceivedRequests(auth.userId!);
    if (!mounted) return;
    setState(() {
      _requests = requests;
      _isLoading = false;
    });
  }

  /// 处理一条申请（接受 / 拒绝）
  ///
  /// 成功后只标记结果、不移除条目，避免列表长度突变造成视觉跳动；
  /// 同时广播「好友关系变化」，让通讯录与聊天列表立刻刷新出新好友。
  Future<void> _handleRequest(FriendRequest request, bool accept) async {
    final auth = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    if (auth.userId == null) return;

    setState(() => _handling.add(request.fromUserId));
    final service = ContactService(auth.apiClient);
    final result = await service.handleFriendRequest(
      request.fromUserId,
      auth.userId!,
      accept,
    );
    if (!mounted) return;
    setState(() => _handling.remove(request.fromUserId));

    if (result['success'] == true) {
      setState(() => _handled[request.fromUserId] = accept);
      // 好友关系变化：通讯录/聊天列表需要重新拉好友目录才能显示新好友
      FriendRequestProvider.notifyFriendListChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? l10n.friendAdded : l10n.reject)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] as String? ?? '操作失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newFriendRequest),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _requests.isEmpty
                  ? _buildEmptyState(l10n)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: [
                        _buildSectionHeader(l10n),
                        const SizedBox(height: 8),
                        ..._requests.map((req) => _buildRequestCard(req, l10n)),
                      ],
                    ),
            ),
    );
  }

  /// 分组标题：显示待处理申请数量
  Widget _buildSectionHeader(AppLocalizations l10n) {
    final pending = _requests.length - _handled.length;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        '${l10n.pendingRequests}（${pending < 0 ? 0 : pending}）',
        style: const TextStyle(fontSize: 13, color: Colors.white54),
      ),
    );
  }

  /// 空态：居中图标 + 说明文案
  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_alt_1, size: 72, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 16),
          const Text(
            '暂无新的好友请求',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            '${l10n.searchUser} / ${l10n.scan} ${l10n.addFriend}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 单张申请卡片
  Widget _buildRequestCard(FriendRequest req, AppLocalizations l10n) {
    final name = req.fromNickname.isNotEmpty ? req.fromNickname : '用户${req.fromUserId}';
    final handling = _handling.contains(req.fromUserId);
    final handled = _handled[req.fromUserId];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 头像
              AvatarWidget(
                imageUrl: req.fromAvatar,
                initials: name.isNotEmpty ? name[0] : '?',
                size: 48,
              ),
              const SizedBox(width: 12),
              // 昵称 + 申请留言
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      req.remark.isNotEmpty ? req.remark : '${l10n.requestSent}',
                      style: const TextStyle(fontSize: 13, color: Colors.white54),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 操作区：处理中显示进度，已处理显示结果，否则显示接受/拒绝
          if (handling)
            const SizedBox(
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (handled != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                handled ? l10n.friendAdded : l10n.reject,
                style: TextStyle(
                  fontSize: 13,
                  color: handled ? AppTheme.accent : Colors.white38,
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 拒绝：描边次要按钮
                OutlinedButton(
                  onPressed: () => _handleRequest(req, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(l10n.reject),
                ),
                const SizedBox(width: 10),
                // 接受：金色主按钮（与底部导航选中态、登录主按钮同色）
                ElevatedButton(
                  onPressed: () => _handleRequest(req, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    minimumSize: const Size(0, 32),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(l10n.accept),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
