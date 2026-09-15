import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/services/chat_background_service.dart';

/// ChatBackgroundService 单元测试
///
/// 验证：设置背景（复制源图到文档目录 + 持久化路径）、读取当前背景、
/// 恢复默认（删除文件并清除持久化值）。
void main() {
  // 每个用例使用独立的临时目录作为"应用文档目录"，避免互相污染
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bg_service_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 创建可注入目录提供者的服务实例
  ChatBackgroundService makeService() {
    return ChatBackgroundService(dirProvider: () async => tempDir);
  }

  /// 在源目录生成一个真实的临时图片文件（含字节内容）
  Future<File> makeSourceImage() async {
    final srcDir = await Directory.systemTemp.createTemp('bg_src');
    final f = File('${srcDir.path}/source.png');
    await f.writeAsBytes([0x89, 0x50, 0x4e, 0x47]); // PNG 魔数
    return f;
  }

  test('setBackground 将源图复制到文档目录并返回持久化路径', () async {
    SharedPreferences.setMockInitialValues({});
    final service = makeService();
    final source = await makeSourceImage();

    final savedPath = await service.setBackground(source);

    // 返回的路径位于注入的文档目录内（新建 chat_background 子目录）
    expect(savedPath, isNotNull);
    expect(savedPath.startsWith('${tempDir.path}/chat_background'), isTrue);
    // 目标文件确实被复制（内容一致）
    final copied = File(savedPath);
    expect(await copied.exists(), isTrue);
    expect(await copied.readAsBytes(), [0x89, 0x50, 0x4e, 0x47]);
    // 路径已持久化到 SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chat_background_path'), savedPath);
  });

  test('getBackgroundPath 在未设置时返回 null', () async {
    SharedPreferences.setMockInitialValues({});
    final service = makeService();

    final path = await service.getBackgroundPath();

    expect(path, isNull);
  });

  test('getBackgroundPath 在设置背景后返回持久化路径', () async {
    SharedPreferences.setMockInitialValues({});
    final service = makeService();
    final source = await makeSourceImage();

    await service.setBackground(source);
    final path = await service.getBackgroundPath();

    expect(path, isNotNull);
    expect(path!.startsWith('${tempDir.path}/chat_background'), isTrue);
  });

  test('getBackgroundPath 能从 SharedPreferences 恢复已持久化的设置（重启场景）', () async {
    // 模拟上次运行已保存路径：直接往 prefs 写入
    SharedPreferences.setMockInitialValues(
        {'chat_background_path': '${tempDir.path}/chat_background/old_bg.png'});
    final service = makeService();

    final path = await service.getBackgroundPath();

    expect(path, '${tempDir.path}/chat_background/old_bg.png');
  });

  test('reset 删除背景文件并清除持久化设置', () async {
    SharedPreferences.setMockInitialValues({});
    final service = makeService();
    final source = await makeSourceImage();
    final savedPath = await service.setBackground(source);
    expect(File(savedPath).existsSync(), isTrue);

    await service.reset();

    // 文件被删除
    expect(await File(savedPath).exists(), isFalse);
    // 持久化值被清除
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chat_background_path'), isNull);
    // 读取路径返回 null（回到默认背景）
    expect(await service.getBackgroundPath(), isNull);
  });
}
