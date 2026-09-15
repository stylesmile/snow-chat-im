import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/services/image_loader.dart';

/// ImageLoader 下载逻辑的单元测试。
///
/// 背景：cached_network_image 在部分安卓环境下对可访问的 HTTPS 图片
/// 反复出现加载挂起/失败，且无磁盘之外的兜底。ImageLoader 用可注入的
/// [BytesFetcher]（默认走 dio）下载字节，提供内存缓存与并发去重，
/// 上传者/接收者都能用同一套可可靠复现、可测试的加载路径。
void main() {
  // 每次测试前清空静态缓存，避免用例间互相污染
  setUp(ImageLoader.clearCache);

  test('成功下载时返回字节并只获取一次', () async {
    // 准备：记录调用次数与返回的假字节
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    var calls = 0;
    // 注入假 fetcher：第一次返回 bytes，此后不应再被调用
    Future<Uint8List?> fakeFetch(String url) async {
      calls++;
      return bytes;
    }

    // 执行：同一 URL 连续获取两次
    final first = await ImageLoader.fetch('https://img/1.png', fetcher: fakeFetch);
    final second = await ImageLoader.fetch('https://img/1.png', fetcher: fakeFetch);

    // 验证：两次都返回同一份字节，但底层只真正下载了一次（命中内存缓存）
    expect(first, same(bytes));
    expect(second, same(bytes));
    expect(calls, 1, reason: '第二次应命中缓存，不再触发下载');
  });

  test('下载失败（返回 null）时返回 null 且不缓存', () async {
    // 注入假 fetcher：始终失败
    Future<Uint8List?> fakeFetch(String url) async => null;

    final result = await ImageLoader.fetch('https://img/x.png', fetcher: fakeFetch);

    // 失败的 URL 不缓存，因此后续仍会重新尝试（不会永久卡住）
    expect(result, isNull);
  });

  test('并发相同 URL 时去重，只发起一次下载', () async {
    // 准备：用 Completer 模拟一个尚未完成的慢请求
    final completer = Completer<Uint8List?>();
    var calls = 0;
    Future<Uint8List?> fakeFetch(String url) {
      calls++;
      return completer.future;
    }

    // 执行：并发发起两个相同 URL 的请求
    final f1 = ImageLoader.fetch('https://img/a.png', fetcher: fakeFetch);
    final f2 = ImageLoader.fetch('https://img/a.png', fetcher: fakeFetch);

    // 验证：重复请求共用同一 Future（未完成前第二发不触发新下载）
    expect(calls, 1, reason: '进行中的相同请求应被去重');

    // 放行并收集结果
    final payload = Uint8List.fromList([9]);
    completer.complete(payload);
    expect(await f1, payload);
    expect(await f2, payload);
  });

  test('清空缓存后同一 URL 会重新下载', () async {
    // 准备：每次返回递增的唯一字节，便于区分是否走缓存
    var calls = 0;
    Future<Uint8List?> fakeFetch(String url) async {
      calls++;
      return Uint8List.fromList([calls]);
    }

    // 首次获取并缓存
    final first = await ImageLoader.fetch('https://img/b.png', fetcher: fakeFetch);
    expect(first!.first, 1);

    // 清空缓存后再次获取
    ImageLoader.clearCache();
    final second = await ImageLoader.fetch('https://img/b.png', fetcher: fakeFetch);

    // 验证：清空后重新下载，返回新的字节
    expect(second!.first, 2);
  });
}