import 'package:dio/dio.dart';
import '../core/network/api_client.dart';

class ProfileService {
  final ApiClient apiClient;

  ProfileService(this.apiClient);

  Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    try {
      final response =
          await apiClient.dio.get('/chat/user/info/$userId');
      return response.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateProfile(int userId,
      {String? nickname, String? avatar, String? signature}) async {
    try {
      await apiClient.dio.put('/chat/user/profile', data: {
        'userId': userId,
        'nickname': nickname,
        'avatar': avatar,
        'signature': signature,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
