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
  bool isPinned;
  bool isMuted;

  Conversation({
    required this.targetId,
    required this.targetType,
    this.lastMsg = '',
    this.lastMsgTime = 0,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
  });
}

class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  List<Conversation> _conversations = [];

  List<ChatMessage> get messages => _messages;
  List<Conversation> get conversations => _conversations;

  /// 所有会话的总未读数，用于导航栏角标
  int get totalUnreadCount => _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  void addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void setMessages(List<ChatMessage> messages) {
    _messages = messages;
    notifyListeners();
  }

  void setConversations(List<Conversation> conversations) {
    _conversations = _sorted(conversations);
    notifyListeners();
  }

  void updateConversation(Conversation conv) {
    final index = _conversations.indexWhere(
      (c) => c.targetId == conv.targetId && c.targetType == conv.targetType,
    );
    if (index >= 0) {
      // 保留已存在的置顶/免打扰设置（避免被一次普通更新覆盖丢失）
      _conversations[index] = Conversation(
        targetId: conv.targetId,
        targetType: conv.targetType,
        lastMsg: conv.lastMsg,
        lastMsgTime: conv.lastMsgTime,
        unreadCount: conv.unreadCount,
        isPinned: _conversations[index].isPinned,
        isMuted: _conversations[index].isMuted,
      );
    } else {
      _conversations.insert(0, conv);
    }
    _conversations = _sorted(_conversations);
    notifyListeners();
  }

  /// 置顶/取消置顶指定会话，并重排列表（置顶排最前）
  ///
  /// [pinned] true 置顶，false 取消置顶
  void togglePinned(int targetId, String targetType, {required bool pinned}) {
    final index = _conversations.indexWhere(
      (c) => c.targetId == targetId && c.targetType == targetType,
    );
    if (index == -1) return;
    final old = _conversations[index];
    _conversations[index] = Conversation(
      targetId: old.targetId,
      targetType: old.targetType,
      lastMsg: old.lastMsg,
      lastMsgTime: old.lastMsgTime,
      unreadCount: old.unreadCount,
      isPinned: pinned,
      isMuted: old.isMuted,
    );
    _conversations = _sorted(_conversations);
    notifyListeners();
  }

  /// 免打扰/取消免打扰指定会话
  ///
  /// [muted] true 免打扰，false 取消免打扰
  void toggleMuted(int targetId, String targetType, {required bool muted}) {
    final index = _conversations.indexWhere(
      (c) => c.targetId == targetId && c.targetType == targetType,
    );
    if (index == -1) return;
    final old = _conversations[index];
    _conversations[index] = Conversation(
      targetId: old.targetId,
      targetType: old.targetType,
      lastMsg: old.lastMsg,
      lastMsgTime: old.lastMsgTime,
      unreadCount: old.unreadCount,
      isPinned: old.isPinned,
      isMuted: muted,
    );
    notifyListeners();
  }

  /// 删除指定会话（从内存列表移除，不删数据库）
  void removeConversation(int targetId, String targetType) {
    _conversations.removeWhere(
      (c) => c.targetId == targetId && c.targetType == targetType,
    );
    notifyListeners();
  }

  /// 会话排序：置顶优先，其次按最后消息时间倒序
  static List<Conversation> _sorted(List<Conversation> list) {
    final result = List<Conversation>.from(list);
    result.sort((a, b) {
      // 置顶优先
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      // 同置顶状态按最后消息时间倒序
      return b.lastMsgTime.compareTo(a.lastMsgTime);
    });
    return result;
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
