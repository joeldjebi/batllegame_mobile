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
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/toast.dart';
import '../../competitions/presentation/match_screen.dart';
import '../data/pending_scores.dart';
import '../data/providers.dart';
import 'jury_scope.dart';
import 'score_form.dart';

/// The matches of a competition the judge scores (open ones first).
class JuryMatchesScreen extends ConsumerWidget {
  const JuryMatchesScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) => JuryScope(
        child: Builder(builder: (context) {
          final c = context.colors;
          return Scaffold(
            appBar: AppBar(title: const Text('Matchs à noter')),
            body: Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  child: ResourceView(
                    value: ref.watch(judgeMatchesProvider(slug)),
                    onRetry: () => ref.invalidate(judgeMatchesProvider(slug)),
                    builder: (data, _) {
                      final matches = data.matches.where((m) => m.toScore || m.scoredParticipants.isNotEmpty).toList();
                      if (matches.isEmpty) return const EmptyState(icon: AppIcons.battle, title: 'Aucun match à noter', message: 'Les matchs apparaissent ici pendant le vote et la délibération.');
                      return ListView.separated(
                        padding: const EdgeInsets.all(Space.gutter),
                        itemCount: matches.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                        itemBuilder: (context, i) {
                          final match = matches[i];
                          return Material(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(Radii.md),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md), side: BorderSide(color: c.border)),
                              title: Text(match.title, style: context.text.titleSmall),
                              subtitle: Text([
                                ?match.stage,
                                if (match.deliberationEndsAt != null) 'notes jusqu\'au ${Labels.date(match.deliberationEndsAt)}',
                              ].join(' · ')),
                              trailing: StatusChip(
                                match.fullyScored ? 'Noté' : '${match.scoredParticipants.length} / ${match.artists.length}',
                                tone: match.fullyScored ? ChipTone.success : ChipTone.info,
                              ),
                              onTap: () => context.push('/jury/$slug/matchs/${match.id}'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      );
}

/// One match: each artist's performance and my notes (rewritable until the deliberation ends).
class JuryMatchScreen extends ConsumerStatefulWidget {
  const JuryMatchScreen({super.key, required this.slug, required this.id});

  final String slug;
  final int id;

  @override
  ConsumerState<JuryMatchScreen> createState() => _JuryMatchScreenState();
}

class _JuryMatchScreenState extends ConsumerState<JuryMatchScreen> {
  final Map<int, Map<int, double>> _edits = {};

  @override
  Widget build(BuildContext context) {
    final key = (slug: widget.slug, id: widget.id);
    return JuryScope(
      child: Builder(builder: (context) {
        final c = context.colors;
        final pending = ref.watch(pendingScoresProvider);
        return Scaffold(
          appBar: AppBar(title: const Text('Notation du match')),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: ResourceView(
                  value: ref.watch(judgeMatchProvider(key)),
                  onRetry: () => ref.invalidate(judgeMatchProvider(key)),
                  builder: (match, _) => ListView(
                    padding: const EdgeInsets.all(Space.gutter),
                    children: [
                      Text(match.title, style: context.text.headlineSmall),
                      Text(
                        match.canScore
                            ? 'Notes modifiables jusqu\'à la fin de la délibération${match.deliberationEndsAt == null ? '' : ' (${Labels.date(match.deliberationEndsAt)})'}.'
                            : 'Notation fermée : notes en lecture seule.',
                        style: context.text.bodySmall,
                      ),
                      const SizedBox(height: Space.lg),
                      for (final artist in match.artists) ...[
                        Builder(builder: (context) {
                          final pendingKey = PendingScores.matchKey(widget.slug, match.id, artist.participantId);
                          final queued = pending[pendingKey];
                          final values = _edits[artist.participantId] ?? queued ?? match.myScores[artist.participantId] ?? {};
                          final max = match.criteria.fold<double>(0, (s, cr) => s + cr.maxPoints);
                          final total = match.criteria.fold<double>(0, (s, cr) => s + (values[cr.id] ?? 0));
                          return Container(
                            margin: const EdgeInsets.only(bottom: Space.xl),
                            padding: const EdgeInsets.all(Space.md),
                            decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(Radii.lg)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  Avatar(name: artist.stageName, url: artist.avatarUrl, size: 36),
                                  const SizedBox(width: Space.md),
                                  Expanded(child: Text(artist.stageName, style: context.text.titleMedium)),
                                  if (queued != null) const StatusChip('En attente d\'envoi', tone: ChipTone.info)
                                  else if (match.myScores.containsKey(artist.participantId)) const StatusChip('Noté', tone: ChipTone.success),
                                ]),
                                const SizedBox(height: Space.md),
                                if (artist.media != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(Radii.md),
                                    child: ColoredBox(
                                      color: Colors.black,
                                      child: AspectRatio(aspectRatio: 16 / 9, child: MediaPlayer(cacheKey: 'media-${artist.media!.id}', media: artist.media!.media)),
                                    ),
                                  )
                                else
                                  Text('Prestation pas encore publiée.', style: context.text.bodySmall),
                                const SizedBox(height: Space.md),
                                ScoreForm(
                                  criteria: match.criteria,
                                  values: values,
                                  readOnly: !match.canScore,
                                  onChanged: (id, v) => setState(() => _edits[artist.participantId] = {...values, id: v}),
                                ),
                                if (match.canScore)
                                  AppButton(
                                    label: 'Enregistrer · ${formatScore(total)} / ${formatScore(max)}',
                                    onPressed: _edits[artist.participantId] == null
                                        ? null
                                        : () async {
                                            final scores = _edits[artist.participantId]!;
                                            unawaited(HapticFeedback.mediumImpact());
                                            await ref.read(pendingScoresProvider.notifier).submit(
                                                  key: pendingKey,
                                                  path: '/competitions/${widget.slug}/matches/${match.id}/jury-scores',
                                                  body: {
                                                    'participant_id': artist.participantId,
                                                    'scores': [for (final cr in match.criteria) {'criterion_id': cr.id, 'score': scores[cr.id] ?? 0}],
                                                  },
                                                  scores: {for (final cr in match.criteria) cr.id: scores[cr.id] ?? 0},
                                                  label: 'Note · ${artist.stageName}',
                                                );
                                            if (!context.mounted) return;
                                            setState(() => _edits.remove(artist.participantId));
                                            showToast(context, ref.read(networkStatusProvider) ? 'Notes enregistrées pour ${artist.stageName}.' : 'Hors ligne : notes gardées, envoyées au retour du réseau.');
                                          },
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
