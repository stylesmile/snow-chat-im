import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/friend_model.dart';

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

  /// 发送好友请求
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

  /// 处理好友请求（接受/拒绝）
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

  /// 获取收到的待处理好友请求
  Future<List<FriendRequest>> getReceivedRequests(int toUserId) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/friend/pending',
        queryParameters: {'toUserId': toUserId},
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => FriendRequest.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  /// 获取已发送的待处理好友请求
  Future<List<FriendRequest>> getSentRequests(int fromUserId) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/friend/sent',
        queryParameters: {'fromUserId': fromUserId},
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => FriendRequest.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  /// 删除好友
  Future<bool> deleteFriend(int userId, int friendId) async {
    try {
      await apiClient.dio.delete('/chat/friend/$userId/$friendId');
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// 好友搜索结果
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

/// 好友请求
class FriendRequest {
  final int id;
  final int fromUserId;
  final int toUserId;
  final String status;
  final String remark;
  final String fromNickname;
  final String fromAvatar;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    this.remark = '',
    this.fromNickname = '',
    this.fromAvatar = '',
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as int? ?? 0,
      fromUserId: json['fromUserId'] as int? ?? json['from_user_id'] as int? ?? 0,
      toUserId: json['toUserId'] as int? ?? json['to_user_id'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      remark: json['remark'] as String? ?? '',
      fromNickname: json['fromNickname'] as String? ?? json['from_nickname'] as String? ?? '',
      fromAvatar: json['fromAvatar'] as String? ?? json['from_avatar'] as String? ?? '',
    );
  }
}
