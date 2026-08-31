import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../core/cache/message_cache_manager.dart';
import '../../core/utils/date_utils.dart' as app_date;
import 'chat_detail_screen.dart';

/// 查找聊天记录页：在指定会话内按关键词搜索本地历史消息。
///
/// - 顶部输入框实时搜索（带防抖，避免高频输入反复查库）
/// - 只搜索当前会话（[sessionId]），不会跨会话干扰
/// - 命中消息展示内容与发送时间；点击进入对应会话
class ChatRecordSearchScreen extends StatefulWidget {
  /// 目标会话标识（决定搜索范围）
  final String sessionId;

  /// 会话信息：点击命中时用于重新进入聊天页
  final int targetId;
  final String targetType;
  final String? targetName;

  const ChatRecordSearchScreen({
    super.key,
    required this.sessionId,
    required this.targetId,
    required this.targetType,
    this.targetName,
  });

  @override
  State<ChatRecordSearchScreen> createState() => _ChatRecordSearchScreenState();
}

class _ChatRecordSearchScreenState extends State<ChatRecordSearchScreen> {
  // 会话内搜索命中结果（DB 模糊查询）
  List<MessageSearchHit> _results = [];
  // 防抖定时器
  Timer? _debounce;
  // 是否已执行过搜索（用于区分引导态与空结果态）
  bool _hasSearched = false;

  @override
  void dispose() {
    // 释放防抖定时器，避免卸载后回调触发
    _debounce?.cancel();
    super.dispose();
  }

  /// 输入框内容变化，带防抖触发搜索。
  void _onQueryChanged(String value) {
    // 取消上一次尚未执行的搜索，避免过期结果覆盖新结果
    _debounce?.cancel();
    // 延迟 300ms 再真正查询，减少高频输入下的数据库压力
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _performSearch(value.trim());
    });
  }

  /// 执行实际搜索：仅查询当前会话内匹配的消息。
  Future<void> _performSearch(String keyword) async {
    // 空关键词时清空结果并标记未搜索，界面回到初始引导态
    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    // 调用会话内搜索接口，范围限定为当前会话
    final hits = await MessageCacheManager().searchMessagesInSession(
      widget.sessionId,
      keyword,
    );
    if (!mounted) return;
    setState(() {
      _results = hits;
      _hasSearched = true;
    });
  }

  /// 点击命中消息：进入该会话，方便在上下文中定位消息。
  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          targetId: widget.targetId,
          targetType: widget.targetType,
          targetName: widget.targetName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 已搜索但无任何命中，展示空结果提示
    final showEmpty = _hasSearched && _results.isEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 1,
        title: Text(l10n.findChatRecord),
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
                // 无命中：居中展示空结果文案
                ? Center(
                    child: Text(
                      l10n.noSearchResult,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) =>
                        _buildResultTile(_results[index]),
                  ),
          ),
        ],
      ),
    );
  }

  /// 单条命中条目：消息内容 + 发送时间，点击进入会话。
  Widget _buildResultTile(MessageSearchHit hit) {
    return ListTile(
      leading: const Icon(Icons.forum_outlined, color: Colors.grey),
      title: Text(
        hit.message.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        app_date.DateUtils.formatTime(hit.message.createTime),
        style: const TextStyle(fontSize: 12),
      ),
      onTap: _openChat,
      // 命中消息可能与关键词部分匹配，用左偏移标记不影响排版
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
    );
  }
}