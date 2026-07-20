/// 统一解析消息状态，兼容后端返回的 int 与本地使用的 string。
///
/// 后端状态：0=已发送/正常，其他值暂时映射为 sent。
/// 本地状态：sending / sent / failed / read 等字符串。
String parseMessageStatus(dynamic value) {
  if (value == null) return 'sent';
  if (value is String) return value.isEmpty ? 'sent' : value;
  if (value is int) {
    // 后续可扩展：0 sent, 1 delivered, 2 read
    return 'sent';
  }
  return 'sent';
}
