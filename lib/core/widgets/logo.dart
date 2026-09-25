import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Wordmark: a solid violet mark + « Battle Game » in Sora.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Battle Game',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(size * 0.3)),
            alignment: Alignment.center,
            child: Text(
              'B',
              style: context.text.titleLarge?.copyWith(color: c.onPrimary, fontSize: size * 0.6, height: 1),
            ),
          ),
          const SizedBox(width: Space.sm),
          Text('Battle Game', style: context.text.titleLarge?.copyWith(fontSize: size * 0.72)),
        ],
      ),
    );
  }
}
