import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/database/database_helper.dart';
import '../core/cache/message_cache_manager.dart';

/// 认证状态提供者
///
/// 管理用户登录状态、token 及用户信息，持久化到 SharedPreferences。
class AuthProvider extends ChangeNotifier {
  /// 头像 storage key 的目录前缀。
  ///
  /// `chat_user.avatar` 存的是对象存储 key（如 `avatars/uuid.jpg`）而非可直接加载的
  /// 地址，后端据此前缀判断是否需要实时转换成 URL（见 `GET /chat/user/info`）。
  static const String _avatarKeyPrefix = 'avatars/';

  final String baseUrl;
  late final ApiClient _apiClient;

  int? _userId;
  String? _username;
  String? _nickname;
  String? _avatar;
  int? _gender; // 0=未设置, 1=男, 2=女
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
  /// 返回性别值：0=未设置, 1=男, 2=女；null 表示数据尚未加载
  int? get gender => _gender;
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
        if (_userId == null || _userId! <= 0) {
          _lastError = '注册响应数据异常：用户ID无效';
          return false;
        }
        _username = userData['username'] as String?;
        _nickname = userData['nickname'] as String?;
        _avatar = userData['avatar'] as String?;
        // 从后端响应中解析性别字段（可能为 int 或 String 类型）
        _gender = _parseGender(userData['gender']);
        _isLoggedIn = true;
        // 头像在库里存的是 storage key，先换成可访问 URL 再持久化
        await resolveAvatarUrlFromBackend();
        await _saveAuthState();
        // 确保当前用户的数据库表已创建
        if (_userId != null) {
          await DatabaseHelper().ensureUserTables(_userId!);
          // 同步设置消息缓存管理器用户ID，否则聊天页初始化时会抛出 StateError 导致 spinner 永不停止
          MessageCacheManager().setUserId(_userId!);
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
        // 从后端响应中解析性别字段（可能为 int 或 String 类型）
        _gender = _parseGender(userData['gender']);
        _isLoggedIn = true;
        // 头像在库里存的是 storage key，先换成可访问 URL 再持久化
        await resolveAvatarUrlFromBackend();
        await _saveAuthState();
        // 确保当前用户的数据库表已创建
        if (_userId != null) {
          await DatabaseHelper().ensureUserTables(_userId!);
          // 同步设置消息缓存管理器用户ID，否则聊天页初始化时会抛出 StateError 导致 spinner 永不停止
          MessageCacheManager().setUserId(_userId!);
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
    // 清空消息缓存用户ID，避免下一个用户读取上一个用户的数据
    MessageCacheManager().setUserId(0);
    notifyListeners();
  }

  /// 更新头像并持久化
  Future<void> updateAvatar(String newAvatarUrl) async {
    _avatar = newAvatarUrl;
    await _saveAuthState();
    notifyListeners();
  }

  /// 头像若仍是对象存储 key（`avatars/...`），向后端换取可访问 URL 并持久化。
  ///
  /// 后端把头像的 storage key 存进 `chat_user.avatar`，只有 `GET /chat/user/info`
  /// 会按存储访问策略把它转成可访问地址（公共读为直链、私有读为带签名的临时链接、
  /// 本地开发用 InMemory 时为 base64 data URL）；登录/注册接口返回的是库里的原始
  /// key。若不在登录后补一次转换，key 会被 `AvatarWidget` 当成网络地址去加载并失败，
  /// 最终回落成首字母占位 —— 用户看到的现象就是「上传头像后重新登录，头像不显示了」。
  ///
  /// 头像已是 URL（`http...` / `data:image...`）或为空时直接返回，不发请求。
  /// 转换失败时保留 key：不影响登录，下次启动/登录会重试。
  @visibleForTesting
  Future<void> resolveAvatarUrlFromBackend() async {
    final avatar = _avatar;
    if (avatar == null || !avatar.startsWith(_avatarKeyPrefix)) return;
    try {
      final response = await _apiClient.dio.get('/chat/user/info');
      final data = response.data['data'] as Map<String, dynamic>?;
      final url = data?['avatar'] as String?;
      if (url == null || url.isEmpty) return;
      _avatar = url;
      await _saveAuthState();
    } on Exception catch (e) {
      if (kDebugMode) print('[AuthProvider] resolve avatar url failed: $e');
    }
  }

  /// 更新昵称并持久化
  Future<void> updateNickname(String newNickname) async {
    _nickname = newNickname;
    await _saveAuthState();
    notifyListeners();
  }

  /// 更新性别并提交到后端
  ///
  /// [genderValue]：0=未设置, 1=男, 2=女
  /// 调用 PUT /chat/user/profile 接口，将性别保存到后端数据库。
  Future<void> setGender(int genderValue) async {
    _gender = genderValue;
    await _saveAuthState();
    notifyListeners();
    // 同步提交到后端，避免离线时丢失性别变更
    try {
      await _apiClient.request('/chat/user/update', data: {
        'gender': genderValue,
      });
    } catch (e) {
      if (kDebugMode) print('[AuthProvider] setGender failed: $e');
    }
  }

  /// 安全解析性别值，支持 int/double/String/null 类型
  /// 返回 0=未设置, 1=男, 2=女；非法值返回 null（保持原有性别状态）
  static int? _parseGender(dynamic value) {
    if (value == null) return null;
    if (value is int) return value >= 0 && value <= 2 ? value : null;
    if (value is double) {
      final intResult = value.toInt();
      return intResult >= 0 && intResult <= 2 ? intResult : null;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      return (parsed != null && parsed >= 0 && parsed <= 2) ? parsed : null;
    }
    return null;
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
    // 性别以字符串形式存储（"0"/"1"/"2"/""）
    // 非 null 且 >= 0 时写入，否则写空字符串表示未设置
    await prefs.setString('gender', (_gender != null && _gender! >= 0) ? '$_gender' : '');
    await prefs.setString('token', _token ?? '');
    await prefs.setBool('isLoggedIn', _isLoggedIn);
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      // 校验 userId 有效性：负值说明 SharedPreferences 数据损坏，清除后重新登录
      final rawUserId = prefs.getInt('userId');
      if (rawUserId != null && rawUserId <= 0) {
        await _clearAuthState();
        notifyListeners();
        return;
      }
      _userId = rawUserId;
      _username = prefs.getString('username');
      _nickname = prefs.getString('nickname');
      _avatar = prefs.getString('avatar');
      // 从本地缓存恢复性别（空字符串表示未设置，对应值 0）
      final genderStr = prefs.getString('gender') ?? '';
      _gender = genderStr.isEmpty ? null : int.tryParse(genderStr);
      _token = prefs.getString('token');
      if (_token != null && _token!.isNotEmpty) {
        _apiClient.token = _token;
      }
      _isLoggedIn = true;
      // 本地缓存若残留 storage key（如上次转换失败时落盘），启动时补一次转换
      // 已是 URL 或没有头像时本方法会直接返回，不产生额外请求
      await resolveAvatarUrlFromBackend();
      // 确保已登录用户的数据库表已创建
      if (_userId != null && _userId! > 0) {
        await DatabaseHelper().ensureUserTables(_userId!);
        // 同步设置消息缓存管理器用户ID，否则聊天页初始化时会抛出 StateError 导致 spinner 永不停止
        MessageCacheManager().setUserId(_userId!);
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
    await prefs.remove('gender');
    await prefs.remove('token');
    await prefs.remove('isLoggedIn');
  }

  /// 安全解析 int，支持 int/double/String 类型
  /// 额外校验：确保返回正值，负值说明数据异常（如 SharedPreferences 损坏或后端返回异常）
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value > 0 ? value : null;
    if (value is double) {
      final intResult = value.toInt();
      return intResult > 0 ? intResult : null;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      return (parsed != null && parsed > 0) ? parsed : null;
    }
    return null;
  }
}
