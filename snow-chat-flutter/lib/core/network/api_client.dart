import 'package:dio/dio.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient(String baseUrl) => _instance..init(baseUrl);
  ApiClient._internal();

  late Dio _dio;
  late String _baseUrl;
  String? _token;

  init(String baseUrl) {
    _baseUrl = baseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;
  String get baseUrl => _baseUrl;

  String? get token => _token;
  set token(String? value) {
    _token = value;
  }

  // Generic response wrapper
  // data: POST body (JSON), query: URL query parameters
  Future<Map<String, dynamic>> request(String path,
      {Map<String, dynamic>? data, Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.post(path, data: data, queryParameters: query);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('${e.response?.statusCode}: ${e.message}');
    }
  }
}
