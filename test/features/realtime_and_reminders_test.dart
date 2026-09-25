import 'package:battlegame/core/notifications/local_notifier.dart';
import 'package:battlegame/core/realtime/realtime_client.dart';
import 'package:battlegame/features/artist/data/models.dart';
import 'package:battlegame/features/artist/data/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what would be scheduled on the phone.
class RecordingNotifier extends LocalNotifier {
  final scheduled = <({int id, DateTime when, String title})>[];
  final cancelled = <int>[];

  @override
  Future<void> schedule({required int id, required DateTime when, required String title, required String body, String? link}) async {
    if (when.isAfter(DateTime.now())) scheduled.add((id: id, when: when, title: title));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

Journey journey({required String type, DateTime? deadline, bool out = false}) => Journey.fromJson({
      'data': {
        'competition': {'slug': 'abidjan', 'name': 'Abidjan Rap'},
        'participant': {'stage_name': 'Awa', 'status': 'valide', 'paid': true},
        'out': out,
        'champion': false,
        'next': {'type': type, 'text': '…', 'deadline': deadline?.toIso8601String(), 'match_id': 4},
        'phases': <Object>[],
      },
    });

void main() {
  test('reads a realtime update', () {
    final event = RealtimeEvent.fromJson({'channel': 'user.7', 'type': 'performance.validee', 'data': {'competition_id': 3}, 'message': 'Ta prestation est validée.'});

    expect(event.isPersonal, isTrue);
    expect(event.isJury, isFalse);
    expect(event.competitionId, 3);
    expect(event.message, 'Ta prestation est validée.');
  });

  test('schedules the submission reminders 24 h and 1 h before the deadline', () async {
    final notifier = RecordingNotifier();
    final deadline = DateTime.now().add(const Duration(days: 3));

    await ReminderScheduler(notifier).sync(journey(type: 'submit', deadline: deadline));

    expect(notifier.scheduled.map((r) => deadline.difference(r.when)), [const Duration(hours: 24), const Duration(hours: 1)]);
    expect(notifier.cancelled, hasLength(3)); // Old reminders replaced, never duplicated.
  });

  test('reminds to share 1 h before the vote closes, skips past times and eliminated artists', () async {
    final notifier = RecordingNotifier();
    await ReminderScheduler(notifier).sync(journey(type: 'vote', deadline: DateTime.now().add(const Duration(hours: 5))));
    expect(notifier.scheduled.single.title, 'Le vote ferme dans 1 h');

    final soon = RecordingNotifier();
    await ReminderScheduler(soon).sync(journey(type: 'submit', deadline: DateTime.now().add(const Duration(minutes: 30))));
    expect(soon.scheduled, isEmpty);

    final out = RecordingNotifier();
    await ReminderScheduler(out).sync(journey(type: 'submit', deadline: DateTime.now().add(const Duration(days: 2)), out: true));
    expect(out.scheduled, isEmpty);
  });

  test('gives stable notification ids', () {
    expect(notificationId('reminder:abidjan:submit-1h'), notificationId('reminder:abidjan:submit-1h'));
    expect(notificationId('reminder:abidjan:submit-1h'), isNot(notificationId('reminder:abidjan:submit-24h')));
    expect(notificationId('x'), greaterThanOrEqualTo(0));
  });
}
