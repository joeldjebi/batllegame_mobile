import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/video_grid.dart';
import '../data/artists.dart';

/// An artist's page: photo, name, followers and « Suivre », their performances
/// (all competitions) and their competitions.
class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.participantId});

  final int participantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(artistProvider(participantId));
    return Scaffold(
      backgroundColor: groupedBackground(context),
      appBar: AppBar(backgroundColor: groupedBackground(context), title: Text(value.valueOrNull?.stageName ?? 'Artiste')),
      body: value.when(
        loading: () => const _ArtistSkeleton(),
        error: (_, _) => EmptyState(
          icon: AppIcons.offline,
          title: 'Page indisponible',
          message: 'Vérifie ta connexion et réessaie.',
          action: AppButton(label: 'Réessayer', expand: false, onPressed: () => ref.invalidate(artistProvider(participantId))),
        ),
        data: (artist) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(artistProvider(participantId))
              ..invalidate(artistVideosProvider(participantId));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xxl),
            children: [
              _Header(artist: artist),
              const SizedBox(height: Space.xl),
              _Videos(participantId: participantId),
              if (artist.participations.isNotEmpty)
                GroupedSection(
                  header: 'Compétitions',
                  children: [
                    for (final p in artist.participations)
                      GroupedTile(
                        icon: AppIcons.trophy,
                        iconColor: p.competitionStatus == 'en_cours' ? context.colors.primary : null,
                        title: p.competitionName,
                        subtitle: [p.stageName, p.statusLabel, if (p.discipline != null) Labels.discipline(p.discipline)].join(' · '),
                        onTap: () => context.push('/competitions/${p.competitionSlug}'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.artist});

  final ArtistProfile artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followStateProvider)[artist.participantId] ?? artist.following;
    // Shown at once: the count moves with the button, before the server confirms.
    final followers = artist.followersCount + (following == artist.following ? 0 : (following ? 1 : -1));

    return Column(
      children: [
        Semantics(image: true, label: 'Photo de ${artist.stageName}', child: Avatar(name: artist.stageName, url: artist.avatarUrl, size: 104)),
        const SizedBox(height: Space.md),
        Text(
          artist.stageName,
          textAlign: TextAlign.center,
          style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: Space.md),
        // Wraps with a large text size.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.xxl,
          runSpacing: Space.md,
          children: [
            _Stat(value: followers, label: followers > 1 ? 'abonnés' : 'abonné'),
            _Stat(value: artist.performancesCount, label: artist.performancesCount > 1 ? 'prestations' : 'prestation'),
            _Stat(value: artist.participations.length, label: artist.participations.length > 1 ? 'compétitions' : 'compétition'),
          ],
        ),
        if (!artist.isMe) ...[
          const SizedBox(height: Space.lg),
          SizedBox(
            width: 200,
            child: AppButton(
              label: following ? 'Abonné' : 'Suivre',
              icon: following ? AppIcons.done : AppIcons.plus,
              variant: following ? AppButtonVariant.secondary : AppButtonVariant.primary,
              onPressed: () async {
                if (ref.read(currentUserProvider) == null) {
                  await context.push('/auth/connexion');
                  return;
                }
                unawaited(HapticFeedback.selectionClick());
                final ok = await ref.read(followStateProvider.notifier).toggle(artist);
                if (!ok && context.mounted) showToast(context, 'Action impossible pour le moment. Réessaie.');
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    excludeSemantics: true,
    child: Column(
      children: [
        Text(Labels.count(value), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: context.text.bodySmall?.copyWith(color: context.colors.textMuted)),
      ],
    ),
  );
}

class _Videos extends ConsumerWidget {
  const _Videos({required this.participantId});

  final int participantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(artistVideosProvider(participantId));
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: Text('PRESTATIONS', style: context.text.labelSmall?.copyWith(color: context.colors.textMuted, letterSpacing: 0.4)),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xl),
            child: videos.when(
              loading: () => const SkeletonGrid(shrink: true),
              error: (_, _) => const SizedBox.shrink(),
              data: (items) => items.isEmpty
                  ? Container(
                      width: double.infinity,
                      color: context.colors.surface,
                      padding: const EdgeInsets.all(Space.xl),
                      child: Text('Pas encore de prestation publiée.', textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted)),
                    )
                  : VideoGrid(items: items, shrink: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistSkeleton extends StatelessWidget {
  const _ArtistSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xxl),
    children: const [
      Center(child: Skeleton(width: 104, height: 104, radius: 52)),
      SizedBox(height: Space.md),
      Center(child: Skeleton(width: 180, height: 26)),
      SizedBox(height: Space.lg),
      Center(child: Skeleton(width: 240, height: 36)),
      SizedBox(height: Space.xl),
      SkeletonGrid(shrink: true),
    ],
  );
}

/// The artists the user follows (Profil › Artistes suivis).
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: groupedBackground(context),
    appBar: AppBar(backgroundColor: groupedBackground(context), title: const Text('Artistes suivis')),
    body: ref
        .watch(followingProvider)
        .when(
          loading: () => const SkeletonList(),
          error: (_, _) => const EmptyState(icon: AppIcons.offline, title: 'Liste indisponible', message: 'Vérifie ta connexion et réessaie.'),
          data: (artists) => artists.isEmpty
              ? const EmptyState(icon: AppIcons.profile, title: 'Aucun artiste suivi', message: 'Touche « Suivre » sur la page d\'un artiste pour le retrouver ici.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xxl),
                  children: [
                    GroupedSection(
                      children: [
                        for (final a in artists)
                          GroupedTile(
                            leading: Avatar(name: a.stageName, url: a.avatarUrl, size: 40),
                            title: a.stageName,
                            subtitle: a.competitionName,
                            onTap: () => context.push('/artistes/${a.participantId}'),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
  );
}
