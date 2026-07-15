import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import 'contact_tab.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.person, size: 30),
            ),
            title: Text(auth.nickname ?? '-'),
            subtitle: Text(auth.username ?? '-'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {},
            ),
          ),
          const Divider(height: 1),

          // Language selection
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

          // Settings options
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(l10n.privacy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            subtitle: const Text('v1.0.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),

          // Logout
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
