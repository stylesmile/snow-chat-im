import '../config/config.dart';

/// 媒体 URL 归一化工具。
///
/// 背景：聊天图片/视频的 content 里存的是阿里云 OSS 的直链
/// （如 https://win-chat-chat.oss-rg-china-mainland.aliyuncs.com/images/2026/09/15/uuid.png）。
/// 海外/非大陆设备可能无法直连大陆 OSS 域名，导致下载超时、图片无法显示。
/// 这里在下载/预览前把这类 OSS 直链改写为经本后端中转的代理地址
/// （{apiBase}/file/raw/{key}），由后端代办到 OSS，从而任意区域的用户都能访问。
///
/// 由于后台 `/file/raw/**` 端点对对象 key 有白名单（avatars/images/videos/files/voices，
/// 可含一层纯数字日期目录），这里只对满足该形态的 OSS 直链重写。
class MediaUrl {
  /// 需要改写的上游图片/媒体域名特征：阿里云 OSS。
  /// 可以是 bucket.oss-<region>.aliyuncs.com 或其他 OSS 自定义域名。
  static const String ossHostSuffix = 'aliyuncs.com';

  /// 判断给定 URL 是否指向阿里云 OSS（据此决定是否改写为后端代理）。
  static bool _isOssUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.endsWith(ossHostSuffix);
  }

  /// 对象 key 白名单：仅放行这五类业务目录，且只认一层纯数字日期目录，
  /// 与后端 FileController.RAW_KEY_PATTERN 保持一致，避免构造非法 key。
  static final RegExp _keyPattern =
      RegExp(r'^(avatars|images|videos|files|voices)/(?:\d{4}/\d{2}/\d{2}/)?[A-Za-z0-9._-]+$');

  /// 从 OSS 直链里提取对象 key（域名后的路径，去掉 query），并校验白名单。
  static String? _ossKeyOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.path.isEmpty) return null;
    // 去掉开头的斜杠，得到如 images/2026/09/15/uuid.png
    final key = uri.path.replaceFirst(RegExp(r'^/+'), '');
    return _keyPattern.hasMatch(key) ? key : null;
  }

  /// 将媒体直链改写为经后端代理的可访问地址。
  ///
  /// 规则：
  /// - data: / 本地/已是代理前缀 → 原样返回；
  /// - OSS 直链且 key 通过白名单 → 返回 {apiBase}/file/raw/{key}；
  /// - 其余（其它图床/非业务目录）→ 原样返回，不做重写。
  ///
  /// @param url    原始媒体 URL（数据库中 content 字段）
  /// @param apiBase 后端基础地址；默认取 [AppConfig.baseUrl]
  /// @return 可直接下载/渲染的 URL
  static String proxyMediaUrl(String url, {String? apiBase}) {
    // 空串与 base64 内嵌数据无需改写
    if (url.isEmpty || url.startsWith('data:')) return url;
    final base = apiBase ?? AppConfig.baseUrl;
    // 已是本后端代理前缀、或本地文件/相对路径：原样返回，避免二次打包
    if (url.startsWith(base) || url.startsWith('/') || url.startsWith('file:')) {
      return url;
    }
    // 仅对 OSS 直链执行改写
    if (!_isOssUrl(url)) return url;
    // 提取并校验对象 key；不符合白名单则不改写
    final key = _ossKeyOf(url);
    if (key == null) return url;
    // 拼接代理地址：{base}/file/raw/{key}
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$normalizedBase/file/raw/$key';
  }
}