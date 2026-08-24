import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_request_provider.dart';
import '../../services/contact_service.dart';
import '../widgets/avatar_widget.dart';

class FriendRequestScreen extends StatefulWidget {
  const FriendRequestScreen({super.key});

  @override
  State<FriendRequestScreen> createState() => _FriendRequestScreenState();
}

class _FriendRequestScreenState extends State<FriendRequestScreen> {
  bool _isLoading = true;
  List<FriendRequest> _requests = [];

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
    setState(() {
      _requests = requests;
      _isLoading = false;
    });
  }

  Future<void> _handleRequest(FriendRequest request, bool accept) async {
    final auth = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    final service = ContactService(auth.apiClient);

    final result = await service.handleFriendRequest(request.fromUserId, auth.userId!, accept);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _requests.remove(request));
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
                  : ListView.separated(
                      itemCount: _requests.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                      itemBuilder: (context, index) {
                        final req = _requests[index];
                        return _buildRequestItem(req, l10n);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '暂无新的好友请求',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(FriendRequest req, AppLocalizations l10n) {
    final name = req.fromNickname.isNotEmpty ? req.fromNickname : '用户${req.fromUserId}';

    return ListTile(
      leading: AvatarWidget(
        imageUrl: req.fromAvatar,
        initials: name.isNotEmpty ? name[0] : '?',
        size: 48,
      ),
      title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: req.remark.isNotEmpty
          ? Text(req.remark, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _handleRequest(req, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: Text(l10n.reject),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () => _handleRequest(req, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(l10n.accept),
          ),
        ],
      ),
    );
  }
}
