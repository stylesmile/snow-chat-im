import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/services/contact_service.dart';

import '../helpers/mock_api_client.dart';

void main() {
  late MockApiClient mockApiClient;
  late ContactService contactService;

  setUp(() {
    mockApiClient = MockApiClient();
    contactService = ContactService(mockApiClient);
  });

  group('ContactService.getFriends', () {
    test('should return friend list when request succeeds', () async {
      mockApiClient.adapter.onGet(
        '/chat/friend/list',
        (server) => server.reply(200, {
          'code': '200',
          'data': [
            {
              'userId': 2,
              'nickname': 'Alice',
              'avatar': '',
              'remark': '',
              'status': 'online',
            },
            {
              'userId': 3,
              'nickname': 'Bob',
              'avatar': '',
              'remark': '',
              'status': 'offline',
            },
          ],
        }),
      );

      final friends = await contactService.getFriends(1);

      expect(friends.length, equals(2));
      expect(friends[0].nickname, equals('Alice'));
      expect(friends[1].nickname, equals('Bob'));
    });

    test('should return empty list when request fails', () async {
      mockApiClient.adapter.onGet(
        '/chat/friend/list',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/friend/list'),
          ),
        ),
      );

      final friends = await contactService.getFriends(1);

      expect(friends, isEmpty);
    });

    test('should return empty list when data is null', () async {
      mockApiClient.adapter.onGet(
        '/chat/friend/list',
        (server) => server.reply(200, {'code': '200', 'data': null}),
      );

      final friends = await contactService.getFriends(1);

      expect(friends, isEmpty);
    });
  });

  group('ContactService.searchUsers', () {
    test('should return search results when request succeeds', () async {
      mockApiClient.adapter.onGet(
        '/chat/user/search',
        (server) => server.reply(200, {
          'code': '200',
          'data': [
            {
              'id': 5,
              'username': 'john',
              'nickname': 'John',
              'avatar': '',
            },
          ],
        }),
      );

      final results = await contactService.searchUsers('john');

      expect(results.length, equals(1));
      expect(results[0].username, equals('john'));
      expect(results[0].nickname, equals('John'));
    });

    test('should return empty list when search fails', () async {
      mockApiClient.adapter.onGet(
        '/chat/user/search',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/user/search'),
          ),
        ),
      );

      final results = await contactService.searchUsers('john');

      expect(results, isEmpty);
    });
  });

  group('ContactService.getUserById', () {
    test('should return scanned user info when request succeeds', () async {
      // 准备：后端 /chat/user/infoById 返回单个用户 data map
      mockApiClient.adapter.onGet(
        '/chat/user/infoById',
        (server) => server.reply(200, {
          'code': '200',
          'data': {
            'id': 7,
            'username': 'bob',
            'nickname': 'Bob',
            'avatar': 'https://img.example.com/avatar.png',
          },
        }),
      );

      // 执行：按 userId 拉取扫码用户资料
      final result = await contactService.getUserById(7);

      // 验证：字段正确映射为可预览的 UserSearchResult
      expect(result, isNotNull);
      expect(result!.id, equals(7));
      expect(result.username, equals('bob'));
      expect(result.nickname, equals('Bob'));
      expect(result.avatar, equals('https://img.example.com/avatar.png'));
    });

    test('should return null when user not found', () async {
      // 准备：后端返回"用户不存在"
      mockApiClient.adapter.onGet(
        '/chat/user/infoById',
        (server) => server.reply(200, {'code': '500', 'msg': '用户不存在'}),
      );

      // 执行
      final result = await contactService.getUserById(404);

      // 验证：返回 null，调用方据此提示
      expect(result, isNull);
    });

    test('should return null when request fails', () async {
      // 准备：网络/接口异常
      mockApiClient.adapter.onGet(
        '/chat/user/infoById',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/user/infoById'),
          ),
        ),
      );

      // 执行
      final result = await contactService.getUserById(7);

      // 验证：返回 null，不抛异常
      expect(result, isNull);
    });
  });

  group('ContactService.sendFriendRequest', () {
    test('should return success map when request succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/friend/request',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await contactService.sendFriendRequest(1, 2, 'Hello!');

      // 成功时应返回 {success: true}，并携带空错误信息
      expect(result['success'], isTrue);
      expect(result['message'], isEmpty);
    });

    test('should return failure map when request fails', () async {
      mockApiClient.adapter.onPost(
        '/chat/friend/request',
        (server) =>
            server.reply(200, {'code': '400', 'msg': 'Already friends'}),
      );

      final result = await contactService.sendFriendRequest(1, 2, 'Hello!');

      // 失败时应返回 {success: false}，并携带后端返回的失败原因
      expect(result['success'], isFalse);
      expect(result['message'], 'Already friends');
    });
  });

  group('ContactService.handleFriendRequest', () {
    test('should return success map when accept succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/friend/handle',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await contactService.handleFriendRequest(1, 2, true);

      // 接受成功应返回 {success: true}
      expect(result['success'], isTrue);
    });

    test('should return success map when reject succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/friend/handle',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await contactService.handleFriendRequest(1, 2, false);

      // 拒绝成功应返回 {success: true}
      expect(result['success'], isTrue);
    });
  });

  group('ContactService.getReceivedRequests', () {
    test('should return pending friend requests', () async {
      mockApiClient.adapter.onGet(
        '/chat/friend/pending',
        (server) => server.reply(200, {
          'code': '200',
          'data': [
            {
              'id': 10,
              'fromUserId': 3,
              'toUserId': 1,
              'status': 'pending',
              'remark': 'Add me!',
              'fromNickname': 'Charlie',
              'fromAvatar': '',
            },
          ],
        }),
      );

      final requests = await contactService.getReceivedRequests(1);

      expect(requests.length, equals(1));
      expect(requests[0].fromUserId, equals(3));
      expect(requests[0].status, equals('pending'));
      expect(requests[0].fromNickname, equals('Charlie'));
    });

    test('should return empty list when request fails', () async {
      mockApiClient.adapter.onGet(
        '/chat/friend/pending',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/friend/pending'),
          ),
        ),
      );

      final requests = await contactService.getReceivedRequests(1);

      expect(requests, isEmpty);
    });
  });

  group('ContactService.getSentRequests', () {
    test('should return sent friend requests', () async {
      mockApiClient.adapter.onGet(
        '/chat/friend/sent',
        (server) => server.reply(200, {
          'code': '200',
          'data': [
            {
              'id': 20,
              'fromUserId': 1,
              'toUserId': 5,
              'status': 'pending',
            },
          ],
        }),
      );

      final requests = await contactService.getSentRequests(1);

      expect(requests.length, equals(1));
      expect(requests[0].toUserId, equals(5));
    });
  });

  group('ContactService.deleteFriend', () {
    test('should return true when delete succeeds', () async {
      mockApiClient.adapter.onDelete(
        '/chat/friend/1/2',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await contactService.deleteFriend(1, 2);

      expect(result, isTrue);
    });

    test('should return false when delete fails', () async {
      mockApiClient.adapter.onDelete(
        '/chat/friend/1/2',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/friend/1/2'),
          ),
        ),
      );

      final result = await contactService.deleteFriend(1, 2);

      expect(result, isFalse);
    });
  });
}

