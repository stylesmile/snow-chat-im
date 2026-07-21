import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/group_model.dart';

class GroupService {
  final ApiClient apiClient;

  GroupService(this.apiClient);

  /// 创建群组
  Future<int?> createGroup({
    required int ownerId,
    required String name,
    String avatar = '',
    List<int>? memberIds,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/chat/group/create',
        data: {
          'ownerId': ownerId,
          'name': name,
          'avatar': avatar,
          'maxMembers': 500,
          'memberIds': memberIds?.join(','),
        },
      );
      final data = response.data['data'];
      if (data != null) {
        return data is int ? data : int.tryParse(data.toString());
      }
      return null;
    } catch (e) {
      debugPrint('createGroup failed: $e');
      return null;
    }
  }

  /// 获取用户所在群组列表
  Future<List<GroupModel>> getGroups(int userId) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/group/list',
        queryParameters: {'userId': userId},
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => GroupModel.fromJson(e)).toList() ?? [];
    } catch (e) {
      debugPrint('getGroups failed: $e');
      return [];
    }
  }

  /// 获取群组成员列表
  Future<List<int>> getGroupMembers(int groupId) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/group/members/$groupId',
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => e['userId'] as int? ?? 0).toList() ?? [];
    } catch (e) {
      debugPrint('getGroupMembers failed: $e');
      return [];
    }
  }

  /// 获取群组详情
  Future<GroupModel?> getGroupDetail(int groupId) async {
    try {
      final response = await apiClient.dio.get('/chat/group/$groupId');
      final data = response.data['data'];
      if (data != null) {
        return GroupModel.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('getGroupDetail failed: $e');
      return null;
    }
  }

  /// 添加群成员
  Future<bool> addMembers(int groupId, List<int> userIds) async {
    try {
      await apiClient.dio.post(
        '/chat/group/members/add',
        data: {'groupId': groupId, 'userIds': userIds},
      );
      return true;
    } catch (e) {
      debugPrint('addMembers failed: $e');
      return false;
    }
  }

  /// 移除群成员
  Future<bool> removeMembers(int groupId, List<int> userIds) async {
    try {
      await apiClient.dio.post(
        '/chat/group/members/remove',
        data: {'groupId': groupId, 'userIds': userIds},
      );
      return true;
    } catch (e) {
      debugPrint('removeMembers failed: $e');
      return false;
    }
  }
}
