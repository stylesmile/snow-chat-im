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
import '../../core/utils/message_utils.dart';
import '../../models/message_model.dart';
import '../../core/cache/message_cache_manager.dart';
import '../../services/conversation_service.dart';
import '../../providers/chat_provider.dart';
import 'group_detail_screen.dart';

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
    _ensureConversationSaved();
    _initCache();
    _initMqtt();
  }

  /// 进入聊天页时把该对话保存到本地会话列表，并清空未读数。
  Future<void> _ensureConversationSaved() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await ConversationService().saveSession(
      userId: auth.userId!,
      targetId: widget.targetId,
      targetType: widget.targetType,
      lastMsg: widget.targetName ?? '',
      lastMsgTime: now,
      unreadCount: 0,
    );

    // 通知服务端标记消息为已读
    final service = ChatService(auth.apiClient);
    service.markAsRead(auth.userId!, widget.targetId, widget.targetType);

    if (!mounted) return;
    // 清空该会话的未读数，导航栏角标和列表角标同步更新
    context.read<ChatProvider>().updateConversation(
      Conversation(
        targetId: widget.targetId,
        targetType: widget.targetType,
        lastMsg: widget.targetName ?? '',
        lastMsgTime: now,
        unreadCount: 0,
      ),
    );
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

    // 进入聊天页面时，请求服务器推送未推送成功的消息
    _fetchUndelivered();
  }

  void _initMqtt() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId ?? 0;
    // 使用独立 clientId，避免与 HomeScreen 的全局 MQTT 连接互踢
    final chatClientId = 'user_${userId}_chat_${widget.targetId}_${widget.targetType}';
    _mqttClient = MqttChatClient(
      host: ApiConstants.mqttHost,
      port: ApiConstants.mqttPort,
      onMessage: _handleMqttMessage,
    );
    // 等待连接完成后再订阅群主题
    await _mqttClient?.connect(
      userId: userId,
      username: ApiConstants.mqttUsername,
      password: ApiConstants.mqttPassword,
      clientId: chatClientId,
    );
    // 连接成功后订阅群主题
    if (widget.targetType == 'group') {
      _mqttClient?.subscribeGroup(widget.targetId);
    }
  }

  /// 处理 MQTT 收到的消息
  Future<void> _handleMqttMessage(int cmd, dynamic data) async {
    if (!mounted) return;
    debugPrint('[ChatDetail] _handleMqttMessage cmd=$cmd, data=$data');
    if (cmd == WsCmd.msgPush) {
      // 只处理与自己相关的消息
      final fromUserId = MessageUtils.toNullableInt(data['fromUserId']);
      final toUserId = MessageUtils.toNullableInt(data['toUserId']);
      final groupId = MessageUtils.toNullableInt(data['groupId']);

      bool isRelated = false;
      if (widget.targetType == 'group') {
        isRelated = groupId == widget.targetId;
      } else {
        final auth = context.read<AuthProvider>();
        isRelated = (fromUserId == widget.targetId && toUserId == auth.userId) ||
                    (fromUserId == auth.userId && toUserId == widget.targetId);
      }
      debugPrint('[ChatDetail] isRelated=$isRelated, targetType=${widget.targetType}, targetId=${widget.targetId}, from=$fromUserId, to=$toUserId, groupId=$groupId');

      if (isRelated) {
        final incoming = _DisplayMessage.fromJson(data);
        final localSeq = MessageUtils.toNullableInt(data['localSeq']);
        await MessageCacheManager().appendMessage(_sessionId, incoming.toModel());
        if (!mounted) return;
        setState(() {
          if (localSeq != null) {
            final idx = _messages.indexWhere(
              (m) => m.id == localSeq && m.fromUserId == incoming.fromUserId,
            );
            if (idx != -1) {
              _messages[idx] = incoming;
              return;
            }
          }
          final exists = _messages.any((m) => m.id == incoming.id);
          if (!exists) {
            _messages.add(incoming);
          }
        });
        _scrollToBottom();

        // 收到对方消息后，向服务器发送回执确认（仅对方发来的消息才回执）
        if (fromUserId != null && fromUserId != (context.read<AuthProvider>().userId ?? 0)) {
          _sendReceipt(incoming.id);
        }
      }
    } else if (cmd == WsCmd.msgReceiptAck) {
      // 服务器回执：确认消息已推送给对方，更新 pushStatus 为 delivered
      final msgId = MessageUtils.toNullableInt(data['messageId']);
      if (msgId != null) {
        debugPrint('[ChatDetail] msgReceiptAck for msgId=$msgId, updating pushStatus to delivered');
        await MessageCacheManager().updatePushStatus(_sessionId, msgId, 'delivered');
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(pushStatus: 'delivered');
          }
        });
      }
    } else if (cmd == WsCmd.fetchUndeliveredAck) {
      // 服务器推送未推送成功的消息列表
      final messages = data as List<dynamic>? ?? [];
      debugPrint('[ChatDetail] fetchUndeliveredAck: ${messages.length} messages');
      for (final msgData in messages) {
        final incoming = _DisplayMessage.fromJson(msgData);
        await MessageCacheManager().appendMessage(_sessionId, incoming.toModel());
        if (!mounted) return;
        final exists = _messages.any((m) => m.id == incoming.id);
        if (!exists) {
          setState(() => _messages.add(incoming));
        }
      }
      // 重新排序并滚动到底部
      if (messages.isNotEmpty && mounted) {
        setState(() {
          _messages.sort((a, b) => a.createTime.compareTo(b.createTime));
        });
        _scrollToBottom();
      }
    } else if (cmd == WsCmd.friendReqNotify) {
      // 好友请求通知
    }
  }

  /// 向服务器发送消息回执（接收方确认收到消息）- 通过 REST API
  void _sendReceipt(int messageId) {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final service = ChatService(auth.apiClient);
    service.sendReceipt(messageId, auth.userId!, widget.targetId, widget.targetType);
    debugPrint('[ChatDetail] sent msgReceipt for messageId=$messageId');
  }

  /// 进入聊天页面时请求服务器推送未推送成功的消息 - 通过 REST API
  void _fetchUndelivered() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final service = ChatService(auth.apiClient);
    final messages = await service.fetchUndelivered(auth.userId!, widget.targetId, widget.targetType);
    debugPrint('[ChatDetail] fetchUndelivered: ${messages.length} messages');
    if (messages.isEmpty || !mounted) return;
    for (final msg in messages) {
      await MessageCacheManager().appendMessage(_sessionId, msg);
      if (!mounted) return;
      final exists = _messages.any((m) => m.id == msg.id);
      if (!exists) {
        setState(() => _messages.add(_DisplayMessage.fromModel(msg)));
      }
    }
    if (mounted) {
      setState(() {
        _messages.sort((a, b) => a.createTime.compareTo(b.createTime));
      });
      _scrollToBottom();
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

    // 以缓存为准重新加载，但保留 _messages 中已有但缓存快照还没同步的实时消息
    // （避免竞态：MQTT 消息刚到、缓存写入尚未完成时被清空）
    final cached = await MessageCacheManager().recentMessages(_sessionId, limit: 30);
    if (!mounted) return;
    setState(() {
      // 用 id 做 key 合并：缓存版本优先（可能含更新的 status），保留 _messages 中未同步的实时消息
      final merged = <int, _DisplayMessage>{};
      for (final m in _messages) {
        merged[m.id] = m;
      }
      for (final m in cached) {
        final display = _DisplayMessage.fromModel(m);
        merged[display.id] = display; // 缓存版本覆盖
      }
      _messages
        ..clear()
        ..addAll(merged.values)
        ..sort((a, b) => a.createTime.compareTo(b.createTime));
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
      // 更新会话列表 lastMsg（私聊已去掉服务端回显，需客户端主动更新）
      if (mounted) {
        context.read<ChatProvider>().updateConversation(
          Conversation(
            targetId: widget.targetId,
            targetType: widget.targetType,
            lastMsg: text,
            lastMsgTime: now,
            unreadCount: 0,
          ),
        );
        await ConversationService().saveSession(
          userId: auth.userId!,
          targetId: widget.targetId,
          targetType: widget.targetType,
          lastMsg: text,
          lastMsgTime: now,
          unreadCount: 0,
        );
      }
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
        // reverse: true 时 minScrollExtent 对应视觉底部（最新消息位置）
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
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
      appBar: AppBar(
        title: Text(displayName),
        // 群聊显示三点按钮，点击直接进入群聊详情
        actions: widget.targetType == 'group'
            ? [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: '群聊信息',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(groupId: widget.targetId),
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
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
                          // reverse: true 时 maxScrollExtent 对应视觉顶部，上滑加载更早消息
                          if (notification is ScrollEndNotification &&
                              notification.metrics.pixels == notification.metrics.maxScrollExtent) {
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
//                   if (!isMe)
//                     Padding(
//                       padding: const EdgeInsets.only(bottom: 2),
//                       child: Text(
//                         msg.fromUserId.toString(),
//                         style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
//                       ),
//                     ),
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
  final String pushStatus; // 推送状态：pending/server_received/client_ack/delivered
  final int createTime;

  _DisplayMessage({
    required this.id,
    required this.fromUserId,
    this.toUserId,
    this.groupId,
    required this.type,
    required this.content,
    this.status = 'sent',
    this.pushStatus = 'pending',
    required this.createTime,
  });

  factory _DisplayMessage.fromJson(dynamic json) {
    if (json == null) return _DisplayMessage(id: 0, fromUserId: 0, type: 'text', content: '', createTime: 0);
    return _DisplayMessage(
      // 使用安全 int 解析：后端 Long/Date 可能序列化为 String 或 num
      id: MessageUtils.toInt(json['id']),
      fromUserId: MessageUtils.toInt(json['fromUserId']),
      toUserId: MessageUtils.toNullableInt(json['toUserId']),
      groupId: MessageUtils.toNullableInt(json['groupId']),
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      status: parseMessageStatus(json['status']),
      pushStatus: json['pushStatus'] as String? ?? 'pending',
      // createTime 兼容 ISO 字符串、毫秒数、DateTime 三种格式
      createTime: json['createTime'] is DateTime
          ? (json['createTime'] as DateTime).millisecondsSinceEpoch
          : MessageUtils.toInt(json['createTime']),
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
      pushStatus: model.pushStatus,
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
    String? pushStatus,
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
      pushStatus: pushStatus ?? this.pushStatus,
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
      pushStatus: pushStatus,
      createTime: createTime,
    );
  }
}
