import 'package:dio/dio.dart';
import '../models/friend_model.dart';
import '../core/network/api_client.dart';

class ContactService {
  final ApiClient apiClient;

  ContactService(this.apiClient);

  Future<List<FriendModel>> getFriends(int userId) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/friend/list',
        queryParameters: {'userId': userId},
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => FriendModel.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<List<UserSearchResult>> searchUsers(String keyword, {int page = 1, int size = 10}) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/user/search',
        queryParameters: {'keyword': keyword, 'page': page, 'size': size},
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => UserSearchResult.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> sendFriendRequest(int fromUserId, int toUserId, String remark) async {
    try {
      await apiClient.dio.post(
        '/chat/friend/request',
        data: {'fromUserId': fromUserId, 'toUserId': toUserId, 'remark': remark},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> handleFriendRequest(int fromUserId, int toUserId, bool accept) async {
    try {
      await apiClient.dio.post(
        '/chat/friend/handle',
        data: {'fromUserId': fromUserId, 'toUserId': toUserId, 'accept': accept},
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

class UserSearchResult {
  final int id;
  final String username;
  final String nickname;
  final String avatar;

  UserSearchResult({
    required this.id,
    required this.username,
    required this.nickname,
    this.avatar = '',
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
    );
  }
}
