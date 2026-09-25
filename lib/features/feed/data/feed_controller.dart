import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/providers.dart';
import 'feed_item.dart';

class FeedState {
  const FeedState({this.items = const [], this.nextCursor, this.loading = false, this.loadingMore = false, this.error, this.fromCache = false});

  final List<FeedItem> items;
  final String? nextCursor;
  final bool loading;
  final bool loadingMore;
  final ApiException? error;

  /// Showing the local copy (offline or before the first answer).
  final bool fromCache;

  bool get hasMore => nextCursor != null;

  FeedState copyWith({List<FeedItem>? items, String? nextCursor, bool clearCursor = false, bool? loading, bool? loadingMore, ApiException? error, bool clearError = false, bool? fromCache}) =>
      FeedState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        fromCache: fromCache ?? this.fromCache,
      );
}

/// The feed (all competitions, or one with [competition]): first page from the local
/// copy at once, then the server; more pages as the viewer scrolls. Likes are applied
/// on screen at once and sent through the offline queue (reverted if refused).
class FeedController extends StateNotifier<FeedState> {
  FeedController({required ApiClient api, required Outbox outbox, this.competition}) : _api = api, _outbox = outbox, super(const FeedState(loading: true)) {
    _results = _outbox.results.listen(_onResult);
    unawaited(refresh());
  }

  final ApiClient _api;
  final Outbox _outbox;
  final String? competition;
  late final StreamSubscription<OutboxResult> _results;

  /// Queued like id → the items to restore if the server refuses it.
  final Map<String, List<FeedItem>> _pendingLikes = {};

  static const int _pageSize = 8;

  Map<String, dynamic> _query([String? cursor]) => {
        'limit': _pageSize,
        'competition': ?competition,
        'cursor': ?cursor,
      };

  Future<void> refresh() async {
    if (state.items.isEmpty) {
      final local = await _api.peek('/feed', query: _query());
      if (local != null && mounted) {
        final page = _parse(local.data);
        state = state.copyWith(items: page.items, nextCursor: page.next, fromCache: true);
      }
    }
    try {
      final response = await _api.get('/feed', query: _query());
      final page = _parse(response.data);
      if (!mounted) return;
      state = FeedState(items: page.items, nextCursor: page.next);
    } on ApiException catch (error) {
      if (mounted) state = state.copyWith(loading: false, error: error);
    }
  }

  /// Called when the viewer approaches the end.
  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = _parse((await _api.get('/feed', query: _query(state.nextCursor))).data);
      if (!mounted) return;
      final known = state.items.map((i) => i.key).toSet();
      state = state.copyWith(
        items: [...state.items, ...page.items.where((i) => !known.contains(i.key))],
        nextCursor: page.next,
        clearCursor: page.next == null,
        loadingMore: false,
      );
    } on ApiException catch (error) {
      if (mounted) state = state.copyWith(loadingMore: false, error: error);
    }
  }

  /// Like (or remove the like of) a pre-selection entry. One like per competition:
  /// liking another entry moves it.
  Future<void> toggleLike(FeedItem item) async {
    final likes = item.likes;
    if (likes == null || !likes.open) return;
    final before = state.items;
    final liking = !likes.liked;

    state = state.copyWith(items: [
      for (final other in state.items)
        if (other.key == item.key)
          other.withLikes(likes.copyWith(liked: liking, count: likes.count == null ? null : likes.count! + (liking ? 1 : -1)))
        else if (liking && other.competitionSlug == item.competitionSlug && other.likes?.liked == true)
          other.withLikes(other.likes!.copyWith(liked: false, count: other.likes!.count == null ? null : other.likes!.count! - 1))
        else
          other,
    ]);

    final id = liking
        ? await _outbox.enqueue(method: 'POST', path: '/competitions/${item.competitionSlug}/preselection/entries/${item.id}/like', label: 'Like · ${item.stageName}')
        : await _outbox.enqueue(method: 'DELETE', path: '/competitions/${item.competitionSlug}/preselection/like', label: 'Like retiré · ${item.stageName}');
    _pendingLikes[id] = before;
  }

  void _onResult(OutboxResult result) {
    final before = _pendingLikes.remove(result.id);
    if (before == null || !mounted) return;
    if (!result.succeeded) {
      state = state.copyWith(items: before, error: result.error);
      return;
    }
    // The server tells the real counts once the viewer has liked.
    final counts = result.response?.json['counts'];
    if (counts is Map) {
      state = state.copyWith(items: [
        for (final item in state.items)
          if (item.isEntry && item.likes != null && counts.containsKey('${item.id}'))
            item.withLikes(item.likes!.copyWith(count: counts['${item.id}'] as int?))
          else
            item,
      ]);
    }
  }

  ({List<FeedItem> items, String? next}) _parse(Object? json) {
    final map = json! as Map<String, dynamic>;
    final items = (map['data'] as List<dynamic>).map((e) => FeedItem.fromJson(e as Map<String, dynamic>)).toList();
    return (items: items, next: (map['meta'] as Map<String, dynamic>)['next_cursor'] as String?);
  }

  @override
  void dispose() {
    _results.cancel();
    super.dispose();
  }
}

/// `null` = « Pour toi » (every competition); a slug = one competition's performances.
final feedProvider = StateNotifierProvider.autoDispose.family<FeedController, FeedState, String?>((ref, competition) {
  // Keep the main feed across tab switches (scroll position, loaded pages).
  if (competition == null) ref.keepAlive();
  // A new account sees its own likes.
  ref.watch(currentUserProvider.select((u) => u?.id));
  return FeedController(api: ref.read(apiClientProvider), outbox: ref.read(outboxProvider), competition: competition);
});
