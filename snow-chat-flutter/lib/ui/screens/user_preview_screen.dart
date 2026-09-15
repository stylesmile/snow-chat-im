import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/contact_service.dart';
import '../../providers/friend_request_provider.dart';
import '../../models/friend_model.dart';
import '../widgets/avatar_widget.dart';

/// 用户预览页（扫一扫结果）
///
/// 展示从二维码解析出的目标用户资料（头像、昵称、@用户名、用户ID），
/// 并提供「添加到通讯录」按钮：发送好友请求，成功后回跳并提示。
/// 支持区分三种状态：自己 / 已是好友 / 可添加。
class UserPreviewScreen extends StatefulWidget {
  /// 扫码解析出的目标用户公开资料
  final UserSearchResult user;

  const UserPreviewScreen({super.key, required this.user});

  @override
  State<UserPreviewScreen> createState() => _UserPreviewScreenState();
}

class _UserPreviewScreenState extends State<UserPreviewScreen> {
  // 好友列表：用于判断目标是否已是好友，避免重复添加
  List<FriendModel> _friends = [];
  // 是否正在发送请求（防止重复点击）
  bool _sending = false;
  // 是否已成功发送请求（用于按钮态切换与禁用）
  bool _requestSent = false;
  // 目标是否为当前登录用户自己
  bool _isSelf = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  /// 加载当前用户好友列表，并判断目标用户与本用户的关系
  Future<void> _loadFriends() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // 目标是自己时不进入好友流程
    _isSelf = auth.userId == widget.user.id;
    // 不是自己时才需要拉好友列表判断是否已是好友
    if (auth.userId == null || _isSelf) return;

    final service = ContactService(auth.apiClient);
    final friends = await service.getFriends(auth.userId!);
    if (!mounted) return;
    setState(() {
      _friends = friends;
    });
  }

  /// 判断目标是否已在通讯录中
  bool get _isAlreadyFriend =>
      _friends.any((f) => f.userId == widget.user.id);

  /// 发送好友请求
  ///
  /// 成功后置 [requestSent] 标记，回跳上一页面并提示已发送。
  Future<void> _sendRequest() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    // 自己或已是好友不应进入此流程（按钮已按状态禁用，防御二次点击）
    if (_sending || _isSelf || _isAlreadyFriend || auth.userId == null) return;
    setState(() => _sending = true);

    final service = ContactService(auth.apiClient);
    final result = await service.sendFriendRequest(
      auth.userId!,
      widget.user.id,
      '',
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _requestSent = result['success'] == true;
    });
    // 发送成功后广播好友关系变化，通讯录/聊天列表据此刷新好友目录
    if (result['success'] == true) {
      FriendRequestProvider.notifyFriendListChanged();
    }

    // 弹出提示后回跳到扫码页（失败时展示后端返回的具体原因）
    final String tip = _requestSent
        ? l10n.friendRequestSent
        : (result['message'] as String? ?? '发送失败，请稍后重试');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tip)),
    );
    // 无论成功与否都返回上一页（已提示原因，避免停留在预览页重复操作）
    Navigator.of(context).pop();
  }

  /// 获取按钮显示文案
  String _buttonText(final AppLocalizations l10n) {
    if (_isSelf) {
      return l10n.cannotAddSelf; // 扫到自己二维码时不可添加，展示提示文案
    }
    if (_isAlreadyFriend) {
      return l10n.alreadyFriend;
    }
    if (_requestSent) {
      return l10n.requestSent;
    }
    return l10n.addToContacts;
  }

  /// 是否禁用按钮（自己 / 已是好友 / 已发送 / 发送中）
  bool get _buttonDisabled =>
      _isSelf || _isAlreadyFriend || _requestSent || _sending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final u = widget.user;
    // 头像占位字母取昵称首字
    final initials = u.nickname.isNotEmpty ? u.nickname.substring(0, 1) : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: Text(l10n.findUser),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部用户信息卡片
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // 大号头像
                  AvatarWidget(
                    imageUrl: u.avatar,
                    initials: initials,
                    size: 80,
                    backgroundColor: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(height: 16),
                  // 昵称
                  Text(
                    u.nickname.isNotEmpty ? u.nickname : '-',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // @用户名
                  Text(
                    '@${u.username}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  // 用户ID
                  Text(
                    '${l10n.userId}: ${u.id}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 底部添加按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _buttonDisabled ? null : _sendRequest,
                  // 发送中显示 loading 指示器
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.person_add_alt),
                  label: Text(_buttonText(l10n)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    disabledBackgroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}