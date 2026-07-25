import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_chat/providers/auth_provider.dart';

/// AuthProvider 单元测试
///
/// 覆盖 updateAvatar / updateNickname：
/// 1. 更新后 getter 立即返回新值
/// 2. 触发 notifyListeners（listener 计数验证）
/// 3. 持久化到 SharedPreferences（重新实例化后仍能恢复）
void main() {
  late AuthProvider provider;

  setUp(() {
    // 初始化 SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    provider = AuthProvider('http://localhost:8091');
  });

  group('AuthProvider.updateAvatar', () {
    test('should update avatar getter immediately', () async {
      // 执行
      await provider.updateAvatar('https://example.com/new_avatar.jpg');

      // 验证：getter 立即返回新值
      expect(provider.avatar, equals('https://example.com/new_avatar.jpg'));
    });

    test('should notify listeners on update', () async {
      // 准备：监听变更次数
      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      // 执行
      await provider.updateAvatar('https://example.com/avatar.jpg');

      // 验证：notifyListeners 至少被触发一次
      expect(notifyCount, greaterThan(0));
    });

    test('should persist avatar to SharedPreferences', () async {
      // 执行
      await provider.updateAvatar('https://example.com/persisted.jpg');

      // 验证：从 SharedPreferences 读取 avatar 键，值应为新 URL
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('avatar'), equals('https://example.com/persisted.jpg'));
    });
  });

  group('AuthProvider.updateNickname', () {
    test('should update nickname getter immediately', () async {
      // 执行
      await provider.updateNickname('新昵称');

      // 验证：getter 立即返回新值
      expect(provider.nickname, equals('新昵称'));
    });

    test('should notify listeners on update', () async {
      // 准备：监听变更次数
      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      // 执行
      await provider.updateNickname('NewName');

      // 验证：notifyListeners 至少被触发一次
      expect(notifyCount, greaterThan(0));
    });

    test('should persist nickname to SharedPreferences', () async {
      // 执行
      await provider.updateNickname('持久化昵称');

      // 验证：从 SharedPreferences 读取 nickname 键
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nickname'), equals('持久化昵称'));
    });
  });
}
