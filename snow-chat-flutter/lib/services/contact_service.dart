import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/friend_model.dart';

class ContactService {
  final ApiClient apiClient;

  ContactService(this.apiClient);

  Future<List<FriendModel>> getFriends(int userId) async {
    try {
      final response =
          await apiClient.dio.get('/chat/friend/list',
              queryParameters: {'userId': userId});
      final data = response.data['data'] as List?;
      return data?.map((e) => FriendModel.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> sendFriendRequest(
      int fromUserId, int toUserId, String remark) async {
    try {
      await apiClient.dio.post('/chat/friend/request', data: {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'remark': remark,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> handleFriendRequest(
      int fromUserId, int toUserId, bool accept) async {
    try {
      await apiClient.dio.post('/chat/friend/handle', data: {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'accept': accept,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
