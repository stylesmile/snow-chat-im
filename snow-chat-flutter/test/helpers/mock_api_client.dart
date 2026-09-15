import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:snow_chat/core/network/api_client.dart';

/// Mock ApiClient，绕过单例模式，直接持有 Dio 和 DioAdapter
/// 服务层只使用 apiClient.dio，所以只需正确实现 dio getter
class MockApiClient implements ApiClient {
  final Dio _dio;
  late final DioAdapter _adapter;
  String? _token;

  MockApiClient()
      : _dio = Dio(BaseOptions(
          baseUrl: 'http://localhost:8080',
          validateStatus: (_) => true,
        )) {
    _adapter = DioAdapter(
      dio: _dio,
      matcher: const UrlRequestMatcher(matchMethod: true),
    );
  }

  @override
  Dio get dio => _dio;

  @override
  String get baseUrl => 'http://localhost:8080';

  @override
  String? get token => _token;

  @override
  set token(String? value) => _token = value;

  @override
  init(String baseUrl) {}

  @override
  Future<Map<String, dynamic>> request(String path,
      {Map<String, dynamic>? data, Map<String, dynamic>? query}) async {
    final response = await _dio.post(path, data: data, queryParameters: query);
    return response.data as Map<String, dynamic>;
  }

  DioAdapter get adapter => _adapter;
}
