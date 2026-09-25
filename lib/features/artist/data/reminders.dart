import '../../../core/notifications/local_notifier.dart';
import 'models.dart';

/// Reminders scheduled on the phone from a journey: the performance to send
/// (24 h and 1 h before the deadline) and the vote to share (1 h before it closes).
/// Rescheduled on every refresh of the journey (dates may move).
class ReminderScheduler {
  const ReminderScheduler(this._notifier);

  final LocalNotifier _notifier;

  static const _kinds = ['submit-24h', 'submit-1h', 'vote-1h'];

  static int idFor(String slug, String kind) => notificationId('reminder:$slug:$kind');

  Future<void> sync(Journey journey) async {
    for (final kind in _kinds) {
      await _notifier.cancel(idFor(journey.slug, kind));
    }
    final next = journey.effectiveNext;
    final deadline = next?.deadline;
    if (journey.out || next == null || deadline == null) return;
    final link = '/competitions/${journey.slug}/parcours';

    if (next.type == 'submit') {
      await _notifier.schedule(
        id: idFor(journey.slug, 'submit-24h'),
        when: deadline.subtract(const Duration(hours: 24)),
        title: 'Plus que 24 h pour envoyer ta prestation',
        body: '${next.stage ?? journey.competitionName} · ${journey.competitionName}',
        link: link,
      );
      await _notifier.schedule(
        id: idFor(journey.slug, 'submit-1h'),
        when: deadline.subtract(const Duration(hours: 1)),
        title: 'Dernière heure pour envoyer ta prestation',
        body: 'Sans prestation à temps, c\'est forfait · ${journey.competitionName}',
        link: link,
      );
    } else if (next.type == 'vote') {
      await _notifier.schedule(
        id: idFor(journey.slug, 'vote-1h'),
        when: deadline.subtract(const Duration(hours: 1)),
        title: 'Le vote ferme dans 1 h',
        body: 'Partage ta prestation pour récolter des votes · ${journey.competitionName}',
        link: next.matchId == null ? link : '/competitions/${journey.slug}/matchs/${next.matchId}',
      );
    }
  }
}
