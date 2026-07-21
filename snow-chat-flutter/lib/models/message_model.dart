import '../core/utils/message_status_parser.dart';
import '../core/utils/message_utils.dart';

class MessageModel {
  final int id;
  final int fromUserId;
  final int? toUserId;
  final int? groupId;
  final String type;
  final String content;
  final String status;
  final String pushStatus; // 推送状态：pending/server_received/client_ack/delivered
  final int createTime;

  MessageModel({
    required this.id,
    required this.fromUserId,
    this.toUserId,
    this.groupId,
    required this.type,
    required this.content,
    required this.status,
    this.pushStatus = 'pending',
    required this.createTime,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // 兼容 camelCase 和 snake_case 两种键名
    dynamic value(String camel, String snake) => json[camel] ?? json[snake];

    return MessageModel(
      // 安全 int 解析：后端 Long/Date 可能序列化为 String 或 num
      id: MessageUtils.toInt(value('id', 'id')),
      fromUserId: MessageUtils.toInt(value('fromUserId', 'from_user_id')),
      toUserId: MessageUtils.toNullableInt(value('toUserId', 'to_user_id')),
      groupId: MessageUtils.toNullableInt(value('groupId', 'group_id')),
      type: value('type', 'type') as String? ?? 'text',
      content: value('content', 'content') as String? ?? '',
      status: parseMessageStatus(value('status', 'status')),
      pushStatus: value('pushStatus', 'push_status') as String? ?? 'pending',
      // createTime 兼容 ISO 字符串、毫秒数
      createTime: MessageUtils.toInt(value('createTime', 'create_time')),
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
      'pushStatus': pushStatus,
      'createTime': createTime,
      'localSeq': createTime,
    };
  }
}
