import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/status_chip.dart';
import '../../shell/presentation/tabs.dart';
import '../data/providers.dart';

String participantLabel(String status) => switch (status) {
      'paiement_en_attente' => 'Paiement en attente',
      'inscrit' => 'Inscrit',
      'valide' => 'Inscription validée',
      'elimine' => 'Éliminé',
      'forfait' => 'Forfait',
      'disqualifie' => 'Disqualifié',
      'non_retenu' => 'Non retenu',
      _ => status,
    };

/// The « + » tab: my competitions, each opening its journey (where performances are sent).
class MyCompetitionsScreen extends ConsumerWidget {
  const MyCompetitionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserProvider) == null) {
      return const SafeArea(child: SignInPrompt(icon: AppIcons.video, title: 'Publie ta prestation', message: 'Connecte-toi pour participer aux compétitions.'));
    }
    final c = context.colors;
    final uploads = ref.watch(uploadsProvider).values.where((u) => u.active).length;

    return SafeArea(
      bottom: false,
      child: ResourceView(
        value: ref.watch(participationsProvider),
        onRetry: () => ref.invalidate(participationsProvider),
        builder: (participations, _) => RefreshIndicator(
          color: c.primary,
          onRefresh: () async => ref.invalidate(participationsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xxl),
            children: [
              Text('Mes compétitions', style: context.text.headlineMedium),
              if (uploads > 0) ...[
                const SizedBox(height: Space.sm),
                StatusChip('$uploads envoi(s) en cours', tone: ChipTone.live),
              ],
              const SizedBox(height: Space.lg),
              if (participations.isEmpty)
                EmptyState(
                  icon: AppIcons.video,
                  title: 'Pas encore de compétition',
                  message: 'Inscris-toi à une compétition pour envoyer tes prestations.',
                  action: AppButton(label: 'Voir les compétitions', expand: false, onPressed: () => context.go('/decouvrir')),
                )
              else
                for (final p in participations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Material(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Radii.lg),
                        onTap: () => context.push('/competitions/${p.slug}/parcours'),
                        child: Container(
                          padding: const EdgeInsets.all(Space.lg),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.border)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.competitionName, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                    Text('${p.stageName}${p.organizer == null ? '' : ' · ${p.organizer}'}', style: context.text.bodySmall),
                                    const SizedBox(height: Space.sm),
                                    Wrap(spacing: Space.sm, runSpacing: Space.xs, children: [
                                      StatusChip(participantLabel(p.status), tone: p.status == 'paiement_en_attente' ? ChipTone.danger : ChipTone.info),
                                      StatusChip(Labels.competitionStatus(p.competitionStatus)),
                                    ]),
                                  ],
                                ),
                              ),
                              Icon(AppIcons.forward, color: c.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
