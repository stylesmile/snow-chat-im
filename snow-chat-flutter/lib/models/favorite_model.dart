// FavoriteModel（收藏数据模型）
//
// 收藏模块对标唐道道 IM"收藏模块"（免费基础功能）：文本/图片消息支持收藏，
// 收藏数据本地持久化（SQLite favorites_{userId} 表）。
//
// 字段说明：
// - id        : 收藏记录主键（自增，本表内）
// - messageId : 被收藏的原始消息ID（用于去重：同一消息只能收藏一次）
// - type      : 消息类型（text / image 等）
// - content   : 文本内容 或 图片URL
// - fromUserId: 该条消息的发送者用户ID
// - fromNickname: 发送者昵称（展示用，冗余存储避免联查）
// - createTime: 收藏时间（毫秒时间戳）
class FavoriteModel {
  final int id;
  final int messageId;
  final String type;
  final String content;
  final int fromUserId;
  final String fromNickname;
  final int createTime;

  const FavoriteModel({
    this.id = 0,
    required this.messageId,
    this.type = 'text',
    this.content = '',
    this.fromUserId = 0,
    this.fromNickname = '',
    this.createTime = 0,
  });

  /// 从数据库/JSON 反序列化；字段名与 favorites 表列名一一对应
  ///
  /// 使用护机制：字段缺失或类型不符时回退默认值，保证脏数据不崩溃。
  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    // 兼容 camelCase 与 snake_case 两种键名
    dynamic value(String camel, String snake) => json[camel] ?? json[snake];

    return FavoriteModel(
      id: value('id', 'id') as int? ?? 0,
      messageId: value('messageId', 'message_id') as int? ?? 0,
      type: value('type', 'msg_type') as String? ?? 'text',
      content: value('content', 'content') as String? ?? '',
      fromUserId: value('fromUserId', 'from_user_id') as int? ?? 0,
      fromNickname: value('fromNickname', 'from_nickname') as String? ?? '',
      // 兼容时间戳为 String 的情况
      createTime: (value('createTime', 'create_time') as num?)?.toInt() ??
          int.tryParse(value('createTime', 'create_time').toString()) ??
          0,
    );
  }

  /// 序列化为 DB 行 / JSON，键名与 favorites 表列名对齐
  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'type': type,
      'content': content,
      'fromUserId': fromUserId,
      'fromNickname': fromNickname,
      'createTime': createTime,
    };
  }
}