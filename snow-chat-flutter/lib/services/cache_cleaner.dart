import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 缓存清理服务：统计并清理应用的临时文件与图片缓存。
///
/// 清理范围：
/// - 系统临时目录（语音/媒体临时文件等）
/// - 应用缓存目录（cached_network_image 的图片缓存等）
///
/// 通过可注入的 [dirsProvider] 隔离 path_provider，便于单元测试。
class CacheCleaner {
  /// 注入"待清理目录列表"的提供者；默认返回临时目录 + 应用缓存目录
  final Future<List<Directory>> Function() _dirsProvider;

  CacheCleaner({Future<List<Directory>> Function()? dirsProvider})
      : _dirsProvider = dirsProvider ?? _defaultDirs;

  /// 默认目录：系统临时目录 + 应用缓存目录
  static Future<List<Directory>> _defaultDirs() async {
    final temp = await getTemporaryDirectory();
    final cache = await getApplicationCacheDirectory();
    return [temp, cache];
  }

  /// 统计所有目录内文件的总体积（字节）。
  ///
  /// 目录不存在或为空时返回 0。
  Future<int> getSizeBytes() async {
    var total = 0;
    for (final dir in await _dirsProvider()) {
      // 目录不存在则跳过（容错）
      if (!await dir.exists()) continue;
      // 遍历目录内所有文件（含子目录），累加字节数
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += entity.lengthSync();
        }
      }
    }
    return total;
  }

  /// 清除所有目录内的文件（保留目录结构），返回释放的字节数。
  ///
  /// 仅删除文件，不删除目录本身，避免破坏依赖目录存在的逻辑。
  Future<int> clear() async {
    // 先记录清理前体积，用于返回实际释放大小
    final before = await getSizeBytes();
    for (final dir in await _dirsProvider()) {
      // 目录不存在则跳过
      if (!await dir.exists()) continue;
      // 逐层删除文件（保留空目录）
      await Directory(dir.path)
          .list(recursive: true)
          .forEach((entity) async {
        if (entity is File && await entity.exists()) {
          await entity.delete();
        }
      });
    }
    return before;
  }
}