import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../storage/database.dart';

/// ETag revalidation: every GET sends the stored ETag in If-None-Match; a 304 is
/// answered from the local copy (as a 200 marked `fromCache`), a 200 refreshes it.
class HttpCacheInterceptor extends Interceptor {
  HttpCacheInterceptor(this._db, this._account);

  final AppDatabase _db;
  final String Function() _account;

  static const String fromCacheKey = 'fromCache';
  static const String _keyExtra = 'cacheKey';

  static String keyFor(String account, RequestOptions options) => '$account|${options.method}|${options.uri}';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.method == 'GET') {
      final key = keyFor(_account(), options);
      options.extra[_keyExtra] = key;
      final cached = await _read(key);
      if (cached?.etag != null) options.headers['If-None-Match'] = cached!.etag;
      options.validateStatus = (status) => status != null && ((status >= 200 && status < 300) || status == 304);
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) async {
    final key = response.requestOptions.extra[_keyExtra] as String?;
    if (key == null) return handler.next(response);

    if (response.statusCode == 304) {
      final cached = await _read(key);
      if (cached != null) {
        return handler.next(
          Response<dynamic>(
            requestOptions: response.requestOptions,
            statusCode: 200,
            data: await decodeJson(cached.body),
            headers: response.headers,
            extra: {fromCacheKey: true},
          ),
        );
      }
    }

    final etag = response.headers.value('etag');
    if (response.statusCode == 200 && response.data != null) {
      await _db
          .into(_db.httpCacheEntries)
          .insertOnConflictUpdate(
            HttpCacheEntriesCompanion.insert(
              key: key,
              etag: Value(etag),
              body: jsonEncode(response.data),
              storedAt: DateTime.now(),
            ),
          );
    }
    handler.next(response);
  }

  /// Local copy of a GET, for an instant (or offline) display before the network answers.
  Future<({Object? data, DateTime storedAt})?> peek(String path, {Map<String, dynamic>? query, required String baseUrl}) async {
    final options = RequestOptions(path: path, baseUrl: baseUrl, queryParameters: query, method: 'GET');
    final cached = await _read(keyFor(_account(), options));
    return cached == null ? null : (data: await decodeJson(cached.body), storedAt: cached.storedAt);
  }

  Future<HttpCacheEntry?> _read(String key) =>
      (_db.select(_db.httpCacheEntries)..where((t) => t.key.equals(key))).getSingleOrNull();
}

/// Large payloads are decoded off the UI thread (smooth scrolling).
Future<Object?> decodeJson(String body) => body.length > 50000 ? compute(jsonDecode, body) : Future.value(jsonDecode(body));
