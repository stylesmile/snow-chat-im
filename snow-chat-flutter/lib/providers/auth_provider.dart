import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/database/database_helper.dart';

/// 认证状态提供者
///
/// 管理用户登录状态、token 及用户信息，持久化到 SharedPreferences。
class AuthProvider extends ChangeNotifier {
  final String baseUrl;
  late final ApiClient _apiClient;

  int? _userId;
  String? _username;
  String? _nickname;
  String? _avatar;
  bool _isLoggedIn = false;
  String? _token; // JWT token
  String? _lastError;

  AuthProvider(this.baseUrl) {
    _apiClient = ApiClient(baseUrl);
  }

  /// 从本地存储恢复登录状态，应在 main() 中 await 调用。
  Future<void> init() async {
    await _loadAuthState();
  }

  int? get userId => _userId;
  String? get username => _username;
  String? get nickname => _nickname;
  String? get avatar => _avatar;
  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
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
        final data = result['data'] as Map<String, dynamic>? ?? {};
        if (data.isEmpty) {
          _lastError = '登录成功但返回数据为空';
          return false;
        }
        // 保存 token
        _token = data['token'] as String?;
        if (_token != null) {
          _apiClient.token = _token; // 同步到 ApiClient，后续请求自动携带
        }
        // 保存用户信息（可能嵌套在 user 字段中）
        final userData = data['user'] as Map<String, dynamic>? ?? data;
        _userId = _parseInt(userData['id']);
        _username = userData['username'] as String?;
        _nickname = userData['nickname'] as String?;
        _avatar = userData['avatar'] as String?;
        _isLoggedIn = true;
        await _saveAuthState();
        // 确保当前用户的数据库表已创建
        if (_userId != null) {
          await DatabaseHelper().ensureUserTables(_userId!);
        }
        notifyListeners();
        return true;
      }

      _lastError = result['msg'] as String? ?? '登录失败 (code: $code)';
      return false;
    } on Exception catch (e) {
      _lastError = '网络错误: $e';
      if (kDebugMode) print('Login error: $e');
      return false;
    }
  }

  /// 注册新用户（需邮箱验证码校验）
  /// POST /chat/user/register  body: {username, password, nickname, email, code}
  Future<bool> register(
    String username,
    String password,
    String nickname,
    String email,
    String code,
  ) async {
    _lastError = null;
    try {
      final result = await _apiClient.request('/chat/user/register', data: {
        'username': username,
        'password': password,
        'nickname': nickname,
        'email': email,
        'code': code,
      });

      final codeVal = result['code'];
      if (codeVal == '200' || codeVal == 200) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        if (data.isEmpty) {
          _lastError = '注册成功但返回数据为空';
          return false;
        }
        // 注册成功后直接登录，保存 token
        _token = data['token'] as String?;
        if (_token != null) {
          _apiClient.token = _token;
        }
        final userData = data['user'] as Map<String, dynamic>? ?? data;
        _userId = _parseInt(userData['id']);
        _username = userData['username'] as String?;
        _nickname = userData['nickname'] as String?;
        _avatar = userData['avatar'] as String?;
        _isLoggedIn = true;
        await _saveAuthState();
        // 确保当前用户的数据库表已创建
        if (_userId != null) {
          await DatabaseHelper().ensureUserTables(_userId!);
        }
        notifyListeners();
        return true;
      }
      _lastError = result['msg'] as String? ?? '注册失败 (code: $codeVal)';
      return false;
    } on Exception catch (e) {
      _lastError = '网络错误: $e';
      if (kDebugMode) print('Register error: $e');
      return false;
    }
  }

  /// 仅校验邮箱验证码是否有效（步骤1，不消耗验证码）
  Future<bool> verifyRegisterCode(String email, String code) async {
    _lastError = null;
    try {
      final result = await _apiClient.request('/chat/user/verify/code', data: {
        'email': email,
        'code': code,
        'type': 'register',
      });
      final data = result['data'];
      if (data is bool) return data;
      final codeVal = result['code'];
      return codeVal == '200' || codeVal == 200;
    } on Exception catch (e) {
      _lastError = '网络错误: $e';
      if (kDebugMode) print('Verify code error: $e');
      return false;
    }
  }

  /// 发送邮箱验证码
  Future<bool> sendVerificationCode(String email, String type) async {
    _lastError = null;
    try {
      final result = await _apiClient.request(
        '/chat/user/send/email/code',
        query: {'email': email, 'type': type},
      );
      final codeVal = result['code'];
      return codeVal == '200' || codeVal == 200;
    } on Exception catch (e) {
      _lastError = '网络错误: $e';
      if (kDebugMode) print('Send code error: $e');
      return false;
    }
  }

  /// 通过邮箱+验证码重置密码
  Future<bool> resetPassword(String email, String code, String newPassword) async {
    _lastError = null;
    try {
      final result = await _apiClient.request('/chat/user/reset/password', data: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });
      final codeVal = result['code'];
      return codeVal == '200' || codeVal == 200;
    } on Exception catch (e) {
      _lastError = '网络错误: $e';
      if (kDebugMode) print('Reset password error: $e');
      return false;
    }
  }

  /// 退出登录：清除所有状态并通知订阅者
  Future<void> logout() async {
    _userId = null;
    _username = null;
    _nickname = null;
    _avatar = null;
    _token = null;
    _apiClient.token = null;
    _isLoggedIn = false;
    _lastError = null;
    await _clearAuthState();
    notifyListeners();
  }

  /// 更新头像并持久化
  Future<void> updateAvatar(String newAvatarUrl) async {
    _avatar = newAvatarUrl;
    await _saveAuthState();
    notifyListeners();
  }

  /// 更新昵称并持久化
  Future<void> updateNickname(String newNickname) async {
    _nickname = newNickname;
    await _saveAuthState();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // 持久化方法
  // -------------------------------------------------------------------------

  Future<void> _saveAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', _userId ?? 0);
    await prefs.setString('username', _username ?? '');
    await prefs.setString('nickname', _nickname ?? '');
    await prefs.setString('avatar', _avatar ?? '');
    await prefs.setString('token', _token ?? '');
    await prefs.setBool('isLoggedIn', _isLoggedIn);
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      _userId = prefs.getInt('userId');
      _username = prefs.getString('username');
      _nickname = prefs.getString('nickname');
      _avatar = prefs.getString('avatar');
      _token = prefs.getString('token');
      if (_token != null && _token!.isNotEmpty) {
        _apiClient.token = _token;
      }
      _isLoggedIn = true;
      // 确保已登录用户的数据库表已创建
      if (_userId != null) {
        await DatabaseHelper().ensureUserTables(_userId!);
      }
      notifyListeners();
    }
  }

  Future<void> _clearAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('nickname');
    await prefs.remove('avatar');
    await prefs.remove('token');
    await prefs.remove('isLoggedIn');
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
