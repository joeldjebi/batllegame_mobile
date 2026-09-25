import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/resource.dart';
import '../../../core/providers.dart';
import 'models.dart';
import 'pending_scores.dart';

final pendingScoresProvider = StateNotifierProvider<PendingScores, Map<String, Map<int, double>>>(
  (ref) => PendingScores(db: ref.read(databaseProvider), outbox: ref.read(outboxProvider)),
);

final judgeCompetitionsProvider = StreamProvider.autoDispose<Resource<List<JudgeCompetition>>>((ref) => watchResource(
      ref.watch(apiClientProvider),
      '/judge/competitions',
      (json) => [for (final c in ((json! as Map<String, dynamic>)['data'] as List<dynamic>)) JudgeCompetition.fromJson(c as Map<String, dynamic>)],
    ));

final juryEntryProvider = StreamProvider.autoDispose.family<Resource<JuryEntryDetail>, ({String slug, int id})>((ref, key) => watchResource(
      ref.watch(apiClientProvider),
      '/judge/competitions/${key.slug}/preselection/entries/${key.id}',
      (json) => JuryEntryDetail.fromJson(json! as Map<String, dynamic>),
    ));

final judgeMatchesProvider = StreamProvider.autoDispose.family<Resource<({List<JudgeMatch> matches, List<Criterion> criteria})>, String>((ref, slug) => watchResource(
      ref.watch(apiClientProvider),
      '/judge/competitions/$slug',
      (json) {
        final map = json! as Map<String, dynamic>;
        return (
          matches: [for (final m in (map['matches'] as List<dynamic>)) JudgeMatch.fromJson(m as Map<String, dynamic>)],
          criteria: [for (final c in (map['criteria'] as List<dynamic>)) Criterion.fromJson(c as Map<String, dynamic>)],
        );
      },
    ));

final judgeMatchProvider = StreamProvider.autoDispose.family<Resource<JudgeMatchDetail>, ({String slug, int id})>((ref, key) => watchResource(
      ref.watch(apiClientProvider),
      '/judge/competitions/${key.slug}/matches/${key.id}',
      (json) => JudgeMatchDetail.fromJson(json! as Map<String, dynamic>),
    ));

class JuryListState {
  const JuryListState({this.entries = const [], this.summary, this.cursor, this.loading = true, this.loadingMore = false, this.error});

  final List<JuryEntry> entries;
  final JurySummary? summary;
  final String? cursor;
  final bool loading;
  final bool loadingMore;
  final ApiException? error;
}

/// Entries to score / scored, cursor-paginated; first page from the local copy.
class JuryListController extends StateNotifier<JuryListState> {
  JuryListController(this._ref, this.slug, this.tab, this.search) : super(const JuryListState()) {
    refresh();
  }

  final Ref _ref;
  final String slug;
  final String tab;
  final String search;

  Map<String, dynamic> _query([String? cursor]) => {'tab': tab, 'limit': 25, if (search.isNotEmpty) 'q': search, 'cursor': ?cursor};

  ({List<JuryEntry> entries, JurySummary summary, String? cursor}) _parse(Object? json) {
    final map = json! as Map<String, dynamic>;
    final meta = map['meta'] as Map<String, dynamic>;
    return (
      entries: [for (final e in (map['data'] as List<dynamic>)) JuryEntry.fromJson(e as Map<String, dynamic>)],
      summary: JurySummary.fromJson(meta),
      cursor: meta['next_cursor'] as String?,
    );
  }

  Future<void> refresh() async {
    final api = _ref.read(apiClientProvider);
    final path = '/judge/competitions/$slug/preselection';
    if (state.entries.isEmpty) {
      final local = await api.peek(path, query: _query());
      if (local != null && mounted) {
        final page = _parse(local.data);
        state = JuryListState(entries: page.entries, summary: page.summary, cursor: page.cursor, loading: true);
      }
    }
    try {
      final page = _parse((await api.get(path, query: _query())).data);
      if (mounted) state = JuryListState(entries: page.entries, summary: page.summary, cursor: page.cursor, loading: false);
    } on ApiException catch (error) {
      if (mounted) state = JuryListState(entries: state.entries, summary: state.summary, cursor: state.cursor, loading: false, error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.cursor == null || state.loadingMore) return;
    state = JuryListState(entries: state.entries, summary: state.summary, cursor: state.cursor, loading: false, loadingMore: true);
    try {
      final page = _parse((await _ref.read(apiClientProvider).get('/judge/competitions/$slug/preselection', query: _query(state.cursor))).data);
      if (mounted) state = JuryListState(entries: [...state.entries, ...page.entries], summary: page.summary, cursor: page.cursor, loading: false);
    } on ApiException catch (error) {
      if (mounted) state = JuryListState(entries: state.entries, summary: state.summary, cursor: state.cursor, loading: false, error: error);
    }
  }
}

final juryListProvider = StateNotifierProvider.autoDispose.family<JuryListController, JuryListState, ({String slug, String tab, String search})>(
  (ref, key) => JuryListController(ref, key.slug, key.tab, key.search),
);
