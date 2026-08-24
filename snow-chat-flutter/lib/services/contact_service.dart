import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../core/database/tables.dart';
import '../core/network/api_client.dart';
import '../models/friend_model.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ContactService {
  final ApiClient apiClient;

  ContactService(this.apiClient);

  /// 从 Provider 获取当前用户ID
  int _getUserId(BuildContext context) {
    return context.read<AuthProvider>().userId ?? 0;
  }

  Future<List<FriendModel>> getFriends(int userId) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/friend/list',
        queryParameters: {'userId': userId},
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => FriendModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    } catch (e) {
      debugPrint('getFriends failed: $e');
      return [];
    }
  }

  /// 从本地 SQLite 读取好友列表（用于快速展示）
  Future<List<FriendModel>> getLocalFriends(BuildContext context) async {
    final userId = _getUserId(context);
    final db = await DatabaseHelper().database;
    final table = Tables.friendsTable(userId);
    final rows = await db.query(table, orderBy: 'nickname ASC');
    return rows.map((row) {
      return FriendModel(
        userId: row['user_id'] as int,
        nickname: row['nickname'] as String? ?? '',
        avatar: row['avatar'] as String? ?? '',
        remark: row['remark'] as String? ?? '',
        status: 'offline',
      );
    }).toList();
  }

  /// 全量保存好友列表到本地 SQLite
  Future<void> saveLocalFriends(BuildContext context, List<FriendModel> friends) async {
    final userId = _getUserId(context);
    final db = await DatabaseHelper().database;
    final table = Tables.friendsTable(userId);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete(table);
      for (final f in friends) {
        await txn.insert(
          table,
          {
            'user_id': f.userId,
            'nickname': f.nickname,
            'avatar': f.avatar,
            'remark': f.remark,
            'update_time': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
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

  /// 发送好友请求，返回 {success, message}
  /// success=false 时 message 包含后端返回的具体原因（如"已发送过好友请求"）
  Future<Map<String, dynamic>> sendFriendRequest(int fromUserId, int toUserId, String remark) async {
    try {
      final response = await apiClient.dio.post(
        '/chat/friend/request',
        data: {'fromUserId': fromUserId, 'toUserId': toUserId, 'remark': remark},
      );
      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String?;
      if (code == '200') {
        return {'success': true, 'message': ''};
      }
      // 业务失败：返回后端 msg 字段作为错误信息
      return {'success': false, 'message': data['msg'] as String? ?? '发送失败'};
    } on DioException catch (e) {
      return {'success': false, 'message': '网络错误: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': '发送失败: $e'};
    }
  }

  /// 处理好友请求（接受/拒绝），返回 {success, message}
  Future<Map<String, dynamic>> handleFriendRequest(int fromUserId, int toUserId, bool accept) async {
    try {
      final response = await apiClient.dio.post(
        '/chat/friend/handle',
        data: {'fromUserId': fromUserId, 'toUserId': toUserId, 'accept': accept},
      );
      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String?;
      if (code == '200') {
        return {'success': true, 'message': ''};
      }
      return {'success': false, 'message': data['msg'] as String? ?? '操作失败'};
    } on DioException catch (e) {
      return {'success': false, 'message': '网络错误: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': '操作失败: $e'};
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
      final response = await apiClient.dio.delete('/chat/friend/$userId/$friendId');
      final code = response.data['code'] as String?;
      return code == '200';
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
