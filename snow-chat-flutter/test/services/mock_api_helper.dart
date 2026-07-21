import 'package:dio/dio.dart';
import 'package:snow_chat/core/network/api_client.dart';

/// Replaces [apiClient]'s Dio interceptors with a mock that returns
/// canned responses keyed by "METHOD /path" (e.g. "POST /chat/user/login").
/// Requests without a matching key throw a [DioException].
void mockApiClient(ApiClient apiClient, Map<String, Object?> responses) {
  apiClient.dio.interceptors.clear();
  apiClient.dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final key = '${options.method.toUpperCase()} ${options.path}';
      if (responses.containsKey(key)) {
        handler.resolve(Response(
          data: responses[key],
          statusCode: 200,
          requestOptions: options,
        ));
      } else {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: 'No mock response for $key',
        ));
      }
    },
  ));
}
