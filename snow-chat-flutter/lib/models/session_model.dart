class SessionModel {
  final int targetId;
  final String targetType;
  String lastMsg;
  int lastMsgTime;
  int unreadCount;

  SessionModel({
    required this.targetId,
    required this.targetType,
    this.lastMsg = '',
    this.lastMsgTime = 0,
    this.unreadCount = 0,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      targetId: json['target_id'] as int? ?? 0,
      targetType: json['target_type'] as String? ?? 'friend',
      lastMsg: json['last_msg'] as String? ?? '',
      lastMsgTime: json['last_msg_time'] as int? ?? 0,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
