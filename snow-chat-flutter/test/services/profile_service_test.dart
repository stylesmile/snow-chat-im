import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/services/profile_service.dart';

import '../helpers/mock_api_client.dart';

/// ProfileService 单元测试
///
/// 覆盖：
/// 1. getUserProfile：成功/失败/data 为 null
/// 2. refreshProfile：委托 getUserProfile
/// 3. updateProfile：成功/失败（PUT JSON body）
/// 4. uploadAvatar：成功返回 UploadResult / 网络异常返回 null
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

  /// refreshProfile 是 getUserProfile 的语义包装，行为应一致
  group('ProfileService.refreshProfile', () {
    test('should return user profile when request succeeds', () async {
      mockApiClient.adapter.onGet(
        '/chat/user/info/1',
        (server) => server.reply(200, {
          'code': '200',
          'data': {
            'id': 1,
            'username': 'testuser',
            'nickname': 'Test User',
          },
        }),
      );

      final profile = await profileService.refreshProfile(1);

      expect(profile, isNotNull);
      expect(profile!['id'], equals(1));
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

      final profile = await profileService.refreshProfile(1);

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

  /// uploadAvatar：POST /file/avatar multipart/form-data
  group('ProfileService.uploadAvatar', () {
    late File tempFile;

    setUp(() {
      // 构造临时图片文件（JPEG 文件头字节），测试后删除
      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}/test_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      tempFile = File(tempPath)..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
    });

    tearDown(() {
      // 清理临时文件
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    });

    test('should return UploadResult when upload succeeds', () async {
      // mock 后端返回 {code:200, data:{key, url}}
      mockApiClient.adapter.onPost(
        '/file/avatar',
        (server) => server.reply(200, {
          'code': '200',
          'data': {
            'key': 'avatars/uuid.jpg',
            'url': 'https://presigned.example.com/avatars/uuid.jpg',
          },
        }),
      );

      final result = await profileService.uploadAvatar(tempFile);

      expect(result, isNotNull);
      expect(result!.key, equals('avatars/uuid.jpg'));
      expect(result.url, equals('https://presigned.example.com/avatars/uuid.jpg'));
    });

    test('should return null when upload fails with network error', () async {
      mockApiClient.adapter.onPost(
        '/file/avatar',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/file/avatar'),
          ),
        ),
      );

      final result = await profileService.uploadAvatar(tempFile);

      expect(result, isNull);
    });

    test('should return null when response data is null', () async {
      mockApiClient.adapter.onPost(
        '/file/avatar',
        (server) => server.reply(200, {'code': '500', 'data': null}),
      );

      final result = await profileService.uploadAvatar(tempFile);

      expect(result, isNull);
    });
  });
}
