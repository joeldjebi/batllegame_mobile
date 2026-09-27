import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../feed/data/feed_item.dart';

class ArtistParticipation {
  const ArtistParticipation({
    required this.participantId,
    required this.stageName,
    required this.status,
    required this.statusLabel,
    required this.competitionSlug,
    required this.competitionName,
    required this.competitionStatus,
    this.discipline,
    this.organizer,
  });

  factory ArtistParticipation.fromJson(Map<String, dynamic> json) {
    final competition = json['competition'] as Map<String, dynamic>;
    return ArtistParticipation(
      participantId: json['participant_id'] as int,
      stageName: json['stage_name'] as String,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      competitionSlug: competition['slug'] as String,
      competitionName: competition['name'] as String,
      competitionStatus: competition['status'] as String,
      discipline: competition['discipline'] as String?,
      organizer: competition['organizer'] as String?,
    );
  }

  final int participantId;
  final String stageName;
  final String status;
  final String statusLabel;
  final String competitionSlug;
  final String competitionName;
  final String competitionStatus;
  final String? discipline;
  final String? organizer;
}

/// GET /artists/{participant}: one page per artist account.
class ArtistProfile {
  const ArtistProfile({
    required this.participantId,
    required this.stageName,
    required this.followersCount,
    required this.following,
    required this.isMe,
    required this.performancesCount,
    required this.participations,
    this.avatarUrl,
  });

  factory ArtistProfile.fromJson(Map<String, dynamic> json) => ArtistProfile(
    participantId: json['participant_id'] as int,
    stageName: json['stage_name'] as String,
    avatarUrl: json['avatar_url'] as String?,
    followersCount: json['followers_count'] as int? ?? 0,
    following: json['following'] == true,
    isMe: json['is_me'] == true,
    performancesCount: json['performances_count'] as int? ?? 0,
    participations: [for (final p in (json['participations'] as List<dynamic>? ?? const [])) ArtistParticipation.fromJson(p as Map<String, dynamic>)],
  );

  final int participantId;
  final String stageName;
  final String? avatarUrl;
  final int followersCount;
  final bool following;
  final bool isMe;
  final int performancesCount;
  final List<ArtistParticipation> participations;
}

class FollowedArtist {
  const FollowedArtist({required this.participantId, required this.stageName, required this.competitionName, this.avatarUrl});

  factory FollowedArtist.fromJson(Map<String, dynamic> json) => FollowedArtist(
    participantId: json['participant_id'] as int,
    stageName: json['stage_name'] as String,
    avatarUrl: json['avatar_url'] as String?,
    competitionName: (json['competition'] as Map<String, dynamic>)['name'] as String,
  );

  final int participantId;
  final String stageName;
  final String? avatarUrl;
  final String competitionName;
}

final artistProvider = FutureProvider.autoDispose.family<ArtistProfile, int>((ref, participantId) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  final response = await ref.watch(apiClientProvider).get('/artists/$participantId');
  return ArtistProfile.fromJson(response.json);
});

final artistVideosProvider = FutureProvider.autoDispose.family<List<FeedItem>, int>((ref, participantId) async {
  final response = await ref.watch(apiClientProvider).get('/feed', query: {'artist': participantId, 'limit': 30});
  return [for (final item in (response.json['data'] as List<dynamic>? ?? const [])) FeedItem.fromJson(item as Map<String, dynamic>)];
});

final followingProvider = FutureProvider.autoDispose<List<FollowedArtist>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  final response = await ref.watch(apiClientProvider).get('/me/following');
  return [for (final a in (response.json['data'] as List<dynamic>? ?? const [])) FollowedArtist.fromJson(a as Map<String, dynamic>)];
});

/// Follow state shown at once (then confirmed by the server, undone on refusal).
class FollowState extends StateNotifier<Map<int, bool>> {
  FollowState(this._ref) : super(const {});

  final Ref _ref;

  Future<bool> toggle(ArtistProfile artist) async {
    final follow = !(state[artist.participantId] ?? artist.following);
    state = {...state, artist.participantId: follow};
    try {
      final api = _ref.read(apiClientProvider);
      follow ? await api.post('/artists/${artist.participantId}/follow') : await api.delete('/artists/${artist.participantId}/follow');
      _ref
        ..invalidate(followingProvider)
        ..invalidate(artistProvider(artist.participantId));
      return true;
    } catch (_) {
      state = {...state, artist.participantId: !follow};
      return false;
    }
  }
}

final followStateProvider = StateNotifierProvider<FollowState, Map<int, bool>>(FollowState.new);
