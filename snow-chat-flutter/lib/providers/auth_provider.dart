import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final String baseUrl;
  late final ApiClient _apiClient;

  int? _userId;
  String? _username;
  String? _nickname;
  String? _avatar;
  bool _isLoggedIn = false;
  String? _lastError;

  AuthProvider(this.baseUrl) {
    _apiClient = ApiClient(baseUrl);
  }

  int? get userId => _userId;
  String? get username => _username;
  String? get nickname => _nickname;
  String? get avatar => _avatar;
  bool get isLoggedIn => _isLoggedIn;
  String? get lastError => _lastError;
  ApiClient get apiClient => _apiClient;

  Future<bool> login(String username, String password) async {
    try {
      final result = await _apiClient.request('/chat/user/login', data: {
        'username': username,
        'password': password,
      });

      if (result['code'] == '200' || result['code'] == 200) {
        final data = result['data'];
        _userId = data['id'] as int?;
        _username = data['username'] as String?;
        _nickname = data['nickname'] as String?;
        _avatar = data['avatar'] as String?;
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('Login error: $e');
      return false;
    }
  }

  Future<bool> register(String username, String password, String nickname, String email) async {
    _lastError = null;
    try {
      final result = await _apiClient.request('/chat/user/register', data: {
        'username': username,
        'password': password,
        'nickname': nickname,
        'email': email,
      });

      if (result['code'] == '200' || result['code'] == 200) {
        final data = result['data'];
        _userId = data['id'] as int?;
        _username = data['username'] as String?;
        _nickname = data['nickname'] as String?;
        _avatar = data['avatar'] as String?;
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }
      _lastError = result['msg'] as String? ?? 'Registration failed';
      return false;
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) print('Register error: $e');
      return false;
    }
  }

  void logout() {
    _userId = null;
    _username = null;
    _nickname = null;
    _avatar = null;
    _isLoggedIn = false;
    _lastError = null;
    notifyListeners();
  }
}
