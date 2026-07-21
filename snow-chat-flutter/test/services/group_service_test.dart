import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/services/group_service.dart';

import '../helpers/mock_api_client.dart';

void main() {
  late MockApiClient mockApiClient;
  late GroupService groupService;

  setUp(() {
    mockApiClient = MockApiClient();
    groupService = GroupService(mockApiClient);
  });

  group('GroupService.createGroup', () {
    test('should return group ID when creation succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/group/create',
        (server) => server.reply(200, {'code': '200', 'data': 100}),
      );

      final groupId = await groupService.createGroup(
        ownerId: 1,
        name: 'Test Group',
        memberIds: [2, 3],
      );

      expect(groupId, equals(100));
    });

    test('should return null when creation fails', () async {
      mockApiClient.adapter.onPost(
        '/chat/group/create',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/group/create'),
          ),
        ),
      );

      final groupId =
          await groupService.createGroup(ownerId: 1, name: 'Test Group');

      expect(groupId, isNull);
    });

    test('should return null when data is null', () async {
      mockApiClient.adapter.onPost(
        '/chat/group/create',
        (server) => server.reply(200, {'code': '200', 'data': null}),
      );

      final groupId =
          await groupService.createGroup(ownerId: 1, name: 'Test Group');

      expect(groupId, isNull);
    });

    test('should parse string group ID', () async {
      mockApiClient.adapter.onPost(
        '/chat/group/create',
        (server) => server.reply(200, {'code': '200', 'data': '200'}),
      );

      final groupId =
          await groupService.createGroup(ownerId: 1, name: 'Test Group');

      expect(groupId, equals(200));
    });
  });

  group('GroupService.getGroups', () {
    test('should return group list when request succeeds', () async {
      mockApiClient.adapter.onGet(
        '/chat/group/list',
        (server) => server.reply(200, {
          'code': '200',
          'data': [
            {'id': 1, 'name': 'Group A', 'ownerId': 1, 'avatar': ''},
            {'id': 2, 'name': 'Group B', 'ownerId': 2, 'avatar': ''},
          ],
        }),
      );

      final groups = await groupService.getGroups(1);

      expect(groups.length, equals(2));
      expect(groups[0].name, equals('Group A'));
      expect(groups[1].name, equals('Group B'));
    });

    test('should return empty list when request fails', () async {
      mockApiClient.adapter.onGet(
        '/chat/group/list',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/group/list'),
          ),
        ),
      );

      final groups = await groupService.getGroups(1);

      expect(groups, isEmpty);
    });
  });

  group('GroupService.getGroupMembers', () {
    test('should return member ID list', () async {
      mockApiClient.adapter.onGet(
        '/chat/group/members/1',
        (server) => server.reply(200, {
          'code': '200',
          'data': [
            {'userId': 1},
            {'userId': 2},
            {'userId': 3},
          ],
        }),
      );

      final members = await groupService.getGroupMembers(1);

      expect(members, equals([1, 2, 3]));
    });

    test('should return empty list when request fails', () async {
      mockApiClient.adapter.onGet(
        '/chat/group/members/1',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/group/members/1'),
          ),
        ),
      );

      final members = await groupService.getGroupMembers(1);

      expect(members, isEmpty);
    });
  });

  group('GroupService.getGroupDetail', () {
    test('should return group detail when request succeeds', () async {
      mockApiClient.adapter.onGet(
        '/chat/group/1',
        (server) => server.reply(200, {
          'code': '200',
          'data': {
            'id': 1,
            'name': 'My Group',
            'ownerId': 1,
            'avatar': 'avatar_url',
          },
        }),
      );

      final group = await groupService.getGroupDetail(1);

      expect(group, isNotNull);
      expect(group!.name, equals('My Group'));
      expect(group.ownerId, equals(1));
    });

    test('should return null when request fails', () async {
      mockApiClient.adapter.onGet(
        '/chat/group/1',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/group/1'),
          ),
        ),
      );

      final group = await groupService.getGroupDetail(1);

      expect(group, isNull);
    });

    test('should return null when data is null', () async {
      mockApiClient.adapter.onGet(
        '/chat/group/1',
        (server) => server.reply(200, {'code': '200', 'data': null}),
      );

      final group = await groupService.getGroupDetail(1);

      expect(group, isNull);
    });
  });

  group('GroupService.addMembers', () {
    test('should return true when add succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/group/members/add',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await groupService.addMembers(1, [2, 3]);

      expect(result, isTrue);
    });

    test('should return false when add fails', () async {
      mockApiClient.adapter.onPost(
        '/chat/group/members/add',
        (server) => server.throws(
          0,
          DioException(
            requestOptions:
                RequestOptions(path: '/chat/group/members/add'),
          ),
        ),
      );

      final result = await groupService.addMembers(1, [2, 3]);

      expect(result, isFalse);
    });
  });

  group('GroupService.removeMembers', () {
    test('should return true when remove succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/group/members/remove',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await groupService.removeMembers(1, [2]);

      expect(result, isTrue);
    });

    test('should return false when remove fails', () async {
      mockApiClient.adapter.onPost(
        '/chat/group/members/remove',
        (server) => server.throws(
          0,
          DioException(
            requestOptions:
                RequestOptions(path: '/chat/group/members/remove'),
          ),
        ),
      );

      final result = await groupService.removeMembers(1, [2]);

      expect(result, isFalse);
    });
  });
}
