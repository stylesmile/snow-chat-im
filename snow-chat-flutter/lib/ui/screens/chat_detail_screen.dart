import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../core/network/mqtt_client.dart';
import '../../core/constants/ws_cmd.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/date_utils.dart' as app_date;
import '../../core/utils/message_status_parser.dart';
import '../../models/message_model.dart';
import '../../core/cache/message_cache_manager.dart';

class ChatDetailScreen extends StatefulWidget {
  final int targetId;
  final String targetType;
  final String? targetName;

  const ChatDetailScreen({
    super.key,
    required this.targetId,
    required this.targetType,
    this.targetName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_DisplayMessage> _messages = [];
  bool _isLoading = true;
  bool _hasMore = false;
  String _sessionId = '';
  MqttChatClient? _mqttClient;

  @override
  void initState() {
    super.initState();
    _initCache();
    _initMqtt();
  }

  Future<void> _initCache() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    _sessionId = widget.targetType == 'group'
        ? MessageCacheManager.sessionIdForGroup(widget.targetId)
        : MessageCacheManager.sessionIdForPrivate(auth.userId!, widget.targetId);

    await MessageCacheManager().init();
    final cached = await MessageCacheManager().recentMessages(_sessionId, limit: 30);

    if (mounted) {
      setState(() {
        _messages.addAll(cached.map((m) => _DisplayMessage.fromModel(m)));
        _isLoading = false;
        _hasMore = _messages.isNotEmpty;
      });
    }

    // 后台同步服务端最新历史，并更新缓存
    await _loadHistory();
  }

  void _initMqtt() {
    final auth = context.read<AuthProvider>();
    _mqttClient = MqttChatClient(
      host: ApiConstants.mqttHost,
      port: ApiConstants.mqttPort,
      onMessage: _handleMqttMessage,
    );
    _mqttClient?.connect(
      userId: auth.userId ?? 0,
      username: ApiConstants.mqttUsername,
      password: ApiConstants.mqttPassword,
    );
    // 群聊需要额外订阅群主题
    if (widget.targetType == 'group') {
      _mqttClient?.subscribeGroup(widget.targetId);
    }
  }

  /// 处理 MQTT 收到的消息
  void _handleMqttMessage(int cmd, dynamic data) {
    if (!mounted) return;
    if (cmd == WsCmd.msgPush) {
      // 只处理与自己相关的消息
      final fromUserId = data['fromUserId'] as int?;
      final toUserId = data['toUserId'] as int?;
      final groupId = data['groupId'] as int?;

      bool isRelated = false;
      if (widget.targetType == 'group') {
        isRelated = groupId == widget.targetId;
      } else {
        // 私聊：消息来自对方或发往自己
        final auth = context.read<AuthProvider>();
        isRelated = (fromUserId == widget.targetId && toUserId == auth.userId) ||
                    (fromUserId == auth.userId && toUserId == widget.targetId);
      }

      if (isRelated) {
        final incoming = _DisplayMessage.fromJson(data);
        MessageCacheManager().appendMessage(_sessionId, incoming.toModel());
        setState(() {
          // 检查是否已存在（去重）
          final exists = _messages.any((m) => m.id == incoming.id);
          if (!exists) {
            _messages.add(incoming);
          }
        });
        // 滚动到底部
        _scrollToBottom();
      }
    } else if (cmd == WsCmd.friendReqNotify) {
      // 好友请求通知，可以在全局处理
    }
  }

  Future<void> _loadHistory() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    if (mounted) setState(() => _isLoading = true);
    final service = ChatService(auth.apiClient);
    final messages = await service.getHistory(
      userId: auth.userId!,
      targetId: widget.targetId,
      targetType: widget.targetType,
      page: 1,
      size: 30,
    );

    // 同步写入本地缓存
    for (final m in messages) {
      await MessageCacheManager().appendMessage(_sessionId, m);
    }

    if (!mounted) return;

    // 以缓存为准重新加载（保证去重与排序）
    final cached = await MessageCacheManager().recentMessages(_sessionId, limit: 30);
    setState(() {
      _messages
        ..clear()
        ..addAll(cached.map((m) => _DisplayMessage.fromModel(m)));
      _hasMore = messages.length >= 30;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _messages.isEmpty) return;

    final earliest = _messages.first;
    final older = await MessageCacheManager().loadHistory(
      _sessionId,
      beforeTime: earliest.createTime,
      limit: 20,
    );

    if (older.isNotEmpty) {
      setState(() {
        _messages.insertAll(0, older.map((m) => _DisplayMessage.fromModel(m)));
        _hasMore = older.length >= 20;
      });
    } else {
      setState(() => _hasMore = false);
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 乐观UI：立即显示
    setState(() {
      _messages.add(_DisplayMessage(
        id: now,
        fromUserId: auth.userId ?? 0,
        toUserId: widget.targetId,
        groupId: widget.targetType == 'group' ? widget.targetId : null,
        type: 'text',
        content: text,
        createTime: now,
        status: 'sending',
      ));
    });
    _controller.clear();
    _scrollToBottom();

    // 通过REST发送，由后端统一落库并MQTT推送
    final service = ChatService(auth.apiClient);
    final sentModel = _DisplayMessage(
      id: now,
      fromUserId: auth.userId ?? 0,
      toUserId: widget.targetId,
      groupId: widget.targetType == 'group' ? widget.targetId : null,
      type: 'text',
      content: text,
      createTime: now,
      status: 'sent',
    );
    final success = await service.sendMessage(sentModel.toModel());

    if (!mounted) return;

    // 更新本地消息状态并写入缓存
    final index = _messages.indexWhere((m) => m.id == now);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(
          status: success ? 'sent' : 'failed',
        );
      });
    }
    if (success) {
      await MessageCacheManager().appendMessage(_sessionId, sentModel.copyWith(status: 'sent').toModel());
    }

