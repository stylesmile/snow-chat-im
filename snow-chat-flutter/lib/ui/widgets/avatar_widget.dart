import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 头像 Widget，支持网络 URL 和 base64 data URL 两种模式
class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.initials,
    this.size = 40,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = backgroundColor ?? theme.colorScheme.primaryContainer;
    final textColor = foregroundColor ?? theme.colorScheme.onPrimaryContainer;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // 判断是否为 base64 data URL（以 data:image 开头）
      if (imageUrl!.startsWith('data:image')) {
        // data URL：解码为字节，用 Image.memory 直接渲染（支持 InMemoryFileStorage）
        try {
          // 提取 base64 部分（去掉 data:image/xxx;base64, 前缀）
          final base64Part = imageUrl!.split(',').last;
          final bytes = base64Decode(base64Part);
          return ClipRRect(
            borderRadius: BorderRadius.circular(size / 2),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(initials, color, textColor),
            ),
          );
        } catch (e) {
          // 解码失败则降级显示占位
          return _buildPlaceholder(initials, color, textColor);
        }
      }
      // 网络 URL：使用 CachedNetworkImage 加载
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildPlaceholder(initials, color, textColor),
          errorWidget: (_, __, ___) => _buildPlaceholder(initials, color, textColor),
        ),
      );
    }

    return _buildPlaceholder(initials, color, textColor);
  }

  Widget _buildPlaceholder(String initials, Color color, Color textColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: textColor,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
