import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../../services/image_loader.dart';
import '../../utils/media_url.dart';

/// 图片保存函数签名，便于测试注入替身（避免在测试中触发真实相册插件）
typedef SaveImageCallback = Future<bool> Function(Uint8List bytes);

/// 图片大图查看页
///
/// 支持：
/// - 全屏查看 + 双指缩放/平移（InteractiveViewer）
/// - 点击右上角保存到系统相册
/// - 图片内容可为 base64 data-URI 或网络 URL
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.content,
    this.title,
    this.saver,
  });

  /// 图片内容：base64 data-URI（如 data:image/png;base64,...）或网络 URL
  final String content;

  /// 顶部标题（可选）
  final String? title;

  /// 保存回调，默认使用 gal 保存到相册；测试可注入替身避免触发插件
  final SaveImageCallback? saver;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  /// 是否正在保存，用于禁用按钮并显示进度
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 全黑背景，营造沉浸式图片查看体验
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.title == null
            ? null
            : Text(widget.title!, style: const TextStyle(fontSize: 16)),
        actions: [
          // 保存到相册按钮
          IconButton(
            tooltip: '保存到相册',
            onPressed: _saving ? null : _handleSave,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          // 支持双指缩放与拖动，最小缩放 1x
          minScale: 1,
          child: _buildImage(),
        ),
      ),
    );
  }

  /// 构建可显示的图片组件（适配 base64 与网络两种来源）
  Widget _buildImage() {
    final content = widget.content;
    if (content.startsWith('data:')) {
      // base64 data-URI：解码为内存图片展示
      return Image.memory(
        base64Decode(content.split(',').last),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _errorPlaceholder(),
      );
    }
    // 网络 URL：走本地磁盘缓存——与聊天气泡共用同一份缓存文件，
    // 气泡已下载过的图在大图页直接读本地，不再重复下载
    return FutureBuilder<String?>(
      // OSS 直链改写为后端代理地址后下载，适配海外设备无法直连大陆 OSS
      future: ImageLoader.localPath(MediaUrl.proxyMediaUrl(content)),
      builder: (context, snap) {
        // 本地文件准备中：显示加载占位
        if (snap.connectionState != ConnectionState.done) {
          return _loadingPlaceholder();
        }
        final localPath = snap.data;
        // 下载/落盘失败：显示错误占位
        if (localPath == null) {
          return _errorPlaceholder();
        }
        // 本地文件渲染，避免 Image.network 在部分设备上的挂起问题
        return Image.file(
          File(localPath),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _errorPlaceholder(),
        );
      },
    );
  }

  /// 保存图片到相册的入口，处理 base64 解码与网络下载
  Future<void> _handleSave() async {
    setState(() => _saving = true);
    try {
      // 1. 解析原始字节：base64 直接解码，网络 URL 下载
      final bytes = await _resolveBytes();
      if (bytes.isEmpty) {
        _showResult(false);
        return;
      }
      // 2. 调用保存逻辑（默认 gal），并依据结果提示用户
      final saver = widget.saver ?? _saveToGallery;
      final ok = await saver(bytes);
      _showResult(ok);
    } catch (_) {
      // 网络波动或解码失败时提示保存失败
      _showResult(false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 根据图片来源解析原始字节
  Future<Uint8List> _resolveBytes() async {
    final content = widget.content;
    if (content.startsWith('data:')) {
      return base64Decode(content.split(',').last);
    }
    // 保存前同样改写为代理地址，与展示链路保持一致
    final proxy = MediaUrl.proxyMediaUrl(content);
    // 优先读本地缓存文件（气泡/大图页已下载过则零网络开销）
    final localPath = await ImageLoader.localPath(proxy);
    if (localPath != null) {
      return File(localPath).readAsBytes();
    }
    // 本地缓存不可用时兜底：直接下载并返回字节内容
    final response = await Dio().get<List<int>>(
      proxy,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? []);
  }

  /// 默认保存实现：通过 gal 写入系统相册
  ///
  /// gal 2.x 的 [_writeGallery] 成功时不返回值、失败时抛异常，
  /// 因此这里用 try/catch 统一转换为布尔结果。
  Future<bool> _saveToGallery(Uint8List bytes) async {
    try {
      await _writeGallery(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 调用 gal 真正写入系统相册（成功无返回，失败抛异常）
  Future<void> _writeGallery(Uint8List bytes) {
    return Gal.putImageBytes(bytes);
  }

  /// 依据保存结果展示成功/失败提示
  void _showResult(bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '已保存到相册' : '保存失败'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 加载中的占位图
  Widget _loadingPlaceholder() {
    return const SizedBox(
      width: 200,
      height: 200,
      child: Center(child: CircularProgressIndicator(color: Colors.white54)),
    );
  }

  /// 加载/解码失败的占位
  Widget _errorPlaceholder() {
    return const SizedBox(
      width: 200,
      height: 200,
      child: Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 64)),
    );
  }
}