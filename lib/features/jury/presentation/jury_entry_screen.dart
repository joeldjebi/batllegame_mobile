import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/toast.dart';
import '../../competitions/presentation/match_screen.dart';
import '../data/models.dart';
import '../data/pending_scores.dart';
import '../data/providers.dart';
import 'jury_scope.dart';
import 'score_form.dart';

/// One entry: the video, one control per criterion, final notes, then the next one.
class JuryEntryScreen extends ConsumerStatefulWidget {
  const JuryEntryScreen({super.key, required this.slug, required this.entryId});

  final String slug;
  final int entryId;

  @override
  ConsumerState<JuryEntryScreen> createState() => _JuryEntryScreenState();
}

class _JuryEntryScreenState extends ConsumerState<JuryEntryScreen> {
  final Map<int, double> _values = {};

  String get _pendingKey => PendingScores.entryKey(widget.slug, widget.entryId);

  Future<void> _validate(JuryEntryDetail detail) async {
    final total = detail.summary.criteria.fold<double>(0, (sum, c) => sum + (_values[c.id] ?? 0));
    final max = detail.summary.criteria.fold<double>(0, (sum, c) => sum + c.maxPoints);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Valider mes notes ?'),
        content: Text('${detail.entry.stageName} : ${formatScore(total)} / ${formatScore(max)}.\nLes notes sont définitives : seul l\'organisateur peut les rouvrir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Modifier')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Valider')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    unawaited(HapticFeedback.mediumImpact());
    await ref.read(pendingScoresProvider.notifier).submit(
          key: _pendingKey,
          path: '/competitions/${widget.slug}/preselection/entries/${widget.entryId}/scores',
          body: {
            'scores': [for (final c in detail.summary.criteria) {'criterion_id': c.id, 'score': _values[c.id] ?? 0}],
          },
          scores: {for (final c in detail.summary.criteria) c.id: _values[c.id] ?? 0},
          label: 'Note · ${detail.entry.stageName}',
        );
    if (!mounted) return;
    final online = ref.read(networkStatusProvider);
    final next = detail.nextEntryId;
    showToast(context, online ? 'Notes enregistrées pour ${detail.entry.stageName}.' : 'Hors ligne : notes gardées, envoyées au retour du réseau.');
    if (next != null) {
      context.pushReplacement('/jury/${widget.slug}/preselection/$next');
    } else {
      showToast(context, 'Toutes tes prestations sont notées.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (slug: widget.slug, id: widget.entryId);
    return JuryScope(
      child: Builder(builder: (context) {
        final c = context.colors;
        final pending = ref.watch(pendingScoresProvider)[_pendingKey];
        final confirmed = ref.read(pendingScoresProvider.notifier).confirmed[_pendingKey];
        return Scaffold(
          appBar: AppBar(title: const Text('Notation')),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: ResourceView(
                  value: ref.watch(juryEntryProvider(key)),
                  onRetry: () => ref.invalidate(juryEntryProvider(key)),
                  builder: (detail, _) {
                    final given = pending ?? confirmed ?? (detail.myScores.isEmpty ? null : detail.myScores);
                    final readOnly = given != null || !detail.canScore;
                    final values = given ?? _values;
                    final criteria = detail.summary.criteria;
                    final total = criteria.fold<double>(0, (sum, cr) => sum + (values[cr.id] ?? 0));
                    final max = criteria.fold<double>(0, (sum, cr) => sum + cr.maxPoints);

                    return Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(Radii.lg),
                                child: ColoredBox(
                                  color: Colors.black,
                                  child: AspectRatio(
                                    aspectRatio: detail.entry.media.isPortrait ? 4 / 5 : 16 / 9,
                                    child: MediaPlayer(key: ValueKey(detail.entry.id), cacheKey: 'preselection-${detail.entry.id}', media: detail.entry.media),
                                  ),
                                ),
                              ),
                              const SizedBox(height: Space.md),
                              Row(
                                children: [
                                  Avatar(name: detail.entry.stageName, url: detail.entry.avatarUrl, size: 40),
                                  const SizedBox(width: Space.md),
                                  Expanded(child: Text(detail.entry.stageName, style: context.text.titleLarge)),
                                  Text('${detail.summary.scored} / ${detail.summary.total}', style: context.text.bodySmall),
                                ],
                              ),
                              const SizedBox(height: Space.lg),
                              if (readOnly)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: Space.md),
                                  child: Row(
                                    children: [
                                      Icon(pending != null ? AppIcons.uploading : AppIcons.locked, size: 18, color: pending != null ? c.warning : c.success),
                                      const SizedBox(width: Space.sm),
                                      Expanded(
                                        child: Text(
                                          pending != null
                                              ? 'Notes gardées sur le téléphone : envoi au retour du réseau.'
                                              : given != null
                                                  ? 'Tes notes (définitives). Une erreur ? Demande à l\'organisateur de les rouvrir.'
                                                  : 'La délibération est close.',
                                          style: context.text.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ScoreForm(criteria: criteria, values: values, readOnly: readOnly, onChanged: (id, v) => setState(() => _values[id] = v)),
                            ],
                          ),
                        ),
                        // Sticky footer: the total and the action.
                        Container(
                          padding: EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, MediaQuery.paddingOf(context).bottom + Space.md),
                          decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
                          child: Row(
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total', style: context.text.bodySmall),
                                  Text('${formatScore(total)} / ${formatScore(max)}', style: context.text.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                                ],
                              ),
                              const SizedBox(width: Space.lg),
                              Expanded(
                                child: readOnly
                                    ? AppButton(
                                        label: detail.nextEntryId == null ? 'Retour à la liste' : 'Prestation suivante',
                                        variant: AppButtonVariant.secondary,
                                        onPressed: () => detail.nextEntryId == null
                                            ? context.pop()
                                            : context.pushReplacement('/jury/${widget.slug}/preselection/${detail.nextEntryId}'),
                                      )
                                    : AppButton(label: detail.nextEntryId == null ? 'Valider' : 'Valider et suivante', onPressed: () => _validate(detail)),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}
