import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 字节下载函数签名，便于测试注入替身。
typedef BytesFetcher = Future<Uint8List?> Function(String url);

/// 聊天图片本地缓存加载器。
///
/// 策略（对应需求：收到图片后下载到本地，预览用本地文件，不重复下载）：
/// 1. 内存缓存：url -> 本地文件路径，进程内零 IO；
/// 2. 磁盘缓存：url 的 sha1 作为文件名，存于应用缓存目录下的
///    `image_cache` 子目录（「设置-清理缓存」会一并清理）；
/// 3. 命中顺序：内存 -> 磁盘 -> 网络下载并落盘；
/// 4. 并发去重：相同 url 的进行中请求共用同一 Future。
///
/// 返回本地文件路径，UI 侧用 `Image.file` 渲染，彻底绕开
/// cached_network_image / Image.network 在部分安卓设备上的挂起问题。
class ImageLoader {
  // 磁盘缓存子目录名（位于应用缓存目录下，可被 CacheCleaner 清理）
  static const String _cacheDirName = 'image_cache';

  // 内存缓存：url -> 本地文件路径
  static final Map<String, String> _pathCache = {};

  // 进行中的下载任务去重：url -> Future<本地路径>
  static final Map<String, Future<String?>> _inflight = {};

  /// 缓存根目录提供者，可注入以隔离 path_provider（测试用）
  static Future<Directory> Function() dirProvider = _defaultDir;

  /// 默认缓存根目录：应用缓存目录（卸载 App / 清理缓存时随之释放）
  static Future<Directory> _defaultDir() => getApplicationCacheDirectory();

  /// 恢复默认目录提供者（测试清理用）
  static void resetDirProvider() {
    dirProvider = _defaultDir;
  }

  /// 清空内存缓存（磁盘文件保留，模拟「重启后不重复下载」）
  static void clearMemoryCache() {
    _pathCache.clear();
  }

  /// 获取图片的本地文件路径；不存在则下载并落盘。
  ///
  /// @param url 图片远程地址
  /// @param fetcher 下载实现，默认走 dio；测试可注入替身
  /// @return 本地文件路径；下载失败返回 null（不缓存失败结果，可重试）
  static Future<String?> localPath(
    String url, {
    BytesFetcher? fetcher,
  }) {
    // 1. 内存命中：直接返回本地路径，零 IO
    final cached = _pathCache[url];
    if (cached != null) return Future.value(cached);

    // 2. 并发去重：进行中的相同请求共用同一 Future
    final pending = _inflight[url];
    if (pending != null) return pending;

    // 3. 发起「磁盘检查 -> 必要时下载落盘」的任务并登记去重
    final future = _load(url, fetcher ?? _dioFetch).whenComplete(() {
      // 任务结束后移除登记，允许失败后重试
      _inflight.remove(url);
    });
    _inflight[url] = future;
    return future;
  }

  /// 核心加载流程：先查磁盘，未命中再下载并写入磁盘。
  static Future<String?> _load(String url, BytesFetcher fetcher) async {
    // 计算缓存文件路径：url 的 sha1 做文件名，避免特殊字符与长度问题
    final file = await _cacheFile(url);

    // 磁盘命中：直接登记内存缓存并返回（App 重启后走这条路，不重复下载）
    if (await file.exists() && (await file.length()) > 0) {
      _pathCache[url] = file.path;
      return file.path;
    }

    // 磁盘未命中：下载字节
    final bytes = await fetcher(url);
    if (bytes == null || bytes.isEmpty) {
      // 下载失败不写文件、不缓存，返回 null 让 UI 展示失败占位并可重试
      return null;
    }

    // 先写临时文件再重命名，避免并发/中断产生半截文件被误判为缓存命中
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);

