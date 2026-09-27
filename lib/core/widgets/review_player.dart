import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../features/competitions/presentation/video_holder.dart';
import '../../features/feed/data/feed_item.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/tokens.dart';
import 'cached_image.dart';

const _speeds = [1.0, 1.25, 0.75];
const _seekStep = Duration(seconds: 10);

/// A player to watch a performance closely (jury): play / pause, ±10 s (buttons and
/// double tap), scrubbing with the time, speed and full screen (landscape for a
/// landscape video). Sound always on.
class ReviewPlayer extends ConsumerStatefulWidget {
  const ReviewPlayer({super.key, required this.cacheKey, required this.media, this.title});

  final String cacheKey;
  final MediaInfo media;

  /// Shown in full screen (the artist).
  final String? title;

  @override
  ConsumerState<ReviewPlayer> createState() => _ReviewPlayerState();
}

class _ReviewPlayerState extends ConsumerState<ReviewPlayer> {
  VideoPlayerControllerHolder? _holder;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // The jury judges on the HD file.
    VideoPlayerControllerHolder.open(ref.read(mediaCacheProvider), widget.cacheKey, widget.media, quality: VideoQuality.hd).then((holder) async {
      if (!mounted) {
        holder?.dispose();
        return;
      }
      if (holder == null) {
        setState(() => _failed = true);
        return;
      }
      await holder.controller.setVolume(1);
      if (!mounted) return;
      setState(() => _holder = holder);
      unawaited(holder.controller.play());
    });
  }

  @override
  void dispose() {
    _holder?.dispose();
    super.dispose();
  }

  Future<void> _fullscreen() async {
    final controller = _holder?.controller;
    if (controller == null) return;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, _, _) => _FullscreenPlayer(controller: controller, title: widget.title),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final holder = _holder;
    if (holder == null) {
      return Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          if (widget.media.posterUrl != null) CachedImage(cacheKey: '${widget.cacheKey}-poster', url: widget.media.posterUrl, fit: BoxFit.contain),
          if (_failed)
            Center(
              child: Text('Vidéo indisponible', style: context.text.bodyMedium?.copyWith(color: Colors.white70)),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white70)),
        ],
      );
    }
    return PlayerSurface(controller: holder.controller, onFullscreen: _fullscreen);
  }
}

/// The video and its controls (inline or full screen).
class PlayerSurface extends StatefulWidget {
  const PlayerSurface({super.key, required this.controller, this.onFullscreen, this.fullscreen = false, this.onClose, this.title});

  final VideoPlayerController controller;
  final VoidCallback? onFullscreen;
  final bool fullscreen;
  final VoidCallback? onClose;
  final String? title;

