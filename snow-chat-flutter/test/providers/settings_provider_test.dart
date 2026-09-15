import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_chat/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 每个用例前重置 SharedPreferences 内存存储，隔离相互影响
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsProvider 新消息通知设置', () {
    test('默认新消息通知/提示音/震动均为开启', () async {
      final settings = SettingsProvider();
      await settings.init();

      expect(settings.notificationEnabled, isTrue);
      expect(settings.soundEnabled, isTrue);
      expect(settings.vibrateEnabled, isTrue);
    });

    test('init 恢复已持久化的通知开关设置', () async {
      // 预置持久化的偏好值：通知开、提示音关、震动开
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'notifications_sound': false,
        'notifications_vibrate': true,
      });

      final settings = SettingsProvider();
      await settings.init();

      expect(settings.notificationEnabled, isTrue);
      expect(settings.soundEnabled, isFalse);
      expect(settings.vibrateEnabled, isTrue);
    });

    test('setNotificationEnabled 更新并持久化总开关', () async {
      final settings = SettingsProvider();
      await settings.init();

      // 关闭新消息通知
      await settings.setNotificationEnabled(false);
      expect(settings.notificationEnabled, isFalse);

      // 重新初始化后仍为关闭，验证已写入持久化存储
      final reloaded = SettingsProvider();
      await reloaded.init();
      expect(reloaded.notificationEnabled, isFalse);
    });

    test('setSoundEnabled 更新并持久化提示音开关', () async {
      final settings = SettingsProvider();
      await settings.init();

      await settings.setSoundEnabled(false);
      expect(settings.soundEnabled, isFalse);

      final reloaded = SettingsProvider();
      await reloaded.init();
      expect(reloaded.soundEnabled, isFalse);
    });

    test('setVibrateEnabled 更新并持久化震动开关', () async {
      final settings = SettingsProvider();
      await settings.init();

      await settings.setVibrateEnabled(false);
      expect(settings.vibrateEnabled, isFalse);

      final reloaded = SettingsProvider();
      await reloaded.init();
      expect(reloaded.vibrateEnabled, isFalse);
    });

    test('关闭通知后再次开启可恢复', () async {
      final settings = SettingsProvider();
      await settings.init();

      await settings.setNotificationEnabled(false);
      await settings.setNotificationEnabled(true);

      expect(settings.notificationEnabled, isTrue);

      final reloaded = SettingsProvider();
      await reloaded.init();
      expect(reloaded.notificationEnabled, isTrue);
    });
  });
}