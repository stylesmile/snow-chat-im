import 'package:flutter/foundation.dart';

class ChatMessage {
  final int id;
  final int fromUserId;
  final int? toUserId;
  final int? groupId;
  final String type;
  final String content;
  final String status;
  final int createTime;
  final String? senderName;
  final String? senderAvatar;

  ChatMessage({
    required this.id,
    required this.fromUserId,
    this.toUserId,
    this.groupId,
    required this.type,
    required this.content,
    required this.status,
    required this.createTime,
    this.senderName,
    this.senderAvatar,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int? ?? 0,
      fromUserId: json['from_user_id'] as int? ?? 0,
      toUserId: json['to_user_id'] as int?,
      groupId: json['group_id'] as int?,
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'sent',
      createTime: json['create_time'] as int? ?? 0,
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
    );
  }
}

class Conversation {
  final int targetId;
  final String targetType;
  String lastMsg;
  int lastMsgTime;
  int unreadCount;

  Conversation({
    required this.targetId,
    required this.targetType,
    this.lastMsg = '',
    this.lastMsgTime = 0,
    this.unreadCount = 0,
  });
}

class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  List<Conversation> _conversations = [];

  List<ChatMessage> get messages => _messages;
  List<Conversation> get conversations => _conversations;

  void addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void setMessages(List<ChatMessage> messages) {
    _messages = messages;
    notifyListeners();
  }

  void updateConversation(Conversation conv) {
    final index = _conversations.indexWhere(
      (c) => c.targetId == conv.targetId && c.targetType == conv.targetType,
    );
    if (index >= 0) {
      _conversations[index] = conv;
    } else {
      _conversations.insert(0, conv);
    }
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
