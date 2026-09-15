import 'package:dio/dio.dart';

import '../config/config.dart';
import '../utils/app_version.dart';

/// App 版本更新拉取服务。
///
/// 每次启动调用后端 `GET /chat/app/version`（匿名白名单接口）获取
/// 应提示的最新版本，再由调用方比对本机当前版本决定是否弹窗。
class AppVersionService {
  /// 构造可注入自定义 [dio]（便于测试 mock），默认使用 AppConfig.baseUrl。
  ///
  /// 版本检查是匿名接口、且要适配「登录前后首页都会调用」的场景，故不依赖
  /// AuthProvider 持有的全局 ApiClient 单例，减少耦合。
  final Dio _dio;

  AppVersionService({Dio? dio})
      : _dio =
            dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ));

  /// 拉取最新应提示的版本；网络/解析异常返回 null，交由调用方静默降级。
  ///
  /// @param appType 平台标识；不传则取后端全局最新一条
  Future<AppVersion?> fetchLatest({String? appType}) async {
    try {
      final response = await _dio.get(
        '/chat/app/version',
        queryParameters: appType == null ? null : {'appType': appType},
      );
      // 后端返回 Result{code, data}，data 为版本对象或 null
      final data = response.data as Map<String, dynamic>?;
      final versionJson = data?['data'];
      if (versionJson == null) return null;
      return AppVersion.fromJson(versionJson as Map<String, dynamic>);
    } catch (e) {
      // 版本检查不能阻塞主流程，失败时按「无更新」处理
      return null;
    }
  }
}