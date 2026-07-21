import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/models/message_model.dart';
import 'package:snow_chat/services/chat_service.dart';

import '../helpers/mock_api_client.dart';

void main() {
  late MockApiClient mockApiClient;
  late ChatService chatService;

  setUp(() {
    mockApiClient = MockApiClient();
    chatService = ChatService(mockApiClient);
  });

  group('ChatService.getHistory', () {
    test('should return list of messages when request succeeds', () async {
      mockApiClient.adapter.onGet(
        '/chat/message/history',
        (server) => server.reply(200, {
          'code': '200',
          'data': [
            {
              'id': 1,
              'fromUserId': 10,
              'toUserId': 20,
              'content': 'Hello',
              'type': 'text',
              'createTime': 1700000000000,
            },
            {
              'id': 2,
              'fromUserId': 20,
              'toUserId': 10,
              'content': 'Hi there',
              'type': 'text',
              'createTime': 1700000001000,
            },
          ],
        }),
      );

      final messages = await chatService.getHistory(
        userId: 10,
        targetId: 20,
        targetType: 'friend',
        page: 1,
        size: 50,
      );

      expect(messages.length, equals(2));
      expect(messages[0].content, equals('Hello'));
      expect(messages[1].content, equals('Hi there'));
    });

    test('should return empty list when request fails', () async {
      mockApiClient.adapter.onGet(
        '/chat/message/history',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/message/history'),
          ),
        ),
      );

      final messages = await chatService.getHistory(userId: 10, targetId: 20);

      expect(messages, isEmpty);
    });

    test('should return empty list when data is null', () async {
      mockApiClient.adapter.onGet(
        '/chat/message/history',
        (server) => server.reply(200, {'code': '200', 'data': null}),
      );

      final messages = await chatService.getHistory(userId: 10, targetId: 20);

      expect(messages, isEmpty);
    });
  });

  group('ChatService.getHistoryByCursor', () {
    test('should return messages with cursor pagination', () async {
      mockApiClient.adapter.onGet(
        '/chat/message/history/cursor',
        (server) => server.reply(200, {
          'code': '200',
          'data': [
            {
              'id': 5,
              'content': 'Older message',
              'type': 'text',
              'createTime': 1700000000000,
            },
          ],
        }),
      );

      final messages = await chatService.getHistoryByCursor(
        userId: 10,
        targetId: 20,
        beforeMessageId: 10,
        size: 20,
      );

      expect(messages.length, equals(1));
      expect(messages[0].content, equals('Older message'));
    });
  });

  group('ChatService.sendMessage', () {
    test('should return true when send succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/message/send',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await chatService.sendMessage(
        MessageModel(
          id: 1,
          fromUserId: 10,
          toUserId: 20,
          content: 'Test',
          type: 'text',
          status: 'sent',
          createTime: 1700000000000,
        ),
      );

      expect(result, isTrue);
    });

    test('should return false when send fails', () async {
      mockApiClient.adapter.onPost(
        '/chat/message/send',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/message/send'),
          ),
        ),
      );

      final result = await chatService.sendMessage(
        MessageModel(
          id: 1,
          fromUserId: 10,
          toUserId: 20,
          content: 'Test',
          type: 'text',
          status: 'sent',
          createTime: 1700000000000,
        ),
      );

      expect(result, isFalse);
    });
  });

  group('ChatService.recallMessage', () {
    test('should return true when recall succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/message/recall',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await chatService.recallMessage(10, 100);

      expect(result, isTrue);
    });

    test('should return false when recall fails', () async {
      mockApiClient.adapter.onPost(
        '/chat/message/recall',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/message/recall'),
          ),
        ),
      );

      final result = await chatService.recallMessage(10, 100);

      expect(result, isFalse);
    });
  });

  group('ChatService.markAsRead', () {
    test('should return true when mark as read succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/message/read',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await chatService.markAsRead(10, 20, 'friend');

      expect(result, isTrue);
    });

    test('should return false when mark as read fails', () async {
      mockApiClient.adapter.onPost(
        '/chat/message/read',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/message/read'),
          ),
        ),
      );

      final result = await chatService.markAsRead(10, 20, 'friend');

      expect(result, isFalse);
    });
  });

  group('ChatService.sendReceipt', () {
    test('should return true when receipt succeeds', () async {
      mockApiClient.adapter.onPost(
        '/chat/message/receipt',
        (server) => server.reply(200, {'code': '200'}),
      );

      final result = await chatService.sendReceipt(100, 10, 20, 'friend');

      expect(result, isTrue);
    });

    test('should return false when receipt fails', () async {
      mockApiClient.adapter.onPost(
        '/chat/message/receipt',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/message/receipt'),
          ),
        ),
      );

      final result = await chatService.sendReceipt(100, 10, 20, 'friend');

      expect(result, isFalse);
    });
  });

  group('ChatService.fetchUndelivered', () {
    test('should return undelivered messages', () async {
      mockApiClient.adapter.onPost(
        '/chat/message/undelivered',
        (server) => server.reply(200, {
          'code': '200',
          'data': [
            {
              'id': 3,
              'content': 'Undelivered msg',
              'type': 'text',
              'createTime': 1700000000000,
            },
          ],
        }),
      );

      final messages = await chatService.fetchUndelivered(10, 20, 'friend');

      expect(messages.length, equals(1));
      expect(messages[0].content, equals('Undelivered msg'));
    });

    test('should return empty list when request fails', () async {
      mockApiClient.adapter.onPost(
        '/chat/message/undelivered',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/chat/message/undelivered'),
          ),
        ),
      );

      final messages = await chatService.fetchUndelivered(10, 20, 'friend');

      expect(messages, isEmpty);
    });
  });
}
