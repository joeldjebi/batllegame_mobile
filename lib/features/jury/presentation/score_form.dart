import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../data/models.dart';

String formatScore(double value) {
  final text = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}

/// One row per criterion: the value in large figures, a slider by half points and
/// −/+ buttons for precision (large touch targets).
class ScoreForm extends StatelessWidget {
  const ScoreForm({super.key, required this.criteria, required this.values, required this.onChanged, this.readOnly = false});

  final List<Criterion> criteria;
  final Map<int, double> values;
  final void Function(int criterionId, double value) onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        for (final criterion in criteria)
          Container(
            margin: const EdgeInsets.only(bottom: Space.md),
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.sm),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(criterion.name, style: context.text.titleMedium)),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: formatScore(values[criterion.id] ?? 0), style: context.text.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                        TextSpan(text: ' / ${formatScore(criterion.maxPoints)}', style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
                      ]),
                      semanticsLabel: '${criterion.name} : ${formatScore(values[criterion.id] ?? 0)} sur ${formatScore(criterion.maxPoints)}',
                    ),
                    const SizedBox(width: Space.sm),
                  ],
                ),
                if (!readOnly)
                  Row(
                    children: [
                      _Step(icon: AppIcons.minus, label: 'Moins', onTap: () => _set(criterion, (values[criterion.id] ?? 0) - 0.5)),
                      Expanded(
                        child: Slider(
                          value: (values[criterion.id] ?? 0).clamp(0, criterion.maxPoints),
                          max: criterion.maxPoints,
                          divisions: (criterion.maxPoints * 2).round(),
                          activeColor: c.primary,
                          label: formatScore(values[criterion.id] ?? 0),
                          onChanged: (v) => _set(criterion, v),
                        ),
                      ),
                      _Step(icon: AppIcons.plus, label: 'Plus', onTap: () => _set(criterion, (values[criterion.id] ?? 0) + 0.5)),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _set(Criterion criterion, double value) {
    final next = (value * 2).round() / 2;
    final clamped = next.clamp(0, criterion.maxPoints).toDouble();
    if (clamped != (values[criterion.id] ?? 0)) HapticFeedback.selectionClick();
    onChanged(criterion.id, clamped);
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: kMinTouchTarget,
        child: IconButton.outlined(tooltip: label, onPressed: onTap, icon: Icon(icon, size: 20)),
      );
}
