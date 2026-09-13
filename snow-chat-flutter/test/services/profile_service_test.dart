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
/// 5. fetchAvatarUrl：取当前用户头像的可访问 URL（key → URL 转换）
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
        '/chat/user/update',
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
        '/chat/user/update',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/user/update'),
          ),
        ),
      );

      final result = await profileService.updateProfile(1, nickname: 'New Name');

      expect(result, isFalse);
    });
  });

  /// uploadAvatar：POST /chat/user/avatar/upload multipart/form-data
  ///
  /// 必须打向「上传并落库」的端点；`/file/avatar` 只上传不写 DB，
  /// 用它会导致重新登录后头像丢失（本地登录态被后端返回值覆盖）。
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
        '/chat/user/avatar/upload',
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
        '/chat/user/avatar/upload',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/user/avatar/upload'),
          ),
        ),
      );

      final result = await profileService.uploadAvatar(tempFile);

      expect(result, isNull);
    });

    test('should return null when response data is null', () async {
      mockApiClient.adapter.onPost(
        '/chat/user/avatar/upload',
        (server) => server.reply(200, {'code': '500', 'data': null}),
      );

      final result = await profileService.uploadAvatar(tempFile);

      expect(result, isNull);
    });
  });

  /// fetchAvatarUrl：GET /chat/user/info
  ///
  /// 该接口会把库里存的 storage key 转成可访问地址（公共读为直链、私有读为
  /// 带签名的临时链接、本地 InMemory 为 base64 data URL），登录后用它补一次转换。
  group('ProfileService.fetchAvatarUrl', () {
    test('should return accessible url when request succeeds', () async {
      mockApiClient.adapter.onGet(
        '/chat/user/info',
        (server) => server.reply(200, {
          'code': '200',
          'data': {
            'id': 1,
            'avatar': 'https://cdn.example.com/avatars/abc.jpg',
          },
        }),
      );

      final url = await profileService.fetchAvatarUrl();

      expect(url, equals('https://cdn.example.com/avatars/abc.jpg'));
    });

    test('should return null when request fails', () async {
      mockApiClient.adapter.onGet(
        '/chat/user/info',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/user/info'),
          ),
        ),
      );

      final url = await profileService.fetchAvatarUrl();

      expect(url, isNull);
    });

    test('should return null when data is null', () async {
      mockApiClient.adapter.onGet(
        '/chat/user/info',
        (server) => server.reply(200, {'code': '200', 'data': null}),
      );

      final url = await profileService.fetchAvatarUrl();

      expect(url, isNull);
    });
  });
}
