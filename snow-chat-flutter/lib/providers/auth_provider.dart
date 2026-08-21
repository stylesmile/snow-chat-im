import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// 从本地存储恢复登录状态，应在 main() 中 await 调用。
  Future<void> init() async {
    await _loadAuthState();
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
        await _saveAuthState();
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
        await _saveAuthState();
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
  /// 调用 POST /chat/user/verify/code，验证通过后可重新发送
  Future<bool> verifyRegisterCode(String email, String code) async {
    _lastError = null;
    try {
      final result = await _apiClient.request('/chat/user/verify/code', data: {
        'email': email,
        'code': code,
        'type': 'register',
      });
      // 后端直接返回 boolean，Result 包装可能不同，取 data 字段
      final data = result['data'];
      if (data is bool) return data;
      // 兼容旧格式：code == '200'
      final codeVal = result['code'];
      return codeVal == '200' || codeVal == 200;
    } on Exception catch (e) {
      _lastError = '网络错误: $e';
      if (kDebugMode) print('Verify code error: $e');
      return false;
    }
  }

  /// 发送邮箱验证码
  /// POST /chat/user/send/email/code?email=&type=
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
  /// POST /chat/user/reset/password  body: {email, code, newPassword}
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

  Future<void> logout() async {
    _userId = null;
    _username = null;
    _nickname = null;
    _avatar = null;
    _isLoggedIn = false;
    _lastError = null;
    await _clearAuthState();
    notifyListeners();
  }

  /// 更新头像并持久化。
  Future<void> updateAvatar(String newAvatarUrl) async {
    _avatar = newAvatarUrl;
    await _saveAuthState();
    notifyListeners();
  }

  /// 更新昵称并持久化。
  Future<void> updateNickname(String newNickname) async {
    _nickname = newNickname;
    await _saveAuthState();
    notifyListeners();
  }

  /// 持久化登录状态到 SharedPreferences
  Future<void> _saveAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', _userId ?? 0);
    await prefs.setString('username', _username ?? '');
    await prefs.setString('nickname', _nickname ?? '');
    await prefs.setString('avatar', _avatar ?? '');
    await prefs.setBool('isLoggedIn', _isLoggedIn);
  }

  /// 从 SharedPreferences 恢复登录状态
  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      _userId = prefs.getInt('userId');
      _username = prefs.getString('username');
      _nickname = prefs.getString('nickname');
      _avatar = prefs.getString('avatar');
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  /// 清除本地持久化的登录状态
  Future<void> _clearAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('nickname');
    await prefs.remove('avatar');
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
