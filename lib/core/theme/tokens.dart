import 'package:flutter/animation.dart';

/// Spacing scale (4 pt grid).
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Side gutter of every screen.
  static const double gutter = 20;
}

abstract final class Radii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;
}

/// Durations and curves: enter slower than exit, springy for playful moments.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;
}

/// Minimum touch target (iOS 44 pt, Material 48 dp).
const double kMinTouchTarget = 48;
