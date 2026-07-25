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

/// 个人中心独立页面（微信"我"风格，与 ProfileTab 同步改造）
///
/// 与 ProfileTab 布局一致，区别：保留 bottomNavigationBar 用于页面跳转。
/// 点击头像行触发底部弹窗选图 → 上传 → 更新头像闭环。
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// 是否正在上传头像（用于在头像上叠加 loading 指示器）
  bool _isUploading = false;

  /// ImagePicker 实例（复用，避免多次创建）
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    // 头像首字母（用于 AvatarWidget 占位显示）
    final nickname = auth.nickname ?? '';
    final initials = nickname.isNotEmpty ? nickname.substring(0, 1) : 'U';
    // username 展示文本（带 @ 前缀，微信风格）
    final usernameDisplay = auth.username != null && auth.username!.isNotEmpty
        ? '@${auth.username}'
        : '@-';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: ListView(
        children: [
          // === 1. 顶部头部行（微信风格，点击触发头像选择）===
          InkWell(
            onTap: _showAvatarPickerSheet, // 点击打开底部选图弹窗
            child: Container(
              color: theme.colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  // 左侧：头像（64x64，上传中叠加 CircularProgressIndicator）
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 头像本体
                      AvatarWidget(
                        imageUrl: auth.avatar,
                        initials: initials,
                        size: 64,
                      ),
                      // 上传中：半透明遮罩 + 旋转进度指示器
                      if (_isUploading) ...[
                        // 半透明黑色圆形遮罩
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
                  const SizedBox(width: 16),
                  // 中间：昵称 + @username
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 昵称（较大字体）
                        Text(
                          nickname.isNotEmpty ? nickname : '-',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // @username（较小灰色字体）
                        Text(
                          usernameDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onPrimaryContainer
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右侧：二维码 + 右箭头图标
                  Icon(Icons.qr_code_2, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: theme.colorScheme.onPrimaryContainer),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // === 2. 资料卡：微信号 + 个性签名 ===
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              children: [
                // 微信号（用 username 字段展示）
                ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: const Text('微信号'),
                  subtitle: Text(auth.username ?? '-'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {}, // 占位，后续接入编辑
                ),
                const Divider(height: 1, indent: 56),
                // 个性签名
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: Text(l10n.signature),
                  subtitle: const Text('未设置'), // AuthProvider 暂未持久化 signature
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {}, // 占位，后续接入编辑
                ),
              ],
            ),
          ),

          // === 3. 设置区 ===
          // 语言切换
          ExpansionTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            children: settings.availableLocales.map((localeInfo) {
              final isSelected = settings.locale.languageCode == localeInfo.locale.languageCode &&
                  settings.locale.countryCode == localeInfo.locale.countryCode;
              return RadioListTile<String>(
                title: Text('${localeInfo.flag} ${settings.getLocaleName(localeInfo.locale)}'),
                value: localeInfo.locale.languageCode,
                groupValue: isSelected ? settings.locale.languageCode : null,
                onChanged: (value) {
                  if (value != null) {
                    settings.setLocale(localeInfo.locale);
                  }
                },
              );
            }).toList(),
          ),
          const Divider(height: 1),

          // 隐私
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(l10n.privacy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),
          // 关于
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            subtitle: const Text('v1.0.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),

          // 退出登录
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(l10n.logout),
                  content: Text(l10n.logout),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(l10n.cancel),
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
      ),
      // 保留底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.chat), label: l10n.chat),
          BottomNavigationBarItem(icon: const Icon(Icons.people), label: l10n.contacts),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: l10n.profile),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pop();
          } else if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactTab()));
          }
        },
      ),
    );
  }

  /// 显示底部选图弹窗（拍照 / 从相册选择 / 取消）
  void _showAvatarPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min, // 高度自适应内容
            children: [
              // 选项 1：拍照
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(sheetContext); // 先关闭弹窗
                  _pickAndUpload(ImageSource.camera); // 再调起相机
                },
              ),
              const Divider(height: 1),
              // 选项 2：从相册选择
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(sheetContext); // 先关闭弹窗
                  _pickAndUpload(ImageSource.gallery); // 再打开相册
                },
              ),
              const Divider(height: 1),
              // 选项 3：取消
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('取消'),
                onTap: () => Navigator.pop(sheetContext), // 直接关闭弹窗
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
    // --- 1. 选图 ---
    final XFile? picked = await _imagePicker.pickImage(
      source: source, // 相机或相册
      maxWidth: 512, // 限制宽度，避免上传过大文件
      imageQuality: 80, // 压缩质量 80%
    );
    if (picked == null) {
      // 用户取消选择，不做任何处理
      return;
    }
    final File imageFile = File(picked.path); // XFile → File

    // --- 进入上传状态 ---
    setState(() {
      _isUploading = true; // 显示 loading 遮罩
    });

    try {
      // 从 Provider 树读取依赖
      final profileService = context.read<ProfileService>();
      final auth = context.read<AuthProvider>();

      // --- 2. 上传到对象存储 ---
      final result = await profileService.uploadAvatar(imageFile);
      if (result == null) {
        // 上传失败：提示用户
        _showErrorSnackBar('头像上传失败，请重试');
        return;
      }

      // --- 3. 更新远端资料（把对象 key 存入 DB） ---
      final userId = auth.userId;
      if (userId == null) {
        _showErrorSnackBar('用户未登录，无法更新头像');
        return;
      }
      final updated = await profileService.updateProfile(
        userId,
        avatar: result.key, // 存 key（avatars/uuid.jpg），后端 info 端点会转成 pre-signed URL
      );
      if (!updated) {
        _showErrorSnackBar('资料更新失败，请重试');
        return;
      }

      // --- 4. 更新本地状态（用 url 立即展示新头像） ---
      await auth.updateAvatar(result.url);

      // 成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像更新成功')),
        );
      }
    } catch (e) {
      // 异常兜底
      _showErrorSnackBar('头像更新失败：$e');
    } finally {
      // --- 退出上传状态 ---
      if (mounted) {
        setState(() {
          _isUploading = false; // 隐藏 loading 遮罩
        });
      }
    }
  }

  /// 显示错误 SnackBar
  void _showErrorSnackBar(String message) {
    if (!mounted) return; // widget 已销毁时不操作 context
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
