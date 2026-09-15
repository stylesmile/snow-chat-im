import 'dart:typed_data';
import 'package:dio/dio.dart';

/// 图片字节获取函数签名。
///
/// 通过注入式设计，把"如何下载字节"与调用方解耦：
/// - 默认走 [Dio]（见 [_dioFetch]），复用的是项目里已被验证可用的网络栈
///   （文字/登录/会话等都依赖 dio），避免 cached_network_image 在部分
///   安卓环境下的加载挂起问题；
/// - 测试时注入替身即可，无需真实网络。
typedef BytesFetcher = Future<Uint8List?> Function(String url);

/// 图片字节加载器（带内存缓存与并发去重）。
///
/// 定位：聊天图片消息渲染稳定、可复现的加载入口。对比 cached_network_image：
/// - 失败/超时是确定性的，不会出现"既不变成功也不报错"的挂起；
/// - 内存缓存避免重复下载，进行中请求去重避免并发打爆网络。
class ImageLoader {
  // 已成功下载的字节缓存：key 为图片 URL，value 为字节
  static final Map<String, Uint8List> _bytesCache = {};

  // 进行中的请求去重：key 为 URL，value 为尚未完成的 Future
  static final Map<String, Future<Uint8List?>> _pending = {};

  /// 获取 [url] 的图片字节。
  ///
  /// - 优先返回内存缓存；无缓存则发起下载并缓存去重；
  /// - 成功返回字节；失败或超时返回 null（调用方可据此展示错误与重试）；
  /// - [fetcher] 仅用于测试注入，生产默认走 dio。
  static Future<Uint8List?> fetch(String url, {BytesFetcher? fetcher}) {
    // 命中内存缓存，直接返回已完成的 Future
    final cached = _bytesCache[url];
    if (cached != null) return Future.value(cached);

    // 同一 URL 有进行中的请求，则复用，避免并发重复下载
    final pending = _pending[url];
    if (pending != null) return pending;

    // 发起下载并在成功时回填缓存、结束时清除进行中标记
    final future = (fetcher ?? _dioFetch)(url).then((bytes) {
      if (bytes != null && bytes.isNotEmpty) {
        // 仅缓存非空字节，避免把失败结果写入缓存
        _bytesCache[url] = bytes;
      }
      // 无论成败都要移除进行中标记，允许下次重试
      _pending.remove(url);
      return bytes;
    });
    _pending[url] = future;
    return future;
  }

  /// 清空某个 [url] 的内存缓存与进行中记录。
  ///
  /// 供"单张失败重试"使用：清除后 [fetch] 会以新的 Future 重新下载。
  static void clear(String url) {
    _bytesCache.remove(url);
    _pending.remove(url);
  }

  /// 清空内存缓存（清除缓存、清理残留的进行中记录）。
  ///
  /// 供"清除缓存"/测试使用；也让失败后可重新触发下载。
  static void clearCache() {
    _bytesCache.clear();
    _pending.clear();
  }

  /// 默认下载实现：走 [Dio] GET 二进制流，带合理的超时兜底。
  ///
  /// 图片为公共可访问对象存储地址，无需携带鉴权头。
  static Future<Uint8List?> _dioFetch(String url) async {
    try {
      final resp = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          // 连接/响应超时，防止网络异常时无限挂起
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          // OSS 图片是公共读，显式禁止跟随会带上无关头的默认配置干扰
          followRedirects: true,
        ),
      );
      final data = resp.data;
      if (data == null) return null;
      return Uint8List.fromList(data);
    } on DioException {
      // 网络/超时/状态码异常统一当作加载失败
      return null;
    } catch (_) {
      // 其它未知异常同样降级为失败
      return null;
    }
  }
}