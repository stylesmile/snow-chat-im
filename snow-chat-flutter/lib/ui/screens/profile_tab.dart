import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../widgets/avatar_widget.dart';
import 'login_screen.dart';

/// 个人中心 Tab（参考 WINCHAT 设计稿）
///
/// 布局结构：
/// 1. 无 AppBar，整体沉浸式深色背景
/// 2. 顶部用户信息区：圆形头像 + 昵称 + @用户ID + 二维码按钮
/// 3. 分组卡片菜单：
///    - 钱包组：钱包（加密资产）+ WIN卡（USDT交易所卡）
///    - 社交组：收藏 + 朋友圈
///    - 其他：设置
/// 4. 底部导航栏（固定金色高亮当前页）
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

// ---------------------------------------------------------------------------
// 菜单数据结构（持有图标颜色与文案，供 ListView.builder 渲染）
// ---------------------------------------------------------------------------
/// 菜单项数据模型
/// [iconColor] 图标的彩色背景色；[label] 主文案；[subtitle] 副文案（可为空）
class ProfileMenuItem {
  final Color iconColor;   // 图标彩色背景
  final String label;      // 主标题文案
  final String subtitle;   // 副标题文案（可为空）

  const ProfileMenuItem({
    required this.iconColor,
    required this.label,
    this.subtitle = '',
  });
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isUploading = false;
  final ImagePicker _imagePicker = ImagePicker();

  // 背景色（与 AppTheme.background 一致，避免硬编码）
  static const Color _bgColor = Color(0xFF111111);
  // 卡片背景色（与 AppTheme.surface 一致，略浅于背景）
  static const Color _cardColor = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();

    // 头像占位首字母（头像未加载时用昵称首字母）
    final nickname = auth.nickname ?? '';
    final initials = nickname.isNotEmpty ? nickname.substring(0, 1) : 'U';

    return Scaffold(
      backgroundColor: _bgColor, // 页面整体深底
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // === 顶部用户信息区 ===
            _buildHeaderSection(context, auth, initials, l10n, nickname),
            const SizedBox(height: 16),

            // === 第一组：钱包 & WIN卡 ===
            _buildMenuCard([
              ProfileMenuItem(
                iconColor: const Color(0xFF00C8E8), // 青色（加密资产风格）
                label: l10n.wallet,
                subtitle: l10n.encryptedAssets,
              ),
              ProfileMenuItem(
                iconColor: const Color(0xFF3B82F6), // 蓝色（金融卡风格）
                label: l10n.winCard,
                subtitle: l10n.usdtExchange,
              ),
            ]),
            const SizedBox(height: 12),

            // === 第二组：收藏 & 朋友圈 ===
            _buildMenuCard([
              ProfileMenuItem(
                iconColor: const Color(0xFFFFB800), // 金色（收藏星标风格）
                label: l10n.favorites,
              ),
              ProfileMenuItem(
                iconColor: const Color(0xFFEA580C), // 橙琥珀色（社交动态风格）
                label: l10n.moments,
              ),
            ]),
            const SizedBox(height: 12),

            // === 第三组：设置 ===
            _buildMenuCard([
              ProfileMenuItem(
                iconColor: const Color(0xFF6B7280), // 灰色（设置齿轮风格）
                label: l10n.settingsMenu,
              ),
            ]),
            const SizedBox(height: 12),

            // === 语言切换（内嵌在设置项内或单独列出）===
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

            // === 退出登录（红色文字，单独放置）===
            _buildLogoutTile(auth, l10n),
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
    AppLocalizations l10n,
    String nickname,
  ) {
    // 确保 auth 已登录（userId 存在），否则返回空占位
    if (auth.userId == null) return const SizedBox.shrink();

    return InkWell(
      onTap: _showAvatarPickerSheet, // 点击触发头像选择弹窗
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // 左侧：圆形头像（64x64，上传中叠加 loading）
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
                      color: Colors.black.withOpacity(0.4),
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
            // 中间：昵称 + 用户ID（带复制提示小图标）
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 昵称：粗体大字
                  Text(
                    nickname.isNotEmpty ? nickname : '-',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 用户ID行：@username + 小锁图标（示意私密标识）
                  Row(
                    children: [
                      Text(
                        '@${auth.username ?? '-'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 小锁图标：暗示账号安全状态
                      const Icon(
                        Icons.lock_open,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 右侧：二维码按钮 + 箭头
            const Icon(Icons.qr_code_2, color: Colors.grey, size: 24),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  /// 构建一组菜单卡片（圆角卡片容器，内含多个 ListTile）
  ///
  /// [items] 该卡片内包含的菜单项列表
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
              // 分割线：最后一项不显示
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
                // 副标题（如"加密资产"）
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

  /// 构建纯色背景圆形图标（模拟设计稿中的彩色小方块图标）
  Widget _buildColoredIcon(Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.apps, color: Colors.white, size: 18),
      // 实际使用时可替换为具体 SVG/PNG 图标
    );
  }

  /// 构建普通 ListTile（无彩色图标，带 chevron）
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

  /// 构建语言切换 ExpansionTile
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
            // 判断当前是否选中该项
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

  /// 构建退出登录 ListTile（红色文字，带确认弹窗）
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
  ///
  /// 流程：
  /// 1. 调用 ImagePicker.pickImage 获取图片文件
  /// 2. 调用 ProfileService.uploadAvatar 上传到对象存储，拿到 {key, url}
  /// 3. 调用 ProfileService.updateProfile 把 key 存到后端 DB
  /// 4. 调用 AuthProvider.updateAvatar 用 url 立即刷新本地头像
  /// 5. 任意步骤失败则显示 SnackBar 错误提示
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

  /// 显示错误 SnackBar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
