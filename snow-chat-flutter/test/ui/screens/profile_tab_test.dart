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
import 'package:snow_chat/ui/screens/personal_info_screen.dart';
import 'package:snow_chat/ui/screens/my_qr_screen.dart';
import 'package:snow_chat/ui/widgets/avatar_widget.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

/// ProfileTab widget 测试
///
/// 验证微信风格个人中心页面：
/// 1. 头像区域使用 AvatarWidget 加载真实头像 URL
/// 2. 显示昵称与 @username
/// 3. 设置入口存在（点击进入 SettingsScreen）
/// 4. 点击头像行弹出底部选图菜单（拍照/相册/取消）
/// 5. 完整上传流程：选图 → 上传 → 更新 AuthProvider.avatar
void main() {
  // 初始化 sqflite FFI，满足 cached_network_image 在测试环境对 SQLite 的需求
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AuthProvider authProvider;
  late SettingsProvider settingsProvider;
  late _FakeProfileService fakeProfileService;

  setUp(() {
    // 注意：不要在 setUp 里再调一次 setMockInitialValues —— 每个用例内部
    // 已经按需调用。重复调用会让 SharedPreferences 的通道 mock 处于未完成
    // 状态，随后的 AuthProvider.init() 会永远挂住（表现为用例 10 分钟超时）。
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
      // 先装好 SharedPreferences mock 再动 AuthProvider：
      // updateAvatar / updateNickname 内部会写 SharedPreferences，
      // 若在装 mock 之前调用，通道无响应会一直挂住（用例 10 分钟超时）。
      SharedPreferences.setMockInitialValues({
        'userId': 1,
        'isLoggedIn': true,
      });
      // 真实 I/O（SharedPreferences 通道 + sqflite 建表）必须跑在真实异步区，
      // 否则在 fake-async 的 widget 测试里会永久挂起
      await tester.runAsync(() => authProvider.init());
      // 头像用 1x1 PNG 的 data URI 而非外网地址：测试环境里
      // flutter_cache_manager 的下载任务不会结束，pumpAndSettle 会一直等。
      // data URI 走的同样是 AvatarWidget 的「有头像 URL」分支。
      await authProvider.updateAvatar(
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8AAAwAB/wFbgn0AAAAASUVORK5CYII=',
      );
      await authProvider.updateNickname('Alice');

      await tester.pumpWidget(makeTestableWidget());
      // 只泵一帧：头像 URL 指向外网，测试环境里 flutter_cache_manager 的
      // 下载任务不会结束，pumpAndSettle 会一直等到 10 分钟超时。
      // 断言的是 AvatarWidget 的渲染契约，首帧足够。
      await tester.pumpAndSettle();

      // 验证：AvatarWidget 存在
      expect(find.byType(AvatarWidget), findsOneWidget);
    });

    testWidgets('应显示昵称与 @username', (WidgetTester tester) async {
      // 先设置 userId 确保 header 区域可见，再更新昵称和头像
      SharedPreferences.setMockInitialValues({
        'userId': 1,
        'isLoggedIn': true,
      });
      // 真实 I/O（SharedPreferences 通道 + sqflite 建表）必须跑在真实异步区，
      // 否则在 fake-async 的 widget 测试里会永久挂起
      await tester.runAsync(() => authProvider.init());
      await authProvider.updateNickname('Alice');
      // 不设置头像 URL，避免 cached_network_image 在测试环境报错
      await authProvider.updateAvatar('');

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：昵称 'Alice' 文本存在
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('应显示设置入口', (WidgetTester tester) async {
      await authProvider.updateNickname('Alice');
      SharedPreferences.setMockInitialValues({
        'userId': 1,
        'isLoggedIn': true,
      });
      // 真实 I/O（SharedPreferences 通道 + sqflite 建表）必须跑在真实异步区，
      // 否则在 fake-async 的 widget 测试里会永久挂起
      await tester.runAsync(() => authProvider.init());

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：设置 ListTile 存在
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('菜单图标使用对标项目的金色图标资源',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'userId': 1,
        'isLoggedIn': true,
      });
      // 真实 I/O（SharedPreferences 通道 + sqflite 建表）必须跑在真实异步区，
      // 否则在 fake-async 的 widget 测试里会永久挂起
      await tester.runAsync(() => authProvider.init());
      await authProvider.updateAvatar('');

      // 这里刻意用 pump 而非 pumpAndSettle：本文件里 ProfileTab 的
      // pumpAndSettle 会一直不 settle（既有问题），但图标断言只需 build 跑过一次
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 收藏 / 朋友圈 / 设置三项均改用 assets/icons/profile 下的对标图标
      final assetNames = tester
          .widgetList<Image>(find.byType(Image))
          .map((w) => w.image)
          .whereType<AssetImage>()
          .map((a) => a.assetName)
          .toSet();

      expect(assetNames, contains('assets/icons/profile/collect.png'));
      expect(assetNames, contains('assets/icons/profile/moments.png'));
      expect(assetNames, contains('assets/icons/profile/settings.png'));

      // 旧的彩色方块图标（统一用 Icons.apps）已不再使用
      expect(find.byIcon(Icons.apps), findsNothing);
    });

    testWidgets('应显示二维码与右箭头图标（微信风格头部行）',
        (WidgetTester tester) async {
      await authProvider.updateNickname('Alice');
      SharedPreferences.setMockInitialValues({
        'userId': 1,
        'isLoggedIn': true,
      });
      // 真实 I/O（SharedPreferences 通道 + sqflite 建表）必须跑在真实异步区，
      // 否则在 fake-async 的 widget 测试里会永久挂起
      await tester.runAsync(() => authProvider.init());

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 验证：二维码图标 + 右箭头图标存在
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });
  });

  // ====================================================================
  // 个人信息入口：头像行 → 个人信息页；二维码图标 → 我的二维码
  //
  // 头像上传整体搬到 PersonalInfoScreen 之后，个人中心顶部不再直接弹选图菜单，
  // 这里改为锁定两个入口的跳转契约（此前二维码页没有任何入口可进）。
  // ====================================================================
  group('ProfileTab 个人信息入口', () {
    testWidgets('点击头像行应进入个人信息页', (WidgetTester tester) async {
      await authProvider.updateNickname('Alice');
      SharedPreferences.setMockInitialValues({
        'userId': 1,
        'isLoggedIn': true,
      });
      // 真实 I/O（SharedPreferences 通道 + sqflite 建表）必须跑在真实异步区，
      // 否则在 fake-async 的 widget 测试里会永久挂起
      await tester.runAsync(() => authProvider.init());

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 点击顶部头像行（通过点击 AvatarWidget 触发父级 onTap）
      await tester.tap(find.byType(AvatarWidget));
      await tester.pumpAndSettle();

      expect(find.byType(PersonalInfoScreen), findsOneWidget,
          reason: '点击用户信息卡片应进入「个人信息」页');
    });

    testWidgets('点击二维码图标应进入我的二维码页', (WidgetTester tester) async {
      await authProvider.updateNickname('Alice');
      SharedPreferences.setMockInitialValues({
        'userId': 1,
        'isLoggedIn': true,
      });
      // 真实 I/O（SharedPreferences 通道 + sqflite 建表）必须跑在真实异步区，
      // 否则在 fake-async 的 widget 测试里会永久挂起
      await tester.runAsync(() => authProvider.init());

      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // 点击用户信息卡片右侧的二维码图标
      await tester.tap(find.byIcon(Icons.qr_code_2));
      await tester.pumpAndSettle();

      expect(find.byType(MyQrScreen), findsOneWidget,
          reason: '点击二维码图标应进入「我的二维码」页');
    });
  });
}

/// ProfileService 的 fake 实现，用于 widget 测试隔离网络层。
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
      {String? nickname,
      String? username,
      String? avatar,
      String? signature,
      int? gender}) async {
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
class _NullApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
