import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_chat/providers/auth_provider.dart';

import '../services/mock_api_helper.dart';

/// AuthProvider 单元测试
///
/// 覆盖：
/// 1. updateAvatar / updateNickname：getter、notifyListeners、持久化
/// 2. resolveAvatarUrlFromBackend：storage key → 可访问 URL（回归：重新登录后头像消失）
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

  /// 回归测试：上传头像后重新登录，头像不显示
  ///
  /// 根因是 `chat_user.avatar` 存的是对象存储 key（`avatars/xxx.jpg`），而登录接口
  /// 直接返回库里的原始 key。key 会被 AvatarWidget 当成网络地址加载并失败，最终
  /// 回落成首字母占位。登录后需要经 `/chat/user/info` 把 key 换成可访问地址。
  group('AuthProvider.resolveAvatarUrlFromBackend', () {
    const keyAvatar = 'avatars/1574e7e9-d3bb-4da0-bd48-a01e4eae0c50.png';
    const accessibleUrl = 'https://cdn.example.com/avatars/1574e7e9.png';

    test('should replace storage key with accessible url and persist it', () async {
      // 准备：模拟登录接口返回的 storage key
      await provider.updateAvatar(keyAvatar);

      // mock：/chat/user/info 会把 key 转成可访问地址
      mockApiClient(provider.apiClient, {
        'GET /chat/user/info': {
          'code': '200',
          'data': {'id': 1, 'avatar': accessibleUrl},
        },
      });

      await provider.resolveAvatarUrlFromBackend();

      // 验证：内存中已是 URL
      expect(provider.avatar, equals(accessibleUrl));
      // 验证：已持久化，否则下次启动又会退回 key
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('avatar'), equals(accessibleUrl));
    });

    test('should keep avatar unchanged when it is already an accessible url', () async {
      await provider.updateAvatar(accessibleUrl);

      // mock 返回一个不同的地址：若代码误发请求，avatar 会被改写成 OTHER
      mockApiClient(provider.apiClient, {
        'GET /chat/user/info': {
          'code': '200',
          'data': {'id': 1, 'avatar': 'https://cdn.example.com/OTHER.png'},
        },
      });

      await provider.resolveAvatarUrlFromBackend();

      expect(provider.avatar, equals(accessibleUrl));
    });

    test('should keep storage key when backend returns empty avatar', () async {
      // 场景：对象存储里的文件已丢失（如 InMemory 存储随进程重启清空）
      await provider.updateAvatar(keyAvatar);

      mockApiClient(provider.apiClient, {
        'GET /chat/user/info': {
          'code': '200',
          'data': {'id': 1, 'avatar': ''},
        },
      });

      await provider.resolveAvatarUrlFromBackend();

      // 保留 key 而不是清空，等对象恢复后仍能显示
      expect(provider.avatar, equals(keyAvatar));
    });

    test('should not throw and keep storage key when request fails', () async {
      await provider.updateAvatar(keyAvatar);

      // 不给任何 mock：请求会被 reject
      mockApiClient(provider.apiClient, {});

      await expectLater(provider.resolveAvatarUrlFromBackend(), completes);

      expect(provider.avatar, equals(keyAvatar));
    });
  });
}
