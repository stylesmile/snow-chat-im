import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/friend_request_provider.dart';
import 'services/profile_service.dart';
import 'config/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 恢复登录状态（用 try-catch 包裹，防止初始化失败导致白屏）
  final authProvider = AuthProvider(AppConfig.baseUrl);
  try {
    await authProvider.init();
  } catch (e) {
    if (kDebugMode) print('[Main] init error: $e');
  }
  // 提前获取 apiClient，避免在 runApp 前访问 context
  final apiClient = authProvider.apiClient;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        // apiClient 已在上方获取，直接传入，不依赖 context.read
        ChangeNotifierProvider(
          create: (_) => FriendRequestProvider(apiClient),
        ),
        // ProfileService 同样使用已获取的 apiClient
        Provider(create: (_) => ProfileService(apiClient)),
      ],
      child: const SnowChatApp(),
    ),
  );
}
