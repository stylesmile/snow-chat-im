import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

/// 性别选择页面
///
/// 用户在此页面选择性别（男 / 女），确认后自动保存并提交到后端，
/// 然后导航返回上一页。
///
/// UI 设计要点：
/// - 使用大尺寸卡片 + 渐变图标背景，增强视觉层次感
/// - 选中状态添加主题色边框和阴影，形成明确的选中反馈
/// - Switch 控件替换为整行点击区域，提升触控体验
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

class _GenderSelectScreenState extends State<GenderSelectScreen>
    with SingleTickerProviderStateMixin {
  /// 当前选中的性别值，默认从页面参数中读取
  late int _selectedGender;

  /// 选中动画控制器，用于切换时的微动效
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // 从传入参数初始化当前选中性别
    // 若用户从未设置过性别，_selectedGender 默认为 0（未设置）
    _selectedGender = widget.currentGender;
    // 初始化动画控制器，用于选项切换时的过渡动效
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        children: [
          // 性别选项：男
          _buildGenderCard(
            context: context,
            l10n: l10n,
            auth: auth,
            label: l10n.genderMale,
            value: 1,
            icon: Icons.male,
            iconBgColor: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          // 性别选项：女
          _buildGenderCard(
            context: context,
            l10n: l10n,
            auth: auth,
            label: l10n.genderFemale,
            value: 2,
            icon: Icons.female,
            iconBgColor: const Color(0xFFEC4899),
          ),
        ],
      ),
    );
  }

  /// 构建单个性别选项卡片
  ///
  /// 使用圆角卡片包裹，选中时添加主题色边框和阴影，
  /// 图标使用彩色圆形背景，提升视觉辨识度。
  Widget _buildGenderCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required AuthProvider auth,
    required String label,
    required int value,
    required IconData icon,
    required Color iconBgColor,
  }) {
    // 判断当前选项是否被选中
    final isSelected = _selectedGender == value;
    return InkWell(
      // 点击区域覆盖整个卡片，提供足够的触控面积（>= 48px）
      onTap: () async {
        // 用户选中后，立即更新本地状态并持久化
        // setGender 内部会调用后端 PUT /chat/user/profile 接口保存性别
        if (isSelected) return; // 已选中则不重复提交
        setState(() => _selectedGender = value);
        // 播放选中动画
        _animationController.forward().then((_) => _animationController.reverse());
        await auth.setGender(value);
        // 保存成功后返回上一页，使用 capturedContext 避免 async gap 问题
        if (context.mounted) Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          // 选中状态添加主题色边框和阴影
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // 图标：彩色圆形背景 + 白色图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? iconBgColor
                    : iconBgColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // 标签文字
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            // 选中状态显示对勾图标
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              )
            else
              Icon(
                Icons.circle_outlined,
                color: Colors.grey.withValues(alpha: 0.5),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
