import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../features/feed/data/feed_item.dart';
import '../providers.dart';
import 'media_cache.dart';

/// The file to play for a video: its disk key, URL, and the disk copy when there is one.
typedef VideoSource = ({String key, String url, File? file});

/// Picks the HD file or its light copy (480p): a copy already on the phone first (it
/// costs nothing), else HD on Wi-Fi and the light copy on mobile data (« Auto »), or
/// what the setting forces. Without a light copy, always HD.
Future<VideoSource?> pickVideoSource(MediaCache cache, String baseKey, MediaInfo media, VideoQuality quality, {Connectivity? connectivity}) async {
  final hd = media.url;
  if (hd == null) return null;
  final light = media.lightUrl;
  final hdKey = mediaFileKey(baseKey, hd);

  final hdFile = await cache.file(hdKey);
  if (hdFile != null || light == null) return (key: hdKey, url: hd, file: hdFile);

  final lightKey = mediaFileKey(baseKey, light);
  final lightFile = await cache.file(lightKey);
  if (lightFile != null && quality != VideoQuality.hd) return (key: lightKey, url: light, file: lightFile);

  final useLight = switch (quality) {
    VideoQuality.hd => false,
    VideoQuality.eco => true,
    VideoQuality.auto => !await isOnWifi(connectivity ?? Connectivity()),
  };
  return useLight ? (key: lightKey, url: light, file: null) : (key: hdKey, url: hd, file: null);
}

Future<bool> isOnWifi(Connectivity connectivity) async {
  final links = await connectivity.checkConnectivity();
  return links.contains(ConnectivityResult.wifi) || links.contains(ConnectivityResult.ethernet);
}
