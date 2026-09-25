import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/resource.dart';
import '../../../core/providers.dart';
import 'models.dart';

typedef CompetitionPage = ({List<CompetitionSummary> items, int page, int lastPage});

/// Competitions by status filter (`null` = every public one), first page cached.
final competitionsProvider = StreamProvider.autoDispose.family<Resource<CompetitionPage>, String?>((ref, status) => watchResource(
      ref.watch(apiClientProvider),
      '/competitions',
      query: {'status': ?status},
      (json) {
        final map = json! as Map<String, dynamic>;
        final meta = map['meta'] as Map<String, dynamic>? ?? const {};
        return (
          items: [for (final c in (map['data'] as List<dynamic>)) CompetitionSummary.fromJson(c as Map<String, dynamic>)],
          page: (meta['current_page'] as int?) ?? 1,
          lastPage: (meta['last_page'] as int?) ?? 1,
        );
      },
    ));

final competitionProvider = StreamProvider.autoDispose.family<Resource<CompetitionDetail>, String>((ref, slug) => watchResource(
      ref.watch(apiClientProvider),
      '/competitions/$slug',
      (json) => CompetitionDetail.fromJson((json! as Map<String, dynamic>)['data'] as Map<String, dynamic>),
    ));

final phaseMatchesProvider = StreamProvider.autoDispose.family<Resource<List<MatchSummary>>, ({String slug, int phase})>((ref, key) => watchResource(
      ref.watch(apiClientProvider),
      '/competitions/${key.slug}/matches',
      query: {'phase': key.phase},
      (json) => [for (final m in ((json! as Map<String, dynamic>)['data'] as List<dynamic>)) MatchSummary.fromJson(m as Map<String, dynamic>)],
    ));

final matchProvider = StreamProvider.autoDispose.family<Resource<MatchDetail>, ({String slug, int id})>((ref, key) => watchResource(
      ref.watch(apiClientProvider),
      '/competitions/${key.slug}/matches/${key.id}',
      (json) => MatchDetail.fromJson(json! as Map<String, dynamic>),
    ));
