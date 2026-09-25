import 'package:dio/dio.dart';

enum ApiErrorKind { offline, timeout, unauthorized, forbidden, notFound, conflict, validation, business, server, unknown }

/// An API failure with a French message ready for the UI, and the field errors of a 422.
class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode, this.fieldErrors = const {}});

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) return const ApiException(ApiErrorKind.unknown, 'Une erreur inattendue est survenue.');

    switch (error.type) {
      case DioExceptionType.connectionError:
        return const ApiException(ApiErrorKind.offline, 'Pas de connexion internet.');
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(ApiErrorKind.timeout, 'Le serveur met trop de temps à répondre. Réessaie.');
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorKind.unknown, 'Requête annulée.');
      default:
        break;
    }

    final status = error.response?.statusCode;
    final data = error.response?.data;
    final json = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final message = json['message'] is String ? json['message'] as String : null;

    return switch (status) {
      401 => ApiException(ApiErrorKind.unauthorized, 'Ta session a expiré : reconnecte-toi.', statusCode: status),
      403 => ApiException(ApiErrorKind.forbidden, message ?? 'Action non autorisée.', statusCode: status),
      404 => ApiException(ApiErrorKind.notFound, 'Introuvable.', statusCode: status),
      409 => ApiException(ApiErrorKind.conflict, message ?? 'Déjà fait.', statusCode: status),
      422 when json['errors'] is Map => ApiException(
        ApiErrorKind.validation,
        message ?? 'Vérifie les champs.',
        statusCode: status,
        fieldErrors: _fieldErrors(json['errors'] as Map),
      ),
      final int s when s >= 400 && s < 500 => ApiException(
        ApiErrorKind.business,
        message ?? 'Action impossible.',
        statusCode: status,
      ),
      final int s when s >= 500 => ApiException(
        ApiErrorKind.server,
        'Le serveur rencontre un problème. Réessaie dans un instant.',
        statusCode: status,
      ),
      _ => const ApiException(ApiErrorKind.unknown, 'Une erreur inattendue est survenue.'),
    };
  }

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  /// First message of each invalid field (`phone`, `password`…).
  final Map<String, String> fieldErrors;

  /// Worth retrying later (network, timeout, 5xx): the offline queue keeps these.
  bool get isTransient => kind == ApiErrorKind.offline || kind == ApiErrorKind.timeout || kind == ApiErrorKind.server;

  static Map<String, String> _fieldErrors(Map<dynamic, dynamic> errors) => {
    for (final entry in errors.entries)
      if (entry.value is List && (entry.value as List).isNotEmpty) '${entry.key}': '${(entry.value as List).first}',
  };

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}
