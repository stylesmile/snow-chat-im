import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../core/utils/date_utils.dart' as app_date;

class MessageBubble extends StatelessWidget {
  final String content;
  final String type;
  final bool isMe;
  final int? createTime;
  final String? status;

  const MessageBubble({
    super.key,
    required this.content,
    required this.type,
    required this.isMe,
    this.createTime,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMe ? theme.colorScheme.primary : Colors.grey.shade200;
    final textColor = isMe ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: const Text('U', style: TextStyle(fontSize: 10)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildContent(type, content, theme, textColor),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: const Text('Y', style: TextStyle(fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(String type, String content, ThemeData theme, Color textColor) {
    switch (type) {
      case 'text':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content, style: TextStyle(color: textColor)),
            if (createTime != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    app_date.DateUtils.formatTime(createTime),
                    style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      status == 'read' ? Icons.done_all : Icons.done,
                      size: 12,
                      color: status == 'read' ? Colors.blueAccent : textColor.withOpacity(0.6),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: content,
                width: 200,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(width: 200, height: 150, color: Colors.grey.shade300),
                errorWidget: (_, __, ___) =>
                    Container(width: 200, height: 150, color: Colors.grey.shade300),
              ),
            ),
            if (createTime != null) ...[
              const SizedBox(height: 4),
              Text(
                app_date.DateUtils.formatTime(createTime),
                style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
              ),
            ],
          ],
        );
      case 'video':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(Icons.play_circle_outline, size: 48, color: textColor),
              ),
            ),
            if (createTime != null) ...[
              const SizedBox(height: 4),
              Text(
                app_date.DateUtils.formatTime(createTime),
                style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
              ),
            ],
          ],
        );
      default:
        return Text(
          content,
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
        );
    }
  }
}
