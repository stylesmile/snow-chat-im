import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// 新消息本地通知服务。
///
/// 职责：
/// 1. 初始化 flutter_local_notifications（创建 Android 通知渠道）
/// 2. 通过 permission_handler 检查/申请通知权限（Android 13+ 需要 POST_NOTIFICATIONS）
/// 3. 显示一条新消息通知
///
/// 权限申请复用手边已有的 permission_handler（与扫码相机权限一致），
/// flutter_local_notifications 仅负责任何系统通知的渲染，职责分离。
class NotificationService {
  // 通知渠道 id 与名称（渠道创建后用户可在系统设置里单独控制）
  static const String _channelId = 'chat_new_message';
  static const String _channelName = '新消息通知';

  // 插件实例：允许测试注入替身；当使用有参构造时会跳过内置单例创建
  final FlutterLocalNotificationsPlugin _plugin;

  // 通知 id 自增计数，保证多次消息各自成条、不互相覆盖
  int _idCounter = 0;

  /// 是否已完成初始化。调用 [initialize] 后为 true。
  bool _initialized = false;

  bool get isInitialized => _initialized;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// 初始化通知插件（创建消息渠道）。应在应用启动后调用一次。
  Future<void> initialize() async {
    // Android 初始化：使用应用启动图标作为通知小图标
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(
      android: androidSettings,
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// 检查通知权限是否已授予。
  Future<bool> checkNotificationPermission() async {
    return await Permission.notification.isGranted;
  }

  /// 请求通知权限并返回是否已授予。
  ///
  /// 用户选择「永久拒绝」时返回 false；需要跳系统设置引导由调用方处理。
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 打开系统的应用设置页（权限被永久拒绝时引导用户手动开启）。
  Future<void> openSystemAppSettings() async {
    // permission_handler 顶层函数，跳转到系统「此应用」设置页
    await openAppSettings();
  }

  /// 关闭/开启新消息通知渠道。
  Future<void> setNotificationsEnabled(bool enabled) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    if (enabled) {
      await android.requestNotificationsPermission();
    } else {
      await android.cancelAll();
    }
  }

  /// 显示一条新消息本地通知。
  ///
  /// @param title 通知标题（通常为发送方昵称）
  /// @param body 通知正文（消息内容摘要）
  Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    // 未初始化时直接跳过，避免空指针（正常流程总会先调用 initialize）
    if (!_initialized) return;

    // Android 渠道详情：默认优先级、显示时间，提示音/震动跟随系统开关
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: '收到新消息时提醒',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);

    // 使用自增 id，让每条新消息都能独立展示成一条通知
    await _plugin.show(_idCounter++, title, body, details);
  }
}