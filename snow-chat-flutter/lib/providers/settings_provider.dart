import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  static const String _notifyKey = 'notifications_enabled';
  static const String _soundKey = 'notifications_sound';
  static const String _vibrateKey = 'notifications_vibrate';

  Locale _locale = const Locale('zh');

  /// 是否允许接收新消息通知（总开关）
  bool _notificationEnabled = true;

  /// 新消息是否播放提示音
  bool _soundEnabled = true;

  /// 新消息是否震动提醒
  bool _vibrateEnabled = true;

  Locale get locale => _locale;

  bool get notificationEnabled => _notificationEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrateEnabled => _vibrateEnabled;

  List<LocaleInfo> get availableLocales => const [
        LocaleInfo(Locale('zh'), '简体中文', '\ud83c\udde8\ud83c\uddf3'),
        LocaleInfo(Locale('en'), 'English', '\ud83c\uddfa\ud83c\uddf8'),
        LocaleInfo(Locale('zh', 'TW'), '繁體中文', '\ud83c\uddfc\ud83c\uddf9'),
        LocaleInfo(Locale('ja'), '日本語', '\ud83c\uddef\ud83c\uddf5'),
        LocaleInfo(Locale('ko'), '한국어', '\ud83c\uddf0\ud83c\uddf7'),
      ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // 恢复语言设置（含国家码：繁体中文是 zh_TW，只恢复 languageCode 会退化成简体）
    final lang = prefs.getString(_languageKey);
    if (lang != null) {
      final country = prefs.getString('locale_country');
      _locale = (lang == 'zh' && country != null && country.isNotEmpty)
          ? Locale('zh', country)
          : Locale(lang);
    }
    // 恢复新消息通知三项开关（不存在则保持默认开启）
    _notificationEnabled = prefs.getBool(_notifyKey) ?? true;
    _soundEnabled = prefs.getBool(_soundKey) ?? true;
    _vibrateEnabled = prefs.getBool(_vibrateKey) ?? true;
    notifyListeners();
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

  /// 切换新消息通知总开关，并持久化
  Future<void> setNotificationEnabled(bool enabled) async {
    _notificationEnabled = enabled;
    await (await SharedPreferences.getInstance()).setBool(_notifyKey, enabled);
    notifyListeners();
  }

  /// 切换新消息提示音开关，并持久化
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await (await SharedPreferences.getInstance()).setBool(_soundKey, enabled);
    notifyListeners();
  }

  /// 切换新消息震动开关，并持久化
  Future<void> setVibrateEnabled(bool enabled) async {
    _vibrateEnabled = enabled;
    await (await SharedPreferences.getInstance()).setBool(_vibrateKey, enabled);
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
