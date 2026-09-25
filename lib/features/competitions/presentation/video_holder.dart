import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/media_cache.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../feed/data/feed_item.dart';

/// One player for the match / full-screen views: disk copy first, else streamed
/// (and saved for next time).
class VideoPlayerControllerHolder {
  VideoPlayerControllerHolder._(this.controller);

  final VideoPlayerController controller;

  static Future<VideoPlayerControllerHolder?> open(MediaCache cache, String key, MediaInfo media) async {
    final url = media.url;
    if (url == null) return null;
    key = mediaFileKey(key, url);
    final file = await cache.file(key);
    final controller = file != null ? VideoPlayerController.file(file) : VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      return null;
    }
    if (file == null) cache.prefetch(key, url);
    return VideoPlayerControllerHolder._(controller);
  }

  Widget build(BuildContext context) => ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) => GestureDetector(
          onTap: () => value.isPlaying ? controller.pause() : controller.play(),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AspectRatio(aspectRatio: value.aspectRatio, child: VideoPlayer(controller)),
              if (!value.isPlaying) const Positioned.fill(child: Center(child: Icon(AppIcons.play, size: 72, color: Colors.white))),
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 10),
                colors: VideoProgressColors(playedColor: context.colors.primary, backgroundColor: Colors.white24, bufferedColor: Colors.white38),
              ),
            ],
          ),
        ),
      );

  void dispose() => controller.dispose();
}
