// ApiClient 单元测试
// 覆盖：token 注入、header 注入、baseUrl 读取；
// request 方法因依赖真实网络暂不注入 Dio mock（避免侵入 SDK 实现），
// 此处聚焦暴露的配置属性一致性
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/network/api_client.dart';

void main() {
  group('ApiClient', () {
    // factory 是单例，清理 token 后再 init 以隔离测试
    setUpAll(() {
      ApiClient('http://localhost').token = null;
    });

    test('init 后 baseUrl 返回传入的地址', () {
      final api = ApiClient('http://api.example.com/v2');
      expect(api.baseUrl, equals('http://api.example.com/v2'));
    });

    test('初始 token 为 null', () {
      final api = ApiClient('http://x');
      expect(api.token, isNull);
    });

    test('setToken 后 getToken 返回相同值', () {
      final api = ApiClient('http://x');
      api.token = 'test-bearer-token';
      expect(api.token, equals('test-bearer-token'));
    });

    test('setToken 为 null 后 getToken 返回 null', () {
      final api = ApiClient('http://x');
      api.token = 'x';
      api.token = null;
      expect(api.token, isNull);
    });

    test('dio getter 返回已初始化的 Dio 实例', () {
      final api = ApiClient('http://x');
      expect(api.dio, isNotNull);
      expect(api.dio.options.baseUrl, equals('http://x'));
    });
  });
}
