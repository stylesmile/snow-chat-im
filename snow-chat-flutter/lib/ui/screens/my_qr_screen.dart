import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/qr_payload.dart';

/// 我的二维码展示页
///
/// 展示本人二维码、用户名、用户 ID，供他人扫一扫添加自己为好友。
/// 二维码内容用 [MyQrPayload.encode] 编码当前 userId（约定格式 snowchat://user/{id}）。
/// 背景沿用个人中心暗色风格，二维码卡片使用白底保证可扫性。
class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  // 画布背景色（与个人中心 ProfileScreen 一致）
  static const Color _bgColor = Color(0xFF111111);
  // 卡片背景色
  static const Color _cardColor = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();

    // 当前用户 ID；未登录时展示占位
    final int? userId = auth.userId;
    final String username = auth.username ?? '-';
    // 头像占位字母取昵称首字
    final String nickname = auth.nickname ?? '';
    final String initials = nickname.isNotEmpty ? nickname.substring(0, 1) : 'U';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(l10n.myQrCode),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // === 白色二维码卡片 ===
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: userId == null
                  // 未登录不展示二维码（理论上到不了此页）
                  ? const SizedBox(
                      height: 240,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.black54),
                      ),
                    )
                  // 用 qr_flutter 生成二维码：data 为约定的 protocol 串
                  // 外层 Center 保证二维码在卡片内水平居中（默认靠左会偏左）
                  : Center(
                      child: QrImageView(
                        data: MyQrPayload.encode(userId),
                        version: QrVersions.auto,
                        size: 240,
                        // 显式指定深色模块与眼区颜色，保证可扫性（避免默认 color 为 null）
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          // 眼区使用黑色，提高识别率
                          color: Color(0xFF000000),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          // 数据区使用黑色模块
                          color: Color(0xFF000000),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // === 用户名 ===
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // 左侧头像占位
                  _buildAvatar(initials),
                  const SizedBox(width: 14),
                  // 右侧昵称 + @用户名
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname.isNotEmpty ? nickname : '-',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // === 用户 ID ===
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: Colors.grey, size: 22),
                  const SizedBox(width: 14),
                  // ID 标签 + 数值
                  Text(
                    '${l10n.userId}: $userId',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 圆形头像占位（首字母）
  Widget _buildAvatar(String initials) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFF3B82F6),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}