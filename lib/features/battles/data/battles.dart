import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/resource.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/providers.dart';
import '../../../core/utils/labels.dart';
import '../../feed/data/feed_item.dart';

class BattleArtist {
  const BattleArtist({required this.participantId, required this.stageName, this.avatarUrl, this.media, this.mediaId});

  final int participantId;
  final String stageName;
  final String? avatarUrl;
  final MediaInfo? media;
  final int? mediaId;
}

/// A match whose public vote is open (GET /live): a duel or a group.
class Battle {
  const Battle({
    required this.id,
    required this.isGroup,
    required this.title,
    required this.competitionSlug,
    required this.competitionName,
    required this.shareUrl,
    required this.artists,
    this.stage,
    this.closesAt,
    this.voteCodeRequired = false,
    this.myVote,
    this.votedInPhase = false,
    this.isMine = false,
  });

  factory Battle.fromJson(Map<String, dynamic> json) {
    final competition = json['competition'] as Map<String, dynamic>;
    return Battle(
      id: json['id'] as int,
      isGroup: json['is_group'] == true,
      title: json['title'] as String,
      stage: json['stage'] as String?,
      competitionSlug: competition['slug'] as String,
      competitionName: competition['name'] as String,
      closesAt: parseDate(json['voting_closes_at']),
      voteCodeRequired: json['vote_code_required'] == true,
      shareUrl: (json['share_url'] as String?) ?? '',
      myVote: json['my_vote'] as int?,
      votedInPhase: json['voted_in_phase'] == true,
      isMine: json['is_mine'] == true,
      artists: [
        for (final a in (json['artists'] as List<dynamic>).cast<Map<String, dynamic>>())
          BattleArtist(
            participantId: a['participant_id'] as int,
            stageName: a['stage_name'] as String,
            avatarUrl: a['avatar_url'] as String?,
            media: a['media'] is Map<String, dynamic> ? MediaInfo.fromJson(a['media'] as Map<String, dynamic>) : null,
            mediaId: (a['media'] as Map<String, dynamic>?)?['id'] as int?,
          ),
      ],
    );
  }

  final int id;
  final bool isGroup;
  final String title;
  final String? stage;
  final String competitionSlug;
  final String competitionName;
  final DateTime? closesAt;
  final bool voteCodeRequired;
  final String shareUrl;
  final List<BattleArtist> artists;
  final int? myVote;
  final bool votedInPhase;
  final bool isMine;

  bool get isDuel => !isGroup && artists.length == 2;
}

final battlesProvider = StreamProvider.autoDispose<Resource<List<Battle>>>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return watchResource(
    ref.watch(apiClientProvider),
    '/live',
    (json) => [for (final b in ((json! as Map<String, dynamic>)['data'] as List<dynamic>)) Battle.fromJson(b as Map<String, dynamic>)],
  );
});

/// Votes given from the Battles tab, shown at once and sent through the offline queue
/// (same key as the match page: one vote per match, remembered on the phone).
class BattleVotes extends StateNotifier<Map<int, int>> {
  BattleVotes(this._ref) : super(const {});

  final Ref _ref;

  Future<void> vote(Battle battle, BattleArtist artist) async {
    state = {...state, battle.id: artist.participantId};
    await _ref
        .read(outboxProvider)
        .enqueue(
          method: 'POST',
          path: '/competitions/${battle.competitionSlug}/matches/${battle.id}/votes',
          body: {'participant_id': artist.participantId},
          label: 'Vote · ${artist.stageName}',
        );
    await _ref.read(databaseProvider).writeValue('vote:${battle.competitionSlug}:${battle.id}', '${artist.participantId}');
  }

  /// A refused vote (already voted, closed): forget it on screen.
  void forget(int battleId) => state = {...state}..remove(battleId);
}

final battleVotesProvider = StateNotifierProvider<BattleVotes, Map<int, int>>((ref) {
  final votes = BattleVotes(ref);
  final sub = ref.read(outboxProvider).results.listen((OutboxResult result) {
    if (!result.succeeded) ref.invalidate(battlesProvider);
  });
  ref.onDispose(sub.cancel);
  return votes;
});
