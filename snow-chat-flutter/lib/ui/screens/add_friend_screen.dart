import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/contact_service.dart';
import '../../providers/friend_request_provider.dart';
import '../../models/friend_model.dart';

class AddFriendScreen extends StatefulWidget {
  final String? keyword;

  const AddFriendScreen({super.key, this.keyword});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<UserSearchResult> _results = [];
  List<FriendModel> _friends = [];
  Set<int> _addedUsers = {};
  Set<int> _sendingUsers = {};

  @override
  void initState() {
    super.initState();
    if (widget.keyword != null && widget.keyword!.isNotEmpty) {
      _searchController.text = widget.keyword!;
      _search(_searchController.text);
    }
    _loadFriends();
  }

  Future<void> _search(String keyword) async {
    if (keyword.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    final service = ContactService(context.read<AuthProvider>().apiClient);
    final results = await service.searchUsers(keyword);
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  Future<void> _loadFriends() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final service = ContactService(auth.apiClient);
    final friends = await service.getFriends(auth.userId!);
    setState(() => _friends = friends);
  }

  Future<void> _sendFriendRequest(UserSearchResult user) async {
    final auth = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    final service = ContactService(auth.apiClient);

    // 防止重复点击
    if (_sendingUsers.contains(user.id)) return;
    setState(() => _sendingUsers.add(user.id));

    final result = await service.sendFriendRequest(auth.userId!, user.id, '');
    setState(() => _sendingUsers.remove(user.id));

    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _addedUsers.add(user.id));
      // 对方若也已向我发过申请，后端会双向直接建好友关系；无论哪种情况
      // 都广播一次变化，让通讯录/聊天列表重新拉好友目录
      FriendRequestProvider.notifyFriendListChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.friendRequestSent)),
      );
    } else {
      // 显示后端返回的具体错误原因
      final msg = result['message'] as String? ?? '发送失败，请稍后重试';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  bool _isAlreadyFriend(int userId) {
    return _friends.any((f) => f.userId == userId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addFriend)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchUser,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true,
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _results = []);
                        },
                      ),
              ),
              onSubmitted: _search,
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(l10n.noContacts, style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final isFriend = _isAlreadyFriend(user.id);
                          final isAdded = _addedUsers.contains(user.id);
                          final isSending = _sendingUsers.contains(user.id);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Text(user.nickname.isNotEmpty ? user.nickname[0] : user.username[0]),
                            ),
                            title: Text(user.nickname.isNotEmpty ? user.nickname : user.username),
                            subtitle: Text('@${user.username}'),
                            trailing: isFriend
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : isAdded
                                    ? const Icon(Icons.check, color: Colors.grey)
                                    : isSending
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : ElevatedButton(
                                            onPressed: () => _sendFriendRequest(user),
                                            child: Text(l10n.sendFriendRequest),
                                          ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
