/// Build-time configuration (`--dart-define=API_URL=https://…`).
abstract final class Env {
  /// Backend root, without `/api`. Default: the test server.
  static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://185.215.167.87:8081');

  static String get apiBase => '$apiUrl/api';

  static const String appName = 'Battle Game';

  /// Development only: open the app on a given screen (`--dart-define=START=/auth/connexion`).
  static const String startRoute = String.fromEnvironment('START', defaultValue: '/');
}
