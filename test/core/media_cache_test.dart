import 'dart:io';

import 'package:battlegame/core/media/media_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('media'));
  tearDown(() => dir.delete(recursive: true));

  test('keys a file by id and storage path: stable across signed URLs, new when the file is replaced', () {
    const first = 'https://s3.example/battle-game/submissions/3/a1b2.mp4?X-Amz-Signature=one';
    const resigned = 'https://s3.example/battle-game/submissions/3/a1b2.mp4?X-Amz-Signature=two';
    const replaced = 'https://s3.example/battle-game/submissions/3/c3d4.mp4?X-Amz-Signature=one';

    expect(mediaFileKey('media-12', first), mediaFileKey('media-12', resigned));
    expect(mediaFileKey('media-12', first), isNot(mediaFileKey('media-12', replaced)));
    expect(mediaFileKey('media-12', first), startsWith('media-12-'));
    expect(mediaFileKey('media-12', first), endsWith('.mp4'));
    expect(mediaFileKey('media-12', 'https://x/poster-1.jpg'), endsWith('.jpg'));
  });

  test('downloads once for concurrent requests, completes, then serves the disk copy', () async {
    final server = FakeServer((_) => reply(200, 'poster-bytes'));
    final cache = MediaCache(dio: Dio()..httpClientAdapter = server, directory: () async => dir);

    final results = await Future.wait([
      cache.fetch('p-poster', 'http://x/p.jpg'),
      cache.fetch('p-poster', 'http://x/p.jpg'),
    ]).timeout(const Duration(seconds: 5));

    expect(results.every((f) => f != null), isTrue);
    expect(server.requests, hasLength(1));
    expect(await cache.file('p-poster'), isNotNull);

    // Next time: from the disk, no request.
    await cache.fetch('p-poster', 'http://x/p.jpg');
    expect(server.requests, hasLength(1));
  });

  test('never exposes a partial file when the download fails', () async {
    final server = FakeServer((_) => reply(500))..offline = true;
    final cache = MediaCache(dio: Dio()..httpClientAdapter = server, directory: () async => dir);

    expect(await cache.fetch('v.mp4', 'http://x/v.mp4').timeout(const Duration(seconds: 5)), isNull);
    expect(await cache.file('v.mp4'), isNull);
    expect(dir.listSync(), isEmpty);
  });

  test('evicts the least recently used files over the budget', () async {
    final server = FakeServer((_) => reply(200, 'x' * 400));
    final cache = MediaCache(dio: Dio()..httpClientAdapter = server, directory: () async => dir, budgetBytes: 1000);

    for (final key in ['a', 'b', 'c']) {
      await cache.fetch(key, 'http://x/$key');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(await cache.file('a'), isNull);
    expect(await cache.file('c'), isNotNull);
  });
}
