import 'dart:io';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/upload_result.dart';

/// 个人资料服务
///
/// 提供用户资料查询、更新，以及头像上传能力。
/// - [getUserProfile] / [refreshProfile]：查询用户资料（refreshProfile 为语义包装，用于刷新场景）
/// - [updateProfile]：更新昵称/头像/签名（JSON body）
/// - [uploadAvatar]：上传头像文件到对象存储，返回 {key, url}
/// - [fetchAvatarUrl]：取当前登录用户头像的可访问 URL（key 由后端转 URL）
class ProfileService {
  final ApiClient apiClient;

  ProfileService(this.apiClient);

  /// 查询用户资料
  ///
  /// 返回后端 Result.data 字段（Map）；失败或 data 为 null 时返回 null。
  Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    try {
      final response = await apiClient.dio.get('/chat/user/info/$userId');
      return response.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// 刷新用户资料（语义包装，等价于 [getUserProfile]）。
  ///
  /// 命名意图：在头像上传成功后或下拉刷新时调用，强调"重新拉取最新资料"。
  Future<Map<String, dynamic>?> refreshProfile(int userId) async {
    return getUserProfile(userId);
  }

  /// 更新个人资料
  ///
  /// 向 `PUT /chat/user/update` 发送 JSON body（与后端 @RequestBody UpdateProfileDTO 对齐）。
  ///
  /// ⚠️ 此前请求的是 `/chat/user/profile`——后端**根本没有这个端点**，
  /// 于是任何资料修改都静默失败（接口返回 404，被 catch 吞成 false）。
  /// 后端实际路径是 `/chat/user/update`。
  ///
  /// 任意字段为 null 表示不更新该字段。成功返回 true，失败返回 false。
  Future<bool> updateProfile(
    int userId, {
    String? nickname,
    String? username,
    String? avatar,
    String? signature,
    int? gender,
  }) async {
    try {
      final response = await apiClient.dio.put('/chat/user/update', data: {
        'userId': userId,
        'nickname': nickname,
        'username': username,
        'avatar': avatar,
        'signature': signature,
        'gender': gender,
      });
      // 后端统一返回 code='200' 表示成功
      return response.data?['code'] == '200' || response.data?['code'] == 200;
    } catch (e) {
      print('[ProfileService] updateProfile failed: $e');
      return false;
    }
  }

  /// 上传头像文件
  ///
  /// 调用 `POST /chat/user/avatar/upload`：后端除了把文件写入对象存储
  /// （key 形如 `avatars/{uuid}.{ext}`），还会把该 key **持久化到
  /// `chat_user.avatar` 字段**，并返回 {key, url}。
  ///
  /// 注意不要改用 `POST /file/avatar`：那个端点只上传、不落库，一旦用户
  /// 重新登录（本地登录态被后端返回值覆盖）头像就会丢失。
  ///
  /// [url] 可直接用于前端头像展示；[key] 为库中持久化的值。
  Future<UploadResult?> uploadAvatar(File imageFile) async {
    try {
      // 读取文件字节
      final bytes = await imageFile.readAsBytes();
      // 构造 multipart 表单：字段名 file，文件名取原始路径末段
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      // 发送 POST 请求到「上传头像并落库」接口
      // 注意：必须显式设置 Options(contentType) 覆盖全局 application/json header，
      // 否则 multipart 边界会被破坏导致上传失败
      final response = await apiClient.dio.post(
        '/chat/user/avatar/upload',
        data: formData,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      // 解析响应：{code: '200', data: {key, url}}
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) {
        return null;
      }
      return UploadResult.fromJson(data);
    } catch (e) {
      // 输出详细错误信息，便于排查上传失败原因
      print('[ProfileService] uploadAvatar failed: $e');
      return null;
    }
  }

  /// 获取当前登录用户头像的可访问 URL
  ///
  /// `chat_user.avatar` 存的是对象存储 key（如 `avatars/uuid.jpg`），不是可直接
  /// 加载的地址。后端只有 `GET /chat/user/info` 会把 key 转换成 URL（公共读为直链、
  /// 私有读为带签名链接），登录/注册接口返回的是库里的原始 key，因此登录后需通过
  /// 本方法补一次转换。
  ///
  /// 返回 null 表示请求失败或用户没有头像。
  Future<String?> fetchAvatarUrl() async {
    try {
      final response = await apiClient.dio.get('/chat/user/info');
      final data = response.data['data'] as Map<String, dynamic>?;
      return data?['avatar'] as String?;
    } catch (e) {
      print('[ProfileService] fetchAvatarUrl failed: $e');
      return null;
    }
  }
}
