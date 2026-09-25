import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_icons.dart';
import 'brand.dart';
import 'tokens.dart';

/// Material themes of the two experiences, built from [AppColors] and [Brand].
abstract final class AppTheme {
  static final ThemeData _light = _build(AppColors.light, Brightness.light);
  static final ThemeData _dark = _build(AppColors.dark, Brightness.dark);

  /// Default theme.
  static ThemeData light() => _light;

  /// Chosen in Réglages, and always for the video feed.
  static ThemeData dark() => _dark;

  static ThemeData _build(AppColors c, Brightness brightness) {
    final text = _textTheme(c);
    final scheme = ColorScheme.fromSeed(seedColor: Brand.primary, brightness: brightness).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      surface: c.surface,
      onSurface: c.text,
      error: c.danger,
      outline: c.border,
    );

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: Brand.bodyFont,
      textTheme: text,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      // Back / close buttons of the app bars in the same icon family.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(AppIcons.back, size: 22),
        closeButtonIconBuilder: (_) => const Icon(AppIcons.close, size: 22),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md + 2, vertical: 12),
        hintStyle: text.bodyLarge?.copyWith(color: c.textMuted),
        border: border(c.border),
        enabledBorder: border(c.border),
        focusedBorder: border(c.primary, 2),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 2),
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark ? c.surfaceRaised : c.text,
        contentTextStyle: text.bodyMedium?.copyWith(color: brightness == Brightness.dark ? c.text : c.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.background,
        indicatorColor: Colors.transparent,
        height: 60,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(color: states.contains(WidgetState.selected) ? c.text : c.textMuted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(size: 24, color: states.contains(WidgetState.selected) ? c.text : c.textMuted),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.surfaceRaised),
    );
  }

  static TextTheme _textTheme(AppColors c) {
    TextStyle display(double size, FontWeight weight, {double height = 1.15}) => TextStyle(
      fontFamily: Brand.displayFont,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: -0.4,
      color: c.text,
    );
    TextStyle body(double size, FontWeight weight, {Color? color, double height = 1.45}) =>
        TextStyle(fontFamily: Brand.bodyFont, fontSize: size, fontWeight: weight, height: height, color: color ?? c.text);

    return TextTheme(
      displaySmall: display(28, FontWeight.w700),
      headlineMedium: display(24, FontWeight.w700),
      headlineSmall: display(20, FontWeight.w700, height: 1.2),
      titleLarge: display(17, FontWeight.w600, height: 1.25),
      titleMedium: body(15, FontWeight.w600),
      titleSmall: body(14, FontWeight.w600),
      bodyLarge: body(15, FontWeight.w400),
      bodyMedium: body(14, FontWeight.w400),
      bodySmall: body(12.5, FontWeight.w400, color: c.textMuted),
      labelLarge: body(15, FontWeight.w600, height: 1.2),
      labelMedium: body(12.5, FontWeight.w600, height: 1.2),
      labelSmall: body(11, FontWeight.w500, height: 1.2),
    );
  }
}
