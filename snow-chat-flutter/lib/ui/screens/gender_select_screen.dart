import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

/// 性别选择页面
///
/// 用户在此页面选择性别（男 / 女），确认后自动保存并提交到后端，
/// 然后导航返回上一页。
class GenderSelectScreen extends StatefulWidget {
  /// 已选中的性别值（0 = 未设置, 1 = 男, 2 = 女）。
  final int currentGender;

  const GenderSelectScreen({
    super.key,
    required this.currentGender,
  });

  @override
  State<GenderSelectScreen> createState() => _GenderSelectScreenState();
}

class _GenderSelectScreenState extends State<GenderSelectScreen> {
  /// 当前选中的性别值，默认从页面参数中读取
  late int _selectedGender;

  @override
  void initState() {
    super.initState();
    // 从传入参数初始化当前选中性别
    // 若用户从未设置过性别，_selectedGender 默认为 0（未设置）
    _selectedGender = widget.currentGender;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.genderSelect),
        leading: const BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 性别选项：男
          _buildGenderTile(
            context: context,
            l10n: l10n,
            auth: auth,
            label: l10n.genderMale,
            value: 1,
            icon: Icons.male,
          ),
          const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),
          // 性别选项：女
          _buildGenderTile(
            context: context,
            l10n: l10n,
            auth: auth,
            label: l10n.genderFemale,
            value: 2,
            icon: Icons.female,
          ),
        ],
      ),
    );
  }

  /// 构建单个性别选项卡片
  ///
  /// 使用 [SwitchListTile] 实现二选一交互：选中即立即提交并返回上一页。
  Widget _buildGenderTile({
    required BuildContext context,
    required AppLocalizations l10n,
    required AuthProvider auth,
    required String label,
    required int value,
    required IconData icon,
  }) {
    return SwitchListTile(
      // value 为 true 表示此选项被选中（_selectedGender == value）
      value: _selectedGender == value,
      onChanged: (bool newVal) async {
        // 使用 localContext 捕获当前 BuildContext，避免 async gap 跨 context 问题
        final localContext = context;
        if (!newVal || !mounted) return;
        // 用户选中后，立即更新本地状态并持久化
        // setGender 内部会调用后端 PUT /chat/user/profile 接口保存性别
        setState(() => _selectedGender = value);
        await auth.setGender(value);
        // 保存成功后返回上一页
        if (localContext.mounted) Navigator.pop(localContext);
      },
      title: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
      activeThumbColor: Theme.of(context).colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
