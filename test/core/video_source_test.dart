import 'dart:io';

import 'package:battlegame/core/media/media_cache.dart';
import 'package:battlegame/core/media/video_source.dart';
import 'package:battlegame/core/providers.dart';
import 'package:battlegame/features/feed/data/feed_item.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

class _Network extends Fake implements Connectivity {
  _Network(this.link);

  final ConnectivityResult link;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [link];
}

void main() {
  late Directory dir;
  late MediaCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('source');
    cache = MediaCache(directory: () async => dir);
  });
  tearDown(() => dir.delete(recursive: true));

  const media = MediaInfo(type: 'video', url: 'https://s3/b/x/hd.mp4?sig=1', lightUrl: 'https://s3/b/x/hd-sd.mp4?sig=1');
  final wifi = _Network(ConnectivityResult.wifi);
  final mobile = _Network(ConnectivityResult.mobile);

  Future<String?> pick(VideoQuality quality, Connectivity network, [MediaInfo m = media]) async =>
      (await pickVideoSource(cache, 'preselection-3', m, quality, connectivity: network))?.url;

  test('Auto: HD on Wi-Fi, the light copy on mobile data; the settings force one', () async {
    expect(await pick(VideoQuality.auto, wifi), media.url);
    expect(await pick(VideoQuality.auto, mobile), media.lightUrl);
    expect(await pick(VideoQuality.hd, mobile), media.url);
    expect(await pick(VideoQuality.eco, wifi), media.lightUrl);
    // No light copy: always HD.
    expect(await pick(VideoQuality.eco, mobile, const MediaInfo(type: 'video', url: 'https://s3/b/x/small.mp4')), 'https://s3/b/x/small.mp4');
  });

  test('a copy already on the phone comes first (it costs nothing)', () async {
    await File('${dir.path}/${mediaFileKey('preselection-3', media.url!)}').writeAsString('hd');
    final source = await pickVideoSource(cache, 'preselection-3', media, VideoQuality.eco, connectivity: mobile);
    expect(source?.url, media.url);
    expect(source?.file, isNotNull);

    await dir.list().forEach((f) => f.deleteSync());
    await File('${dir.path}/${mediaFileKey('preselection-3', media.lightUrl!)}').writeAsString('light');
    expect((await pickVideoSource(cache, 'preselection-3', media, VideoQuality.auto, connectivity: wifi))?.url, media.lightUrl);
    // HD forced: the light copy on the phone is not enough.
    expect(await pick(VideoQuality.hd, wifi), media.url);
  });
}
