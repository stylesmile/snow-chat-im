import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/cache_cleaner.dart';

/// CacheCleaner 单元测试
///
/// 验证：计算指定目录总体积（byte/MB）、清理时删除目录内所有文件、
/// 不误删其它无关内容、空/不存在的目录安全处理。
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cache_cleaner_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 创建可注入目录列表的 CacheCleaner
  CacheCleaner makeCleaner(List<Directory> dirs) {
    return CacheCleaner(dirsProvider: () async => dirs);
  }

  /// 生成一个指定字节数内容的文件
  Future<File> makeFile(String name, int bytes) {
    return File('${tempDir.path}/$name').writeAsBytes(List.filled(bytes, 1));
  }

  test('getSizeBytes 返回所有目录内文件体积之和', () async {
    // 准备：子目录 + 两个文件，共 1500 字节
    final sub = Directory('${tempDir.path}/sub')..createSync();
    final another = await Directory.systemTemp.createTemp('cache_cleaner_other');
    addTearDown(() async {
      if (await another.exists()) await another.delete(recursive: true);
    });
    await makeFile('a.bin', 1000);
    await File('${sub.path}/b.bin').writeAsBytes(List.filled(500, 1));
    await File('${another.path}/c.bin').writeAsBytes(List.filled(2000, 1));
    final cleaner = makeCleaner([tempDir, another]);

    final bytes = await cleaner.getSizeBytes();

    // a(1000) + sub/b(500) + another/c(2000) = 3500
    expect(bytes, 3500);
  });

  test('clear 删除目录内所有文件并保留目录结构', () async {
    // 准备：根目录一个文件 + 子目录内一个文件
    final sub = Directory('${tempDir.path}/sub')..createSync();
    await makeFile('a.bin', 300);
    await File('${sub.path}/b.bin').writeAsBytes(List.filled(200, 1));
    final cleaner = makeCleaner([tempDir]);

    final freed = await cleaner.clear();

    // 释放字节数等于删除前的总体积
    expect(freed, 500);
    // 根目录与子目录仍存在
    expect(await tempDir.exists(), isTrue);
    expect(await sub.exists(), isTrue);
    // 文件已清空
    expect(tempDir.listSync().whereType<File>(), isEmpty);
    expect(sub.listSync().whereType<File>(), isEmpty);
  });

  test('clear 对不存在或为空的目录安全返回 0', () async {
    // 指向不存在目录的容错
    final missing = Directory('${tempDir.path}/not_exist');
    final cleaner = makeCleaner([missing]);

    expect(await cleaner.getSizeBytes(), 0);
    expect(await cleaner.clear(), 0);
  });
}