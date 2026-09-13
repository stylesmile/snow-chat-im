import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/utils/qr_payload.dart';

/// MyQrPayload 编解码单元测试
///
/// 覆盖：正常编码/解码、非本协议返回 null、非数字 / 空段 / 非法输入防御。
void main() {
  group('encode', () {
    test('应生成 snowchat://user/{id} 格式', () {
      // 执行：编码 userId
      expect(MyQrPayload.encode(1001), 'snowchat://user/1001');
    });
  });

  group('decode', () {
    test('应从合法二维码内容还原 userId', () {
      // 验证：基础还原
      expect(MyQrPayload.decode('snowchat://user/1001'), 1001);
      // 验证：较大 id 也能解析
      expect(MyQrPayload.decode('snowchat://user/1065095167'), 1065095167);
    });

    test('非本协议前缀返回 null', () {
      // 验证：裸数字 / 其他协议均无法识别
      expect(MyQrPayload.decode('1001'), isNull);
      expect(MyQrPayload.decode('https://example.com/user/1001'), isNull);
      expect(MyQrPayload.decode(''), isNull);
    });

    test('协议头之后非数字返回 null', () {
      // 验证：id 段不是数字或为空时防御返回 null
      expect(MyQrPayload.decode('snowchat://user/abc'), isNull);
      expect(MyQrPayload.decode('snowchat://user/'), isNull);
      expect(MyQrPayload.decode('snowchat://user/1001abc'), isNull);
    });

    test('encode 与 decode 互为逆操作', () {
      // 验证：任意 id 编解码一致
      for (final id in [1, 42, 9999, 1065095167]) {
        expect(MyQrPayload.decode(MyQrPayload.encode(id)), id);
      }
    });
  });
}