import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// « Maintenir pour voter »: the ring fills while the finger stays down (a vote is
/// final, a hold avoids accidental taps), a firm haptic confirms. Screen readers get
/// a plain activation instead of the hold.
class HoldToVote extends StatefulWidget {
  const HoldToVote({super.key, required this.label, required this.onVote, this.onQuickTap, this.enabled = true, this.voted = false, this.compact = false});

  final String label;
  final VoidCallback onVote;

  /// Released too soon: explain the hold (a toast).
  final VoidCallback? onQuickTap;
  final bool enabled;
  final bool voted;
  final bool compact;

  @override
  State<HoldToVote> createState() => _HoldToVoteState();
}

class _HoldToVoteState extends State<HoldToVote> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onVote();
        _hold.reset();
      }
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled || widget.voted) return;
    HapticFeedback.selectionClick();
    context.reduceMotion ? _hold.value = 1 : _hold.forward(from: 0);
  }

  Offset? _origin;

  void _cancel() {
    _origin = null;
    if (_hold.isAnimating) _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = widget.enabled && !widget.voted;
    final text = widget.voted ? 'Ton vote' : widget.label;
    final height = widget.compact ? 36.0 : 44.0;

    return Semantics(
      button: true,
      enabled: active,
      label: widget.voted ? 'Tu as voté pour cet artiste' : widget.label,
      onTap: active ? widget.onVote : null,
      excludeSemantics: true,
      // Raw pointer events: the hold starts as soon as the finger is down (no gesture
      // arena hand-over from tap to long press), a scroll of the page cancels it.
      child: Listener(
        onPointerDown: (event) {
          _origin = event.position;
          _start();
        },
        onPointerMove: (event) {
          if (_origin != null && (event.position - _origin!).distance > 12) _cancel();
        },
        onPointerUp: (_) {
          if (_hold.isAnimating && _hold.value < 0.5) widget.onQuickTap?.call();
          _cancel();
        },
        onPointerCancel: (_) => _cancel(),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) {
            final fill = _hold.value;
            Widget label(Color color) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.voted ? AppIcons.done : AppIcons.vote, size: widget.compact ? 15 : 17, color: color),
                  const SizedBox(width: Space.xs + 2),
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (widget.compact ? context.text.labelMedium : context.text.labelLarge)?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            );
            // The fill runs edge to edge inside the pill (clipped to its shape), and the
            // label turns white exactly where the fill has passed: one gauge, no jump.
            return ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Container(
                height: height,
                color: widget.voted ? c.success : (active ? Colors.white : Colors.white24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (fill > 0)
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fill,
                        child: ColoredBox(color: c.primary),
                      ),
                    label(_fg(c, active)),
                    if (fill > 0) ClipRect(clipper: _LeftPart(fill), child: label(Colors.white)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _fg(AppColors c, bool active) => widget.voted ? Colors.white : (active ? const Color(0xFF0B0B12) : Colors.white70);
}

/// The left [fraction] of the button (the part the fill has covered).
class _LeftPart extends CustomClipper<Rect> {
  const _LeftPart(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftPart old) => old.fraction != fraction;
}
