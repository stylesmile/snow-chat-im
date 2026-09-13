import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../widgets/avatar_widget.dart';
import 'settings_screen.dart';
import 'gender_select_screen.dart';
import 'favorites_screen.dart';

/// 个人中心 Tab（参考 WINCHAT 设计稿）
///
/// 布局结构：
/// 1. 无 AppBar，整体沉浸式深色背景（外层 HomeScreen 在该 tab 也不画标题栏）
/// 2. 顶部用户信息区：圆形头像 + 昵称 + @用户ID + 二维码按钮
/// 3. 分组卡片菜单：收藏/朋友圈、设置，图标取自对标项目 win-chat-android
///    的金色单色图标
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
/// [iconAsset] 图标资源路径（金色单色 PNG，渲染时按主题色染色）；
/// [iconSize] 图标绘制尺寸，对标项目里收藏/朋友圈为 28，其余为 24；
/// [label] 主文案；[subtitle] 副文案（可为空）
class ProfileMenuItem {
  final String iconAsset;
  final double iconSize;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const ProfileMenuItem({
    required this.iconAsset,
    this.iconSize = 24,
    required this.label,
    this.subtitle = '',
    this.onTap,
  });
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isUploading = false;
  // wechat_assets_picker 选图用；不再依赖 image_picker

  // 背景色（与 AppTheme.background 一致）
  static const Color _bgColor = Color(0xFF111111);
  // 卡片背景色（与 AppTheme.surface 一致）
  static const Color _cardColor = Color(0xFF1E1E1E);

  // ===========================================================================
  // 菜单图标（形状取自对标项目 win-chat-android 的「我的」页）
  // ===========================================================================

  /// 收藏：五角星
  static const String _iconCollect = 'assets/icons/profile/collect.png';

  /// 朋友圈：相机
  static const String _iconMoments = 'assets/icons/profile/moments.png';

  /// 设置：齿轮
  static const String _iconSettings = 'assets/icons/profile/settings.png';

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

            // === 性别入口（点击跳转到性别选择页面）===
            _buildGenderEntry(context, auth, l10n),
            const SizedBox(height: 12),

            // === 收藏 & 朋友圈 ===
            _buildMenuCard([
              ProfileMenuItem(
                iconAsset: _iconCollect,
                iconSize: 28,
                label: l10n.favorites,
                // 点击"收藏"跳转到"我的收藏"页面
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  );
                },
              ),
              ProfileMenuItem(
                iconAsset: _iconMoments,
                iconSize: 28,
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

  /// 构建性别入口卡片，点击跳转到性别选择页面
  ///
  /// 显示当前已选性别（男/女/未设置），与现有卡片风格保持一致。
  Widget _buildGenderEntry(
    BuildContext context,
    AuthProvider auth,
    AppLocalizations l10n,
  ) {
    // 将 gender 值转换为显示文案：null 或 0 显示"未设置"，1=男, 2=女
    final String displayText;
    if (auth.gender == 1) {
      displayText = l10n.genderMale;
    } else if (auth.gender == 2) {
      displayText = l10n.genderFemale;
    } else {
      displayText = l10n.unknown;
    }
    return InkWell(
      onTap: () {
        // 跳转到性别选择页面，传入当前性别值以便回显选中状态
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GenderSelectScreen(
              currentGender: auth.gender ?? 0,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // 性别图标：根据选中状态显示不同颜色
            Icon(
              auth.gender == 1
                  ? Icons.male
                  : auth.gender == 2
                      ? Icons.female
                      : Icons.person_outline,
              color: auth.gender == 1
                  ? const Color(0xFF3B82F6)
                  : auth.gender == 2
                      ? const Color(0xFFEC4899)
                      : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 14),
            // 性别标签文字
            Expanded(
              child: Text(
                l10n.gender,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            // 右侧显示当前值 + 箭头
            Text(
              displayText,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
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
      leading: _buildMenuIcon(item.iconAsset, item.iconSize),
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
      onTap: item.onTap ?? () {}, // 保留占位：未配 onTap 的菜单项暂不响应
    );
  }

  /// 菜单图标（对标项目风格的单色图标，无彩色底块）
  ///
  /// 用 [BlendMode.srcIn] 只取 PNG 的透明度通道并染成 [AppTheme.accent]，
  /// 因此换主题色只需改令牌，不必重新导出图片；与底部导航选中态同色。
  /// 外层固定 32x32 容器，保证「图标—文字」间距与分隔线缩进（64）保持稳定。
  Widget _buildMenuIcon(String assetPath, double size) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          color: AppTheme.accent,
          colorBlendMode: BlendMode.srcIn,
          filterQuality: FilterQuality.high,
        ),
      ),
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
        leading: _buildMenuIcon(_iconSettings, 24),
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

  /// 显示底部选图弹窗（从相册选择 / 取消）
  void _showAvatarPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadAvatar();
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

  /// 使用 wechat_assets_picker 选择图片并上传头像
  Future<void> _pickAndUploadAvatar() async {
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
    if (file == null) return;
    _doUploadAvatar(file);
  }

  /// 执行头像上传：上传 → 更新本地状态
  Future<void> _doUploadAvatar(File imageFile) async {
    setState(() => _isUploading = true);

    try {
      final profileService = context.read<ProfileService>();
      final auth = context.read<AuthProvider>();

      final result = await profileService.uploadAvatar(imageFile);
      if (result == null) {
        _showErrorSnackBar('头像上传失败，请重试');
        return;
      }

      // 后端独立接口已完成上传，直接更新本地头像 URL
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
