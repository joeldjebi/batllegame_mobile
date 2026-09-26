import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../competitions/data/models.dart';
import '../../feed/data/feed_item.dart';

class SearchArtist {
  const SearchArtist({required this.participantId, required this.stageName, required this.competitionSlug, required this.competitionName, this.avatarUrl});

  factory SearchArtist.fromJson(Map<String, dynamic> json) {
    final competition = json['competition'] as Map<String, dynamic>;
    return SearchArtist(
      participantId: json['participant_id'] as int,
      stageName: json['stage_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      competitionSlug: competition['slug'] as String,
      competitionName: competition['name'] as String,
    );
  }

  final int participantId;
  final String stageName;
  final String? avatarUrl;
  final String competitionSlug;
  final String competitionName;
}

/// GET /search: competitions and artists (empty query: suggestions).
class SearchResults {
  const SearchResults({this.competitions = const [], this.artists = const []});

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
    competitions: [for (final c in (json['competitions'] as List<dynamic>? ?? const [])) CompetitionSummary.fromJson(c as Map<String, dynamic>)],
    artists: [for (final a in (json['artists'] as List<dynamic>? ?? const [])) SearchArtist.fromJson(a as Map<String, dynamic>)],
  );

  final List<CompetitionSummary> competitions;
  final List<SearchArtist> artists;
}

final searchProvider = FutureProvider.autoDispose.family<SearchResults, String>((ref, query) async {
  final response = await ref.watch(apiClientProvider).get('/search', query: {if (query.isNotEmpty) 'q': query});
  return SearchResults.fromJson(response.json);
});

/// The videos matching a search (artist or competition name), newest first.
final searchVideosProvider = FutureProvider.autoDispose.family<List<FeedItem>, String>((ref, query) async {
  final response = await ref.watch(apiClientProvider).get('/feed', query: {'q': query, 'limit': 30});
  return [for (final item in (response.json['data'] as List<dynamic>? ?? const [])) FeedItem.fromJson(item as Map<String, dynamic>)];
});

/// Recent searches, kept on the phone (10 max, newest first).
class SearchHistory extends StateNotifier<List<String>> {
  SearchHistory(this._ref) : super(const []) {
    _load();
  }

  static const _key = 'search_history';
  static const _max = 10;
  final Ref _ref;

  Future<void> _load() async {
    final raw = await _ref.read(databaseProvider).readValue(_key);
    if (raw == null || !mounted) return;
    try {
      state = (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {}
  }

  Future<void> add(String query) async {
    final value = query.trim();
    if (value.isEmpty) return;
    state = [value, ...state.where((q) => q.toLowerCase() != value.toLowerCase())].take(_max).toList();
    await _save();
  }

  Future<void> remove(String query) async {
    state = state.where((q) => q != query).toList();
    await _save();
  }

  Future<void> clear() async {
    state = const [];
    await _save();
  }

  Future<void> _save() => _ref.read(databaseProvider).writeValue(_key, jsonEncode(state));
}

final searchHistoryProvider = StateNotifierProvider<SearchHistory, List<String>>(SearchHistory.new);
