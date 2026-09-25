import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/status_chip.dart';
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

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.md),
            child: Text('Découvrir', style: context.text.headlineMedium),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
              itemBuilder: (context, i) {
                final filter = _filters[i];
                final selected = filter.status == _status;
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _status = filter.status),
                  labelStyle: context.text.labelMedium?.copyWith(color: selected ? c.onPrimary : c.text),
                  selectedColor: c.primary,
                  backgroundColor: c.surfaceRaised,
                  side: BorderSide(color: selected ? c.primary : c.border),
                  shape: const StadiumBorder(),
                );
              },
            ),
          ),
          const SizedBox(height: Space.md),
          Expanded(
            child: ResourceView(
              value: value,
              onRetry: () => ref.invalidate(competitionsProvider(_status)),
              builder: (page, resource) => RefreshIndicator(
                color: c.primary,
                onRefresh: () async => ref.invalidate(competitionsProvider(_status)),
                child: page.items.isEmpty
                    ? ListView(children: const [SizedBox(height: 80), EmptyState(icon: AppIcons.trophy, title: 'Aucune compétition', message: 'Reviens bientôt : de nouvelles battles arrivent.')])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
                        itemCount: page.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                        itemBuilder: (context, i) => CompetitionCard(competition: page.items[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CompetitionCard extends StatelessWidget {
  const CompetitionCard({super.key, required this.competition});

  final CompetitionSummary competition;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = switch (competition.status) {
      'en_cours' => ChipTone.live,
      'inscriptions' => ChipTone.info,
      'terminee' => ChipTone.success,
      _ => ChipTone.neutral,
    };

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => context.push('/competitions/${competition.slug}'),
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.border)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: Avatar(name: competition.organizerName ?? competition.name, url: competition.organizerLogoUrl, size: 52),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(competition.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (competition.organizerName != null)
                      Text(competition.organizerName!, style: context.text.bodySmall),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      children: [
                        StatusChip(Labels.competitionStatus(competition.status), tone: tone),
                        StatusChip(Labels.discipline(competition.discipline)),
                        StatusChip(Labels.money(competition.entryFee, competition.currency)),
                      ],
                    ),
                    if (competition.registrationOpen && competition.registrationEndsAt != null) ...[
                      const SizedBox(height: Space.sm),
                      Text('Inscriptions jusqu\'au ${Labels.day(competition.registrationEndsAt)}', style: context.text.bodySmall?.copyWith(color: c.accent)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
