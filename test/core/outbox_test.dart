import 'package:battlegame/core/offline/outbox.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late FakeServer server;
  late Outbox outbox;
  late DateTime now;

  setUp(() {
    server = FakeServer((_) => reply(201, {'message': 'ok'}));
    final db = memoryDatabase();
    now = DateTime(2026, 9, 25, 12);
    outbox = Outbox(db: db, api: fakeApi(server, db), account: () => 'u1', clock: () => now);
  });

  tearDown(() => outbox.dispose());

  test('sends a queued action once, with its id as Idempotency-Key, then forgets it', () async {
    final id = await outbox.enqueue(method: 'POST', path: '/competitions/x/preselection/entries/1/like', label: 'Like');
    await outbox.flush();

    expect(server.requests, hasLength(1));
    expect(server.requests.single.headers['Idempotency-Key'], id);
    expect(await outbox.watch().first, isEmpty);
  });

  test('keeps the actions offline, in order, and sends them when the network is back', () async {
    server.offline = true;
    await outbox.enqueue(method: 'POST', path: '/first', label: '1');
    await outbox.enqueue(method: 'POST', path: '/second', label: '2');
    await outbox.flush();

    final waiting = await outbox.watch().first;
    expect(waiting.map((a) => a.label), ['1', '2']);
    expect(waiting.first.attempts, 1);
    expect(waiting.first.lastError, 'Pas de connexion internet.');
    // Stopped at the first failure: the order is kept.
    expect(server.requests.map((r) => r.path), everyElement(endsWith('/first')));

    server.offline = false;
    server.requests.clear();
    await outbox.flush(force: true);

    expect(server.requests.map((r) => r.path), [endsWith('/first'), endsWith('/second')]);
    expect(await outbox.watch().first, isEmpty);
  });

  test('backs off after a transient failure', () async {
    server.handler = (_) => reply(503);
    await outbox.enqueue(method: 'POST', path: '/vote', label: 'Vote');
    await outbox.flush();
    await outbox.flush(); // Not due yet: nothing sent.

    expect(server.requests, hasLength(1));
    now = now.add(const Duration(minutes: 1));
    await outbox.flush();
    expect(server.requests, hasLength(2));
  });

  test('marks a refused action as failed and goes on with the next ones', () async {
    server.handler = (request) => request.path.endsWith('/closed') ? reply(422, {'message': 'Le vote est clos.'}) : reply(201);
    final results = <OutboxResult>[];
    final sub = outbox.results.listen(results.add);

    await outbox.enqueue(method: 'POST', path: '/closed', label: 'Vote');
    await outbox.enqueue(method: 'POST', path: '/open', label: 'Like');
    await outbox.flush();
    await Future<void>.delayed(Duration.zero);

    final left = await outbox.watch().first;
    expect(left.single.state, 'failed');
    expect(left.single.lastError, 'Le vote est clos.');
    expect(results.where((r) => r.succeeded), hasLength(1));
    await sub.cancel();
  });
}
