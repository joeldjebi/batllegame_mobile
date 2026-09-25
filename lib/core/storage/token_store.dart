import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API token in the phone's secure vault (Keychain / Keystore), mirrored in memory.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const String _key = 'api_token';

  String? _token;

  String? get token => _token;

  Future<String?> load() async => _token = await _storage.read(key: _key);

  Future<void> save(String token) async {
    _token = token;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _token = null;
    await _storage.delete(key: _key);
  }
}
