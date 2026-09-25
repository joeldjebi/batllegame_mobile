import 'package:battlegame/features/auth/data/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Map<String, Object?> userJson({bool mustChange = false}) => {
  'id': 7,
  'name': 'Awa',
  'phone': '+2250700000002',
  'phone_verified': true,
  'must_change_password': mustChange,
  'is_judge': false,
};

void main() {
  test('signs in, then reopens offline from the cached profile', () async {
    final db = memoryDatabase();
    final tokens = MemoryTokenStore();
    final server = FakeServer(
      (request) => request.path.endsWith('/auth/login')
          ? reply(200, {'token': 'abc', 'user': userJson()})
          : reply(200, {'data': userJson()}),
    );
    final session = SessionController(
      api: () => fakeApi(server, db, tokens: tokens),
      tokens: tokens,
      db: db,
    );
    await session.restore(); // first launch
    expect(session.state, isA<SessionGuest>());

    await session.login(countryId: 1, phone: '0700000002', password: '12345678');
    expect(session.state, isA<SessionSignedIn>());
    expect(tokens.token, 'abc');

    // App restarted without network: signed in at once from the local copy.
    server.offline = true;
    final restarted = SessionController(
      api: () => fakeApi(server, db, tokens: tokens),
      tokens: tokens,
      db: db,
    );
    await restarted.restore();
    expect(restarted.state.user?.name, 'Awa');
  });

  test('signs out locally even offline and forgets the account data', () async {
    final db = memoryDatabase();
    final tokens = MemoryTokenStore();
    final server = FakeServer((_) => reply(200, {'token': 'abc', 'user': userJson()}));
    final session = SessionController(
      api: () => fakeApi(server, db, tokens: tokens),
      tokens: tokens,
      db: db,
    );
    await session.login(countryId: 1, phone: '0700000002', password: '12345678');

    server.offline = true;
    await session.logout();

    expect(session.state, isA<SessionGuest>());
    expect(tokens.token, isNull);
    expect(await db.readValue('me'), isNull);
  });

  test('starts signed out after a reinstall even if the vault kept a token', () async {
    final db = memoryDatabase();
    final tokens = MemoryTokenStore('left-by-a-previous-install');
    final server = FakeServer((_) => reply(200, {'data': userJson()}));
    final session = SessionController(
      api: () => fakeApi(server, db, tokens: tokens),
      tokens: tokens,
      db: db,
    );

    await session.restore();

    expect(session.state, isA<SessionGuest>());
    expect(tokens.token, isNull);
    expect(server.requests, isEmpty);
  });
}
