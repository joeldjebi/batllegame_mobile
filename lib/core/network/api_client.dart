import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/database.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';
import 'http_cache.dart';

/// The only door to the backend: base URL, token, device id, French errors,
/// ETag cache for reads, Idempotency-Key for writes, network health reporting.
class ApiClient {
  ApiClient({
    required AppDatabase db,
    required TokenStore tokens,
    required String Function() account,
    required Future<String> Function() deviceId,
    this.onUnauthorized,
    this.onReachability,
    Dio? dio,
  }) : _tokens = tokens,
       dio = dio ?? Dio() {
    cache = HttpCacheInterceptor(db, account);
    this.dio.options
      ..baseUrl = Env.apiBase
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 30)
      ..headers = {'Accept': 'application/json', 'Accept-Language': 'fr'};
    this.dio.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = _tokens.token;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          options.headers['X-Device-Id'] = await deviceId();
          handler.next(options);
        },
      ),
      cache,
    ]);
  }

  final Dio dio;
  final TokenStore _tokens;
  late final HttpCacheInterceptor cache;

  /// A 401 on an authenticated call: the session is over.
  final void Function()? onUnauthorized;

  /// Every call tells whether the server was reachable (offline banner).
  final void Function(bool reachable)? onReachability;

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => dio.get<dynamic>(path, queryParameters: query));

  Future<ApiResponse> post(String path, {Object? data, String? idempotencyKey}) =>
      _run(() => dio.post<dynamic>(path, data: data, options: _write(idempotencyKey)));

  Future<ApiResponse> delete(String path, {Object? data, String? idempotencyKey}) =>
      _run(() => dio.delete<dynamic>(path, data: data, options: _write(idempotencyKey)));

  Future<ApiResponse> send(String method, String path, {Object? data, String? idempotencyKey}) => _run(
    () => dio.request<dynamic>(
      path,
      data: data,
      options: _write(idempotencyKey).copyWith(method: method),
    ),
  );

  /// Local copy of a GET (instant display, offline).
  Future<({Object? data, DateTime storedAt})?> peek(String path, {Map<String, dynamic>? query}) =>
      cache.peek(path, query: query, baseUrl: dio.options.baseUrl);

  Options _write(String? idempotencyKey) => Options(headers: {'Idempotency-Key': ?idempotencyKey});

  Future<ApiResponse> _run(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      onReachability?.call(true);
      return ApiResponse(
        response.data,
        fromCache: response.extra[HttpCacheInterceptor.fromCacheKey] == true,
        statusCode: response.statusCode ?? 200,
      );
    } catch (error) {
      final exception = ApiException.from(error);
      onReachability?.call(!(exception.kind == ApiErrorKind.offline || exception.kind == ApiErrorKind.timeout));
      if (exception.kind == ApiErrorKind.unauthorized && _tokens.token != null) onUnauthorized?.call();
      throw exception;
    }
  }
}

class ApiResponse {
  const ApiResponse(this.data, {this.fromCache = false, this.statusCode = 200});

  final Object? data;
  final bool fromCache;
  final int statusCode;

  Map<String, dynamic> get json => data is Map<String, dynamic> ? data! as Map<String, dynamic> : const {};
}
