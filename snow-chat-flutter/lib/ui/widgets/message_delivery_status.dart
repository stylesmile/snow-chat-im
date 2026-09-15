// 消息送达/已读状态图标组件（对标唐道道 IM 旗舰模块"已读/未读"展示）
//
// 在聊天气泡旁展示本机发送消息的投递进度：
//   - sending   ：转圈进度指示器
//   - failed    ：红色感叹号（提示发送失败，可点击重发）
//   - sent      ：灰色单勾（已发送未送达）
//   - delivered ：蓝色双勾（已送达 / 已读）
//
// 用法：根据消息 status/pushStatus 用 resolveDeliveryState() 得到状态，
// 再传给本组件渲染。纯展示，无副作用，便于单元测试。

import 'package:flutter/material.dart';
import '../../core/utils/message_delivery_state.dart';

/// 消息送达状态图标
///
/// [state] 送达状态；[size] 图标尺寸；[color] 可选覆盖颜色（默认按状态语义）。
class MessageDeliveryStatus extends StatelessWidget {
  const MessageDeliveryStatus({super.key, required this.state, this.size = 14});

  /// 送达状态（由 resolveDeliveryState 推导）
  final MessageDeliveryState state;

  /// 图标尺寸
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case MessageDeliveryState.sending:
        // 发送中：使用小尺寸转圈指示器
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey.shade500),
        );
      case MessageDeliveryState.failed:
        // 发送失败：红色感叹号，视觉上醒目警示
        return Icon(Icons.error_rounded, size: size, color: Colors.redAccent);
      case MessageDeliveryState.sent:
        // 已发送：灰色单勾
        return Icon(Icons.done, size: size, color: Colors.grey.shade500);
      case MessageDeliveryState.delivered:
        // 已送达/已读：主题色双勾（阅读态主色）
        return Icon(Icons.done_all, size: size, color: Colors.blueAccent);
    }
  }
}