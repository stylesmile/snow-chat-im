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
  /// 向 `PUT /chat/user/profile` 发送 JSON body（与后端 @RequestBody UpdateProfileDTO 对齐）。
  /// 任意字段为 null 表示不更新该字段。
  /// 成功返回 true，失败返回 false。
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

  /// 上传头像文件
  ///
  /// 向 `POST /file/upload` 发送 multipart/form-data 请求：
  /// - 字段名：`file`
  /// - 内容：图片二进制
  ///
  /// 成功返回 [UploadResult]（包含对象 key 与 pre-signed URL），失败返回 null。
  /// 前端流程：uploadAvatar → 拿到 result.key 调 updateProfile 存 DB → 用 result.url 立即展示。
  Future<UploadResult?> uploadAvatar(File imageFile) async {
    try {
      // 读取文件字节
      final bytes = await imageFile.readAsBytes();
      // 构造 multipart 表单：字段名 file，文件名取原始路径末段
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      // 发送 POST 请求
      final response = await apiClient.dio.post('/file/upload', data: formData);
      // 解析响应：{code: '200', data: {key, url}}
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) {
        return null;
      }
      // 构造 UploadResult 返回
      return UploadResult.fromJson(data);
    } catch (e) {
      // 网络异常或解析失败时返回 null
      return null;
    }
  }
}
