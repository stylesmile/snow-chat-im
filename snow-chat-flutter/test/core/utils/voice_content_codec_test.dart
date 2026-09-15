import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/utils/voice_content_codec.dart';

/// VoiceContentCodec 单元测试
///
/// 语音消息的 content 需要同时携带音频 URL 与时长（秒），
/// 格式约定为 "url|durationSeconds"。
/// 本组测试验证编码、解码、以及对旧数据（无时长）的兼容回退。
void main() {
  group('encode', () {
    test('将 URL 与时长编码为 "url|秒数" 格式', () {
      // 执行：编码一条 5 秒语音
      final encoded = VoiceContentCodec.encode('http://host/voice/a.m4a', 5);

      // 验证：格式为 url|duration
      expect(encoded, 'http://host/voice/a.m4a|5');
    });

    test('时长为 0 时同样编码（避免丢失占位信息）', () {
      final encoded = VoiceContentCodec.encode('http://host/v.m4a', 0);
      expect(encoded, 'http://host/v.m4a|0');
    });
  });

  group('decode', () {
    test('解析带时长的内容为 url 与 duration', () {
      // 执行：解码标准格式
      final result = VoiceContentCodec.decode('http://host/voice/a.m4a|12');

      // 验证：url 与时长均正确还原
      expect(result.url, 'http://host/voice/a.m4a');
      expect(result.durationSeconds, 12);
    });

    test('兼容旧数据：无 "|" 分隔符时时长回退为 0', () {
      // 旧版本语音消息 content 只有 URL，没有时长
      final result = VoiceContentCodec.decode('http://host/voice/old.m4a');

      expect(result.url, 'http://host/voice/old.m4a');
      expect(result.durationSeconds, 0);
    });

    test('时长部分非数字时回退为 0（容错脏数据）', () {
      final result = VoiceContentCodec.decode('http://host/v.m4a|abc');

      expect(result.url, 'http://host/v.m4a');
      expect(result.durationSeconds, 0);
    });

    test('URL 本身含多个 "|" 时只按最后一个分隔符拆分', () {
      // 极端情况：URL 中意外包含 "|"，取最后一个作为时长分隔符
      final result = VoiceContentCodec.decode('http://host/a|b.m4a|7');

      expect(result.url, 'http://host/a|b.m4a');
      expect(result.durationSeconds, 7);
    });
  });

  group('formatDuration', () {
    test('秒数格式化为可读时长（如 5"）', () {
      expect(VoiceContentCodec.formatDuration(5), '5"');
    });

    test('0 秒显示为 1"（微信风格：最短显示 1 秒）', () {
      expect(VoiceContentCodec.formatDuration(0), '1"');
    });
  });
}