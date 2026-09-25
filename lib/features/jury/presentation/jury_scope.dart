import 'package:flutter/widgets.dart';

/// The jury space follows the appearance chosen in Réglages (light by default);
/// kept as a single place to give it its own look later.
class JuryScope extends StatelessWidget {
  const JuryScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
