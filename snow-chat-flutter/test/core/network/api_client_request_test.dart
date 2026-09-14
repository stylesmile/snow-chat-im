// Flutter API Client request 单元测试
// 覆盖：成功响应解析、DioException 包装为通用 Exception、错误状态码透传
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/network/api_client.dart';

void main() {
  group('ApiClient.request', () {
    late ApiClient client;
    late Dio dio;

    setUp(() {
      client = ApiClient('http://localhost:8091');
      dio = client.dio;
    });

    test('返回 JSON 对象时正常解析', () async {
      // 拦截器层已注入 token（当前 token 为 null 时不加 Authorization）
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options);
        },
        // 直接返回固定 payload，绕过真实网络
        onResponse: (response, handler) {
          response.data = {'code': '200', 'data': {'ok': true}};
          return handler.next(response);
        },
      ));

      final result = await client.request('/test');

      expect(result, isA<Map>());
      expect(result['code'], equals('200'));
      expect(result['data']['ok'], isTrue);
    });

    test('抛出包含 HTTP 状态码的异常', () async {
      dio.interceptors.add(InterceptorsWrapper(
        onError: (error, handler) {
          final response = Response(
            statusCode: 401,
            data: {'message': '未登录'},
            requestOptions: RequestOptions(path: '/unauthorized'),
          );
          // DioException.response 是 setter，需替换为抛出一个包含 response 的异常
          throw DioException(requestOptions: response.requestOptions, response: response);
        },
      ));

      expect(
        () => client.request('/unauthorized'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('401'),
        )),
      );
    });

    test('抛出包含原始错误的异常', () async {
      dio.interceptors.add(InterceptorsWrapper(
        onError: (error, handler) {
          final response = Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: '/server-error'),
          );
          throw DioException(requestOptions: response.requestOptions, response: response);
        },
      ));

      expect(
        () => client.request('/server-error'),
        throwsA(isA<Exception>()),
      );
    });

    test('携带 queryParameters 与 body 正确转发到下游请求', () async {
      String? capturedPath;
      Map<String, dynamic>? capturedData;
      Map<String, dynamic>? capturedQuery;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedPath = options.path;
          capturedData = options.data as Map<String, dynamic>?;
          capturedQuery = options.queryParameters;
          return handler.next(options);
        },
        onResponse: (response, handler) => handler.next(response),
      ));

      await client.request(
        '/messages',
        data: {'content': 'hi'},
        query: {'page': '1'},
      );

      expect(capturedPath, equals('messages'));
      expect(capturedData, equals({'content': 'hi'}));
      expect(capturedQuery, equals({'page': '1'}));
    });
  });
}
