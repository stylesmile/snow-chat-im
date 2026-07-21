import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/message_model.dart';

class ChatService {
  final ApiClient apiClient;

  ChatService(this.apiClient);

  /// 获取历史消息（分页）
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

  /// 获取历史消息（游标分页，用于滚动加载更多）
  Future<List<MessageModel>> getHistoryByCursor({
    required int userId,
    required int targetId,
    String targetType = 'friend',
    int? beforeMessageId,
    int size = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/message/history/cursor',
        queryParameters: {
          'userId': userId,
          'targetId': targetId,
          'targetType': targetType,
          if (beforeMessageId != null) 'beforeMessageId': beforeMessageId,
          'size': size,
        },
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => MessageModel.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  /// 发送消息（REST fallback）
  Future<bool> sendMessage(MessageModel message) async {
    try {
      await apiClient.dio.post('/chat/message/send', data: message.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 撤回消息
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

  /// 标记消息为已读
  Future<bool> markAsRead(int userId, int targetId, String targetType) async {
    try {
      await apiClient.dio.post(
        '/chat/message/read',
        data: {'userId': userId, 'targetId': targetId, 'targetType': targetType},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 发送消息回执：接收方确认收到消息
  Future<bool> sendReceipt(int messageId, int userId, int targetId, String targetType) async {
    try {
      await apiClient.dio.post(
        '/chat/message/receipt',
        data: {
          'messageId': messageId,
          'userId': userId,
          'targetId': targetId,
          'targetType': targetType,
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 请求服务器推送未推送成功的消息
  Future<List<MessageModel>> fetchUndelivered(int userId, int targetId, String targetType) async {
    try {
      final response = await apiClient.dio.post(
        '/chat/message/undelivered',
        data: {
          'userId': userId,
          'targetId': targetId,
          'targetType': targetType,
        },
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => MessageModel.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }
}
