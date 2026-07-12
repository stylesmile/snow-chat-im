import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  Locale _locale = const Locale('zh');

  Locale get locale => _locale;

  List<LocaleInfo> get availableLocales => const [
        LocaleInfo(Locale('zh'), '简体中文', '\ud83c\udde8\ud83c\uddf3'),
        LocaleInfo(Locale('en'), 'English', '\ud83c\uddfa\ud83c\uddf8'),
        LocaleInfo(Locale('zh', 'TW'), '繁體中文', '\ud83c\uddfc\ud83c\uddf9'),
        LocaleInfo(Locale('ja'), '日本語', '\ud83c\uddef\ud83c\uddf5'),
        LocaleInfo(Locale('ko'), '한국어', '\ud83c\uddf0\ud83c\uddf7'),
      ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_languageKey);
    if (lang != null) {
      _locale = Locale(lang);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
    if (locale.countryCode != null) {
      await prefs.setString('locale_country', locale.countryCode!);
    }
    notifyListeners();
  }

  String getLocaleName(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        return locale.countryCode == 'TW' ? '繁體中文' : '简体中文';
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      default:
        return locale.languageCode;
    }
  }
}

class LocaleInfo {
  final Locale locale;
  final String name;
  final String flag;
  const LocaleInfo(this.locale, this.name, this.flag);
}
