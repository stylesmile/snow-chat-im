import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../services/contact_service.dart';
import '../../models/group_model.dart';
import '../../models/friend_model.dart';
import '../widgets/avatar_widget.dart';
import '../../l10n/app_localizations.dart';

/// 群聊详情页面：显示群信息、成员列表，群主可管理
class GroupDetailScreen extends StatefulWidget {
  final int groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  GroupModel? _group;
  List<_MemberInfo> _members = [];
  bool _isLoading = true;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    final service = GroupService(auth.apiClient);

    // 获取群组信息
    final group = await service.getGroupDetail(widget.groupId);
    if (!mounted) return;

    // 获取群成员列表（带昵称）
    final memberIds = await service.getGroupMembers(widget.groupId);
    final contactService = ContactService(auth.apiClient);
    final friends = await contactService.getLocalFriends(context);
    final friendMap = {for (final f in friends) f.userId: f};

    final members = memberIds.map((id) {
      final friend = friendMap[id];
      return _MemberInfo(
        userId: id,
        nickname: friend?.nickname ?? '用户$id',
        avatar: friend?.avatar ?? '',
        isOwner: group?.ownerId == id,
      );
    }).toList();

    if (!mounted) return;
    setState(() {
      _group = group;
      _members = members;
      _isOwner = group?.ownerId == auth.userId;
      _isLoading = false;
    });
  }

  /// 添加成员
  Future<void> _addMembers() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    // 获取好友列表，排除已是群成员的
    final contactService = ContactService(auth.apiClient);
    final friends = await contactService.getLocalFriends(context);
    final memberIds = _members.map((m) => m.userId).toSet();
    final availableFriends = friends.where((f) => !memberIds.contains(f.userId)).toList();

    if (!mounted) return;

    if (availableFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noAddableFriends)),
      );
      return;
    }

    // 弹出选择好友对话框
    final selectedIds = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => _MemberSelectDialog(
        friends: availableFriends,
        title: l10n.selectMembersToAdd,
      ),
    );

    if (selectedIds == null || selectedIds.isEmpty) return;

    final service = GroupService(auth.apiClient);
    final success = await service.addMembers(widget.groupId, selectedIds);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.membersAdded(selectedIds.length))),
      );
      _loadGroupInfo(); // 刷新列表
    }
  }

  /// 移除成员
  Future<void> _removeMember(int userId, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeMember),
        content: Text(l10n.removeMemberConfirm(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    final service = GroupService(auth.apiClient);
    final success = await service.removeMembers(widget.groupId, [userId]);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.memberRemoved(name))),
      );
      _loadGroupInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupInfo),
        actions: [
          // 群主可以添加成员
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: l10n.addMember,
              onPressed: _addMembers,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _group == null
              ? Center(child: Text(l10n.groupNotExist))
              : ListView(
                  children: [
                    // 群名称
                    _buildSection([
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          radius: 24,
                          child: Text(
                            _group!.name.isNotEmpty ? _group!.name[0] : '群',
                            style: const TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                        title: Text(_group!.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        subtitle: Text(l10n.peopleCount(_members.length)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    // 群成员列表
                    _buildSection([
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.membersCount(_members.length), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            if (_isOwner)
                              TextButton.icon(
                                onPressed: _addMembers,
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(l10n.add),
                              ),
                          ],
                        ),
                      ),
                      // 成员网格展示
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: _members.map((member) {
                            return GestureDetector(
                              onLongPress: _isOwner && !member.isOwner
                                  ? () => _removeMember(member.userId, member.nickname)
                                  : null,
                              child: SizedBox(
                                width: 56,
                                child: Column(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        AvatarWidget(
                                          imageUrl: member.avatar,
                                          initials: member.nickname.isNotEmpty ? member.nickname[0] : '?',
                                          size: 48,
                                        ),
                                        if (member.isOwner)
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.star, size: 12, color: Colors.white),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      member.nickname,
                                      style: const TextStyle(fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ]),
                  ],
                ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: children),
    );
  }
}

/// 成员信息模型
class _MemberInfo {
  final int userId;
  final String nickname;
  final String avatar;
  final bool isOwner;

  _MemberInfo({
    required this.userId,
    required this.nickname,
    this.avatar = '',
    this.isOwner = false,
  });
}

/// 选择成员对话框
class _MemberSelectDialog extends StatefulWidget {
  final List<FriendModel> friends;
  final String title;

  const _MemberSelectDialog({required this.friends, required this.title});

  @override
  State<_MemberSelectDialog> createState() => _MemberSelectDialogState();
}

class _MemberSelectDialogState extends State<_MemberSelectDialog> {
  final Set<int> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: widget.friends.length,
          itemBuilder: (context, index) {
            final friend = widget.friends[index];
            final name = friend.remark.isNotEmpty ? friend.remark : friend.nickname;
            return CheckboxListTile(
              value: _selectedIds.contains(friend.userId),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.add(friend.userId);
                  } else {
                    _selectedIds.remove(friend.userId);
                  }
                });
              },
              secondary: AvatarWidget(
                imageUrl: friend.avatar,
                initials: name.isNotEmpty ? name[0] : '?',
                size: 36,
              ),
              title: Text(name),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedIds.toList()),
          child: Text(l10n.addMembersCount(_selectedIds.length)),
        ),
      ],
    );
  }
}
