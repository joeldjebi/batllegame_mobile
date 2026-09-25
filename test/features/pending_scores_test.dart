import 'package:battlegame/core/offline/outbox.dart';
import 'package:battlegame/features/jury/data/pending_scores.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('keeps the notes offline, then forgets them once the server confirms', () async {
    final server = FakeServer((_) => reply(201, {'message': 'Notes enregistrées.'}))..offline = true;
    final db = memoryDatabase();
    final outbox = Outbox(db: db, api: fakeApi(server, db), account: () => 'u1');
    final pending = PendingScores(db: db, outbox: outbox);
    final key = PendingScores.entryKey('abidjan', 7);

    await pending.submit(key: key, path: '/competitions/abidjan/preselection/entries/7/scores', body: {'scores': <Object>[]}, scores: {1: 8, 2: 6.5}, label: 'Note');
    await outbox.flush();
    expect(pending.state[key], {1: 8, 2: 6.5});

    // Restarted app: still pending, from the phone.
    final reopened = PendingScores(db: db, outbox: outbox);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(reopened.state[key], {1: 8, 2: 6.5});

    server.offline = false;
    await outbox.flush(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(pending.state[key], isNull);
    expect(pending.confirmed[key], {1: 8, 2: 6.5});
  });

  test('drops a refused note and keeps the reason', () async {
    final server = FakeServer((_) => reply(422, {'message': 'Tes notes sont définitives.'}));
    final db = memoryDatabase();
    final outbox = Outbox(db: db, api: fakeApi(server, db), account: () => 'u1');
    final pending = PendingScores(db: db, outbox: outbox);
    final key = PendingScores.entryKey('abidjan', 8);

    await pending.submit(key: key, path: '/x', body: {}, scores: {1: 5}, label: 'Note');
    await outbox.flush();
    await Future<void>.delayed(Duration.zero);

    expect(pending.state[key], isNull);
    expect(pending.lastError?.message, 'Tes notes sont définitives.');
  });
}
