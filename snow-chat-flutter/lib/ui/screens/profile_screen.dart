import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../widgets/avatar_widget.dart';
import 'contact_tab.dart';
import 'login_screen.dart';

/// 个人中心独立页面（微信"我"风格，与 ProfileTab 同步改造）
///
/// 与 ProfileTab 布局一致，区别：保留 bottomNavigationBar 用于页面跳转。
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          // === 1. 顶部头部行（微信风格）===
          Container(
            color: theme.colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                // 左侧：头像（64x64，使用 AvatarWidget 真实加载）
                AvatarWidget(
                  imageUrl: auth.avatar,
                  initials: initials,
                  size: 64,
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
                  onTap: () {}, // 占位，Commit 7 接入编辑
                ),
                const Divider(height: 1, indent: 56),
                // 个性签名
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: Text(l10n.signature),
                  subtitle: const Text('未设置'), // AuthProvider 暂未持久化 signature
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {}, // 占位，Commit 7 接入编辑
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
}
