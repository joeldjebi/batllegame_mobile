/// Build-time configuration (`--dart-define=API_URL=https://…`).
abstract final class Env {
  /// Backend root, without `/api`. Default: the test server.
  static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://185.215.167.87:8081');

  static String get apiBase => '$apiUrl/api';

  static const String appName = 'Battle Game';

  /// Shown in Réglages (`--dart-define=APP_VERSION=…` at release time).
  static const String version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// Development only: open the app on a given screen (`--dart-define=START=/auth/connexion`).
  static const String startRoute = String.fromEnvironment('START', defaultValue: '/');
}