/// UserSearchResult 和 FriendRequest 的 fromJson 测试
void main2() {
  group('UserSearchResult.fromJson', () {
    test('should parse JSON correctly', () {
      final json = {
        'id': 5,
        'username': 'john',
        'nickname': 'John',
        'avatar': 'url',
      };
      final result = UserSearchResult.fromJson(json);

      expect(result.id, equals(5));
      expect(result.username, equals('john'));
      expect(result.nickname, equals('John'));
      expect(result.avatar, equals('url'));
    });

    test('should use defaults for missing fields', () {
      final result = UserSearchResult.fromJson({});

      expect(result.id, equals(0));
      expect(result.username, equals(''));
      expect(result.nickname, equals(''));
      expect(result.avatar, equals(''));
    });
  });

  group('FriendRequest.fromJson', () {
    test('should parse camelCase JSON correctly', () {
      final json = {
        'id': 10,
        'fromUserId': 3,
        'toUserId': 1,
        'status': 'pending',
        'remark': 'Add me!',
        'fromNickname': 'Charlie',
        'fromAvatar': 'url',
      };
      final result = FriendRequest.fromJson(json);

      expect(result.id, equals(10));
      expect(result.fromUserId, equals(3));
      expect(result.toUserId, equals(1));
      expect(result.status, equals('pending'));
      expect(result.remark, equals('Add me!'));
      expect(result.fromNickname, equals('Charlie'));
    });

    test('should parse snake_case JSON correctly', () {
      final json = {
        'id': 10,
        'from_user_id': 3,
        'to_user_id': 1,
        'status': 'pending',
        'from_nickname': 'Charlie',
        'from_avatar': 'url',
      };
      final result = FriendRequest.fromJson(json);

      expect(result.fromUserId, equals(3));
      expect(result.toUserId, equals(1));
      expect(result.fromNickname, equals('Charlie'));
    });

    test('should use defaults for missing fields', () {
      final result = FriendRequest.fromJson({});

      expect(result.id, equals(0));
      expect(result.fromUserId, equals(0));
      expect(result.toUserId, equals(0));
      expect(result.status, equals(''));
    });
  });
}
