import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../widgets/avatar_widget.dart';
import 'gender_select_screen.dart';
import 'my_qr_screen.dart';
import 'scan_screen.dart';

/// 个人信息页
///
/// 个人中心顶部的用户信息卡片点击后进入本页，集中展示与修改个人资料：
/// - 头像：点击从相册选择并上传
/// - 昵称 / 用户名：点击弹窗编辑，后端写入后同步本地登录态
/// - 性别：跳转性别选择页
/// - 我的二维码：展示本人二维码供他人扫码添加
/// - 扫一扫：扫码添加好友
///
/// 所有字段都从 [AuthProvider] 读取，修改成功后通过
/// [AuthProvider.updateProfile] 回写，保证返回上一页立即生效。
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();

    final nickname = auth.nickname ?? '';
    final initials = nickname.isNotEmpty ? nickname.substring(0, 1) : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人信息'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // === 头像 ===
          _buildCard(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const Text('头像', style: TextStyle(fontSize: 15, color: Colors.white70)),
                trailing: Stack(
                  alignment: Alignment.center,
                  children: [
                    AvatarWidget(
                      imageUrl: auth.avatar,
                      initials: initials,
                      size: 52,
                    ),
                    if (_isUploading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                  ],
                ),
                onTap: _isUploading ? null : _pickAndUploadAvatar,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // === 昵称 / 用户名 / 性别 ===
          _buildCard(
            children: [
              _buildEditableTile(
                label: l10n.nickname,
                value: nickname.isEmpty ? '-' : nickname,
                onTap: () => _showEditDialog(
                  title: l10n.nickname,
                  initialValue: nickname,
                  field: 'nickname',
                ),
              ),
              _divider(),
              _buildEditableTile(
                label: l10n.gender,
                value: _genderText(auth.gender, l10n),
                onTap: () async {
                  // 性别选择页保存成功后会回写 AuthProvider，这里只需等待返回
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GenderSelectScreen(currentGender: auth.gender ?? 0),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // === 二维码 / 扫一扫 ===
          _buildCard(
            children: [
              _buildActionTile(
                icon: Icons.qr_code_2,
                label: l10n.myQrCode,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyQrScreen()),
                  );
                },
              ),
              _divider(),
              _buildActionTile(
                icon: Icons.qr_code_scanner,
                label: l10n.scan,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 分组卡片容器
  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  /// 卡片内的分隔线（左侧缩进，避免压在标题文字下方）
  Widget _divider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }

  /// 可编辑的资料项：左侧标签、右侧当前值 + 箭头
  Widget _buildEditableTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label, style: const TextStyle(fontSize: 15, color: Colors.white70)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontSize: 14, color: Colors.white)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }

  /// 带图标的动作项（二维码 / 扫一扫）
  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: AppTheme.accent, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 15, color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
      onTap: onTap,
    );
  }

  /// 性别值转文案
  String _genderText(int? gender, AppLocalizations l10n) {
    if (gender == 1) return l10n.genderMale;
    if (gender == 2) return l10n.genderFemale;
    return l10n.unknown;
  }

  /// 弹出编辑框，确认后写入后端并同步本地
  ///
  /// [field] 取值 nickname / username，决定提交给后端的字段。
  Future<void> _showEditDialog({
    required String title,
    required String initialValue,
    required String field,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialValue == '-' ? '' : initialValue);
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;

    final newValue = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: title,
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.confirm, style: const TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );

    // 用户取消或内容未变化：不发起请求
    if (newValue == null || newValue.isEmpty || newValue == initialValue) return;
    if (!mounted) return;

    final ok = await ProfileService(auth.apiClient).updateProfile(
      userId,
      nickname: field == 'nickname' ? newValue : null,
      username: field == 'username' ? newValue : null,
    );
    if (!mounted) return;
    if (ok) {
      await auth.updateProfile(
        nickname: field == 'nickname' ? newValue : null,
        username: field == 'username' ? newValue : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdated)),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请重试')),
      );
    }
  }

  /// 从相册选择头像并上传
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
    await _doUploadAvatar(file);
  }

  /// 执行头像上传
  Future<void> _doUploadAvatar(File imageFile) async {
    setState(() => _isUploading = true);
    try {
      final auth = context.read<AuthProvider>();
      final result = await ProfileService(auth.apiClient).uploadAvatar(imageFile);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像上传失败，请重试')),
        );
        return;
      }
      await auth.updateAvatar(result.url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像更新成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像更新失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
