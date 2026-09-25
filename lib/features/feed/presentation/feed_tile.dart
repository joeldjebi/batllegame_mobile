import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/cached_image.dart';
import '../data/feed_item.dart';
import '../data/video_pool.dart';

/// One full-screen performance: poster at once, then the video; tap = pause,
/// double tap = like (heart burst); actions on the right, credits at the bottom.
class FeedTile extends StatefulWidget {
  const FeedTile({
    super.key,
    required this.item,
    required this.pool,
    required this.active,
    required this.onLike,
    required this.onShare,
    required this.onCompetition,
    required this.onVote,
  });

  final FeedItem item;
  final VideoPool pool;
  final bool active;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onCompetition;
  final VoidCallback onVote;

  @override
  State<FeedTile> createState() => _FeedTileState();
}

class _FeedTileState extends State<FeedTile> with SingleTickerProviderStateMixin {
  bool _pausedByUser = false;
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(FeedTile old) {
    super.didUpdateWidget(old);
    if (!widget.active) _pausedByUser = false;
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _togglePause(VideoPlayerController? player) {
    if (player == null) return;
    setState(() => _pausedByUser = !_pausedByUser);
    _pausedByUser ? player.pause() : player.play();
  }

  void _doubleTapLike() {
    final likes = widget.item.likes;
    if (likes == null || !likes.enabled) return;
    HapticFeedback.mediumImpact();
    _burst.forward(from: 0);
    if (!likes.liked) widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = context.colors;

    return ListenableBuilder(
      listenable: widget.pool,
      builder: (context, _) {
        final player = widget.pool.player(item.key);
        final ready = player != null && player.value.isInitialized;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _togglePause(player),
          onDoubleTap: _doubleTapLike,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              // Poster: instant, from the disk once seen.
              if (item.media.posterUrl != null)
                CachedImage(cacheKey: '${item.key}-poster', url: item.media.posterUrl, fit: item.media.isPortrait ? BoxFit.cover : BoxFit.contain),
              // The video layer appears with its first frame (the poster stays until then: no black flash).
              if (ready)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: player,
                  builder: (context, value, child) => AnimatedOpacity(
                    opacity: value.isPlaying || value.position > Duration.zero ? 1 : 0,
                    duration: Motion.fast,
                    child: child,
                  ),
                  child: RepaintBoundary(
                    child: FittedBox(
                      fit: item.media.isPortrait ? BoxFit.cover : BoxFit.contain,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(width: player.value.size.width, height: player.value.size.height, child: VideoPlayer(player)),
                    ),
                  ),
                ),
              if (!ready && widget.active)
                const Center(child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70))),
              if (_pausedByUser)
                Center(child: Icon(Icons.play_arrow_rounded, size: 84, color: Colors.white.withValues(alpha: 0.85))),
              // Double-tap heart.
              Center(
                child: AnimatedBuilder(
                  animation: _burst,
                  builder: (context, _) {
                    final t = Curves.easeOutBack.transform((_burst.value * 1.6).clamp(0, 1));
                    final fade = _burst.value < 0.6 ? 1.0 : 1 - (_burst.value - 0.6) / 0.4;
                    return _burst.isAnimating
                        ? Opacity(opacity: fade, child: Transform.scale(scale: 0.6 + t * 0.6, child: Icon(Icons.favorite_rounded, size: 120, color: c.like)))
                        : const SizedBox.shrink();
                  },
                ),
              ),
              // Bottom veil for the credits (solid, no gradient).
              Positioned(left: 0, right: 0, bottom: 0, height: 170, child: ColoredBox(color: Colors.black.withValues(alpha: 0.28))),
              Positioned(
                left: Space.lg,
                right: 88,
                bottom: Space.lg,
                child: _Credits(item: item, onCompetition: widget.onCompetition),
              ),
              Positioned(
                right: Space.sm,
                bottom: Space.lg,
                child: _Actions(item: item, onLike: widget.onLike, onShare: widget.onShare, onVote: widget.onVote, onCompetition: widget.onCompetition),
              ),
              if (ready)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: 2,
                    child: VideoProgressIndicator(player, allowScrubbing: false, padding: EdgeInsets.zero, colors: VideoProgressColors(playedColor: c.primary, backgroundColor: Colors.white24, bufferedColor: Colors.white38)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

const _shadow = [Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1))];

class _Credits extends StatelessWidget {
  const _Credits({required this.item, required this.onCompetition});

  final FeedItem item;
  final VoidCallback onCompetition;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('@${item.stageName}', style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, shadows: _shadow)),
        const SizedBox(height: Space.xs),
        Text(
          [item.contextLabel, if (item.discipline != null) Labels.discipline(item.discipline)].where((s) => s.isNotEmpty).join(' · '),
          style: text.bodyMedium?.copyWith(color: Colors.white, shadows: _shadow),
        ),
        const SizedBox(height: Space.sm),
        Semantics(
          button: true,
          label: 'Voir la compétition ${item.competitionName}',
          child: GestureDetector(
            onTap: onCompetition,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(Radii.pill)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.trophy, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Flexible(child: Text(item.competitionName, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelMedium?.copyWith(color: Colors.white))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.item, required this.onLike, required this.onShare, required this.onVote, required this.onCompetition});

  final FeedItem item;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onVote;
  final VoidCallback onCompetition;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final likes = item.likes;
    final vote = item.vote;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Profil de ${item.stageName}',
          child: GestureDetector(
            onTap: onCompetition,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Avatar(name: item.stageName, url: item.avatarUrl, size: 46),
            ),
          ),
        ),
        const SizedBox(height: Space.xl),
        if (likes != null && likes.enabled)
          _ActionButton(
            icon: likes.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: likes.liked ? c.like : Colors.white,
            label: likes.count != null ? Labels.count(likes.count!) : 'J\'aime',
            semantics: likes.liked ? 'Retirer mon like' : 'Liker cette prestation',
            onTap: likes.open ? onLike : null,
          ),
        if (vote != null)
          _ActionButton(
            icon: Icons.how_to_vote_rounded,
            color: vote.open ? c.accent : Colors.white,
            label: vote.open ? 'Voter' : 'Match',
            semantics: vote.open ? 'Voter pour ce match' : 'Voir le match',
            onTap: onVote,
          ),
        _ActionButton(icon: Icons.ios_share_rounded, color: Colors.white, label: 'Partager', semantics: 'Partager la prestation', onTap: onShare),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.color, required this.label, required this.semantics, this.onTap});

  final IconData icon;
  final Color color;
  final String label;
  final String semantics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          radius: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.xs),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: Icon(icon, key: ValueKey(icon), size: 36, color: onTap == null ? color.withValues(alpha: 0.5) : color, shadows: _shadow),
                ),
                const SizedBox(height: 2),
                Text(label, style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600, shadows: _shadow)),
              ],
            ),
          ),
        ),
      );
}
