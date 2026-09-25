import 'package:intl/intl.dart';

/// French labels of the API values (same wording as the website).
abstract final class Labels {
  static String competitionStatus(String? value) => switch (value) {
    'inscriptions' => 'Inscriptions ouvertes',
    'en_cours' => 'En cours',
    'terminee' => 'Terminée',
    'annulee' => 'Annulée',
    _ => 'Bientôt',
  };

  static String discipline(String? value) => switch (value) {
    'rap' => 'Rap',
    'chant' => 'Chant',
    'freestyle' => 'Freestyle',
    'slam' => 'Slam',
    'beatbox' => 'Beatbox',
    _ => 'Autre',
  };

  static String matchStatus(String? value) => switch (value) {
    'planifie' => 'Planifié',
    'soumissions' => 'Envois en cours',
    'vote' => 'Vote en cours',
    'cloture' => 'Terminé',
    'annule' => 'Annulé',
    _ => '',
  };

  static String phaseType(String? value) => switch (value) {
    'poules' => 'Poules',
    'elimination' => 'Élimination simple',
    'double_elimination' => 'Double élimination',
    _ => 'Phase',
  };

  static String money(int amount, String currency) =>
      amount == 0 ? 'Gratuit' : '${NumberFormat.decimalPattern('fr').format(amount)} ${currency == 'XOF' ? 'FCFA' : currency}';

  /// « 25 sept. · 18:00 » (local time of the phone).
  static String date(DateTime? date) => date == null ? '' : DateFormat('d MMM · HH:mm', 'fr').format(date.toLocal());

  static String day(DateTime? date) => date == null ? '' : DateFormat('d MMMM y', 'fr').format(date.toLocal());

  /// Compact counts: 1 234 → « 1,2 k ».
  static String count(int value) => value < 1000 ? '$value' : NumberFormat.compact(locale: 'fr').format(value);

  /// « dans 2 h », « dans 3 j » until a deadline.
  static String remaining(DateTime until) {
    final left = until.difference(DateTime.now());
    if (left.isNegative) return 'terminé';
    if (left.inDays >= 1) return 'dans ${left.inDays} j';
    if (left.inHours >= 1) return 'dans ${left.inHours} h';
    return 'dans ${left.inMinutes.clamp(1, 59)} min';
  }

  /// When a vote opens: « Vote dans 18 min », « Vote le 26 sept. · 21:40 », « Vote imminent ».
  static String voteOpens(DateTime at) {
    final left = at.difference(DateTime.now());
    if (left.inSeconds <= 0) return 'Vote imminent';
    if (left.inHours < 24) return 'Vote ${remaining(at)}';
    return 'Vote le ${date(at)}';
  }
}

DateTime? parseDate(Object? value) => value is String ? DateTime.tryParse(value) : null;
