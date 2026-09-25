import 'package:flutter/painting.dart';

/// The one place to change the brand: the violet of the website (Tailwind
/// `brand-*`, hue 293), converted from OKLCH. Every screen reads its colors
/// from [AppColors], built on this palette — change it here, it changes everywhere.
abstract final class Brand {
  static const Color c50 = Color(0xFFF5F3FF);
  static const Color c100 = Color(0xFFECE7FF);
  static const Color c200 = Color(0xFFDCD2FF);
  static const Color c300 = Color(0xFFC4B0FF);
  static const Color c400 = Color(0xFFA885FF);
  static const Color c500 = Color(0xFF915DFF);
  static const Color c600 = Color(0xFF7F3CF2);
  static const Color c700 = Color(0xFF6A2ACF);
  static const Color c800 = Color(0xFF511FA2);
  static const Color c900 = Color(0xFF3F1C7C);
  static const Color c950 = Color(0xFF240C4D);

  /// Main action color (buttons, active tab, progress).
  static const Color primary = c600;

  static const String displayFont = 'Sora';
  static const String bodyFont = 'Inter';
}
