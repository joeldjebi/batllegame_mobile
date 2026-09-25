import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Cache key of a media file: its id + the extension of its URL (`.mp4`, `.mov`…).
/// Players need the extension to recognise the format of a local file (iOS refuses
/// a video file without one).
String mediaFileKey(String id, String url) {
  final ext = RegExp(r'\.([A-Za-z0-9]{2,4})$').firstMatch(Uri.tryParse(url)?.path ?? '')?.group(1)?.toLowerCase();
  return ext == null ? id : '$id.$ext';
}

/// Disk cache of videos and posters, keyed by the media **id** (signed URLs change
/// every few hours, the id never does). Least recently used files go first once the
/// budget is exceeded. A file is only visible once fully downloaded.
class MediaCache {
  MediaCache({Dio? dio, Future<Directory> Function()? directory, this.budgetBytes = 500 * 1024 * 1024})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15))),
        _directory = directory ?? _defaultDirectory;

  final Dio _dio;
  final Future<Directory> Function() _directory;
  final int budgetBytes;
  final Map<String, Future<File?>> _inFlight = {};
  Directory? _dir;

  static Future<Directory> _defaultDirectory() async => Directory('${(await getApplicationCacheDirectory()).path}/media');

  Future<Directory> get _root async => _dir ??= await (await _directory()).create(recursive: true);

  Future<File> _fileFor(String key) async => File('${(await _root).path}/${key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')}');

  /// The cached file, or null. Touching it keeps it (least recently used eviction).
  Future<File?> file(String key) async {
    final file = await _fileFor(key);
    if (!await file.exists()) return null;
    unawaited(file.setLastModified(DateTime.now()).catchError((Object _) {}));
    return file;
  }

  /// The file, downloaded first when missing (one download per key at a time).
  Future<File?> fetch(String key, String url) async {
    final cached = await file(key);
    if (cached != null) return cached;
    // Block body: whenComplete waits for a Future returned by its callback (remove() returns this one).
    return _inFlight[key] ??= _download(key, url).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  /// Warm the cache in the background (next videos of the feed).
  void prefetch(String key, String url) => unawaited(fetch(key, url).catchError((Object _) => null));

  Future<File?> _download(String key, String url) async {
    final target = await _fileFor(key);
    final part = File('${target.path}.part');
    try {
      await _dio.download(url, part.path);
      await part.rename(target.path);
      unawaited(_evict());
      return target;
    } catch (_) {
      if (await part.exists()) await part.delete();
      return null;
    }
  }

  Future<void> _evict() async {
    final files = (await (await _root).list().toList()).whereType<File>().where((f) => !f.path.endsWith('.part')).toList();
    final stats = [for (final f in files) (file: f, stat: await f.stat())];
    var total = stats.fold<int>(0, (sum, s) => sum + s.stat.size);
    if (total <= budgetBytes) return;
    stats.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    for (final s in stats) {
      if (total <= budgetBytes * 0.8) break;
      total -= s.stat.size;
      await s.file.delete().catchError((Object _) => s.file);
    }
  }

  /// Bytes on disk (Réglages).
  Future<int> size() async {
    final root = await _root;
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final entity in root.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Settings › free space.
  Future<void> clear() async {
    final root = await _root;
    if (await root.exists()) await root.delete(recursive: true);
    _dir = null;
  }
}
