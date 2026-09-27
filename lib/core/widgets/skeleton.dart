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

/// Rows of a grouped section, the shape of the lists (competitions, entries, artists):
/// one white rounded block with an avatar and two lines per row.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.avatar = true, this.padding = const EdgeInsets.all(Space.gutter)});

  final int count;
  final bool avatar;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Chargement',
        liveRegion: true,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.xl),
              child: ColoredBox(
                color: context.colors.surface,
                child: Column(
                  children: [
                    for (var i = 0; i < count; i++) ...[
                      if (i > 0) Padding(padding: const EdgeInsets.only(left: 60), child: Divider(height: 1, thickness: 0.5, color: context.colors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                        child: Row(
                          children: [
                            if (avatar) ...[const Skeleton(height: 36, circle: true), const SizedBox(width: Space.lg)],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Skeleton(width: i.isEven ? 180 : 130, height: 14),
                                  const SizedBox(height: Space.sm),
                                  Skeleton(width: i.isEven ? 110 : 150, height: 11),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

/// Posters of a video grid (3 columns), while the videos load.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({super.key, this.count = 6, this.shrink = false});

  final int count;
  final bool shrink;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Chargement',
        liveRegion: true,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: shrink,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 0.66,
          padding: const EdgeInsets.all(2),
          children: [for (var i = 0; i < count; i++) const Skeleton(radius: 0)],
        ),
      );
}
