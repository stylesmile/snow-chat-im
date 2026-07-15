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
    _lastError = null;
    try {
      final result = await _apiClient.request('/chat/user/login', data: {
        'username': username,
        'password': password,
      });

      // 后端返回 code 为字符串 "200"
      final code = result['code'];
      if (code == '200' || code == 200) {
        final data = result['data'];
        if (data == null) {
          _lastError = '登录成功但返回数据为空';
          return false;
        }
        _userId = _parseInt(data['id']);
        _username = data['username'] as String?;
        _nickname = data['nickname'] as String?;
        _avatar = data['avatar'] as String?;
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }

      // 登录失败，保存后端返回的错误信息
      _lastError = result['msg'] as String? ?? '登录失败 (code: $code)';
      return false;
    } on Exception catch (e) {
      _lastError = '网络错误: $e';
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

      final code = result['code'];
      if (code == '200' || code == 200) {
        final data = result['data'];
        if (data == null) {
          _lastError = '注册成功但返回数据为空';
          return false;
        }
        _userId = _parseInt(data['id']);
        _username = data['username'] as String?;
        _nickname = data['nickname'] as String?;
        _avatar = data['avatar'] as String?;
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }
      _lastError = result['msg'] as String? ?? '注册失败 (code: $code)';
      return false;
    } on Exception catch (e) {
      _lastError = '网络错误: $e';
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

  /// 安全解析 int，支持 int/double/String 类型
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
