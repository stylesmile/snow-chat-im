import '../core/utils/message_status_parser.dart';

class MessageModel {
  final int id;
  final int fromUserId;
  final int? toUserId;
  final int? groupId;
  final String type;
  final String content;
  final String status;
  final int createTime;

  MessageModel({
    required this.id,
    required this.fromUserId,
    this.toUserId,
    this.groupId,
    required this.type,
    required this.content,
    required this.status,
    required this.createTime,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    dynamic value(String camel, String snake) => json[camel] ?? json[snake];

    return MessageModel(
      id: value('id', 'id') as int? ?? 0,
      fromUserId: value('fromUserId', 'from_user_id') as int? ?? 0,
      toUserId: value('toUserId', 'to_user_id') as int?,
      groupId: value('groupId', 'group_id') as int?,
      type: value('type', 'type') as String? ?? 'text',
      content: value('content', 'content') as String? ?? '',
      status: parseMessageStatus(value('status', 'status')),
      createTime: value('createTime', 'create_time') as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'groupId': groupId,
      'type': type,
      'content': content,
      'status': status,
      'createTime': createTime,
      'localSeq': createTime,
    };
  }
}
