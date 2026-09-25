import 'package:flutter/material.dart';

import 'brand.dart';

/// Semantic colors of one experience. Widgets never use raw hex values: they read
/// `context.colors` (see [AppColorsX]).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.like,
    required this.success,
    required this.warning,
    required this.danger,
    required this.scrim,
  });

  /// Dark theme (and always the video feed): deep neutral, the video comes first.
  static const AppColors dark = AppColors(
    background: Color(0xFF09090F),
    surface: Color(0xFF14141D),
    surfaceRaised: Color(0xFF1E1E2A),
    border: Color(0x1FFFFFFF),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFFA3A3B8),
    primary: Brand.primary,
    onPrimary: Color(0xFFFFFFFF),
    accent: Brand.c400,
    like: Color(0xFFFF3D6E),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFFB7185),
    scrim: Color(0x99000000),
  );

  /// Light theme, the default: clear, calm, professional.
  static const AppColors light = AppColors(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    text: Color(0xFF0F172A),
    textMuted: Color(0xFF475569),
    primary: Brand.primary,
    onPrimary: Color(0xFFFFFFFF),
    accent: Brand.c700,
    like: Color(0xFFE11D48),
    success: Color(0xFF047857),
    warning: Color(0xFFB45309),
    danger: Color(0xFFBE123C),
    scrim: Color(0x66000000),
  );

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color like;
  final Color success;
  final Color warning;
  final Color danger;

  /// Solid veil over videos and sheets (no gradients: owner's rule).
  final Color scrim;

  @override
  AppColors copyWith({Color? background, Color? surface, Color? primary}) => AppColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised,
    border: border,
    text: text,
    textMuted: textMuted,
    primary: primary ?? this.primary,
    onPrimary: onPrimary,
    accent: accent,
    like: like,
    success: success,
    warning: warning,
    danger: danger,
    scrim: scrim,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      border: l(border, other.border),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      like: l(like, other.like),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      scrim: l(scrim, other.scrim),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
