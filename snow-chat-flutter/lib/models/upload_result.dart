/// 文件上传结果数据类。
///
/// 对应后端 `UploadResult` record：
/// - [key]：对象存储中的 key（如 `avatars/uuid.jpg`），用于持久化到用户 avatar 字段；
/// - [url]：访问该对象的 pre-signed URL（带有效期），前端可直接用于展示。
///
/// 使用 `fromJson` 工厂方法从后端响应的 `data` 字段解析。
class UploadResult {
  /// 对象 key（如 `avatars/uuid.jpg`）
  final String key;

  /// pre-signed 访问 URL（带有效期）
  final String url;

  const UploadResult({required this.key, required this.url});

  /// 从后端 JSON 响应的 data 字段构造 UploadResult。
  /// 若 key 或 url 缺失，返回 null（调用方应做空判断）。
  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      key: json['key'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}
