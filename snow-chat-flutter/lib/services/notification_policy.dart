import '../core/utils/message_utils.dart';

/// 一条待展示的新消息通知内容。
///
/// 请求层级：仅是「收到消息该弹什么」，真正的系统状态与平台权限判断在
/// [NotificationService] 里完成，这里保持为纯函数，便于单元测试。
class IncomingMessageNotification {
  /// 发送方 userId，用于去重/定位（会话目标）
  final int fromUserId;

  /// 是否群消息（群消息标题展示群标识）
  final bool isGroup;

  /// 通知标题：好友消息为发送者名，群消息为群名（暂无则回落为「新消息」）
  final String title;

  /// 通知正文：消息内容解析后的摘要（图片/视频等为中文占位）
  final String body;

  const IncomingMessageNotification({
    required this.fromUserId,
    required this.isGroup,
    required this.title,
    required this.body,
  });
}

/// 新消息通知的内容构建策略（纯函数，无平台依赖，便于测试）。
///
/// 职责：接收一条 MQTT 推送的 `msgPush` 消息数据，判断是否值得弹系统通知，
/// 并构造出标题与正文。若消息不应打扰用户（例如文件传输助手把自己发给自己
/// 的回推），返回 null，上层据此跳过。
class NotificationPolicy {
  /// 通知标题默认文案："新消息"（当无法解析出发送方昵称时使用）
  static const String defaultTitle = '新消息';

  /// 根据收到的消息数据构建通知内容。
  ///
  /// @param data MQTT `msgPush` 的消息字段（fromUserId/toUserId/groupId/type/content…）
  /// @param currentUserId 当前登录用户 id
  /// @param senderName 发送方昵称（可能为空，此时标题回落为 [defaultTitle]）
  /// @return 可展示的通知内容；若为"自己发给自己的文件助手回推"，返回 null
  static IncomingMessageNotification? buildIncomingMessageNotification({
    required Map<String, dynamic> data,
    required int currentUserId,
    String? senderName,
  }) {
    // 解析基础字段：发送方、接收方、群号，均可能缺失需兜底
    final fromUserId = MessageUtils.toNullableInt(data['fromUserId']);
    final toUserId = MessageUtils.toNullableInt(data['toUserId']);
    final groupId = MessageUtils.toNullableInt(data['groupId']);
    final isGroup = groupId != null;

    // 文件传输助手会把「发给自己的消息」回推到自己的 topic，
    // 此时 fromUserId == toUserId == 自己，弹通知会自扰，直接跳过。
    if (!isGroup &&
        fromUserId != null &&
        fromUserId == toUserId &&
        fromUserId == currentUserId) {
      return null;
    }

    // 消息类型与原文，用于生成正文占位（图片/视频等）
    final type = data['type'] as String? ?? 'text';
    final content = data['content'] as String? ?? '';
    // 复用列表摘要逻辑，保证通知正文与会话列表文案一致
    final body = MessageUtils.getMessagePreview(type, content);

    // 标题优先用发送方昵称，群消息前加群徽标，拿不到则用默认文案
    final String title;
    if (isGroup) {
      title = senderName?.isEmpty == false ? '群消息 $senderName' : defaultTitle;
    } else {
      title = senderName?.isEmpty == false ? senderName! : defaultTitle;
    }

    return IncomingMessageNotification(
      fromUserId: fromUserId ?? 0,
      isGroup: isGroup,
      title: title,
      body: body,
    );
  }
}