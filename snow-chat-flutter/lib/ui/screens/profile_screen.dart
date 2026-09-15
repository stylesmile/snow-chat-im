import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../widgets/avatar_widget.dart';
import 'contact_tab.dart';
import 'settings_screen.dart';
import 'gender_select_screen.dart';
import 'my_qr_screen.dart';
import 'scan_screen.dart';

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
  // wechat_assets_picker 选图用；不再依赖 image_picker

  static const Color _bgColor = Color(0xFF111111);
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
            _buildHeaderSection(context, auth, initials, nickname),
            const SizedBox(height: 16),

            // === 性别入口（点击跳转到性别选择页面）===
            _buildGenderEntry(context, auth, l10n),
            const SizedBox(height: 12),

            // === 扫一扫 & 我的二维码（扫码添加好友 / 展示本人二维码）===
            _buildScanSection(context, l10n),
            const SizedBox(height: 12),

            // === 收藏（朋友圈入口已隐藏）===
            _buildMenuCard([
              ProfileMenuItem(
                iconColor: const Color(0xFFFFB800),
                label: l10n.favorites,
              ),
            ]),
            const SizedBox(height: 12),

            // === 设置（点击进入子页面）===
            _buildSettingTile(context, l10n),
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
    String nickname,
  ) {
    if (auth.userId == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () {
        // 点击头像行时上传头像
        _showAvatarPickerSheet();
      },
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
            // 二维码（点击进入"我的二维码"页）+ 箭头
            GestureDetector(
              onTap: () {
                // 跳转到我的二维码展示页
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyQrScreen()),
                );
              },
              child: const Icon(Icons.qr_code_2, color: Colors.grey, size: 24),
            ),
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

  /// 构建"扫一扫"与"我的二维码"入口卡片
  ///
  /// 置于性别下方，包含两个菜单项：
  /// - 扫一扫：跳转 [ScanScreen]，用相机扫二维码添加好友
  /// - 我的二维码：跳转 [MyQrScreen]，展示本人二维码供他人扫描
  Widget _buildScanSection(BuildContext context, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      // 组合两个入口项，中间用分隔线隔开
      child: Column(
        children: [
          // 扫一扫入口
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: _buildColoredIcon(const Color(0xFF3B82F6)),
            title: Text(
              l10n.scan,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            onTap: () {
              // 跳转到扫码页
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanScreen()),
              );
            },
          ),
          Divider(
            height: 1,
            indent: 64,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          // 我的二维码入口
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: _buildColoredIcon(const Color(0xFF10B981)),
            title: Text(
              l10n.myQrCode,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            onTap: () {
              // 跳转到我的二维码展示页
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyQrScreen()),
              );
            },
          ),
        ],
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

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
