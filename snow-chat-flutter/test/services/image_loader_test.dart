import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/services/image_loader.dart';

/// ImageLoader「本地磁盘缓存」加载逻辑的单元测试。
///
/// 需求：收到聊天图片后下载到本地，预览直接读本地文件，
/// 每次进入聊天页面不再重复下载（含 App 重启后）。
/// 通过可注入的 [BytesFetcher] 与 [dirProvider] 隔离网络与文件系统根目录。
void main() {
  late Directory tempRoot;

  setUp(() async {
    // 每个用例使用独立临时目录，避免互相污染
    tempRoot = await Directory.systemTemp.createTemp('image_loader_test');
    ImageLoader.dirProvider = () async => tempRoot;
    ImageLoader.clearMemoryCache();
  });

  tearDown(() async {
    // 恢复默认目录提供者并清理临时目录
    ImageLoader.resetDirProvider();
    ImageLoader.clearMemoryCache();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('首次获取应下载并写入本地文件，返回本地路径', () async {
    // 准备：假字节与计数 fetcher
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    var calls = 0;
    Future<Uint8List?> fakeFetch(String url) async {
      calls++;
      return bytes;
    }

    // 执行
    final path = await ImageLoader.localPath('https://img/1.png', fetcher: fakeFetch);

    // 验证：返回本地路径且文件内容与下载字节一致
    expect(path, isNotNull);
    expect(calls, 1);
    final file = File(path!);
    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), bytes);
  });

  test('同一 URL 再次获取应命中缓存，不再下载', () async {
    var calls = 0;
    Future<Uint8List?> fakeFetch(String url) async {
      calls++;
      return Uint8List.fromList([calls]);
    }

    // 执行：连续获取两次
    final first = await ImageLoader.localPath('https://img/1.png', fetcher: fakeFetch);
    final second = await ImageLoader.localPath('https://img/1.png', fetcher: fakeFetch);

    // 验证：路径相同且只下载了一次
    expect(second, first);
    expect(calls, 1, reason: '第二次应命中本地缓存，不再触发下载');
  });

  test('内存缓存清空后仍应从磁盘读取，不重新下载（模拟重启 App）', () async {
    var calls = 0;
    Future<Uint8List?> fakeFetch(String url) async {
      calls++;
      return Uint8List.fromList([7, 8, 9]);
    }

    // 首次获取，落盘
    final first = await ImageLoader.localPath('https://img/a.png', fetcher: fakeFetch);
    expect(calls, 1);

    // 清空内存缓存，模拟 App 重启后重新进入聊天页
    ImageLoader.clearMemoryCache();
    final second = await ImageLoader.localPath('https://img/a.png', fetcher: fakeFetch);

    // 验证：磁盘文件仍在，直接复用，不再下载
    expect(second, first);
    expect(calls, 1, reason: '重启后应从磁盘缓存读取，不重复下载');
  });

  test('下载失败时返回 null 且不写入文件', () async {
    Future<Uint8List?> fakeFetch(String url) async => null;

    final path = await ImageLoader.localPath('https://img/x.png', fetcher: fakeFetch);

    expect(path, isNull);
    // 目录下不应产生任何文件
    final files = await tempRoot.list(recursive: true).toList();
    expect(files.whereType<File>().length, 0);
  });

  test('并发相同 URL 时去重，只发起一次下载', () async {
    final completer = Completer<Uint8List?>();
    var calls = 0;
    Future<Uint8List?> fakeFetch(String url) {
      calls++;
      return completer.future;
    }

    // 执行：并发发起两个相同 URL 的请求
    final f1 = ImageLoader.localPath('https://img/a.png', fetcher: fakeFetch);
    final f2 = ImageLoader.localPath('https://img/a.png', fetcher: fakeFetch);

    // 放行慢请求并等待两个 Future 完成
    completer.complete(Uint8List.fromList([9]));
    final p1 = await f1;
    final p2 = await f2;

    // 验证：去重生效——两次请求拿到同一路径，且底层只下载了一次
    expect(p2, p1);
    expect(calls, 1, reason: '并发的相同请求应去重，只发起一次下载');
  });

  test('precache 应在后台把图片下载落盘（fire-and-forget）', () async {
    // 准备：计数 fetcher，并记录图片 URL
    var calls = 0;
    Future<Uint8List?> fakeFetch(String url) async {
      calls++;
      return Uint8List.fromList([5, 6, 7]);
    }

    // 执行：后台预下载（不 await），明确触发落盘
    ImageLoader.precache(['https://img/pre.png'], fetcher: fakeFetch);

    // 验证：轮询等待磁盘出现对应的缓存文件
    final dir = Directory('${tempRoot.path}/image_cache');
    var found = false;
    for (var i = 0; i < 50 && !found; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (await dir.exists()) {
        final files = await dir.list().toList();
        found =
            files.any((e) => e is File && e.path.endsWith('.png'));
      }
    }
    expect(found, isTrue, reason: 'precache 应把图片下载并落盘到 image_cache');
    expect(calls, 1);

    // 预下载后 localPath 应直接命中本地文件，不再发起第二次下载
    final path = await ImageLoader.localPath('https://img/pre.png', fetcher: fakeFetch);
    expect(path, isNotNull);
    expect(calls, 1, reason: '预下载后再次获取应命中本地缓存');
  });

  test('precache 应忽略空地址与 base64 data-URI（不触发下载）', () async {
    var calls = 0;
    Future<Uint8List?> fakeFetch(String url) async {
      calls++;
      return Uint8List.fromList([1]);
    }

    // 执行：传空串、base64 头、正常 url
    ImageLoader.precache(
      ['', 'data:image/png;base64,xxx', 'https://img/ok.png'],
      fetcher: fakeFetch,
    );

    // 等待足够时间后断言：仅正常 url 触发了一次下载
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(calls, 1, reason: '空地址与 data-URI 不应触发下载');
  });

  test('clear 后应删除本地文件，下次获取重新下载', () async {
    var calls = 0;
    Future<Uint8List?> fakeFetch(String url) async {
      calls++;
      return Uint8List.fromList([calls]);
    }

    // 首次获取并落盘
    final first = await ImageLoader.localPath('https://img/b.png', fetcher: fakeFetch);
    expect(await File(first!).exists(), isTrue);

    // 清除该 URL 的本地缓存（用于「点击重试」场景）
    await ImageLoader.clear('https://img/b.png');
    expect(await File(first).exists(), isFalse);

    // 再次获取应重新下载
    final second = await ImageLoader.localPath('https://img/b.png', fetcher: fakeFetch);
    expect(calls, 2);
    expect(second, isNotNull);
  });
}
