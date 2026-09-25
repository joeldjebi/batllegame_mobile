import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

enum ChipTone { neutral, live, success, info, danger }

/// Small status label: a colored dot + text (never color alone).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = ChipTone.neutral, this.onDark = false});

  final String label;
  final ChipTone tone;

  /// Over a video: solid dark veil.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dot = switch (tone) {
      ChipTone.live => c.like,
      ChipTone.success => c.success,
      ChipTone.info => c.accent,
      ChipTone.danger => c.danger,
      ChipTone.neutral => c.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? c.scrim : c.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: onDark ? null : Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: context.text.labelSmall?.copyWith(color: c.text)),
        ],
      ),
    );
  }
}
