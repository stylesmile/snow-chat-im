// 消息送达/已读状态解析工具（对标唐道道 IM 旗舰模块"已读/未读"展示）
//
// 发送的消息在聊天气泡旁需要展示清晰的投递进度，通常四态：
//   1. sending   - 发送中（转圈 loading）
//   2. failed    - 发送失败（感叹号，可点击重发）
//   3. sent      - 已发送未送达（单勾）
//   4. delivered - 已送达/已读（双勾）
//
// 该状态由消息的两个字段推导：
//   - status    : 'sending' | 'sent' | 'failed'（发送过程状态）
//   - pushStatus: 'pending' | 'delivered'（是否已收到接收端回执 ack）
//
// 纯函数设计：便于单测，UI 层只需消费 MessageDeliveryState 枚举。

/// 送达/已读状态枚举（供 UI 渲染图标）
enum MessageDeliveryState {
  /// 发送中（转圈）
  sending,

  /// 发送失败（红色感叹号）
  failed,

  /// 已发送但尚未收到送达回执（单勾）
  sent,

  /// 已送达 / 已读（双勾）
  delivered,
}

/// 由消息的 status 与 pushStatus 推导展示状态
///
/// @param status      消息发送状态：sending/sent/failed
/// @param pushStatus  投递回执状态：pending/delivered
/// @return MessageDeliveryState 展示用状态
MessageDeliveryState resolveDeliveryState({
  required String status,
  required String pushStatus,
}) {
  // 发送中：无论是否已收到回执，都表现为加载中，避免误标已读
  if (status == 'sending') return MessageDeliveryState.sending;

  // 发送失败：明确提示用户，优先级高于一切
  if (status == 'failed') return MessageDeliveryState.failed;

  // 其余（sent 或未知）按投递回执区分：
  // 已收到"送达"回执 => 已读；否则 => 已发送
  final delivered = pushStatus == 'delivered';
  return delivered ? MessageDeliveryState.delivered : MessageDeliveryState.sent;
}