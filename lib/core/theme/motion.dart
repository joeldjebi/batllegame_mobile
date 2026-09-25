import 'package:flutter/widgets.dart';

/// « Réduire les animations » (iOS) / « Supprimer les animations » (Android): every
/// animated widget asks here, and becomes instant when the user turned motion off.
extension MotionX on BuildContext {
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
