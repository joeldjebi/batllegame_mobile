import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/resource_view.dart';
import '../data/models.dart';
import '../data/providers.dart';

const _filters = [
  (label: 'Toutes', status: null),
  (label: 'En cours', status: 'en_cours'),
  (label: 'Inscriptions', status: 'inscriptions'),
  (label: 'Terminées', status: 'terminee'),
];

/// Découvrir: every public competition, filtered by status.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = ref.watch(competitionsProvider(_status));

    return ColoredBox(
      color: groupedBackground(context),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.gutter),
              child: LargeTitle('Découvrir'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
              child: _Segmented(selected: _status, onChanged: (status) => setState(() => _status = status)),
            ),
            Expanded(
              child: ResourceView(
                value: value,
                onRetry: () => ref.invalidate(competitionsProvider(_status)),
                builder: (page, resource) => RefreshIndicator(
                  color: c.primary,
                  onRefresh: () async => ref.invalidate(competitionsProvider(_status)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
                    children: [
                      if (page.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: Space.xxxl),
                          child: EmptyState(icon: AppIcons.trophy, title: 'Aucune compétition', message: 'Reviens bientôt : de nouvelles battles arrivent.'),
                        )
                      else
                        GroupedSection(
                          header: '${page.items.length} compétition${page.items.length > 1 ? 's' : ''}',
                          children: [for (final competition in page.items) CompetitionCard(competition: competition)],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status filter, the iOS segmented control way.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: light ? const Color(0x1F767680) : c.surfaceRaised, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          for (final filter in _filters)
            Expanded(
              child: Semantics(
                button: true,
                selected: filter.status == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(filter.status),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filter.status == selected ? (light ? Colors.white : c.surface) : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.md - 2),
                      boxShadow: filter.status == selected && light ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 1))] : null,
                    ),
                    child: Text(
                      filter.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(color: c.text, fontWeight: filter.status == selected ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One competition, as a row of a grouped section: logo, name, organizer, then its
/// status, discipline and price as three small tags, and the registration deadline.
class CompetitionCard extends StatelessWidget {
  const CompetitionCard({super.key, required this.competition});

  final CompetitionSummary competition;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = switch (competition.status) {
      'en_cours' => ('En cours', c.like),
      'inscriptions' => ('Inscriptions', c.success),
      'terminee' => ('Terminée', c.textMuted),
      _ => (Labels.competitionStatus(competition.status), c.textMuted),
    };
    final free = competition.entryFee <= 0;
    final deadline = competition.registrationOpen && competition.registrationEndsAt != null
        ? 'Inscriptions jusqu\'au ${DateFormat('d MMMM', 'fr').format(competition.registrationEndsAt!.toLocal())}'
        : null;

    return GroupedTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: Avatar(name: competition.organizerName ?? competition.name, url: competition.organizerLogoUrl, size: 48),
      ),
      title: competition.name,
      subtitle: competition.organizerName,
      detail: Padding(
        padding: const EdgeInsets.only(top: Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                _Tag(label: label, color: color, dot: true),
                _Tag(label: Labels.discipline(competition.discipline), icon: AppIcons.microphone),
                _Tag(
                  label: free ? 'Gratuit' : Labels.money(competition.entryFee, competition.currency),
                  color: free ? c.success : null,
                  icon: AppIcons.payment,
                ),
              ],
            ),
            if (deadline != null) ...[const SizedBox(height: Space.xs), Text(deadline, style: context.text.labelSmall?.copyWith(color: c.textMuted))],
          ],
        ),
      ),
      onTap: () => context.push('/competitions/${competition.slug}'),
    );
  }
}

/// Small tag: tinted when it carries a color (status, free), grey otherwise.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color, this.icon, this.dot = false});

  final String label;
  final Color? color;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: (color ?? c.textMuted).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          if (icon != null && !dot) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
