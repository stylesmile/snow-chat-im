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

  /// 安全将动态值解析为 int（兼容 num、String、null）
  /// 后端 Jackson 可能将 Long/Integer 序列化为 JSON number 或 String，
  /// 直接 `as int?` 会在 String 情况下抛出 type cast 异常，需统一兜底。
  static int toInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      // 字符串可能是数字或 ISO 时间；先尝试直接 parse
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      // 处理 ISO 8601 时间字符串（如 2026-07-19T10:30:00.000+00:00）
      final dt = DateTime.tryParse(value);
      if (dt != null) return dt.millisecondsSinceEpoch;
    }
    return defaultValue;
  }

  /// 安全将动态值解析为可空 int（兼容 num、String、null）
  static int? toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      final dt = DateTime.tryParse(value);
      if (dt != null) return dt.millisecondsSinceEpoch;
    }
    return null;
  }
}
