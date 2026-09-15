import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/services/notification_service.dart';

void main() {
  group('NotificationService.buildAndroidDetails', () {
    test('should 默认开启提示音与震动', () {
      // 执行 - 使用默认参数（都未关闭）
      final details = NotificationService.buildAndroidDetails(
        soundEnabled: true,
        vibrateEnabled: true,
      );

      // 验证 - 提示音与震动都应开启；渠道重要性须为 HIGH 保证发声
      expect(details.playSound, isTrue);
      expect(details.enableVibration, isTrue);
      expect(details.importance, Importance.high);
      expect(details.priority, Priority.high);
    });

    test('should 关闭震动后 enableVibration 为 false', () {
      // 执行 - 关闭震动、保留提示音
      final details = NotificationService.buildAndroidDetails(
        soundEnabled: true,
        vibrateEnabled: false,
      );

      // 验证 - 震动被关闭，提示音仍开启
      expect(details.enableVibration, isFalse);
      expect(details.playSound, isTrue);
    });

    test('should 关闭提示音后 playSound 为 false', () {
      // 执行 - 关闭提示音、保留震动
      final details = NotificationService.buildAndroidDetails(
        soundEnabled: false,
        vibrateEnabled: true,
      );

      // 验证 - 提示音被关闭，震动仍开启
      expect(details.playSound, isFalse);
      expect(details.enableVibration, isTrue);
    });

    test('should 同时关闭提示音与震动时两者都关闭', () {
      // 执行 - 提示音与震动都关闭
      final details = NotificationService.buildAndroidDetails(
        soundEnabled: false,
        vibrateEnabled: false,
      );

      // 验证 - 两者应同时关闭
      expect(details.playSound, isFalse);
      expect(details.enableVibration, isFalse);
      // 使用「新消息通知」渠道，保证与其他通知区分
      expect(details.channelDescription, isNotNull);
    });
  });
}