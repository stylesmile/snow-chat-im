import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 聊天背景管理服务：负责把用户选中的图片设置为聊天窗口背景。
///
/// 实现策略：
/// - 将源图复制到应用文档目录下的 chat_background 子目录，避免依赖原图路径有效期
/// - 复制后的路径持久化到 SharedPreferences，保证重启后依然生效
/// - 提供 [reset] 恢复系统默认背景（删除文件 + 清除持久化值）
///
/// 通过可注入的 [dirProvider] 隔离 path_provider，方便单元测试。
class ChatBackgroundService {
  /// 持久化背景路径用的 SharedPreferences 键
  static const String backgroundKey = 'chat_background_path';

  /// 注入"应用文档目录"的提供者；默认使用 path_provider 的真实目录
  final Future<Directory> Function() _dirProvider;

  ChatBackgroundService({Future<Directory> Function()? dirProvider})
      : _dirProvider = dirProvider ?? getApplicationDocumentsDirectory;

  /// 把选中的图片 [source] 复制为聊天背景，返回持久化路径。
  ///
  /// 文件会被复制到 `{文档目录}/chat_background/chat_bg.png`，该目录不存在时自动创建。
  Future<String> setBackground(File source) async {
    // 1) 获取注入的文档目录
    final root = await _dirProvider();

    // 2) 定位背景子目录，不存在则创建
    final bgDir = Directory('${root.path}/chat_background');
    if (!await bgDir.exists()) {
      await bgDir.create(recursive: true);
    }

    // 3) 目标文件名固定为 chat_bg.png（覆盖旧背景，避免历史文件堆积）
    final dest = File('${bgDir.path}/chat_bg.png');
    await source.copy(dest.path);

    // 4) 持久化背景路径，供重启后恢复
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(backgroundKey, dest.path);

    return dest.path;
  }

  /// 返回当前聊天背景路径；未设置时返回 null（表示使用系统默认背景）。
  Future<String?> getBackgroundPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(backgroundKey);
  }

  /// 恢复默认背景：删除背景文件并清除持久化设置。
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) 读取当前背景路径，若存在则删除对应文件
    final path = prefs.getString(backgroundKey);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // 2) 清除持久化值，使 [getBackgroundPath] 回到 null
    await prefs.remove(backgroundKey);
  }
}