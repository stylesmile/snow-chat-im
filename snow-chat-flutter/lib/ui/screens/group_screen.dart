import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../models/group_model.dart';
import 'create_group_screen.dart';
import 'chat_detail_screen.dart';

/// 群组列表页面
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  List<GroupModel> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final service = GroupService(auth.apiClient);
    final groups = await service.getGroups(auth.userId!);
    debugPrint('[GroupScreen] loaded ${groups.length} groups for userId=${auth.userId}');
    for (final g in groups) {
      debugPrint('[GroupScreen]   group: id=${g.id}, name=${g.name}, ownerId=${g.ownerId}');
    }
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群聊'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '创建群聊',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              ).then((_) => _loadGroups());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('暂无群组', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('点击右上角 + 创建群聊', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  child: ListView.separated(
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            group.name.isNotEmpty ? group.name[0] : '群',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(group.name),
                        subtitle: Text('${group.memberCount} 人'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                targetId: group.id,
                                targetType: 'group',
                                targetName: group.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
