import 'package:dio/dio.dart';
import '../core/network/api_client.dart';

class AuthService {
  final ApiClient apiClient;

  AuthService(this.apiClient);

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await apiClient.dio.post(
        '/chat/user/login',
        data: {'username': username, 'password': password},
      );
      return response.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    apiClient.token = null;
  }
}