    if (!success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.messageFailed)),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _mqttClient?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displayName = widget.targetName ?? l10n.myFriends;

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(l10n.noMessages, style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollEndNotification &&
                              notification.metrics.pixels == notification.metrics.minScrollExtent) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[_messages.length - 1 - index];
                            final isMe = msg.fromUserId == (context.read<AuthProvider>().userId ?? 0);
                            return _buildMessageBubble(msg, isMe, theme);
                          },
                        ),
                      ),
          ),
          _buildInputBar(theme, l10n),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_DisplayMessage msg, bool isMe, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: Text(msg.content.isNotEmpty ? msg.content[0] : '?'),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? theme.colorScheme.primary : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        msg.fromUserId.toString(),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ),
                  Text(
                    msg.content,
                    style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        app_date.DateUtils.formatTime(msg.createTime),
                        style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey.shade600),
                      ),
                      if (msg.status == 'sending') ...[
                        const SizedBox(width: 4),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: const Text('Y'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.attach_file), onPressed: () {}),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: l10n.inputMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.none,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send),
            color: theme.colorScheme.primary,
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

/// 内部消息显示模型
class _DisplayMessage {
  final int id;
  final int fromUserId;
  final int? toUserId;
  final int? groupId;
  final String type;
  final String content;
  final String status;
  final int createTime;

  _DisplayMessage({
    required this.id,
    required this.fromUserId,
    this.toUserId,
    this.groupId,
    required this.type,
    required this.content,
    this.status = 'sent',
    required this.createTime,
  });

  factory _DisplayMessage.fromJson(dynamic json) {
    if (json == null) return _DisplayMessage(id: 0, fromUserId: 0, type: 'text', content: '', createTime: 0);
    return _DisplayMessage(
      id: json['id'] as int? ?? 0,
      fromUserId: json['fromUserId'] as int? ?? 0,
      toUserId: json['toUserId'] as int?,
      groupId: json['groupId'] as int?,
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      status: parseMessageStatus(json['status']),
      createTime: json['createTime'] is DateTime
          ? (json['createTime'] as DateTime).millisecondsSinceEpoch
          : (json['createTime'] as num?)?.toInt() ?? 0,
    );
  }

  factory _DisplayMessage.fromModel(MessageModel model) {
    return _DisplayMessage(
      id: model.id,
      fromUserId: model.fromUserId,
      toUserId: model.toUserId,
      groupId: model.groupId,
      type: model.type,
      content: model.content,
      status: model.status,
      createTime: model.createTime,
    );
  }

  _DisplayMessage copyWith({
    int? id,
    int? fromUserId,
    int? toUserId,
    int? groupId,
    String? type,
    String? content,
    String? status,
    int? createTime,
  }) {
    return _DisplayMessage(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      groupId: groupId ?? this.groupId,
      type: type ?? this.type,
      content: content ?? this.content,
      status: status ?? this.status,
      createTime: createTime ?? this.createTime,
    );
  }

  MessageModel toModel() {
    return MessageModel(
      id: id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      groupId: groupId,
      type: type,
      content: content,
      status: status,
      createTime: createTime,
    );
  }
}
