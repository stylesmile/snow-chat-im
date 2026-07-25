import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_chat/core/network/api_client.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/models/upload_result.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/providers/settings_provider.dart';
import 'package:snow_chat/services/profile_service.dart';
import 'package:snow_chat/ui/screens/profile_tab.dart';
import 'package:snow_chat/ui/widgets/avatar_widget.dart';

/// ProfileTab widget 测试
///
/// 验证微信风格个人中心页面：
/// 1. 头像区域使用 AvatarWidget 加载真实头像 URL
/// 2. 显示昵称与 @username
/// 3. 退出登录按钮存在
/// 4. 点击头像行弹出底部选图菜单（拍照/相册/取消）
/// 5. 完整上传流程：选图 → 上传 → 更新 AuthProvider.avatar
///
/// 测试策略：
/// - image_picker 通过 MethodChannel mock（返回临时文件路径）
/// - ProfileService 通过 [_FakeProfileService] 替换，避免真实网络与文件 IO
///   这样 widget 测试聚焦 UI 行为，网络层由 profile_service_test.dart 覆盖
void main() {
  late AuthProvider authProvider;
  late SettingsProvider settingsProvider;
  late _FakeProfileService fakeProfileService;

  setUp(() {
    // 初始化 SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    // 构造已登录的 AuthProvider
    authProvider = AuthProvider('http://localhost:8091');
    settingsProvider = SettingsProvider();
    // 构造 fake ProfileService，默认上传成功
    fakeProfileService = _FakeProfileService();

    // mock path_provider 通道（cached_network_image 在加载头像 URL 时需要临时目录）
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    pathProviderChannel.setMockMethodCallHandler((call) async {
      // 所有目录方法都返回系统临时目录，满足 flutter_cache_manager 需求
      return Directory.systemTemp.path;
    });
  });

  tearDown(() {
    // 清理 path_provider mock，避免影响其他测试
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    pathProviderChannel.setMockMethodCallHandler(null);
  });

  /// 构造测试用 widget 树：MultiProvider + MaterialApp（带本地化）+ ProfileTab
  ///
  /// 注入 [_FakeProfileService]，让 widget 测试不依赖真实网络。
  Widget makeTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        // 用 fake 替换真实 ProfileService，断开网络依赖
        Provider<ProfileService>.value(value: fakeProfileService),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('zh'), Locale('en')],
        locale: Locale('zh'),
        home: ProfileTab(),
      ),
    );
  }

  group('ProfileTab 微信风格布局', () {
    testWidgets('应显示 AvatarWidget 加载真实头像', (WidgetTester tester) async {
      // 预设头像 URL
      await authProvider.updateAvatar('https://example.com/avatar.jpg');
      await authProvider.updateNickname('Alice');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：AvatarWidget 存在（替代了原来的 Icons.person 占位）
      expect(find.byType(AvatarWidget), findsOneWidget);
    });

    testWidgets('应显示昵称与 @username', (WidgetTester tester) async {
      // 预设昵称与用户名
      await authProvider.updateNickname('Alice');
      // username 无法通过公开方法设置，Auth 内部字段默认为 null
      // 这里验证昵称显示即可；username 为 null 时显示占位
      await authProvider.updateAvatar('https://example.com/a.jpg');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：昵称 'Alice' 文本存在
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('应显示退出登录按钮', (WidgetTester tester) async {
      await authProvider.updateNickname('Alice');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：退出登录图标存在（Icons.logout）
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('应显示二维码与右箭头图标（微信风格头部行）',
        (WidgetTester tester) async {
      await authProvider.updateNickname('Alice');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：二维码图标 + 右箭头图标存在
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });
  });

  // ====================================================================
  // Commit 7：头像选择与上传交互测试（TDD）
  // ====================================================================
  group('ProfileTab 头像选择交互', () {
    testWidgets('点击头像行应弹出底部选图菜单（拍照/相册/取消）',
        (WidgetTester tester) async {
      // 预设昵称，确保头像区域可点击
      await authProvider.updateNickname('Alice');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 点击顶部头像行（通过点击 AvatarWidget 触发父级 onTap）
      await tester.tap(find.byType(AvatarWidget));
      await tester.pumpAndSettle();

      // 验证：底部弹窗显示三个选项
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('从相册选择'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('点击"取消"应关闭底部选图菜单', (WidgetTester tester) async {
      await authProvider.updateNickname('Alice');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 打开底部弹窗
      await tester.tap(find.byType(AvatarWidget));
      await tester.pumpAndSettle();
      expect(find.text('取消'), findsOneWidget);

      // 点击"取消"
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 验证：底部弹窗已关闭
      expect(find.text('拍照'), findsNothing);
      expect(find.text('从相册选择'), findsNothing);
    });

    testWidgets('完整上传流程：从相册选择 → 上传 → 更新 AuthProvider.avatar',
        (WidgetTester tester) async {
      // --- 准备：mock image_picker 平台通道，返回临时图片文件路径 ---
      final tempFile = File(
        '${Directory.systemTemp.path}/test_avatar_upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
      )..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG 文件头
      const imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');
      imagePickerChannel.setMockMethodCallHandler((call) async {
        if (call.method == 'pickImage') {
          return tempFile.path; // 返回临时文件路径
        }
        return null;
      });

      // fake ProfileService 配置为上传成功
      fakeProfileService.uploadResult = const UploadResult(
        key: 'avatars/test-uuid.jpg',
        url: 'https://presigned.example.com/avatars/test-uuid.jpg',
      );
      fakeProfileService.updateProfileResult = true;

      // 设置已登录状态（含 userId），让 _pickAndUpload 的 userId 检查通过
      SharedPreferences.setMockInitialValues({
        'isLoggedIn': true,
        'userId': 1,
        'username': 'alice',
        'nickname': 'Alice',
        'avatar': '',
      });
      await authProvider.init(); // 从 SharedPreferences 恢复登录态

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 点击头像行打开底部弹窗
      await tester.tap(find.byType(AvatarWidget));
      await tester.pumpAndSettle();

      // 点击"从相册选择"触发 onTap（关闭弹窗 + 启动 _pickAndUpload 异步链）
      await tester.tap(find.text('从相册选择'));
      await tester.pump(); // 触发 tap 回调 + 关闭弹窗
      // 用 runAsync 等待真实异步链（pickImage 通道 + fake 上传 + AuthProvider 持久化）跑完
      // 注意：上传期间 CircularProgressIndicator 是无限动画，pumpAndSettle 会超时，故改用 runAsync
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump(); // 刷新 UI

      // 验证：ProfileService.uploadAvatar 被调用
      expect(fakeProfileService.uploadCallCount, equals(1));
      // 验证：ProfileService.updateProfile 被调用，且 avatar 参数为对象 key
      expect(fakeProfileService.updateProfileCallCount, equals(1));
      expect(fakeProfileService.lastUpdateProfileAvatar, equals('avatars/test-uuid.jpg'));
      // 验证：AuthProvider.avatar 已更新为 fake 返回的 pre-signed URL
      expect(
        authProvider.avatar,
        equals('https://presigned.example.com/avatars/test-uuid.jpg'),
      );

      // --- 清理 ---
      imagePickerChannel.setMockMethodCallHandler(null);
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    });

    testWidgets('上传失败时应显示错误 SnackBar', (WidgetTester tester) async {
      // --- 准备：mock image_picker 返回临时文件 ---
      final tempFile = File(
        '${Directory.systemTemp.path}/test_avatar_fail_${DateTime.now().millisecondsSinceEpoch}.jpg',
      )..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
      const imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');
      imagePickerChannel.setMockMethodCallHandler((call) async {
        if (call.method == 'pickImage') {
          return tempFile.path;
        }
        return null;
      });

      // fake 配置为上传失败（uploadAvatar 返回 null）
      fakeProfileService.uploadResult = null;

      await authProvider.updateNickname('Alice');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 点击头像行打开底部弹窗
      await tester.tap(find.byType(AvatarWidget));
      await tester.pumpAndSettle();

      // 点击"从相册选择"触发 onTap（启动 _pickAndUpload 异步链，fake 上传返回 null）
      await tester.tap(find.text('从相册选择'));
      await tester.pump(); // 触发 tap 回调 + 关闭弹窗
      // 用 runAsync 等待上传失败链完成（pickImage 通道 + fake 返回 null + SnackBar 显示）
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump(); // 刷新 UI 显示 SnackBar

      // 验证：显示错误 SnackBar
      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);

      // --- 清理 ---
      imagePickerChannel.setMockMethodCallHandler(null);
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    });
  });
}

/// ProfileService 的 fake 实现，用于 widget 测试隔离网络层。
///
/// 继承自 [ProfileService] 以保持类型兼容（Provider<ProfileService>），
/// 但重写所有方法，返回可配置的预设值，并记录调用次数供断言。
class _FakeProfileService extends ProfileService {
  _FakeProfileService() : super(_NullApiClient());

  /// uploadAvatar 返回的结果；null 表示上传失败
  UploadResult? uploadResult;

  /// updateProfile 返回的结果；false 表示更新失败
  bool updateProfileResult = true;

  /// uploadAvatar 被调用的次数
  int uploadCallCount = 0;

  /// updateProfile 被调用的次数
  int updateProfileCallCount = 0;

  /// 最近一次 updateProfile 调用的 avatar 参数
  String? lastUpdateProfileAvatar;

  @override
  Future<UploadResult?> uploadAvatar(File imageFile) async {
    uploadCallCount++;
    return uploadResult;
  }

  @override
  Future<bool> updateProfile(int userId,
      {String? nickname, String? avatar, String? signature}) async {
    updateProfileCallCount++;
    lastUpdateProfileAvatar = avatar;
    return updateProfileResult;
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(int userId) async => null;

  @override
  Future<Map<String, dynamic>?> refreshProfile(int userId) async => null;
}

/// 占位 ApiClient，仅用于满足 ProfileService 构造函数签名。
/// fake 重写了所有方法，不会真正使用此 ApiClient。
class _NullApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
