import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/media_cache.dart';
import 'feed_item.dart';

/// Players of the feed: at most a handful alive (current, previous, next ones),
/// created from the disk copy when there is one, else streamed. The video watched
/// is saved to disk whatever the network (watching it again never reloads it),
/// the next ones only on Wi-Fi (or « always »); nothing with the « never » setting.
class VideoPool extends ChangeNotifier {
  VideoPool(this._cache, {Connectivity? connectivity, this.prefetch = _wifi}) : _connectivity = connectivity ?? Connectivity();

  static String _wifi() => 'wifi';

  /// Data saver setting: `wifi` (default), `always`, `never`.
  final String Function() prefetch;

  final MediaCache _cache;
  final Connectivity _connectivity;
  final Map<String, VideoPlayerController> _players = {};
  final Map<String, Future<VideoPlayerController?>> _creating = {};

  /// Disk key and URL of each item created, to save the one being watched.
  final Map<String, ({String key, String url})> _sources = {};
  bool _muted = false;

  /// The item that should play: a player ready later starts at once.
  String? _current;
  bool _disposed = false;

  bool get muted => _muted;

  VideoPlayerController? player(String key) => _players[key];

  /// Keeps these items ready (in order of priority), releases the others.
  Future<void> keep(List<FeedItem> items) async {
    final wanted = items.map((i) => i.key).toSet();
    for (final key in _players.keys.where((k) => !wanted.contains(k)).toList()) {
      final player = _players.remove(key)!;
      unawaited(player.dispose());
    }
    for (final item in items) {
      await _ensure(item);
    }
  }

  Future<VideoPlayerController?> _ensure(FeedItem item) {
    if (_players.containsKey(item.key)) return Future.value(_players[item.key]);
    final url = item.media.url;
    if (url == null || !item.media.isVideo) return Future.value(null);
    return _creating[item.key] ??= _create(item, url).whenComplete(() {
      _creating.remove(item.key);
    });
  }

  Future<VideoPlayerController?> _create(FeedItem item, String url) async {
    final key = mediaFileKey(item.key, url);
    _sources[item.key] = (key: key, url: url);
    final file = await _cache.file(key);
    final player = file != null ? VideoPlayerController.file(file) : VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await player.initialize();
    } catch (_) {
      await player.dispose();
      return null;
    }
    if (_disposed) {
      await player.dispose();
      return null;
    }
    await player.setLooping(true);
    await player.setVolume(_muted ? 0 : 1);
    _players[item.key] = player;
    if (item.key == _current) unawaited(player.play());
    notifyListeners();

    final mode = prefetch();
    if (file == null && mode != 'never' && (item.key == _current || mode == 'always' || await _onWifi())) _cache.prefetch(key, url);
    return player;
  }

  Future<bool> _onWifi() async {
    final links = await _connectivity.checkConnectivity();
    return links.contains(ConnectivityResult.wifi) || links.contains(ConnectivityResult.ethernet);
  }

  /// Only [key] plays; the others wait at their start.
  void play(String? key) {
    _current = key;
    _keepWatched(key);
    for (final entry in _players.entries) {
      if (entry.key == key) {
        if (!entry.value.value.isPlaying) unawaited(entry.value.play());
      } else if (entry.value.value.isPlaying || entry.value.value.position > Duration.zero) {
        unawaited(entry.value.pause().then((_) => entry.value.seekTo(Duration.zero)));
      }
    }
  }

  /// The video being watched stays on the phone (one download, in the background).
  void _keepWatched(String? key) {
    final source = key == null ? null : _sources[key];
    if (source == null || prefetch() == 'never') return;
    _cache.prefetch(source.key, source.url);
  }

  void pauseAll() {
    _current = null;
    for (final player in _players.values) {
      unawaited(player.pause());
    }
  }

  void toggleMute() {
    _muted = !_muted;
    for (final player in _players.values) {
      unawaited(player.setVolume(_muted ? 0 : 1));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final player in _players.values) {
      unawaited(player.dispose());
    }
    _players.clear();
    super.dispose();
  }
}
