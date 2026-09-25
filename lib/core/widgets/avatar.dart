import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/brand.dart';

/// Round photo, or the initials on the brand color while it loads / when there is none.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 40});

  final String name;
  final String? url;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      alignment: Alignment.center,
      color: Brand.c800,
      child: Text(
        _initials,
        style: context.text.labelMedium?.copyWith(color: Brand.c100, fontSize: size * 0.36),
      ),
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);

    // Always shown next to the name: decorative for screen readers.
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: url == null
              ? fallback
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  cacheWidth: (size * dpr).round(),
                  errorBuilder: (_, _, _) => fallback,
                  frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : fallback,
                ),
        ),
      ),
    );
  }
}
