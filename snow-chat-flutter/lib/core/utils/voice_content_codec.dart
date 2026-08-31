/// 语音消息内容编解码工具。
///
/// 语音消息的 [content] 需要同时携带音频 URL 与时长（秒），
/// 格式约定为 `"url|durationSeconds"`。
/// 旧版本消息只有 URL 没有时长，解码时兼容回退为 0。
class VoiceContentCodec {
  /// 分隔符：URL 与时长之间的唯一分隔字符
  static const String _separator = '|';

  /// 将音频 [url] 与 [durationSeconds] 编码为 content 字符串。
  ///
  /// 返回格式：`"url|durationSeconds"`。
  static String encode(String url, int durationSeconds) {
    return '$url$_separator$durationSeconds';
  }

  /// 解码 content 字符串，返回 [VoiceContent]（url + 时长）。
  ///
  /// 兼容规则：
  /// - 无分隔符（旧数据）：时长回退为 0
  /// - 时长部分非数字（脏数据）：时长回退为 0
  /// - URL 中意外含分隔符：按最后一个分隔符拆分
  static VoiceContent decode(String content) {
    // 找最后一个分隔符位置（URL 中可能意外包含 "|"）
    final lastSep = content.lastIndexOf(_separator);

    // 无分隔符：旧格式，只有 URL
    if (lastSep == -1) {
      return VoiceContent(url: content, durationSeconds: 0);
    }

    final url = content.substring(0, lastSep);
    final durationPart = content.substring(lastSep + 1);

    // 尝试解析时长，失败则回退为 0
    final duration = int.tryParse(durationPart) ?? 0;

    return VoiceContent(url: url, durationSeconds: duration);
  }

  /// 将秒数格式化为可读时长文本。
  ///
  /// 微信风格：最短显示 1 秒（0 秒也显示 1"），格式为 `N"`。
  static String formatDuration(int seconds) {
    // 最短显示 1 秒，与微信语音气泡一致
    final display = seconds < 1 ? 1 : seconds;
    return '$display"';
  }
}

/// 解码后的语音内容：音频 URL + 时长（秒）
class VoiceContent {
  /// 音频文件的网络地址
  final String url;

  /// 语音时长（秒）；旧数据或解析失败时为 0
  final int durationSeconds;

  const VoiceContent({required this.url, required this.durationSeconds});
}