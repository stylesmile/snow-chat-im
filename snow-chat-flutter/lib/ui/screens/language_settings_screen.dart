import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

/// 语言设置页（从设置页"语言"入口进入）
///
/// 独立页面替代原来设置页内嵌的 ExpansionTile：
/// 列出全部支持语言（旗帜 + 语言自称），点击即切换并持久化，
/// 当前语言打勾。切换通过 SettingsProvider 驱动全局重建，无需返回。
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    const cardColor = Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.language),
        leading: const BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final localeInfo in settings.availableLocales) ...[
            _buildLanguageTile(context, settings, localeInfo),
            const Divider(height: 1, indent: 56, color: Color(0x0FFFFFFF)),
          ],
        ],
      ),
    );
  }

  /// 单个语言行：旗帜 + 语言自称，当前选中项右侧打勾
  Widget _buildLanguageTile(
    BuildContext context,
    SettingsProvider settings,
    LocaleInfo localeInfo,
  ) {
    final isSelected = settings.locale.languageCode == localeInfo.locale.languageCode &&
        settings.locale.countryCode == localeInfo.locale.countryCode;
    return ListTile(
      leading: Text(
        localeInfo.flag,
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(
        localeInfo.name,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppTheme.accent, size: 22)
          : null,
      onTap: () => settings.setLocale(localeInfo.locale),
    );
  }
}
