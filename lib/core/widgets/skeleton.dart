import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Loading placeholder with the shape of the content: solid blocks that softly pulse
/// (no shimmer gradient — owner's rule; still under reduced motion).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = Radii.sm, this.circle = false});

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900), lowerBound: 0.45, upperBound: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.reduceMotion ? _pulse.value = 0.7 : _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: FadeTransition(
          opacity: _pulse,
          child: Container(
            width: widget.circle ? widget.height : widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: context.colors.surfaceRaised,
              shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
            ),
          ),
        ),
      );
}

/// A list of card-shaped placeholders (lists of competitions, entries, journeys).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.avatar = true});

  final int count;
  final bool avatar;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Chargement',
        liveRegion: true,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Space.gutter),
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(height: Space.md),
          itemBuilder: (context, i) => Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: context.colors.border)),
            child: Row(
              children: [
                if (avatar) ...[const Skeleton(height: 44, circle: true), const SizedBox(width: Space.md)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: i.isEven ? 180 : 140, height: 16),
                      const SizedBox(height: Space.sm),
                      const Skeleton(width: 96, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
