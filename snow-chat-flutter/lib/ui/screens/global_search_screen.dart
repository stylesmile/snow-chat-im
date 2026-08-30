import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../core/cache/message_cache_manager.dart';
import '../../models/friend_model.dart';
import '../../services/contact_service.dart';
import '../../providers/auth_provider.dart';
import 'chat_detail_screen.dart';

/// 全局搜索页：同时检索本地联系人昵称与历史聊天记录。
///
/// - 顶部输入框实时搜索（带 300ms 防抖，避免每敲一个字都查库）
/// - 结果分两组展示：联系人（好友昵称/备注匹配）与聊天记录（文本内容匹配）
/// - 点击联系人进入对应单聊；点击聊天记录进入所属会话
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  // 本地好友列表（昵称/备注搜索的数据源），init 时从 SQLite 加载
  List<FriendModel> _friends = [];
  // 好友 userId -> 昵称 映射，用于把消息命中映射回会话显示名
  final Map<int, String> _friendNames = {};
  // 联系人命中结果（实时过滤内存中的数据）
  List<FriendModel> _contactResults = [];
  // 聊天记录命中结果（DB 模糊查询）
  List<MessageSearchHit> _messageResults = [];
  // 防抖定时器
  Timer? _debounce;
  // 是否已经执行过搜索（用于展示空结果提示，而不是初始引导文案）
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // 进入页面即加载本地好友到内存，供后续关键词过滤
    _loadFriends();
  }

  @override
  void dispose() {
    // 释放防抖定时器，避免卸载后回调触发
    _debounce?.cancel();
    super.dispose();
  }

  /// 从本地 SQLite 加载好友列表并构建昵称映射。
  Future<void> _loadFriends() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    // 使用"本地优先"策略读取缓存的好友，保证离线也能搜索联系人
    final friends = await ContactService(auth.apiClient).getLocalFriends(context);
    if (!mounted) return;
    setState(() {
      _friends = friends;
      // 构建昵称映射，供聊天记录命中时反查会话显示名
      _friendNames
        ..clear()
        ..addAll({for (final f in friends) f.userId: f.nickname});
    });
  }

  /// 输入框内容变化，带防抖触发搜索。
  void _onQueryChanged(String value) {
    // 取消上一次未执行的搜索，避免并发过期结果覆盖新结果
    _debounce?.cancel();
    // 延迟 300ms 再真正查询，减少高频输入下的数据库压力
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _performSearch(value.trim());
    });
  }

  /// 执行实际搜索：过滤联系人 + 查询历史消息。
  Future<void> _performSearch(String keyword) async {
    // 空关键词时清空结果并标记未搜索，界面回到初始态
    if (keyword.isEmpty) {
      setState(() {
        _contactResults = [];
        _messageResults = [];
        _hasSearched = false;
      });
      return;
    }

    final lower = keyword.toLowerCase();
    // 1) 在内存好友列表中按昵称/备注模糊匹配联系人
    final contactMatches = _friends.where((f) {
      return f.nickname.toLowerCase().contains(lower) ||
          f.remark.toLowerCase().contains(lower);
    }).toList();

    // 2) 在本地消息库中按内容模糊匹配聊天记录
    final hits = await MessageCacheManager().searchMessages(keyword);

    if (!mounted) return;
    setState(() {
      _contactResults = contactMatches;
      _messageResults = hits;
      _hasSearched = true;
    });
  }

  /// 解析一条消息命中所属的会话信息，用于点击跳转与展示名称。
  ///
  /// 群消息按群私聊，单聊消息按"非当前用户"判定对方。
  ConversationTarget _resolveTarget(MessageSearchHit hit) {
    final current = context.read<AuthProvider>().userId;
    // 群消息：直接使用消息携带的群ID
    if (hit.message.groupId != null) {
      final gid = hit.message.groupId!;
      return ConversationTarget(
        targetId: gid,
        targetType: 'group',
        displayName: '群组 $gid',
      );
    }
    // 单聊：对方 = 发送者若非当前用户，否则为接收者
    final peer = hit.message.fromUserId == current
        ? (hit.message.toUserId ?? 0)
        : hit.message.fromUserId;
    return ConversationTarget(
      targetId: peer,
      targetType: 'friend',
      displayName: _friendNames[peer] ?? '用户 $peer',
    );
  }

  /// 点击联系人：进入对应单聊会话。
  void _openPrivateChat(FriendModel friend) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          targetId: friend.userId,
          targetType: 'friend',
          targetName: friend.nickname,
        ),
      ),
    );
  }

  /// 点击聊天记录命中：进入所属会话。
  void _openHitChat(MessageSearchHit hit) {
    final target = _resolveTarget(hit);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          targetId: target.targetId,
          targetType: target.targetType,
          targetName: target.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 是否展示了任何结果或已搜索过
    final showEmpty = _hasSearched &&
        _contactResults.isEmpty &&
        _messageResults.isEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 1,
        title: Text(l10n.search),
      ),
      body: Column(
        children: [
          // 顶部搜索输入框，自动聚焦便于直接输入
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // 结果列表
          Expanded(
            child: showEmpty
                // 已搜索但无任何命中，展示空结果提示
                ? Center(
                    child: Text(
                      l10n.noSearchResult,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView(
                    children: [
                      // 联系人分组
                      if (_contactResults.isNotEmpty) ...[
                        _buildSectionHeader(l10n.contacts),
                        ..._contactResults.map(_buildContactTile),
                      ],
                      // 聊天记录分组
                      if (_messageResults.isNotEmpty) ...[
                        _buildSectionHeader(l10n.searchChatHistory),
                        ..._messageResults.map(_buildMessageTile),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 分组标题栏。
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 提取名称首字符用于头像展示；空名称时回退为占位符。
  String _avatarChar(String name) {
    return name.isNotEmpty ? name.substring(0, 1) : '?';
  }

  /// 联系人结果条目：头像 + 昵称，点击进入单聊。
  Widget _buildContactTile(FriendModel friend) {
    return ListTile(
      leading: CircleAvatar(child: Text(_avatarChar(friend.nickname))),
      title: Text(friend.nickname),
      subtitle: friend.remark.isNotEmpty ? Text(friend.remark) : null,
      onTap: () => _openPrivateChat(friend),
    );
  }

  /// 聊天记录结果条目：所属会话名 + 命中消息摘要，点击进入该会话。
  Widget _buildMessageTile(MessageSearchHit hit) {
    final target = _resolveTarget(hit);
    return ListTile(
      leading: CircleAvatar(child: Text(_avatarChar(target.displayName))),
      title: Text(target.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        hit.message.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _openHitChat(hit),
    );
  }
}

/// 一条聊天记录命中对应的会话目标信息。
class ConversationTarget {
  final int targetId;
  final String targetType;
  final String displayName;

  const ConversationTarget({
    required this.targetId,
    required this.targetType,
    required this.displayName,
  });
}