import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../core/cache/message_cache_manager.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/conversation_service.dart';
import 'chat_record_search_screen.dart';

/// 单聊设置页：针对单个会话提供常用设置与操作入口。
///
/// 包含入口：
/// - 查找聊天记录：会话内按关键词搜索本地历史消息
/// - 置顶 / 取消置顶：持久化到会话表并重排聊天列表
/// - 免打扰 / 关闭免打扰：持久化到会话表
/// - 清空聊天记录：清除该会话本地消息
/// - 投诉：提交一条投诉反馈（当前为本地确认，等待后端接入）
class SingleChatSettingsScreen extends StatefulWidget {
  final int targetId;
  final String targetType;
  final String? targetName;

  const SingleChatSettingsScreen({
    super.key,
    required this.targetId,
    required this.targetType,
    this.targetName,
  });

  @override
  State<SingleChatSettingsScreen> createState() => _SingleChatSettingsScreenState();
}

class _SingleChatSettingsScreenState extends State<SingleChatSettingsScreen> {
  final _controller = TextEditingController();
  String _sessionId = '';

  @override
  void initState() {
    super.initState();
    // 先生成会话ID；依赖 userId，若非空则立即计算
    final userId = context.read<AuthProvider>().userId;
    if (userId != null) {
      _sessionId = MessageCacheManager.sessionIdForPrivate(userId, widget.targetId);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 从会话表读取当前会话的置顶 / 免打扰状态。
  ///
  /// 若会话尚不存在（例如还没产生过会话记录），回退为未设置（false）。
  Conversation? _conversation() {
    final conversations = context.watch<ChatProvider>().conversations;
    final idx = conversations.indexWhere(
      (c) => c.targetId == widget.targetId && c.targetType == widget.targetType,
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
    chat.togglePinned(widget.targetId, widget.targetType, pinned: value);
    await ConversationService().updateSessionFlags(
      context: context,
      targetId: widget.targetId,
      targetType: widget.targetType,
      isPinned: value,
    );
  }

  /// 切换免打扰：更新内存 Provider 并持久化到本地会话表。
  Future<void> _toggleMuted(bool value) async {
    final chat = context.read<ChatProvider>();
    // 先更新内存，再异步落库
    chat.toggleMuted(widget.targetId, widget.targetType, muted: value);
    await ConversationService().updateSessionFlags(
      context: context,
      targetId: widget.targetId,
      targetType: widget.targetType,
      isMuted: value,
    );
  }

  /// 查找聊天记录：进入会话内搜索页。
  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRecordSearchScreen(
          sessionId: _sessionId,
          targetId: widget.targetId,
          targetType: widget.targetType,
          targetName: widget.targetName,
        ),
      ),
    );
  }

  /// 弹出"清空聊天记录"确认对话框，确认后清空该会话本地消息。
  Future<void> _confirmClearChat() async {
    final l10n = AppLocalizations.of(context)!;
    // 确认对话框，防止误操作；取消则直接返回
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearChatConfirmTitle),
        content: Text(l10n.clearChatConfirmBody(widget.targetName ?? l10n.myFriends)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    // 清除该会话的本地消息（DB + 内存）
    await MessageCacheManager().clearSessionMessages(_sessionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.clearChatDone)),
    );
  }

  /// 弹出投诉对话框；提交后给出已接收提示。
  ///
  /// 当前为本地确认（等待后端投诉接口接入）。
  Future<void> _showReportDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.reportComplaint),
        content: TextField(
          controller: _controller,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.reportHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.reportSubmit)),
        ],
      ),
    );
    if (submitted != true) return;
    _controller.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.reportSubmitted)),
    );
  }

  /// 提取头像首字符；空名称时回退为占位符。
  String _avatarChar(String name) => name.isNotEmpty ? name.substring(0, 1) : '?';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.targetName ?? l10n.myFriends;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 1,
        title: Text(l10n.chatSettings),
      ),
      body: ListView(
        children: [
          // 顶部会话信息：头像 + 昵称
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
          const Divider(height: 1),
          // 投诉入口
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Icon(Icons.report_problem_outlined, color: Colors.redAccent),
            ),
            title: Text(l10n.reportComplaint),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showReportDialog,
          ),
        ],
      ),
    );
  }
}