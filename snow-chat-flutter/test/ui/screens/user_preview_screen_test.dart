import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/providers/auth_provider.dart';
import 'package:snow_chat/services/contact_service.dart';
import 'package:snow_chat/ui/screens/user_preview_screen.dart';

/// UserPreviewScreen widget 测试
///
/// 覆盖三种关键状态：
/// - 正常用户：展示昵称 / @用户名 / 用户ID，按钮为「添加到通讯录」
/// - 扫到自己：按钮禁用并显示「不能添加自己」
/// - 拉取失败后的发送：点击按钮走网络（测试环境返回失败），展示失败提示并返回
void main() {
  // 初始化 sqflite FFI，满足 AuthProvider.init 对 SQLite 的需求
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AuthProvider auth;

  setUp(() async {
    // 构造已登录用户（userId=1001）
    SharedPreferences.setMockInitialValues({
      'userId': 1001,
      'username': 'alice',
      'nickname': 'Alice',
      'isLoggedIn': true,
      'token': 'mock-token',
    });
    auth = AuthProvider('http://localhost:8091');
    await auth.init();
  });

  /// 构建预览页，目标用户为 [target]
  ///
  /// 用 [MaterialApp] 包 [AuthProvider]；通过一个初始基页在 initState 中
  /// push 预览页，从而让预览页的 `pop()` 有真实的返回目标（测试能验证回到基页）。
  Widget buildScreen(UserSearchResult target) {
    return ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        home: _BaseHost(previewTarget: target),
      ),
    );
  }

  testWidgets('展示昵称、用户名、用户ID与添加按钮', (tester) async {
    // 准备：目标用户 Bob（非自己）
    final target = UserSearchResult(
      id: 2002,
      username: 'bob',
      nickname: 'Bob',
      avatar: '',
    );

    // 执行：渲染预览页
    await tester.pumpWidget(buildScreen(target));
    await tester.pumpAndSettle();

    // 验证：昵称、@用户名、用户ID、标题「找到用户」、按钮「添加到通讯录」
    expect(find.text('找到用户'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('@bob'), findsOneWidget);
    expect(find.textContaining('2002'), findsOneWidget);
    // 网络在测试环境失败 → 好友列表为空 → 按钮应为可添加状态
    expect(find.text('添加到通讯录'), findsOneWidget);
  });

  testWidgets('扫到自己时按钮禁用并提示无法添加', (tester) async {
    // 准备：目标用户即当前登录用户（userId=1001）
    final self = UserSearchResult(
      id: 1001,
      username: 'alice',
      nickname: 'Alice',
      avatar: '',
    );

    // 执行：渲染预览页
    await tester.pumpWidget(buildScreen(self));
    await tester.pumpAndSettle();

    // 验证：按钮文案为「不能添加自己」，且按钮处于禁用态
    expect(find.text('不能添加自己'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('点击添加按钮后发送失败并返回基页', (tester) async {
    // 准备：目标用户 Bob（非自己）
    final target = UserSearchResult(
      id: 2002,
      username: 'bob',
      nickname: 'Bob',
      avatar: '',
    );

    // 执行：渲染基页，等待预览页 push 完成后点击添加按钮
    await tester.pumpWidget(buildScreen(target));
    await tester.pumpAndSettle();
    expect(find.text('添加到通讯录'), findsOneWidget);
    await tester.tap(find.text('添加到通讯录'));
    // 发送请求是异步网络操作，多 pump 几次让 Future 完成并触发 pop
    await tester.pumpAndSettle();

    // 验证：发送失败后已 pop 回到基页（基页标记 visible），预览页不再存在
    expect(find.text('base-host'), findsOneWidget);
    expect(find.text('添加到通讯录'), findsNothing);
  });
}

/// 基页组件：initState 中 push 一次预览页，提供真实的返回堆栈
class _BaseHost extends StatefulWidget {
  final UserSearchResult previewTarget;

  const _BaseHost({required this.previewTarget});

  @override
  State<_BaseHost> createState() => _BaseHostState();
}

class _BaseHostState extends State<_BaseHost> {
  @override
  void initState() {
    super.initState();
    // 首帧后 push 预览页（确保基页在返回栈底部）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserPreviewScreen(user: widget.previewTarget),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 基页标记：用于验证从预览页 pop 后回到此处
    return const Scaffold(body: Center(child: Text('base-host')));
  }
}