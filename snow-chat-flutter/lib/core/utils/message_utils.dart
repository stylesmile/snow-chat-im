class MessageUtils {
  static String getMessagePreview(String type, String content) {
    switch (type) {
      case 'text':
        return content.length > 20
            ? '${content.substring(0, 20)}...'
            : content;
      case 'image':
        return '[图片]';
      case 'video':
        return '[视频]';
      case 'system':
        return content;
      default:
        return '[未知消息]';
    }
  }

  static String getMessageTypeLabel(String type) {
    switch (type) {
      case 'text':
        return '文本消息';
      case 'image':
        return '图片消息';
      case 'video':
        return '视频消息';
      case 'system':
        return '系统消息';
      default:
        return '未知消息';
    }
  }
}
