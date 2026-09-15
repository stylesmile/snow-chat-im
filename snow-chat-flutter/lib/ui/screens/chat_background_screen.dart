import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../services/chat_background_service.dart';

/// 聊天背景设置页
///
/// 允许用户：
/// - 从相册选择一张图片作为聊天窗口背景（复制到本地并持久化）
/// - 恢复系统默认背景
class ChatBackgroundScreen extends StatefulWidget {
  /// 测试注入用：默认使用真实 [ChatBackgroundService]
  final ChatBackgroundService? service;

  const ChatBackgroundScreen({super.key, this.service});

  @override
  State<ChatBackgroundScreen> createState() => _ChatBackgroundScreenState();
}

class _ChatBackgroundScreenState extends State<ChatBackgroundScreen> {
  // 当前背景路径；null 表示使用默认背景
  String? _currentPath;
  // 是否正在设置背景（用于加载态）
  bool _setting = false;

  /// 实际使用的服务：注入优先，否则新建
  ChatBackgroundService get _service =>
      widget.service ?? ChatBackgroundService();

  @override
  void initState() {
    super.initState();
    // 进入页面即读取当前背景
    _loadCurrent();
  }

  /// 异步读取已持久化的背景路径
  Future<void> _loadCurrent() async {
    final path = await _service.getBackgroundPath();
    if (!mounted) return;
    setState(() => _currentPath = path);
  }

  /// 从相册选一张图片并设置为聊天背景
  Future<void> _pickFromAlbum() async {
    // 避免重复点击进入选图
    if (_setting) return;
    setState(() => _setting = true);
    try {
      // 与头像/聊天选图一致，复用 wechat_assets_picker
      final results = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          requestType: RequestType.image,
          maxAssets: 1,
          themeColor: Theme.of(context).colorScheme.primary,
          textDelegate: AssetPickerTextDelegate(),
        ),
      );
      if (results == null || results.isEmpty) return;
      final file = await results.first.file;
      if (file == null || !mounted) return;

      // 复制为背景并持久化
      final path = await _service.setBackground(file);
      if (!mounted) return;
      setState(() => _currentPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.clearCacheDone)),
      );
    } catch (_) {
      // 选图或设置失败时给出友好提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置背景失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _setting = false);
    }
  }

  /// 恢复系统默认背景
  Future<void> _resetToDefault() async {
    await _service.reset();
    if (!mounted) return;
    setState(() => _currentPath = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.chatBackground),
        leading: const BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          // 背景预览区
          SizedBox(
            height: 220,
            child: _currentPath != null
                // 已设置背景：展示所选图片
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(_currentPath!), fit: BoxFit.cover),
                          // 顶部半透明遮罩强化文字可读性
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x33000000),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                // 未设置：默认深色底 + 提示
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined,
                              size: 48, color: Colors.grey.shade500),
                          const SizedBox(height: 8),
                          Text(
                            l10n.resetToDefault,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // 从相册选择
          ListTile(
            leading: const Icon(Icons.photo_library_outlined,
                color: Colors.grey, size: 24),
            title: Text(
              l10n.chooseFromAlbum,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            trailing: _setting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            onTap: _pickFromAlbum,
          ),
          const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),
          // 恢复默认
          ListTile(
            leading: const Icon(Icons.restart_alt, color: Colors.grey, size: 24),
            title: Text(
              l10n.resetToDefault,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            onTap: _resetToDefault,
          ),
        ],
      ),
    );
  }
}