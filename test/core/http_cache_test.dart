import 'package:battlegame/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('revalidates with the ETag and serves the local copy on a 304', () async {
    final db = memoryDatabase();
    final server = FakeServer(
      (request) => request.headers['If-None-Match'] == 'W/"v1"' ? reply(304) : reply(200, {'data': 'fresh'}, {'etag': 'W/"v1"'}),
    );
    final api = fakeApi(server, db);

    final first = await api.get('/competitions');
    expect(first.json['data'], 'fresh');
    expect(first.fromCache, isFalse);

    final second = await api.get('/competitions');
    expect(server.requests.last.headers['If-None-Match'], 'W/"v1"');
    expect(second.fromCache, isTrue);
    expect(second.json['data'], 'fresh');

    // Offline: the copy is still readable for an instant display.
    server.offline = true;
    expect((await api.peek('/competitions'))?.data, {'data': 'fresh'});
    await expectLater(api.get('/competitions'), throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.offline)));
  });

  test('never shares the cache between two accounts', () async {
    final db = memoryDatabase();
    final server = FakeServer((_) => reply(200, {'data': 'mine'}, {'etag': 'W/"a"'}));
    await fakeApi(server, db).get('/auth/me');

    expect(await fakeApi(server, db, account: 'u2').peek('/auth/me'), isNull);
  });

  test('turns API errors into French messages with the field errors', () async {
    final db = memoryDatabase();
    final server = FakeServer(
      (_) => reply(422, {
        'message': 'Numéro ou mot de passe incorrect.',
        'errors': {
          'phone': ['Numéro ou mot de passe incorrect.'],
        },
      }),
    );

    await expectLater(
      fakeApi(server, db).post('/auth/login'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.validation)
            .having((e) => e.fieldErrors['phone'], 'phone', 'Numéro ou mot de passe incorrect.'),
      ),
    );
  });
}
