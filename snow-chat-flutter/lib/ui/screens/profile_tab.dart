import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../widgets/avatar_widget.dart';
import 'settings_screen.dart';

/// 个人中心 Tab（参考 WINCHAT 设计稿）
///
/// 布局结构：
/// 1. 无 AppBar，整体沉浸式深色背景
/// 2. 顶部用户信息区：圆形头像 + 昵称 + @用户ID + 二维码按钮
/// 3. 分组卡片菜单：钱包、收藏/朋友圈、设置
/// 4. 退出登录（红色，单独放置）
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

// ---------------------------------------------------------------------------
// 菜单数据结构
// ---------------------------------------------------------------------------
/// 菜单项数据模型
/// [iconColor] 图标的彩色背景色；[label] 主文案；[subtitle] 副文案（可为空）
class ProfileMenuItem {
  final Color iconColor;
  final String label;
  final String subtitle;

  const ProfileMenuItem({
    required this.iconColor,
    required this.label,
    this.subtitle = '',
  });
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isUploading = false;
  final ImagePicker _imagePicker = ImagePicker();

  // 背景色（与 AppTheme.background 一致）
  static const Color _bgColor = Color(0xFF111111);
  // 卡片背景色（与 AppTheme.surface 一致）
  static const Color _cardColor = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();

    // 头像占位首字母
    final nickname = auth.nickname ?? '';
    final initials = nickname.isNotEmpty ? nickname.substring(0, 1) : 'U';

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // === 顶部用户信息区 ===
            _buildHeaderSection(context, auth, initials, nickname),
            const SizedBox(height: 16),

            // === 钱包 & WIN卡 ===
            _buildMenuCard([
              ProfileMenuItem(
                iconColor: const Color(0xFF00C8E8),
                label: l10n.wallet,
                subtitle: l10n.encryptedAssets,
              ),
              ProfileMenuItem(
                iconColor: const Color(0xFF3B82F6),
                label: l10n.winCard,
                subtitle: l10n.usdtExchange,
              ),
            ]),
            const SizedBox(height: 12),

            // === 收藏 & 朋友圈 ===
            _buildMenuCard([
              ProfileMenuItem(
                iconColor: const Color(0xFFFFB800),
                label: l10n.favorites,
              ),
              ProfileMenuItem(
                iconColor: const Color(0xFFEA580C),
                label: l10n.moments,
              ),
            ]),
            const SizedBox(height: 12),

            // === 设置（点击进入子页面）===
            _buildSettingTile(context, l10n),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 布局构建方法
  // ===========================================================================

  /// 构建顶部用户信息区域（头像 + 昵称 + ID + 二维码按钮）
  Widget _buildHeaderSection(
    BuildContext context,
    AuthProvider auth,
    String initials,
    String nickname,
  ) {
    if (auth.userId == null) return const SizedBox.shrink();

    return InkWell(
      onTap: _showAvatarPickerSheet,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // 圆形头像（64x64，上传中叠加 loading）
            Stack(
              alignment: Alignment.center,
              children: [
                AvatarWidget(
                  imageUrl: auth.avatar,
                  initials: initials,
                  size: 64,
                ),
                if (_isUploading) ...[
                  // 上传中：半透明遮罩
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // 白色旋转进度指示器
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 14),
            // 昵称 + 用户ID
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 昵称
                  Text(
                    nickname.isNotEmpty ? nickname : '-',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // @username + 锁图标
                  Row(
                    children: [
                      Text(
                        '@${auth.username ?? '-'}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.lock_open, size: 14, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            // 二维码 + 箭头
            const Icon(Icons.qr_code_2, color: Colors.grey, size: 24),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  /// 构建分组菜单卡片
  Widget _buildMenuCard(List<ProfileMenuItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items.map((item) {
          final isLast = item == items.last;
          return Column(
            children: [
              _buildIconMenuItem(item),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 64,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 构建单个带彩色图标的菜单项
  Widget _buildIconMenuItem(ProfileMenuItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildColoredIcon(item.iconColor),
      title: Text(
        item.label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: item.subtitle.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
              ],
            )
          : const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: () {}, // 占位，后续接入具体功能
    );
  }

  /// 纯色背景圆角方块图标
  Widget _buildColoredIcon(Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.apps, color: Colors.white, size: 18),
    );
  }

  /// 构建"设置"条目（点击跳转到 SettingsScreen）
  Widget _buildSettingTile(BuildContext context, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _buildColoredIcon(const Color(0xFF6B7280)),
        title: Text(
          l10n.settingsMenu,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 头像选择与上传逻辑
  // ===========================================================================

  /// 显示底部选图弹窗（拍照 / 从相册选择 / 取消）
  void _showAvatarPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUpload(ImageSource.camera);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUpload(ImageSource.gallery);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('取消'),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 选图 + 上传头像 + 更新资料的完整流程
  Future<void> _pickAndUpload(ImageSource source) async {
    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    final File imageFile = File(picked.path);
    setState(() => _isUploading = true);

    try {
      final profileService = context.read<ProfileService>();
      final auth = context.read<AuthProvider>();

      final result = await profileService.uploadAvatar(imageFile);
      if (result == null) {
        _showErrorSnackBar('头像上传失败，请重试');
        return;
      }

      // 后端独立接口已完成上传+存DB，直接更新本地头像 URL
      await auth.updateAvatar(result.url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像更新成功')),
        );
      }
    } catch (e) {
      _showErrorSnackBar('头像更新失败：$e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  /// 显示错误 SnackBar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