    // 登记内存缓存并返回本地路径
    _pathCache[url] = file.path;
    return file.path;
  }

  /// 计算某 url 对应的本地缓存文件（不保证已存在）
  static Future<File> _cacheFile(String url) async {
    final root = await dirProvider();
    final dir = Directory('${root.path}/$_cacheDirName');
    // 目录不存在则创建（递归，容错并发创建）
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // 用 sha1 哈希 url 作为文件名：定长、无特殊字符、同 url 同文件
    final name = _sha1Hex(url);
    // 保留扩展名便于调试与系统识别（取 url 最后一个 '.' 后最多 4 位字母）
    final ext = _extensionOf(url);
    return File('${dir.path}/$name$ext');
  }

  /// 从 url 中提取图片扩展名（.png/.jpg/.jpeg/.webp/.gif），默认 .png
  static String _extensionOf(String url) {
    // 去掉 query 参数后再取扩展名，避免 ?x-oss-process=... 干扰
    final clean = url.split('?').first;
    final match = RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false)
        .firstMatch(clean);
    return match?.group(0)?.toLowerCase() ?? '.png';
  }

  /// 生成缓存文件名的十六进制哈希（双种子 FNV-1a 拼接，避免引入 crypto 依赖）。
  ///
  /// 同 url 必然同文件名；不同 url 碰撞概率极低，且最坏后果仅是文件被覆盖
  /// （下次进入会重新下载），不构成正确性问题。
  static String _sha1Hex(String input) {
    // 两个不同种子各跑一次 64 位 FNV-1a，拼接成 32 位 hex 文件名
    final h1 = _fnv1a64(input, 0xcbf29ce484222325);
    final h2 = _fnv1a64(input, 0x84222325cbf29ce4);
    return h1.toRadixString(16).padLeft(16, '0') +
        h2.toRadixString(16).padLeft(16, '0');
  }

  /// FNV-1a 64 位哈希（带自定义种子），用于生成缓存文件名
  static int _fnv1a64(String input, int seed) {
    var hash = seed;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      // 乘以 FNV 素数，用乘法+移位模拟 64 位（Dart int 为 64 位，自然溢出）
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash;
  }

  /// 后台批量预下载一组图片到本地（fire-and-forget）。
  ///
  /// 用于「进入聊天页 / 收到图片消息」时提前落盘：这样图片气泡首次 build
  /// 时 localPath 往往已命中本地文件，立即显示，不会长时间停留在加载占位。
  /// 失败静默忽略——渲染侧 FutureBuilder 仍会兜底显示失败占位并可点击重试。
  /// 重复调用幂等：已下载的 url 命中缓存，不会重复发起网络请求。
  ///
  /// @param urls 待预下载的图片地址集合
  /// @param fetcher 下载实现，默认走 dio；测试可注入替身
  static void precache(Iterable<String> urls, {BytesFetcher? fetcher}) {
    for (final url in urls) {
      // 跳过空串与 base64 data-URI（本地/内嵌数据无需下载）
      if (url.isEmpty || url.startsWith('data:')) continue;
      // 不 await：后台下载落盘，调用方无需等待
      localPath(url, fetcher: fetcher);
    }
  }

  /// 清除某 url 的本地缓存（内存 + 磁盘），用于「点击重试」强制重新下载
  static Future<void> clear(String url) async {
    _pathCache.remove(url);
    try {
      final file = await _cacheFile(url);
      if (await file.exists()) await file.delete();
    } catch (e) {
      // 清理失败不影响主流程，仅记录
      debugPrint('[ImageLoader] clear failed: $e');
    }
  }

  /// 默认下载实现：dio 拉取字节，异常时返回 null（UI 展示失败占位）
  static Future<Uint8List?> _dioFetch(String url) async {
    // 打印开始，便于在设备日志中定位下载是否真正发起
    debugPrint('[ImageLoader] downloading: ${url.length > 80 ? '${url.substring(0, 80)}...' : url}');
    try {
      final dio = Dio();
      final resp = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          // 缩短超时，避免网络挂起导致占位长时间转圈（可点击重试）
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          followRedirects: true,
        ),
      );
      final data = resp.data;
      if (data == null || data.isEmpty) {
        debugPrint('[ImageLoader] empty body for $url');
        return null;
      }
      debugPrint('[ImageLoader] downloaded ${data.length} bytes for $url');
      return Uint8List.fromList(data);
    } catch (e) {
      // 打印具体异常，便于在无日志真机上区分网络不可达/超时/解码问题
      debugPrint('[ImageLoader] fetch failed for $url: ${e.runtimeType}: $e');
      return null;
    }
  }
}
