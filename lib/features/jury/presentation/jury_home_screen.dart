import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/resource_view.dart';
import '../data/models.dart';
import '../data/providers.dart';
import 'jury_scope.dart';

/// Jury space: the competitions I judge and what is left to score.
class JuryHomeScreen extends ConsumerWidget {
  const JuryHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => JuryScope(
        child: Builder(builder: (context) {
          final c = context.colors;
          final user = ref.watch(currentUserProvider);
          return Scaffold(
            body: Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  child: SafeArea(
                    child: ResourceView(
                      value: ref.watch(judgeCompetitionsProvider),
                      onRetry: () => ref.invalidate(judgeCompetitionsProvider),
                      builder: (competitions, _) => RefreshIndicator(
                        color: c.primary,
                        onRefresh: () async => ref.invalidate(judgeCompetitionsProvider),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xxl),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Espace jury', style: context.text.headlineMedium),
                                      if (user != null) Text('Bonjour ${user.name}', style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
                                    ],
                                  ),
                                ),
                                TextButton.icon(onPressed: () => context.go('/profil'), icon: const Icon(AppIcons.back, size: 18), label: const Text('Quitter')),
                              ],
                            ),
                            const SizedBox(height: Space.xl),
                            if (competitions.isEmpty)
                              const EmptyState(icon: AppIcons.jury, title: 'Aucune compétition à noter', message: 'Les organisateurs t\'ajoutent comme juré : elles apparaîtront ici.')
                            else
                              for (final competition in competitions) _CompetitionCard(competition: competition),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      );
}

class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({required this.competition});

  final JudgeCompetition competition;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pre = competition.preselection;
    final done = pre != null && pre.total > 0 && pre.scored >= pre.total;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.lg),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(competition.name, style: context.text.titleLarge),
          if (competition.organizer != null) Text(competition.organizer!, style: context.text.bodySmall),
          if (pre != null) ...[
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Text('Présélection', style: context.text.titleSmall),
                const Spacer(),
                Text('${pre.scored} / ${pre.total} notées', style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
            const SizedBox(height: Space.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: LinearProgressIndicator(value: pre.total == 0 ? 0 : pre.scored / pre.total, minHeight: 8, color: done ? c.success : c.primary, backgroundColor: c.surfaceRaised),
            ),
            const SizedBox(height: Space.md),
            AppButton(
              label: !pre.acceptsScores ? 'Voir mes notes' : done ? 'Tout est noté · revoir' : pre.scored == 0 ? 'Commencer la notation' : 'Continuer la notation',
              variant: pre.acceptsScores && !done ? AppButtonVariant.primary : AppButtonVariant.secondary,
              onPressed: () => context.push('/jury/${competition.slug}/preselection'),
            ),
          ],
          if (competition.matchesToScore > 0) ...[
            const SizedBox(height: Space.md),
            AppButton(
              label: 'Matchs à noter (${competition.matchesToScore})',
              variant: AppButtonVariant.secondary,
              icon: AppIcons.battle,
              onPressed: () => context.push('/jury/${competition.slug}/matchs'),
            ),
          ],
        ],
      ),
    );
  }
}
