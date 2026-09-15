/// 版本更新相关的纯逻辑与数据模型。
library;

/// 语义化版本字符串比较（纯函数，便于单测）。
///
/// 规则：
/// - 支持可选的 `v` 前缀（如 v2.1.0 与 2.1.0 视为相同）；
/// - 以 `.` 分割成段，逐段按数值比较（2.10 > 2.9）；
/// - 段数不同时缺失段按 0 处理（2.1 与 2.1.0 视为相同）；
/// - 忽略 `-` 之后的预发布后缀（如 2.1.0-beta 与 2.1.0 按 2.1.0 比较）；
/// - 无法解析的段按 0 处理，保证不抛异常。
///
/// @return >0 表示 a 大于 b；<0 表示 a 小于 b；0 表示相等
int compareVersions(String a, String b) {
  // 归一化：去空格、小写、去 v 前缀、截断预发布后缀
  String normalize(String s) {
    var r = s.trim().toLowerCase();
    if (r.startsWith('v')) r = r.substring(1);
    final dash = r.indexOf('-');
    if (dash >= 0) r = r.substring(0, dash);
    return r;
  }

  // 拆段并逐个转为数值，无法解析的段按 0 处理
  List<int> parts(String s) => normalize(s)
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList();

  final ap = parts(a);
  final bp = parts(b);
  // 以较长的段数为界，缺失段按 0 补齐后逐段比较
  final maxLen = ap.length > bp.length ? ap.length : bp.length;
  for (var i = 0; i < maxLen; i++) {
    final x = i < ap.length ? ap[i] : 0;
    final y = i < bp.length ? bp[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

/// 服务端下发的版本更新信息（对应 chat_app_version 表的字段）。
class AppVersion {
  /// 服务端最新版本号（如 2.1.0）
  final String version;

  /// 下载/跳转地址（打开浏览器访问）
  final String downloadUrl;

  /// 更新说明文案
  final String updateMessage;

  /// 是否提示更新（对应 isNotify：1=提示，0=不提示）
  final bool isNotify;

  const AppVersion({
    required this.version,
    required this.downloadUrl,
    required this.updateMessage,
    required this.isNotify,
  });

  /// 是否应提示用户更新：开启提示且下载地址非空才弹窗
  bool get shouldNotify => isNotify && downloadUrl.isNotEmpty;

  /// 从后端返回的 data 字段解析；缺省字段用空值兜底，避免解析崩溃
  factory AppVersion.fromJson(Map<String, dynamic> json) => AppVersion(
        version: json['version'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String? ?? '',
        updateMessage: json['updateMessage'] as String? ?? '',
        isNotify: (json['isNotify'] as num?)?.toInt() == 1,
      );
}

/// 判断是否该弹出版本更新提示（纯函数，便于单测）。
///
/// @param latest 服务端拉取到的最新可提示版本；可能为 null（无更新记录或请求失败）
/// @param currentVersion 本机当前版本号
/// @return true 表示应弹窗：服务端有记录、开启提示、有下载地址、且版本比当前新
bool shouldShowUpdate(AppVersion? latest, String currentVersion) {
  // 无服务端版本记录，或未开启提示/无下载地址，一律不提示
  if (latest == null || !latest.shouldNotify) return false;
  // 服务端版本不高于当前版本（<=0）则已是最新，无需提示
  return compareVersions(latest.version, currentVersion) > 0;
}