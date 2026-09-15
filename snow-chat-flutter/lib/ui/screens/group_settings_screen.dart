import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../core/cache/message_cache_manager.dart';
import '../../providers/chat_provider.dart';
import '../../services/conversation_service.dart';
import 'chat_record_search_screen.dart';
import 'group_detail_screen.dart';

/// 群聊设置页：针对单个群聊会话提供常用设置与操作入口。
///
/// 包含入口：
/// - 群聊信息：进入群资料页，查看/添加/移除成员（群主可管理）
/// - 查找聊天记录：会话内按关键词搜索本地历史消息
/// - 置顶 / 取消置顶：持久化到会话表并重排聊天列表
/// - 免打扰 / 关闭免打扰：持久化到会话表
/// - 清空聊天记录：清除该群聊会话本地消息
class GroupSettingsScreen extends StatefulWidget {
  final int groupId;
  final String targetType;
  final String? targetName;

  const GroupSettingsScreen({
    super.key,
    required this.groupId,
    required this.targetType,
    this.targetName,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  String _sessionId = '';

  @override
  void initState() {
    super.initState();
    // 计算群聊会话ID；群聊会话与成员无关，仅由群ID决定
    _sessionId = MessageCacheManager.sessionIdForGroup(widget.groupId);
  }

  /// 从会话表读取当前会话的置顶 / 免打扰状态。
  ///
  /// 若会话尚不存在（例如还没产生过会话记录），回退为未设置（false）。
  Conversation? _conversation() {
    final conversations = context.watch<ChatProvider>().conversations;
    final idx = conversations.indexWhere(
      (c) => c.targetId == widget.groupId && c.targetType == widget.targetType,
    );
    return idx >= 0 ? conversations[idx] : null;
  }

  /// 是否处于置顶状态。
  bool get _isPinned => _conversation()?.isPinned ?? false;

  /// 是否处于免打扰状态。
  bool get _isMuted => _conversation()?.isMuted ?? false;

  /// 切换置顶：更新内存 Provider 并持久化到本地会话表。
  Future<void> _togglePinned(bool value) async {
    final chat = context.read<ChatProvider>();
    // 先更新内存（立即反馈 UI），再异步落库（不阻塞交互）
    chat.togglePinned(widget.groupId, widget.targetType, pinned: value);
    await ConversationService().updateSessionFlags(
      context: context,
      targetId: widget.groupId,
      targetType: widget.targetType,
      isPinned: value,
    );
  }

  /// 切换免打扰：更新内存 Provider 并持久化到本地会话表。
  Future<void> _toggleMuted(bool value) async {
    final chat = context.read<ChatProvider>();
    // 先更新内存，再异步落库
    chat.toggleMuted(widget.groupId, widget.targetType, muted: value);
    await ConversationService().updateSessionFlags(
      context: context,
      targetId: widget.groupId,
      targetType: widget.targetType,
      isMuted: value,
    );
  }

  /// 进入群聊资料页（成员管理）。
  void _openGroupInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(groupId: widget.groupId),
      ),
    );
  }

  /// 查找聊天记录：进入会话内搜索页。
  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRecordSearchScreen(
          sessionId: _sessionId,
          targetId: widget.groupId,
          targetType: widget.targetType,
          targetName: widget.targetName,
        ),
      ),
    );
  }

  /// 弹出"清空聊天记录"确认对话框，确认后清空该群聊会话本地消息。
  Future<void> _confirmClearChat() async {
    final l10n = AppLocalizations.of(context)!;
    // 确认对话框，防止误操作；取消则直接返回
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearChatConfirmTitle),
        content: Text(l10n.clearChatConfirmBody(widget.targetName ?? l10n.myGroups)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    // 清除该群聊会话的本地消息（DB + 内存）
    await MessageCacheManager().clearSessionMessages(_sessionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.clearChatDone)),
    );
  }

  /// 提取头像首字符；空名称时回退为占位符。
  String _avatarChar(String name) => name.isNotEmpty ? name.substring(0, 1) : '?';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.targetName ?? l10n.myGroups;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 1,
        title: Text(l10n.groupSettings),
      ),
      body: ListView(
        children: [
          // 顶部群信息：头像 + 群名称
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    _avatarChar(name),
                    style: const TextStyle(fontSize: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(name, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          const Divider(height: 1),
          // 群聊信息入口（成员管理）
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Icon(Icons.groups_outlined, color: Colors.teal),
            ),
            title: Text(l10n.groupInfo),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openGroupInfo,
          ),
          // 查找聊天记录入口
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Icon(Icons.search, color: Colors.blue),
            ),
            title: Text(l10n.findChatRecord),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openSearch,
          ),
          // 置顶开关（以 Provider 状态驱动，切换时持久化）
          SwitchListTile(
            secondary: const Icon(Icons.push_pin_outlined, color: Colors.orange),
            title: Text(l10n.topChat),
            value: _isPinned,
            onChanged: _togglePinned,
          ),
          // 免打扰开关
          SwitchListTile(
            secondary: const Icon(Icons.notifications_none, color: Colors.purple),
            title: Text(l10n.mute),
            value: _isMuted,
            onChanged: _toggleMuted,
          ),
          const Divider(height: 1),
          // 清空聊天记录入口
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Icon(Icons.delete_outline, color: Colors.red),
            ),
            title: Text(l10n.clearChat),
            trailing: const Icon(Icons.chevron_right),
            onTap: _confirmClearChat,
          ),
        ],
      ),
    );
  }
}