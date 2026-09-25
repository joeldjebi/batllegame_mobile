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
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/resource_view.dart';
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
      return const SafeArea(
        child: SignInPrompt(icon: AppIcons.video, title: 'Publie ta prestation', message: 'Connecte-toi pour participer aux compétitions.'),
      );
    }
    final c = context.colors;
    final uploads = ref.watch(uploadsProvider).values.where((u) => u.active).length;

    return ColoredBox(
      color: groupedBackground(context),
      child: SafeArea(
        bottom: false,
        child: ResourceView(
          value: ref.watch(participationsProvider),
          onRetry: () => ref.invalidate(participationsProvider),
          builder: (participations, _) => RefreshIndicator(
            color: c.primary,
            onRefresh: () async => ref.invalidate(participationsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
              children: [
                const LargeTitle('Mes compétitions'),
                if (uploads > 0)
                  GroupedSection(
                    children: [
                      GroupedTile(
                        icon: AppIcons.uploading,
                        iconColor: c.primary,
                        title: '$uploads envoi${uploads > 1 ? 's' : ''} en cours',
                        subtitle: 'Continue même si tu quittes l\'app.',
                      ),
                    ],
                  ),
                if (participations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xxxl),
                    child: EmptyState(
                      icon: AppIcons.video,
                      title: 'Pas encore de compétition',
                      message: 'Inscris-toi à une compétition pour envoyer tes prestations.',
                      action: AppButton(label: 'Voir les compétitions', expand: false, onPressed: () => context.go('/decouvrir')),
                    ),
                  )
                else
                  GroupedSection(
                    header: 'Mes inscriptions',
                    footer: 'Touche une compétition pour suivre ton parcours et envoyer tes prestations.',
                    children: [
                      for (final p in participations)
                        GroupedTile(
                          icon: AppIcons.trophy,
                          iconColor: p.status == 'paiement_en_attente' ? c.danger : (p.competitionStatus == 'en_cours' ? c.primary : const Color(0xFF8E8E93)),
                          title: p.competitionName,
                          subtitle: [
                            '${p.stageName}${p.organizer == null ? '' : ' · ${p.organizer}'}',
                            '${participantLabel(p.status)} · ${Labels.competitionStatus(p.competitionStatus)}',
                          ].join('\n'),
                          onTap: () => context.push('/competitions/${p.slug}/parcours'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
