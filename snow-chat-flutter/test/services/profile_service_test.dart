import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/services/profile_service.dart';

import '../helpers/mock_api_client.dart';

void main() {
  late MockApiClient mockApiClient;
  late ProfileService profileService;

  setUp(() {
    mockApiClient = MockApiClient();
    profileService = ProfileService(mockApiClient);
  });

  group('ProfileService.getUserProfile', () {
    test('should return user profile when request succeeds', () async {
      mockApiClient.adapter.onGet(
        '/chat/user/info/1',
        (server) => server.reply(200, {
          'code': '200',
          'data': {
            'id': 1,
            'username': 'testuser',
            'nickname': 'Test User',
            'avatar': 'avatar_url',
            'signature': 'Hello!',
          },
        }),
      );

      final profile = await profileService.getUserProfile(1);

      expect(profile, isNotNull);
      expect(profile!['username'], equals('testuser'));
      expect(profile['nickname'], equals('Test User'));
    });

    test('should return null when request fails', () async {
      mockApiClient.adapter.onGet(
        '/chat/user/info/1',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/user/info/1'),
          ),
        ),
      );

      final profile = await profileService.getUserProfile(1);

      expect(profile, isNull);
    });

    test('should return null when data is null', () async {
      mockApiClient.adapter.onGet(
        '/chat/user/info/1',
        (server) => server.reply(200, {'code': '200', 'data': null}),
      );

      final profile = await profileService.getUserProfile(1);

      expect(profile, isNull);
    });
  });

  group('ProfileService.updateProfile', () {
    test('should return true when update succeeds', () async {
      mockApiClient.adapter.onPut(
        '/chat/user/profile',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await profileService.updateProfile(
        1,
        nickname: 'New Name',
        avatar: 'new_avatar',
        signature: 'New signature',
      );

      expect(result, isTrue);
    });

    test('should return false when update fails', () async {
      mockApiClient.adapter.onPut(
        '/chat/user/profile',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/user/profile'),
          ),
        ),
      );

      final result = await profileService.updateProfile(1, nickname: 'New Name');

      expect(result, isFalse);
    });
  });
}
