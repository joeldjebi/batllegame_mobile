import '../../../core/utils/labels.dart';

/// A playable media (feed, match, entry).
class MediaInfo {
  const MediaInfo({required this.type, this.url, this.posterUrl, this.width, this.height, this.durationSeconds});

  factory MediaInfo.fromJson(Map<String, dynamic> json) => MediaInfo(
        type: (json['type'] as String?) ?? 'video',
        url: json['url'] as String?,
        posterUrl: json['poster_url'] as String?,
        width: json['width'] as int?,
        height: json['height'] as int?,
        durationSeconds: json['duration_seconds'] as int?,
      );

  final String type;
  final String? url;
  final String? posterUrl;
  final int? width;
  final int? height;
  final int? durationSeconds;

  bool get isVideo => type == 'video';

  /// Portrait (or unknown): fills the screen; landscape: fits the width.
  bool get isPortrait => width == null || height == null || height! >= width!;
}

class FeedLikes {
  const FeedLikes({required this.enabled, required this.open, required this.liked, this.count});

  factory FeedLikes.fromJson(Map<String, dynamic> json) => FeedLikes(
        enabled: json['enabled'] == true,
        open: json['open'] == true,
        liked: json['liked'] == true,
        count: json['count'] as int?,
      );

  final bool enabled;
  final bool open;
  final bool liked;

  /// Hidden (null) until the viewer liked in this competition, or results are public.
  final int? count;

  FeedLikes copyWith({bool? liked, int? count, bool clearCount = false}) =>
      FeedLikes(enabled: enabled, open: open, liked: liked ?? this.liked, count: clearCount ? null : (count ?? this.count));
}

class FeedVote {
  const FeedVote({required this.matchId, required this.open, this.closesAt});

  factory FeedVote.fromJson(Map<String, dynamic> json) =>
      FeedVote(matchId: json['match_id'] as int, open: json['open'] == true, closesAt: parseDate(json['closes_at']));

  final int matchId;
  final bool open;
  final DateTime? closesAt;
}

/// One performance of the « Pour toi » feed (GET /feed).
class FeedItem {
  const FeedItem({
    required this.key,
    required this.kind,
    required this.id,
    required this.media,
    required this.participantId,
    required this.stageName,
    required this.competitionSlug,
    required this.competitionName,
    required this.contextLabel,
    required this.shareUrl,
    this.avatarUrl,
    this.discipline,
    this.matchId,
    this.likes,
    this.vote,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>;
    final competition = json['competition'] as Map<String, dynamic>;
    final context = json['context'] as Map<String, dynamic>;
    return FeedItem(
      key: json['key'] as String,
      kind: json['kind'] as String,
      id: json['id'] as int,
      media: MediaInfo.fromJson(json['media'] as Map<String, dynamic>),
      participantId: artist['participant_id'] as int,
      stageName: (artist['stage_name'] as String?) ?? 'Artiste',
      avatarUrl: artist['avatar_url'] as String?,
      competitionSlug: competition['slug'] as String,
      competitionName: competition['name'] as String,
      discipline: competition['discipline'] as String?,
      contextLabel: (context['label'] as String?) ?? '',
      matchId: context['match_id'] as int?,
      likes: json['likes'] is Map<String, dynamic> ? FeedLikes.fromJson(json['likes'] as Map<String, dynamic>) : null,
      vote: json['vote'] is Map<String, dynamic> ? FeedVote.fromJson(json['vote'] as Map<String, dynamic>) : null,
      shareUrl: json['share_url'] as String,
    );
  }

  /// `preselection-12` / `performance-34`: stable across pages, used as cache key.
  final String key;
  final String kind;
  final int id;
  final MediaInfo media;
  final int participantId;
  final String stageName;
  final String? avatarUrl;
  final String competitionSlug;
  final String competitionName;
  final String? discipline;
  final String contextLabel;
  final int? matchId;
  final FeedLikes? likes;
  final FeedVote? vote;
  final String shareUrl;

  bool get isEntry => kind == 'preselection';

  FeedItem withLikes(FeedLikes likes) => FeedItem(
        key: key,
        kind: kind,
        id: id,
        media: media,
        participantId: participantId,
        stageName: stageName,
        avatarUrl: avatarUrl,
        competitionSlug: competitionSlug,
        competitionName: competitionName,
        discipline: discipline,
        contextLabel: contextLabel,
        matchId: matchId,
        likes: likes,
        vote: vote,
        shareUrl: shareUrl,
      );
}
