import 'dart:convert';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../core/network/mqtt_client.dart';
import '../../core/constants/ws_cmd.dart';
import '../../core/constants/api_constants.dart';
import '../widgets/avatar_widget.dart';
import '../../core/utils/date_utils.dart' as app_date;
import '../../models/message_model.dart';

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
  int? _lastMessageId;
  MqttChatClient? _mqttClient;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initMqtt();
  }

  void _initMqtt() {
    final auth = context.read<AuthProvider>();
    _mqttClient = MqttChatClient(
      host: ApiConstants.mqttHost,
      port: ApiConstants.mqttPort,
      onMessage: _handleMqttMessage,
    );
    _mqttClient?.connect(userId: auth.userId ?? 0);
  }

  /// 处理 MQTT 收到的消息
  void _handleMqttMessage(int cmd, dynamic data) {
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
        setState(() {
          // 检查是否已存在（去重）
          final exists = _messages.any((m) => m.id == data['id']);
          if (!exists) {
            _messages.add(_DisplayMessage.fromJson(data));
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

    setState(() => _isLoading = true);
    final service = ChatService(auth.apiClient);
    final messages = await service.getHistory(
      userId: auth.userId!,
      targetId: widget.targetId,
      targetType: widget.targetType,
      page: 1,
      size: 30,
    );

    setState(() {
      _messages.clear();
      for (final m in messages) {
        _messages.add(_DisplayMessage(
          id: m.id,
          fromUserId: m.fromUserId,
          toUserId: m.toUserId,
          groupId: m.groupId,
          type: m.type,
          content: m.content,
          createTime: m.createTime,
          status: m.status,
        ));
      }
      if (messages.isNotEmpty) {
        _lastMessageId = messages.last.id;
        _hasMore = messages.length >= 30;
      }
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _lastMessageId == null) return;
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    final service = ChatService(auth.apiClient);
    final messages = await service.getHistoryByCursor(
      userId: auth.userId!,
      targetId: widget.targetId,
      targetType: widget.targetType,
      beforeMessageId: _lastMessageId,
      size: 20,
    );

    if (messages.isNotEmpty) {
      setState(() {
        for (final m in messages) {
          _messages.insert(0, _DisplayMessage(
            id: m.id,
            fromUserId: m.fromUserId,
            toUserId: m.toUserId,
            groupId: m.groupId,
            type: m.type,
            content: m.content,
            createTime: m.createTime,
            status: m.status,
          ));
        }
        _lastMessageId = messages.first.id;
        _hasMore = messages.length >= 20;
      });
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

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

    // 通过REST发送
    final service = ChatService(auth.apiClient);
    service.sendMessage(_DisplayMessage(
      id: now,
      fromUserId: auth.userId ?? 0,
      toUserId: widget.targetId,
      groupId: widget.targetType == 'group' ? widget.targetId : null,
      type: 'text',
      content: text,
      createTime: now,
      status: 'sent',
    ).toModel());

    // 同时通过MQTT发送（实时推送）
    if (_mqttClient?.isConnected == true) {
      final message = {
        'fromUserId': auth.userId,
        'toUserId': widget.targetId,
        'groupId': widget.targetType == 'group' ? widget.targetId : null,
        'type': 'text',
        'content': text,
        'localSeq': now,
        'createTime': now,
      };
      if (widget.targetType == 'group') {
        _mqttClient!.sendGroupMessage(message, widget.targetId);
      } else {
        _mqttClient!.sendPrivateMessage(message, widget.targetId);
      }
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
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
      status: json['status'] as String? ?? 'sent',
      createTime: json['createTime'] is DateTime
          ? (json['createTime'] as DateTime).millisecondsSinceEpoch
          : (json['createTime'] as num?)?.toInt() ?? 0,
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
