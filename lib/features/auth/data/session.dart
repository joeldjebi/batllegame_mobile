import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/database.dart';
import '../../../core/storage/token_store.dart';
import 'models.dart';

sealed class SessionState {
  const SessionState();

  User? get user => null;
}

/// Reading the vault at startup (a few milliseconds).
class SessionLoading extends SessionState {
  const SessionLoading();
}

/// Browsing without an account (feed, competitions): the TikTok way.
class SessionGuest extends SessionState {
  const SessionGuest();
}

class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.user);

  @override
  final User user;
}

/// Sign-in, sign-up, phone verification, password change, sign-out. Offline first:
/// the cached profile opens the app at once, the server refreshes it in background.
class SessionController extends StateNotifier<SessionState> {
  SessionController({required ApiClient Function() api, required TokenStore tokens, required AppDatabase db})
    : _api = api,
      _tokens = tokens,
      _db = db,
      super(const SessionLoading());

  final ApiClient Function() _api;
  final TokenStore _tokens;
  final AppDatabase _db;

  static const String _meKey = 'me';
  static const String _installedKey = 'installed_at';

  /// Key of the local data of the current account.
  String get account => state.user == null ? 'guest' : 'u${state.user!.id}';

  Future<void> restore() async {
    // iOS keeps the Keychain after an uninstall: a fresh install starts signed out.
    if (await _db.readValue(_installedKey) == null) {
      await _tokens.clear();
      await _db.writeValue(_installedKey, DateTime.now().toIso8601String());
    }
    final token = await _tokens.load();
    if (token == null) {
      state = const SessionGuest();
      return;
    }
    final cached = await _db.readValue(_meKey);
    if (cached == null) {
      state = const SessionGuest();
      await refresh().catchError((Object _) {});
      return;
    }
    state = SessionSignedIn(User.fromJson(jsonDecode(cached) as Map<String, dynamic>));
    unawaited(refresh().catchError((Object _) {}));
  }

  /// Latest profile from the server (a 401 signs out, offline keeps the copy).
  Future<void> refresh() async {
    if (_tokens.token == null) return;
    final response = await _api().get('/auth/me');
    await _store(User.fromJson(response.json['data'] as Map<String, dynamic>));
  }

  Future<void> login({required int countryId, required String phone, required String password}) async {
    final response = await _api().post(
      '/auth/login',
      data: {'country_id': countryId, 'phone': phone, 'password': password, 'device_name': 'app-mobile'},
    );
    await _signIn(response.json);
  }

  Future<void> register({required String name, required int countryId, required String phone, required String password}) async {
    final response = await _api().post(
      '/auth/register',
      data: {
        'name': name,
        'country_id': countryId,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
        'device_name': 'app-mobile',
      },
    );
    await _signIn(response.json);
  }

  Future<void> sendCode() => _api().post('/auth/phone/send-code');

  Future<void> verifyCode(String code) async {
    await _api().post('/auth/phone/verify', data: {'code': code});
    await refresh();
  }

  Future<void> changePassword({required String current, required String password}) async {
    final response = await _api().post(
      '/auth/password',
      data: {'current_password': current, 'password': password, 'password_confirmation': password},
    );
    await _store(User.fromJson(response.json['data'] as Map<String, dynamic>));
  }

  Future<void> logout() async {
    try {
      await _api().post('/auth/logout');
    } on ApiException {
      // Offline or already revoked: the token is dropped locally anyway.
    }
    await _clear();
  }

  /// The server refused the token (revoked, expired).
  Future<void> expire() => _clear();

  Future<void> _signIn(Map<String, dynamic> json) async {
    await _tokens.save(json['token'] as String);
    await _store(User.fromJson(json['user'] as Map<String, dynamic>));
  }

  Future<void> _store(User user) async {
    await _db.writeValue(_meKey, jsonEncode(user.toJson()));
    state = SessionSignedIn(user);
  }

  Future<void> _clear() async {
    final previous = account;
    await _tokens.clear();
    await _db.deleteValue(_meKey);
    await _db.forgetAccount(previous);
    state = const SessionGuest();
  }
}
