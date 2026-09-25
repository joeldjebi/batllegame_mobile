import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/brand.dart';

/// Typographic wordmark: « Battle » bold, « Game » light, the brand dot.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = TextStyle(fontFamily: Brand.displayFont, fontSize: size, height: 1, letterSpacing: -0.4, color: c.text);
    return Semantics(
      label: 'Battle Game',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Battle', style: base.copyWith(fontWeight: FontWeight.w800)),
          TextSpan(text: 'Game', style: base.copyWith(fontWeight: FontWeight.w600, color: c.textMuted)),
          TextSpan(text: '.', style: base.copyWith(fontWeight: FontWeight.w800, color: c.primary)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
