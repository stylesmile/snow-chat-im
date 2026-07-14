import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/contact_service.dart';
import '../../models/friend_model.dart';
import '../widgets/avatar_widget.dart';
import 'add_friend_screen.dart';

class ContactTab extends StatefulWidget {
  const ContactTab({super.key});

  @override
  State<ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<ContactTab> {
  bool _isLoading = true;
  List<FriendModel> _friends = [];
  final _searchController = TextEditingController();
  int _activeSection = 0;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final service = ContactService(auth.apiClient);
    final friends = await service.getFriends(auth.userId!);
    setState(() {
      _friends = friends;
      _isLoading = false;
    });
  }

  void _handleDeleteFriend(FriendModel friend) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.delete),
        content: Text('"${friend.nickname}" ${l10n.deleteFriend}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final dio = auth.apiClient.dio;
              try {
                await dio.delete('/chat/friend/${auth.userId}/${friend.userId}');
                setState(() => _friends.remove(friend));
              } catch (e) {
                // ignore
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.contacts)),
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
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddFriendScreen(keyword: value)),
                  );
                }
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildTab(l10n.myFriends, _activeSection == 0, () => setState(() => _activeSection = 0)),
              ),
              Expanded(
                child: _buildTab(
                  l10n.friendRequests,
                  _activeSection == 1,
                  () => setState(() => _activeSection = 1),
                  badge: _pendingCount,
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _activeSection == 0
                    ? _buildFriendsList(l10n)
                    : _buildPendingRequests(l10n),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSearchDialog(context),
        icon: const Icon(Icons.person_add),
        label: Text(l10n.addFriend),
      ),
    );
  }

  Widget _buildTab(String title, bool isActive, VoidCallback onTap, {int? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(title, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Theme.of(context).colorScheme.primary : null)),
            if (badge != null && badge > 0)
              Positioned(
                right: 8, top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(AppLocalizations l10n) {
    if (_friends.isEmpty) {
      return Center(child: Text(l10n.noContacts, style: TextStyle(color: Colors.grey.shade600)));
    }
    return ListView.separated(
      itemCount: _friends.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return ListTile(
          leading: AvatarWidget(imageUrl: friend.avatar, initials: friend.nickname.isNotEmpty ? friend.nickname[0] : '?', size: 40),
          title: Text(friend.nickname),
          subtitle: Text(friend.remark.isNotEmpty ? friend.remark : friend.status),
          trailing: friend.status == 'online'
              ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle))
              : null,
          onLongPress: () => _handleDeleteFriend(friend),
        );
      },
    );
  }

  Widget _buildPendingRequests(AppLocalizations l10n) {
    return const Center(child: Text('Coming soon'));
  }

  void _showSearchDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.addFriend),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l10n.searchUser),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddFriendScreen(keyword: controller.text)));
              }
            },
            child: Text(l10n.search),
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
