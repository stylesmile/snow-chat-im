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

  static const int recallMaxAgeMs = 2 * 60 * 1000; // 撤回时限：2 分钟

  /// 判断某条消息当前是否允许撤回
  ///
  /// 撤回条件（与主流 IM 一致）：
  /// 1. 必须是本人发送的消息（[isMe] 为 true）
  /// 2. 必须是已成功投递给服务器的消息（status 为 sent/read，发送中/失败不可撤回）
  /// 3. 必须在发送后 2 分钟内操作（超过时限服务端同样拒绝，此处前端先行拦截）
  ///
  /// @param isMe 是否本人发送
  /// @param createTime 消息创建时间戳（毫秒）
  /// @param status 消息状态：sent/read 视为已成功
  /// @param nowMillis 当前时间戳（毫秒），默认取本机时间
  /// @param maxAgeMs 撤回时限（毫秒），默认 2 分钟，便于测试注入
  /// @return 是否允许撤回
  static bool canRecallMessage({
    required bool isMe,
    required int createTime,
    required String status,
    required int nowMillis,
    int maxAgeMs = recallMaxAgeMs,
  }) {
    // 非本人消息一律不可撤回
    if (!isMe) return false;
    // 仅发送成功/已读的消息可撤回；发送中(sending)、失败(failed)不可撤回
    if (status != 'sent' && status != 'read') return false;
    // 超过撤回时限不可撤回
    if (nowMillis - createTime > maxAgeMs) return false;
    return true;
  }
}
