import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart' as app_date;

/// 聊天气泡背景形状（对标 win-chat-android `BubbleLayout`）
///
/// 视觉规格取自参考项目 `BubbleLayout.setAll`（夜间主题）：
/// - 大圆角 20、箭头侧小圆角 5；
/// - 10dp 小箭头贴着气泡下部、指向头像一侧（我方在右、对方在左）。
class BubblePainter extends CustomPainter {
  final bool isMe;
  final Color color;

  BubblePainter({required this.isMe, required this.color});

  // 大圆角 / 箭头侧小圆角 / 箭头长度与纵向跨度
  static const double _radius = 20;
  static const double _smallRadius = 5;
  static const double _arrowLen = 10;
  static const double _arrowSpan = 20; // 箭头在直边上的纵向占位

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 箭头位于头像侧直边下部；气泡过矮时整体下移，保证画在直边范围内
    final arrowBottom = (h - 4).clamp(_arrowSpan + _radius, h);
    final arrowTop = arrowBottom - _arrowSpan;
    final arrowTipY = arrowTop + _arrowSpan / 2;

    final path = Path()
      ..moveTo(_radius, 0)
      ..lineTo(w - _radius, 0)
      ..quadraticBezierTo(w, 0, w, _radius);

    if (isMe) {
      // 我方：箭头在右下，指向右侧头像；右下角收小圆角
      path
        ..lineTo(w, arrowTop)
        ..lineTo(w + _arrowLen, arrowTipY)
        ..lineTo(w, arrowBottom)
        ..lineTo(w, h - _smallRadius)
        ..quadraticBezierTo(w, h, w - _smallRadius, h)
        ..lineTo(_radius, h)
        ..quadraticBezierTo(0, h, 0, h - _radius)
        ..lineTo(0, _radius)
        ..quadraticBezierTo(0, 0, _radius, 0);
    } else {
      // 对方：箭头在左下，指向左侧头像；左下角收小圆角
      path
        ..lineTo(w, h - _smallRadius)
        ..quadraticBezierTo(w, h, w - _smallRadius, h)
        ..lineTo(_radius, h)
        ..quadraticBezierTo(0, h, 0, h - _radius)
        ..lineTo(0, arrowBottom)
        ..lineTo(-_arrowLen, arrowTipY)
        ..lineTo(0, arrowTop)
        ..lineTo(0, _radius)
        ..quadraticBezierTo(0, 0, _radius, 0);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BubblePainter oldDelegate) =>
      isMe != oldDelegate.isMe || color != oldDelegate.color;
}

/// 带箭头的气泡容器：ChatBubble（文本）与 ChatDetailScreen 的多媒体气泡共用，
/// 保证整页气泡形状一致。
class BubbleContainer extends StatelessWidget {
  final bool isMe;
  final Widget child;
  final EdgeInsets padding;

  const BubbleContainer({
    super.key,
    required this.isMe,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
  });

  /// 箭头伸出气泡外 10dp，外层行需要预留等宽间距，避免被裁剪
  static const double arrowLen = 10;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BubblePainter(isMe: isMe, color: _bubbleColor),
      child: Padding(padding: padding, child: child),
    );
  }

  Color get _bubbleColor => isMe ? AppTheme.bubbleSent : AppTheme.bubbleReceived;
}

/// 聊天文本消息气泡组件
///
/// 对标 win-chat-android 夜间主题（values-night/color.xml）：
/// - 我方气泡：金黄底（chat_bubble_send #FFCC00）+ 黑字
/// - 对方气泡：灰紫底（chat_bubble_received #505060）+ 白字
/// - 圆角 20、箭头 10dp 指向头像一侧（BubbleLayout.setAll 规格）
class ChatBubble extends StatelessWidget {
  /// 消息文本内容
  final String content;

  /// 是否为自己发送的消息（决定气泡颜色与箭头方向）
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
    // 文字颜色跟随气泡底色：金底黑字、灰紫底白字
    final textColor =
        isMe ? AppTheme.bubbleSentText : AppTheme.bubbleReceivedText;
    return BubbleContainer(
      isMe: isMe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content, style: TextStyle(color: textColor)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                // 复用全局时间格式化：今天显示时分，更早显示日期
                app_date.DateUtils.formatTime(createTime),
                // 时间戳弱化显示：跟随文字色做半透明
                style: TextStyle(
                    fontSize: 10, color: textColor.withOpacity(0.55)),
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
