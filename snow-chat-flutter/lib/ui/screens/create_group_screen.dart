import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/contact_service.dart';
import '../../services/group_service.dart';
import '../../models/friend_model.dart';
import '../widgets/avatar_widget.dart';
import 'chat_detail_screen.dart';

/// 创建群聊页面：输入群名称 + 选择好友加入群组
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final Set<int> _selectedUserIds = {};
  List<FriendModel> _friends = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final service = ContactService(auth.apiClient);
    final friends = await service.getLocalFriends(context);
    if (!mounted) return;
    setState(() {
      _friends = friends;
      _isLoading = false;
    });
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入群名称')),
      );
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一位好友')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    setState(() => _isCreating = true);

    final service = GroupService(auth.apiClient);
    final groupId = await service.createGroup(
      ownerId: auth.userId!,
      name: name,
      memberIds: _selectedUserIds.toList(),
    );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (groupId != null) {
      // 创建成功，进入群聊页面
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            targetId: groupId,
            targetType: 'group',
            targetName: name,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建群组失败')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群聊'),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 群名称输入框
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '群名称',
                hintText: '请输入群名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              maxLength: 20,
            ),
          ),
          // 已选人数提示
          if (_selectedUserIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    '已选择 ${_selectedUserIds.length} 位好友',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          // 好友列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _friends.isEmpty
                    ? Center(
                        child: Text(
                          '暂无好友',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _friends.length,
                        itemBuilder: (context, index) {
                          final friend = _friends[index];
                          final isSelected = _selectedUserIds.contains(friend.userId);
                          final name = friend.remark.isNotEmpty ? friend.remark : friend.nickname;
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedUserIds.add(friend.userId);
                                } else {
                                  _selectedUserIds.remove(friend.userId);
                                }
                              });
                            },
                            secondary: AvatarWidget(
                              imageUrl: friend.avatar,
                              initials: name.isNotEmpty ? name[0] : '?',
                              size: 40,
                            ),
                            title: Text(name),
                            subtitle: friend.remark.isNotEmpty
                                ? Text(friend.nickname, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
