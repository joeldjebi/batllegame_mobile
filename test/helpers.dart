import 'dart:convert';
import 'dart:typed_data';

import 'package:battlegame/core/network/api_client.dart';
import 'package:battlegame/core/storage/database.dart';
import 'package:battlegame/core/storage/token_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A recorded request and the programmed answer of [FakeServer].
typedef Handler = ({int status, Object? body, Map<String, String> headers}) Function(RequestOptions request);

/// In-memory backend: records every request, answers with [handler], or fails like
/// a phone without network when [offline] is true.
class FakeServer implements HttpClientAdapter {
  FakeServer(this.handler);

  Handler handler;
  bool offline = false;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (offline) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    final answer = handler(options);
    return ResponseBody.fromString(
      answer.body == null ? '' : jsonEncode(answer.body),
      answer.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        for (final h in answer.headers.entries) h.key: [h.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({int status, Object? body, Map<String, String> headers}) reply(
  int status, [
  Object? body,
  Map<String, String> headers = const {},
]) => (status: status, body: body, headers: headers);

AppDatabase memoryDatabase() {
  // One fresh in-memory database per test.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Secure storage stand-in (no Keychain in unit tests).
class MemoryTokenStore extends TokenStore {
  MemoryTokenStore([this._value]) : super(const FlutterSecureStorage());

  String? _value;

  @override
  String? get token => _value;

  @override
  Future<String?> load() async => _value;

  @override
  Future<void> save(String token) async => _value = token;

  @override
  Future<void> clear() async => _value = null;
}

ApiClient fakeApi(FakeServer server, AppDatabase db, {TokenStore? tokens, String account = 'u1'}) {
  final dio = Dio()..httpClientAdapter = server;
  return ApiClient(
    db: db,
    tokens: tokens ?? MemoryTokenStore('token-1'),
    account: () => account,
    deviceId: () async => 'device-1',
    dio: dio,
  );
}
