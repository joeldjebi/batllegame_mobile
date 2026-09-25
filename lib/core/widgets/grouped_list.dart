import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/tokens.dart';

/// Grouped lists, the iOS settings way: a large title, rounded white sections on a
/// light grey page, rows with an icon tile, a value and a chevron.

/// Page background behind grouped sections (light: grey, so the white sections stand out).
Color groupedBackground(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF2F2F7) : context.colors.background;

/// Large page title (« Activité », « Découvrir »…).
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, Space.lg),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A rounded section of rows, with an optional caption above and note below.
class GroupedSection extends StatelessWidget {
  const GroupedSection({super.key, required this.children, this.header, this.footer});

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
              child: Text(header!.toUpperCase(), style: context.text.labelSmall?.copyWith(color: c.textMuted, letterSpacing: 0.4)),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xl),
            child: ColoredBox(
              color: c.surface,
              child: Column(
                children: [
                  for (final (i, child) in children.indexed) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 60),
                        child: Divider(height: 1, thickness: 0.5, color: c.border),
                      ),
                    child,
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
              child: Text(footer!, style: context.text.bodySmall?.copyWith(color: c.textMuted)),
            ),
        ],
      ),
    );
  }
}

/// Square icon tile of a row (grey by default, a color for what stands out).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color, this.size = 32});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color ?? const Color(0xFF8E8E93), borderRadius: BorderRadius.circular(size * 0.24)),
    child: Icon(icon, size: size * 0.58, color: Colors.white),
  );
}

/// One row: leading (icon tile or any widget), title, optional subtitle, value, trailing and chevron.
class GroupedTile extends StatelessWidget {
  const GroupedTile({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.leading,
    this.subtitle,
    this.detail,
    this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.destructive = false,
    this.unread = false,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String? subtitle;

  /// Extra line under the subtitle (e.g. a colored status).
  final Widget? detail;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool destructive;

  /// A new item: bold title and a dot.
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lead = leading ?? (icon == null ? null : IconTile(icon!, color: iconColor));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
            child: Row(
              children: [
                if (lead != null) ...[lead, const SizedBox(width: Space.lg)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: destructive && lead == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: context.text.bodyLarge?.copyWith(color: destructive ? c.danger : c.text, fontWeight: unread ? FontWeight.w700 : FontWeight.w400),
                      ),
                      if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: context.text.bodySmall?.copyWith(color: c.textMuted))],
                      if (detail != null) ...[const SizedBox(height: 2), detail!],
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: Space.sm),
                  Text(value!, style: context.text.bodyMedium?.copyWith(color: valueColor ?? c.textMuted)),
                ],
                if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
                if (unread) ...[
                  const SizedBox(width: Space.sm),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                  ),
                ],
                if (chevron && onTap != null && !destructive) ...[
                  const SizedBox(width: Space.sm),
                  Icon(AppIcons.forward, size: 16, color: c.textMuted.withValues(alpha: 0.6)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
