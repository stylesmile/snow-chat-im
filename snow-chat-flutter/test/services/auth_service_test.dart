import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/services/auth_service.dart';

import '../helpers/mock_api_client.dart';

void main() {
  late MockApiClient mockApiClient;
  late AuthService authService;

  setUp(() {
    mockApiClient = MockApiClient();
    authService = AuthService(mockApiClient);
  });

  group('AuthService.login', () {
    test('should return user data when login succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/user/login',
        data: {'username': 'testuser', 'password': 'password123'},
        (server) => server.reply(200, {
          'code': '200',
          'data': {
            'id': 1,
            'username': 'testuser',
            'nickname': 'Test',
            'token': 'abc123',
          },
        }),
      );

      final result = await authService.login('testuser', 'password123');

      expect(result, isNotNull);
      expect(result!['username'], equals('testuser'));
      expect(result['token'], equals('abc123'));
    });

    test('should return null when login fails', () async {
      mockApiClient.adapter.onPost(
        '/chat/user/login',
        (server) => server.reply(401, {
          'code': '401',
          'message': 'Invalid credentials',
        }),
      );

      final result = await authService.login('wronguser', 'wrongpass');

      expect(result, isNull);
    });

    test('should return null when network error occurs', () async {
      mockApiClient.adapter.onPost(
        '/chat/user/login',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/user/login'),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );

      final result = await authService.login('testuser', 'password');

      expect(result, isNull);
    });

    test('should return null when response data is null', () async {
      mockApiClient.adapter.onPost(
        '/chat/user/login',
        (server) => server.reply(200, {
          'code': '200',
          'data': null,
        }),
      );

      final result = await authService.login('testuser', 'password');

      expect(result, isNull);
    });
  });

  group('AuthService.logout', () {
    test('should clear token', () {
      mockApiClient.token = 'some_token';
      expect(mockApiClient.token, equals('some_token'));

      authService.logout();

      expect(mockApiClient.token, isNull);
    });
  });
}
