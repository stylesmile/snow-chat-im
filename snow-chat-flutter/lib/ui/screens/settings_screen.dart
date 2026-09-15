import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import 'language_settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'sqlite_browser_screen.dart';
import 'chat_background_screen.dart';
import '../../services/cache_cleaner.dart';

/// 设置页面（从个人中心"设置"入口进入）
///
/// 包含：语言切换、隐私、关于、退出登录
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _cardColor = Color(0xFF1E1E1E);
  // 版本号从 PackageInfo 动态获取，避免硬编码
  String _version = '';
  // 关于快速点击检测：10秒内点击 5 次触发 SQLite 浏览器（调试入口）
  int _aboutTapCount = 0;
  Timer? _aboutTapTimer;

  @override
  void initState() {
    super.initState();
    // 异步加载版本号，不阻塞首帧渲染
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.settingsMenu),
        leading: const BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // === 语言切换 ===
          _buildLanguageTile(settings, l10n),
          const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),

          // === 新消息通知设置 ===
          _buildNotificationSection(settings),
          const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),

          // === 通用设置（聊天背景 + 清理缓存） ===
          _buildGeneralSection(l10n),
          const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),

          // === 隐私 ===
          _buildSimpleTile(
            iconColor: const Color(0xFF6B7280),
            label: l10n.privacy,
            onTap: () {},
          ),
          const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),

          // === 关于 ===
          _buildSimpleTile(
            iconColor: const Color(0xFF6B7280),
            label: l10n.about,
            subtitle: _version.isEmpty ? '' : 'v$_version',
            onTap: () => _handleAboutTap(),
          ),
          const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),

          // === 退出登录 ===
          const SizedBox(height: 8),
          _buildLogoutTile(auth, l10n),
        ],
      ),
    );
  }

  /// 通用设置区：聊天背景 + 清理缓存
  Widget _buildGeneralSection(AppLocalizations l10n) {
    return Column(
      children: [
        // 聊天背景入口：进入独立设置页（选图/恢复默认）
        ListTile(
          leading: const Icon(Icons.wallpaper, color: Colors.grey, size: 24),
          title: Text(
            l10n.chatBackground,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatBackgroundScreen()),
            );
          },
        ),
        const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),
        // 清理缓存入口：计算并清理临时/图片缓存
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined, color: Colors.grey, size: 24),
          title: Text(
            l10n.clearCache,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          onTap: () => _confirmClearCache(l10n),
        ),
      ],
    );
  }

  /// 清理缓存：先弹窗确认，再调用 [CacheCleaner] 清理并提示
  Future<void> _confirmClearCache(AppLocalizations l10n) async {
    // 确认弹窗，避免误触清空缓存
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(l10n.clearCache, style: const TextStyle(color: Colors.white)),
        content: Text(l10n.confirm, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 执行清理（清理临时目录与图片缓存）
    await CacheCleaner().clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.clearCacheDone)),
    );
  }

  /// 新消息通知设置区：总开关 + 提示音 + 震动
  Widget _buildNotificationSection(SettingsProvider settings) {
    // 通知总开关关闭时，提示音/震动子项禁用（置灰）
    final masterOn = settings.notificationEnabled;
    return Column(
      children: [
        // 新消息通知总开关
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined, color: Colors.grey, size: 24),
          title: const Text('新消息通知', style: TextStyle(color: Colors.white, fontSize: 16)),
          value: masterOn,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          onChanged: (value) => settings.setNotificationEnabled(value),
        ),
        const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),
        // 提示音开关
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_outlined, color: Colors.grey, size: 24),
          title: Text(
            '通知提示音',
            style: TextStyle(color: masterOn ? Colors.white : Colors.white30, fontSize: 16),
          ),
          value: masterOn && settings.soundEnabled,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          onChanged: masterOn
              ? (value) => settings.setSoundEnabled(value)
              : null, // 总开关关闭时禁用
        ),
        const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),
        // 震动开关
        SwitchListTile(
          secondary: const Icon(Icons.vibration, color: Colors.grey, size: 24),
          title: Text(
            '通知震动',
            style: TextStyle(color: masterOn ? Colors.white : Colors.white30, fontSize: 16),
          ),
          value: masterOn && settings.vibrateEnabled,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          onChanged: masterOn
              ? (value) => settings.setVibrateEnabled(value)
              : null, // 总开关关闭时禁用
        ),
      ],
    );
  }

  /// 语言入口：显示当前语言，点击进入独立的语言设置页
  Widget _buildLanguageTile(SettingsProvider settings, AppLocalizations l10n) {
    return ListTile(
      leading: const Icon(Icons.language, color: Colors.grey, size: 24),
      title: Text(
        l10n.language,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            settings.getLocaleName(settings.locale),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
        );
      },
    );
  }

  /// 构建普通 ListTile（带彩色图标和 chevron）
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
      ],
    );
  }

  /// 纯色背景圆角方块图标
  Widget _buildColoredIcon(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.apps, color: Colors.white, size: 14),
    );
  }

  /// 构建退出登录 ListTile（红色）
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

  /// 处理"关于"点击：10秒内连续点击 5 次触发 SQLite 浏览器（调试入口）
  void _handleAboutTap() {
    // 重置计时器，开启 10 秒窗口
    _aboutTapTimer?.cancel();
    _aboutTapTimer = Timer(const Duration(seconds: 10), () {
      _aboutTapCount = 0;
    });
    _aboutTapCount++;
    if (_aboutTapCount >= 5) {
      _aboutTapCount = 0;
      _aboutTapTimer?.cancel();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SqliteBrowserScreen()),
      );
    }
  }
}