  @override
  State<PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<PlayerSurface> {
  bool _controls = true;
  Timer? _hide;

  /// « −10 s » / « +10 s » shown briefly after a double tap.
  String? _seekLabel;
  Timer? _seekTimer;

  VideoPlayerController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _seekTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && _c.value.isPlaying) setState(() => _controls = false);
    });
  }

  void _show() {
    setState(() => _controls = true);
    _scheduleHide();
  }

  void _togglePlay() {
    HapticFeedback.selectionClick();
    _c.value.isPlaying ? _c.pause() : _c.play();
    _show();
  }

  void _seekBy(Duration step, {bool fromDoubleTap = false}) {
    final value = _c.value;
    var target = value.position + step;
    if (target < Duration.zero) target = Duration.zero;
    if (target > value.duration) target = value.duration;
    _c.seekTo(target);
    HapticFeedback.selectionClick();
    if (fromDoubleTap) {
      _seekTimer?.cancel();
      setState(() => _seekLabel = step.isNegative ? '−10 s' : '+10 s');
      _seekTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _seekLabel = null);
      });
    }
    _show();
  }

  void _cycleSpeed() {
    final current = _c.value.playbackSpeed;
    final next = _speeds[(_speeds.indexOf(current) + 1) % _speeds.length];
    _c.setPlaybackSpeed(next);
    _show();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: _c,
    builder: (context, value, _) {
      final ended = value.duration > Duration.zero && value.position >= value.duration - const Duration(milliseconds: 300) && !value.isPlaying;
      final visible = _controls || !value.isPlaying;
      return LayoutBuilder(
        builder: (context, box) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => visible && value.isPlaying ? setState(() => _controls = false) : _show(),
          onDoubleTapDown: (details) => _doubleTapX = details.localPosition.dx,
          onDoubleTap: () {
            final x = _doubleTapX ?? box.maxWidth / 2;
            if (x < box.maxWidth / 3) {
              _seekBy(-_seekStep, fromDoubleTap: true);
            } else if (x > box.maxWidth * 2 / 3) {
              _seekBy(_seekStep, fromDoubleTap: true);
            } else {
              _togglePlay();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(aspectRatio: value.aspectRatio, child: VideoPlayer(_c)),
                ),
              ),
              if (_seekLabel != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Text(
                      _seekLabel!,
                      style: context.text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: _Controls(
                    value: value,
                    ended: ended,
                    fullscreen: widget.fullscreen,
                    title: widget.title,
                    onPlay: ended
                        ? () {
                            _c.seekTo(Duration.zero);
                            _c.play();
                            _show();
                          }
                        : _togglePlay,
                    onBack: () => _seekBy(-_seekStep),
                    onForward: () => _seekBy(_seekStep),
                    onSeek: (position) {
                      _c.seekTo(position);
                      _show();
                    },
                    onSpeed: _cycleSpeed,
                    onFullscreen: widget.fullscreen ? widget.onClose : widget.onFullscreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  double? _doubleTapX;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.value,
    required this.ended,
    required this.fullscreen,
    required this.onPlay,
    required this.onBack,
    required this.onForward,
    required this.onSeek,
    required this.onSpeed,
    this.onFullscreen,
    this.title,
  });

  final VideoPlayerValue value;
  final bool ended;
  final bool fullscreen;
  final VoidCallback onPlay;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onSpeed;
  final VoidCallback? onFullscreen;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final duration = value.duration;
    final position = value.position > duration ? duration : value.position;
    final big = fullscreen ? 72.0 : 58.0;
    final speed = value.playbackSpeed;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: SafeArea(
        top: fullscreen,
        bottom: fullscreen,
        child: Stack(
          children: [
            if (fullscreen)
              Positioned(
                top: Space.sm,
                left: Space.sm,
                right: Space.sm,
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: onFullscreen,
                      icon: const Icon(AppIcons.back, color: Colors.white, size: 20),
                      label: Text(
                        'Noter',
                        style: context.text.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(color: Colors.white70),
                        ),
                      ),
                  ],
                ),
              ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundButton(icon: AppIcons.rewind, label: '10', size: big * 0.7, tooltip: 'Reculer de 10 secondes', onTap: onBack),
                  SizedBox(width: fullscreen ? Space.xxl : Space.xl),
                  _RoundButton(
                    icon: ended ? AppIcons.rewind : (value.isPlaying ? AppIcons.pause : AppIcons.play),
                    size: big,
                    filled: true,
                    tooltip: ended ? 'Revoir' : (value.isPlaying ? 'Pause' : 'Lecture'),
                    onTap: onPlay,
                  ),
                  SizedBox(width: fullscreen ? Space.xxl : Space.xl),
                  _RoundButton(icon: AppIcons.forwardTen, label: '10', size: big * 0.7, tooltip: 'Avancer de 10 secondes', onTap: onForward),
                ],
              ),
            ),
            Positioned(
              left: Space.md,
              right: Space.xs,
              bottom: fullscreen ? Space.md : 0,
              child: Row(
                children: [
                  Text(
                    '${_time(position)} / ${_time(duration)}',
                    style: context.text.labelSmall?.copyWith(color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: context.colors.primary,
                        inactiveTrackColor: Colors.white30,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: duration.inMilliseconds == 0 ? 0 : position.inMilliseconds / duration.inMilliseconds,
                        onChanged: duration.inMilliseconds == 0 ? null : (v) => onSeek(duration * v),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Vitesse ${_speedLabel(speed)}',
                    child: GestureDetector(
                      onTap: onSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: speed == 1 ? Colors.transparent : Colors.white24,
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          _speedLabel(speed),
                          style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: fullscreen ? 'Quitter le plein écran' : 'Plein écran',
                    onPressed: onFullscreen,
                    icon: Icon(fullscreen ? AppIcons.fullscreenExit : AppIcons.fullscreen, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _time(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _speedLabel(double speed) => '${speed.toString().replaceAll(RegExp(r'\.0$'), '').replaceAll('.', ',')}×';
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.size, required this.tooltip, required this.onTap, this.filled = false, this.label});

  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;
  final String? label;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: filled ? Colors.white : Colors.black38, shape: BoxShape.circle),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: size * 0.5, color: filled ? Colors.black : Colors.white),
              if (label != null)
                Text(
                  label!,
                  style: context.text.labelSmall?.copyWith(color: Colors.white, fontSize: size * 0.2, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Full screen, landscape allowed (the phone turns for a landscape video), system bars hidden.
class _FullscreenPlayer extends StatefulWidget {
  const _FullscreenPlayer({required this.controller, this.title});

  final VideoPlayerController controller;
  final String? title;

  @override
  State<_FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<_FullscreenPlayer> {
  @override
  void initState() {
    super.initState();
    final landscape = widget.controller.value.aspectRatio > 1;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
      landscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: PlayerSurface(controller: widget.controller, fullscreen: true, title: widget.title, onClose: () => Navigator.of(context).pop()),
  );
}
