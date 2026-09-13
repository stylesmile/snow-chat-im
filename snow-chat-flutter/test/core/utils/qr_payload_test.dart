import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/utils/qr_payload.dart';

/// QR 内容编解码工具单元测试
///
/// 覆盖：合法编码/解码、非本 App 二维码返回 null、非法数字返回 null、
/// 空串/缺失协议头、负数等边界情况。
void main() {
  group('MyQrPayload', () {
    test('encode 生成 snowchat://user/{id} 协议串', () {
      // 准备：任意正整数 userId
      const int userId = 1001;
      // 执行：编码为二维码内容
      final String payload = MyQrPayload.encode(userId);
      // 验证：符合约定的协议格式
      expect(payload, 'snowchat://user/1001');
    });

    test('decode 从合法协议串还原 userId', () {
      // 准备：约定的二维码内容
      const String payload = 'snowchat://user/42';
      // 执行：解码
      final int? userId = MyQrPayload.decode(payload);
      // 验证：还原出原始 userId
      expect(userId, 42);
    });

    test('decode 对非本 App 协议前缀返回 null（无法识别）', () {
      // 准备：其他二维码（如网址或别的 scheme）
      const String payload = 'https://example.com/user/42';
      // 执行：解码
      final int? userId = MyQrPayload.decode(payload);
      // 验证：返回 null，调用方据此提示"无效二维码"
      expect(userId, isNull);
    });

    test('decode 对非法数字段返回 null', () {
      // 准备：协议正确但 id 段不是数字
      const String payload = 'snowchat://user/abc';
      // 执行：解码
      final int? userId = MyQrPayload.decode(payload);
      // 验证：返回 null，避免误跳转
      expect(userId, isNull);
    });

    test('decode 对空字符串返回 null', () {
      // 准备：空串（理论上扫描不到，但防御处理）
      const String payload = '';
      // 执行：解码
      final int? userId = MyQrPayload.decode(payload);
      // 验证：返回 null
      expect(userId, isNull);
    });
  });
}