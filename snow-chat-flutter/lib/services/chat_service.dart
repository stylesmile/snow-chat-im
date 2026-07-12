import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/message_model.dart';

class ChatService {
  final ApiClient apiClient;

  ChatService(this.apiClient);

  Future<List<MessageModel>> getHistory({
    required int userId,
    required int targetId,
    String targetType = 'friend',
    int page = 1,
    int size = 50,
  }) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/message/history',
        queryParameters: {
          'userId': userId,
          'targetId': targetId,
          'targetType': targetType,
          'page': page,
          'size': size,
        },
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => MessageModel.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> sendMessage(MessageModel message) async {
    try {
      await apiClient.dio.post('/chat/message/send', data: message.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> recallMessage(int userId, int messageId) async {
    try {
      await apiClient.dio.post(
        '/chat/message/recall',
        data: {'userId': userId, 'messageId': messageId},
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
