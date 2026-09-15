import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:snow_chat/services/app_version_service.dart';

/// AppVersionService 单元测试（用 http_mock_adapter 拦截请求验证 URL 与解析）。
void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
  });

  test('拉取最新版本并正确解析 data 字段', () async {
    // 准备 - mock /chat/app/version 返回 Result 包裹的版本对象
    adapter.onGet(
      '/chat/app/version',
      (server) => server.reply(
        200,
        {
          'code': '200',
          'data': {
            'version': '2.1.0',
            'downloadUrl': 'https://dl.test/app.apk',
            'updateMessage': '新功能上线',
            'isNotify': 1,
          },
        },
      ),
    );

    // 执行
    final service = AppVersionService(dio: dio);
    final version = await service.fetchLatest();

    // 验证
    expect(version, isNotNull);
    expect(version!.version, '2.1.0');
    expect(version.downloadUrl, 'https://dl.test/app.apk');
    expect(version.shouldNotify, isTrue);
  });

  test('data 为 null（当前已最新）时返回 null', () async {
    adapter.onGet(
      '/chat/app/version',
      (server) => server.reply(200, {'code': '200', 'data': null}),
    );

    final version = await AppVersionService(dio: dio).fetchLatest();
    expect(version, isNull);
  });

  test('请求失败时静默返回 null，不抛异常', () async {
    adapter.onGet(
      '/chat/app/version',
      (server) => server.reply(500, {'code': '500', 'msg': 'error'}),
    );

    final version = await AppVersionService(dio: dio).fetchLatest();
    expect(version, isNull);
  });

  test('传入 appType 时带 query 参数', () async {
    // 准备 - 用拦截器记录请求 URI 并直接返回空 data
    Uri? requestedUri;
    final capture = Dio(BaseOptions(baseUrl: 'https://api.test'));
    capture.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requestedUri = options.uri;
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'code': '200', 'data': null},
          ),
        );
      },
    ));

    // 执行
    await AppVersionService(dio: capture).fetchLatest(appType: 'android');

    // 验证 - 请求 URL 携带 appType=android
    expect(requestedUri, isNotNull);
    expect(requestedUri!.queryParameters['appType'], 'android');
  });
}