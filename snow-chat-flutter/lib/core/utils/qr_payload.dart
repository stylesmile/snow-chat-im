/// QR 码内容编码/解码工具
///
/// 约定二维码内容格式：`snowchat://user/{userId}`。
/// 「我的二维码」页用它编码自己的 userId；「扫一扫」页用它解析对方二维码，
/// 得到 userId 后拉取对方公开资料并添加好友。
///
/// 采用自定义 scheme `snowchat://user/` 而非裸 userId，一可避免误扫别的数字二维码，
/// 二为未来扩展其他 protocol（如 `snowchat://group/{id}`）预留空间。
library;

/// 二维码内容编解码的命名空间（纯静态方法，无需实例化）
class MyQrPayload {
  /// 二维码内容自定义 scheme 协议头
  static const String _scheme = 'snowchat://user/';

  /// 将 userId 编码为二维码内容
  ///
  /// 例如 `encode(1001)` → `snowchat://user/1001`
  static String encode(int userId) {
    return '$_scheme$userId';
  }

  /// 从二维码内容还原 userId
  ///
  /// - 协议头不是 `snowchat://user/` 时返回 null（无法识别，提示"无效二维码"）
  /// - 协议头之后不是合法数字时返回 null（防御异常数据）
  static int? decode(String payload) {
    // 空串或缺少协议前缀视为无法识别
    if (!payload.startsWith(_scheme)) {
      return null;
    }
    // 截取协议头之后的 id 段
    final String idSegment = payload.substring(_scheme.length);
    // 解析为 int；非数字（含空）时 int.tryParse 返回 null
    return int.tryParse(idSegment);
  }
}