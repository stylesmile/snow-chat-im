import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../widgets/avatar_widget.dart';
import 'contact_tab.dart';
import 'login_screen.dart';

/// 个人中心独立页面（WINCHAT 设计稿风格）
///
/// 与 ProfileTab 布局一致，区别：保留 bottomNavigationBar 用于页面跳转。
/// 点击头像行触发底部弹窗选图 → 上传 → 更新头像闭环。
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
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

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  final ImagePicker _imagePicker = ImagePicker();

  static const Color _bgColor = Color(0xFF111111);
  static const Color _cardColor = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();

    // 头像占位首字母
    final nickname = auth.nickname ?? '';
    final initials = nickname.isNotEmpty ? nickname.substring(0, 1) : 'U';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(l10n.profile),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // === 顶部用户信息区 ===
            _buildHeaderSection(context, auth, initials, l10n),
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

            // === 设置 ===
            _buildMenuCard([
              ProfileMenuItem(
                iconColor: const Color(0xFF6B7280),
                label: l10n.settingsMenu,
              ),
            ]),
            const SizedBox(height: 12),

            // === 语言切换 ===
            _buildLanguageTile(settings, l10n),
            const SizedBox(height: 12),

            // === 隐私 ===
            _buildSimpleTile(
              iconColor: const Color(0xFF6B7280),
              label: l10n.privacy,
              onTap: () {},
            ),
            const SizedBox(height: 12),

            // === 关于 ===
            _buildSimpleTile(
              iconColor: const Color(0xFF6B7280),
              label: l10n.about,
              subtitle: 'v1.0.0',
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // === 退出登录 ===
            _buildLogoutTile(auth, l10n),
          ],
        ),
      ),
      // 底部导航栏（仅在此页面显示）
      bottomNavigationBar: _buildBottomNav(context, l10n),
    );
  }

  // ===========================================================================
  // 布局构建方法
  // ===========================================================================

  /// 构建顶部用户信息区域
  Widget _buildHeaderSection(
    BuildContext context,
    AuthProvider auth,
    String initials,
    AppLocalizations l10n,
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
            // 圆形头像
            Stack(
              alignment: Alignment.center,
              children: [
                AvatarWidget(
                  imageUrl: auth.avatar,
                  initials: initials,
                  size: 64,
                ),
                if (_isUploading) ...[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
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
                  Text(
                    initials.isNotEmpty ? initials : '-',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
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

  /// 构建一组菜单卡片
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

  /// 构建带彩色图标的单个菜单项
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
      onTap: () {},
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

  /// 普通 ListTile
  Widget _buildSimpleTile({
    required Color iconColor,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          leading: _buildColoredIcon(iconColor),
          title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          trailing: subtitle != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                  ],
                )
              : const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          onTap: onTap,
        ),
        const Divider(height: 1, indent: 64, color: Color(0x0FFFFFFF)),
      ],
    );
  }

  /// 语言切换 ExpansionTile
  Widget _buildLanguageTile(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      children: [
        ExpansionTile(
          leading: const Icon(Icons.language, color: Colors.grey, size: 24),
          title: Text(
            l10n.language,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          children: settings.availableLocales.map((localeInfo) {
            final isSelected = settings.locale.languageCode == localeInfo.locale.languageCode &&
                settings.locale.countryCode == localeInfo.locale.countryCode;
            return RadioListTile<String>(
              title: Text(
                '${localeInfo.flag} ${settings.getLocaleName(localeInfo.locale)}',
                style: const TextStyle(color: Colors.white70),
              ),
              value: localeInfo.locale.languageCode,
              groupValue: isSelected ? settings.locale.languageCode : null,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  settings.setLocale(localeInfo.locale);
                }
              },
            );
          }).toList(),
        ),
        const Divider(height: 1, indent: 64, color: Color(0x0FFFFFFF)),
      ],
    );
  }

  /// 退出登录 ListTile
  Widget _buildLogoutTile(AuthProvider auth, AppLocalizations l10n) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red, size: 24),
          title: Text(
            l10n.logout,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: _cardColor,
                title: Text(l10n.logout, style: const TextStyle(color: Colors.white)),
                content: Text(l10n.logout, style: const TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      auth.logout();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text(l10n.confirm),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// 底部导航栏
  Widget _buildBottomNav(BuildContext context, AppLocalizations l10n) {
    return BottomNavigationBar(
      currentIndex: 2,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.black,
      selectedItemColor: const Color(0xFFFFB800),
      unselectedItemColor: Colors.white54,
      items: [
        BottomNavigationBarItem(
          icon: Image.asset('assets/images/navigation/chat.png', width: 24, height: 24),
          activeIcon: Image.asset('assets/images/navigation/chat_s.png', width: 24, height: 24),
          label: l10n.chat,
        ),
        BottomNavigationBarItem(
          icon: Image.asset('assets/images/navigation/contract.png', width: 24, height: 24),
          activeIcon: Image.asset('assets/images/navigation/contract_s.png', width: 24, height: 24),
          label: l10n.contacts,
        ),
        BottomNavigationBarItem(
          icon: Image.asset('assets/images/navigation/my.png', width: 24, height: 24),
          activeIcon: Image.asset('assets/images/navigation/my_s.png', width: 24, height: 24),
          label: l10n.profile,
        ),
      ],
      onTap: (index) {
        if (index == 0) {
          Navigator.of(context).pop(); // 返回 HomeScreen
        } else if (index == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactTab()));
        }
      },
    );
  }

  // ===========================================================================
  // 头像选择与上传
  // ===========================================================================

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

      final userId = auth.userId;
      if (userId == null) {
        _showErrorSnackBar('用户未登录，无法更新头像');
        return;
      }

      final updated = await profileService.updateProfile(
        userId,
        avatar: result.key,
      );
      if (!updated) {
        _showErrorSnackBar('资料更新失败，请重试');
        return;
      }

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

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
