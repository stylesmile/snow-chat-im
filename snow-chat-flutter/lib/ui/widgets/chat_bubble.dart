import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart' as app_date;

/// 聊天消息气泡组件
///
/// 从 ChatDetailScreen._buildMessageBubble 提取的纯 UI 组件：
/// - 我方气泡：品牌蓝底（AppTheme.primary）+ 白字
/// - 对方气泡：深色表面（AppTheme.surface）+ 白字
///
/// 提取为独立组件的原因：
/// 1. ChatDetailScreen 依赖 MQTT/SQLite，无法在 widget 测试中直接 pump；
///    独立气泡组件可针对颜色/布局做纯 UI 测试（见 chat_bubble_test.dart）
/// 2. 气泡样式集中一处，深色主题调整不需散改聊天页
class ChatBubble extends StatelessWidget {
  /// 消息文本内容
  final String content;

  /// 是否为自己发送的消息（决定气泡颜色与文字颜色的方向）
  final bool isMe;

  /// 消息创建时间（毫秒时间戳），显示在气泡内底部
  final int createTime;

  /// 消息状态：sending 时在时间旁显示加载圈
  final String status;

  const ChatBubble({
    super.key,
    required this.content,
    required this.isMe,
    required this.createTime,
    this.status = 'sent',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        // 我方=品牌蓝，对方=深色表面（原浅灰 #EEEEEE 在深色页面是刺眼亮块）
        color: isMe ? AppTheme.primary : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            // 两种气泡均为深底，文字统一用白色保证可读（原 black87 在深色气泡上不可读）
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                // 复用全局时间格式化：今天显示时分，更早显示日期
                app_date.DateUtils.formatTime(createTime),
                // 时间戳弱化显示：两种气泡均用半透明白（原 grey.shade600 不可读）
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
              // 发送中的消息在时间旁显示小加载圈，给出"正在发送"反馈
              if (status == 'sending') ...[
                const SizedBox(width: 4),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
