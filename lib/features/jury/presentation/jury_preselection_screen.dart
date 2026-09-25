import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/pending_scores.dart';
import '../data/providers.dart';
import 'jury_scope.dart';
import 'score_form.dart';

/// Pre-selection of a judge: progress, « À noter » / « Notées », search, one row per entry.
class JuryPreselectionScreen extends ConsumerStatefulWidget {
  const JuryPreselectionScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<JuryPreselectionScreen> createState() => _JuryPreselectionScreenState();
}

class _JuryPreselectionScreenState extends ConsumerState<JuryPreselectionScreen> {
  String _tab = 'a_noter';
  String _search = '';

  ({String slug, String tab, String search}) get _key => (slug: widget.slug, tab: _tab, search: _search);

  @override
  Widget build(BuildContext context) => JuryScope(
        child: Builder(builder: (context) {
          final c = context.colors;
          final state = ref.watch(juryListProvider(_key));
          final pending = ref.watch(pendingScoresProvider);
          final summary = state.summary;

          return Scaffold(
            appBar: AppBar(title: const Text('Présélection')),
            body: Column(
              children: [
                const OfflineBanner(),
                if (summary != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.md),
                    child: Container(
                      padding: const EdgeInsets.all(Space.lg),
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${summary.scored}', style: context.text.displaySmall),
                              Text(' / ${summary.total} notées', style: context.text.titleMedium?.copyWith(color: c.textMuted)),
                            ],
                          ),
                          const SizedBox(height: Space.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.pill),
                            child: LinearProgressIndicator(value: summary.total == 0 ? 0 : summary.scored / summary.total, minHeight: 8, color: c.success, backgroundColor: c.surfaceRaised),
                          ),
                          const SizedBox(height: Space.sm),
                          Text(
                            summary.acceptsScores
                                ? 'Délibération ${summary.deliberationEndsAt == null ? 'en cours' : 'jusqu\'au ${Labels.date(summary.deliberationEndsAt)}'} · notes définitives une fois validées'
                                : 'Délibération close : notes en lecture seule',
                            style: context.text.bodySmall,
                          ),
                          if (summary.acceptsScores && summary.nextEntryId != null) ...[
                            const SizedBox(height: Space.md),
                            AppButton(
                              label: summary.scored == 0 ? 'Commencer la notation' : 'Continuer la notation',
                              onPressed: () => _open(summary.nextEntryId!),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Row(
                    children: [
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [ButtonSegment(value: 'a_noter', label: Text('À noter')), ButtonSegment(value: 'notees', label: Text('Notées'))],
                        selected: {_tab},
                        onSelectionChanged: (s) => setState(() => _tab = s.first),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(hintText: 'Rechercher', prefixIcon: Icon(AppIcons.search), isDense: true),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) => setState(() => _search = value.trim()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                Expanded(
                  child: state.entries.isEmpty
                      ? (state.loading
                          ? const Center(child: CircularProgressIndicator())
                          : EmptyState(
                              icon: _tab == 'notees' ? AppIcons.doneOutline : AppIcons.jury,
                              title: _tab == 'notees' ? 'Aucune prestation notée' : 'Rien à noter ici',
                              message: state.error?.message ?? (_search.isNotEmpty ? 'Aucun artiste ne correspond à la recherche.' : 'Les prestations validées par l\'organisateur apparaissent ici.'),
                            ))
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n.metrics.extentAfter < 400) ref.read(juryListProvider(_key).notifier).loadMore();
                            return false;
                          },
                          child: RefreshIndicator(
                            color: c.primary,
                            onRefresh: () => ref.read(juryListProvider(_key).notifier).refresh(),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
                              itemCount: state.entries.length,
                              separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                              itemBuilder: (context, i) {
                                final entry = state.entries[i];
                                final queued = pending[PendingScores.entryKey(widget.slug, entry.id)];
                                final total = queued != null ? queued.values.fold<double>(0, (a, b) => a + b) : entry.myTotal;
                                return Material(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(Radii.md),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(Radii.md),
                                    onTap: () => _open(entry.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(Space.md),
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.border)),
                                      child: Row(
                                        children: [
                                          Avatar(name: entry.stageName, url: entry.avatarUrl, size: 44),
                                          const SizedBox(width: Space.md),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(entry.stageName, style: context.text.titleSmall),
                                                if (entry.media.durationSeconds != null)
                                                  Text('${entry.media.durationSeconds! ~/ 60}:${(entry.media.durationSeconds! % 60).toString().padLeft(2, '0')}', style: context.text.bodySmall),
                                              ],
                                            ),
                                          ),
                                          if (queued != null)
                                            const StatusChip('En attente d\'envoi', tone: ChipTone.info)
                                          else if (total != null)
                                            StatusChip('${formatScore(total)} pts', tone: ChipTone.success)
                                          else
                                            const StatusChip('À noter'),
                                          Icon(AppIcons.forward, color: c.textMuted),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        }),
      );

  Future<void> _open(int entryId) async {
    await context.push('/jury/${widget.slug}/preselection/$entryId');
    if (mounted) {
      ref.invalidate(juryListProvider((slug: widget.slug, tab: 'a_noter', search: _search)));
      ref.invalidate(juryListProvider((slug: widget.slug, tab: 'notees', search: _search)));
    }
  }
}
