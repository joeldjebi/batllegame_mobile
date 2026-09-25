import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

/// The app's button: 52 pt high (comfortable touch target), press feedback,
/// loading state that keeps its width, haptic tick on primary actions.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color fg, Color? outline) = switch (widget.variant) {
      AppButtonVariant.primary => (c.primary, c.onPrimary, null),
      AppButtonVariant.secondary => (c.surfaceRaised, c.text, c.border),
      AppButtonVariant.ghost => (Colors.transparent, c.text, null),
      AppButtonVariant.danger => (c.surfaceRaised, c.danger, c.border),
    };

    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        else ...[
          if (widget.icon != null) ...[Icon(widget.icon, size: 20, color: fg), const SizedBox(width: Space.sm)],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge?.copyWith(color: fg),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: _enabled
            ? () {
                if (widget.variant == AppButtonVariant.primary) HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: Motion.fast,
          curve: Motion.enter,
          child: AnimatedOpacity(
            opacity: widget.onPressed == null ? 0.45 : 1,
            duration: Motion.fast,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(Radii.md),
                border: outline == null ? null : Border.all(color: outline),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
