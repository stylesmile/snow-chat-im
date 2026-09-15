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
    _conversations = _sorted(_dedup(conversations));
    notifyListeners();
  }

  /// 按 (targetType, targetId) 去重，同一会话只保留最新的一条
  ///
  /// 数据源（本地 SQLite / 服务端推送 / 通讯录跳转）都可能带进同一会话的多条记录，
  /// 这里是渲染前的最后一道防线：宁可多合并一次，也不让列表出现两条同名会话。
  /// 保留策略：最后消息时间更大的那条胜出，置顶/免打扰取两者的并集（不丢用户设置）。
  static List<Conversation> _dedup(List<Conversation> list) {
    final byKey = <String, Conversation>{};
    for (final conv in list) {
      final key = '${conv.targetType}:${conv.targetId}';
      final kept = byKey[key];
      if (kept == null) {
        byKey[key] = conv;
        continue;
      }
      final newer = conv.lastMsgTime >= kept.lastMsgTime ? conv : kept;
      byKey[key] = Conversation(
        targetId: newer.targetId,
        targetType: newer.targetType,
        lastMsg: newer.lastMsg,
        lastMsgTime: newer.lastMsgTime,
        unreadCount: newer.unreadCount,
        isPinned: kept.isPinned || conv.isPinned,
        isMuted: kept.isMuted || conv.isMuted,
      );
    }
    return byKey.values.toList();
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

  /// 打开会话时清零该会话的未读数
  ///
  /// 只改未读数：不动最后消息与时间（避免把会话顶到列表最前、看起来像新数据），
  /// 也保留置顶/免打扰；列表里没有这条会话时什么也不做（不新建）。
  void clearUnread(int targetId, String targetType) {
    final index = _conversations.indexWhere(
      (c) => c.targetId == targetId && c.targetType == targetType,
    );
    if (index == -1) return;
    final old = _conversations[index];
    if (old.unreadCount == 0) return;
    _conversations[index] = Conversation(
      targetId: old.targetId,
      targetType: old.targetType,
      lastMsg: old.lastMsg,
      lastMsgTime: old.lastMsgTime,
      unreadCount: 0,
      isPinned: old.isPinned,
      isMuted: old.isMuted,
    );
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
