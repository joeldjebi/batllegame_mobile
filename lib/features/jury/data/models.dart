import '../../../core/utils/labels.dart';
import '../../feed/data/feed_item.dart';

List<Map<String, dynamic>> _list(Object? value) => (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

class Criterion {
  const Criterion({required this.id, required this.name, required this.maxPoints});

  factory Criterion.fromJson(Map<String, dynamic> json) =>
      Criterion(id: json['id'] as int, name: json['name'] as String, maxPoints: (json['max_points'] as num).toDouble());

  final int id;
  final String name;
  final double maxPoints;
}

/// A competition I judge (GET /judge/competitions).
class JudgeCompetition {
  const JudgeCompetition({required this.id, required this.slug, required this.name, required this.status, required this.matchesToScore, this.organizer, this.preselection});

  factory JudgeCompetition.fromJson(Map<String, dynamic> json) {
    final pre = json['preselection'] as Map<String, dynamic>?;
    return JudgeCompetition(
      id: json['id'] as int,
      slug: json['slug'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      organizer: json['organizer'] as String?,
      matchesToScore: (json['matches_to_score'] as int?) ?? 0,
      preselection: pre == null
          ? null
          : (state: pre['state'] as String, acceptsScores: pre['accepts_scores'] == true, total: (pre['total'] as int?) ?? 0, scored: (pre['scored'] as int?) ?? 0),
    );
  }

  final int id;
  final String slug;
  final String name;
  final String status;
  final String? organizer;
  final int matchesToScore;
  final ({String state, bool acceptsScores, int total, int scored})? preselection;
}

/// The progress block of a judge's pre-selection (meta of the list).
class JurySummary {
  const JurySummary({required this.state, required this.acceptsScores, required this.total, required this.scored, required this.criteria, this.deliberationEndsAt, this.nextEntryId, this.splitsJudging = false});

  factory JurySummary.fromJson(Map<String, dynamic> json) => JurySummary(
        state: json['state'] as String,
        acceptsScores: json['accepts_scores'] == true,
        total: (json['total'] as int?) ?? 0,
        scored: (json['scored'] as int?) ?? 0,
        deliberationEndsAt: parseDate(json['deliberation_ends_at']),
        nextEntryId: json['next_entry_id'] as int?,
        splitsJudging: json['splits_judging'] == true,
        criteria: [for (final c in _list(json['criteria'])) Criterion.fromJson(c)],
      );

  final String state;
  final bool acceptsScores;
  final int total;
  final int scored;
  final DateTime? deliberationEndsAt;
  final int? nextEntryId;
  final bool splitsJudging;
  final List<Criterion> criteria;
}

class JuryEntry {
  const JuryEntry({required this.id, required this.stageName, required this.media, this.avatarUrl, this.myTotal});

  factory JuryEntry.fromJson(Map<String, dynamic> json) => JuryEntry(
        id: json['id'] as int,
        stageName: json['stage_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        media: MediaInfo.fromJson(json['media'] as Map<String, dynamic>),
        myTotal: (json['my_total'] as num?)?.toDouble(),
      );

  final int id;
  final String stageName;
  final String? avatarUrl;
  final MediaInfo media;
  final double? myTotal;
}

/// One entry to score (GET /judge/competitions/{slug}/preselection/entries/{id}).
class JuryEntryDetail {
  const JuryEntryDetail({required this.entry, required this.myScores, required this.canScore, required this.summary, this.nextEntryId});

  factory JuryEntryDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return JuryEntryDetail(
      entry: JuryEntry.fromJson(data),
      myScores: {for (final s in _list(data['my_scores'])) s['criterion_id'] as int: (s['score'] as num).toDouble()},
      canScore: data['can_score'] == true,
      nextEntryId: data['next_entry_id'] as int?,
      summary: JurySummary.fromJson(json['meta'] as Map<String, dynamic>),
    );
  }

  final JuryEntry entry;
  final Map<int, double> myScores;
  final bool canScore;
  final int? nextEntryId;
  final JurySummary summary;
}

/// A match to score (GET /judge/competitions/{slug}).
class JudgeMatch {
  const JudgeMatch({required this.id, required this.title, required this.status, required this.toScore, required this.scoredParticipants, required this.artists, this.stage, this.deliberationEndsAt});

  factory JudgeMatch.fromJson(Map<String, dynamic> json) => JudgeMatch(
        id: json['id'] as int,
        title: json['title'] as String,
        status: json['status'] as String,
        stage: (json['stage'] as Map<String, dynamic>?)?['name'] as String?,
        toScore: json['to_score'] == true,
        deliberationEndsAt: parseDate(json['deliberation_ends_at']),
        scoredParticipants: {for (final id in (json['scored_participants'] as List<dynamic>? ?? const [])) id as int},
        artists: [for (final s in _list(json['slots'])) if (s['participant'] != null) (s['participant'] as Map<String, dynamic>)['id'] as int],
      );

  final int id;
  final String title;
  final String status;
  final String? stage;
  final bool toScore;
  final DateTime? deliberationEndsAt;
  final Set<int> scoredParticipants;
  final List<int> artists;

  bool get fullyScored => artists.isNotEmpty && artists.every(scoredParticipants.contains);
}

class JudgeMatchArtist {
  const JudgeMatchArtist({required this.participantId, required this.stageName, this.avatarUrl, this.media});

  final int participantId;
  final String stageName;
  final String? avatarUrl;
  final ({int id, MediaInfo media})? media;
}

/// A match with its performances and my notes (GET /judge/competitions/{slug}/matches/{id}).
class JudgeMatchDetail {
  const JudgeMatchDetail({required this.id, required this.title, required this.canScore, required this.artists, required this.criteria, required this.myScores, this.deliberationEndsAt});

  factory JudgeMatchDetail.fromJson(Map<String, dynamic> json) {
    final match = json['match'] as Map<String, dynamic>;
    final scores = <int, Map<int, double>>{};
    for (final s in _list(json['my_scores'])) {
      (scores[s['participant_id'] as int] ??= {})[s['criterion_id'] as int] = (s['score'] as num).toDouble();
    }
    return JudgeMatchDetail(
      id: match['id'] as int,
      title: match['title'] as String,
      canScore: match['jury_scoring_open'] == true,
      deliberationEndsAt: parseDate(match['deliberation_ends_at']),
      criteria: [for (final c in _list(json['criteria'])) Criterion.fromJson(c)],
      myScores: scores,
      artists: [
        for (final s in _list(match['slots']))
          if (s['participant'] != null)
            JudgeMatchArtist(
              participantId: (s['participant'] as Map<String, dynamic>)['id'] as int,
              stageName: (s['participant'] as Map<String, dynamic>)['stage_name'] as String,
              avatarUrl: (s['participant'] as Map<String, dynamic>)['avatar_url'] as String?,
              media: _list(s['media']).isEmpty ? null : (id: _list(s['media']).first['id'] as int, media: MediaInfo.fromJson(_list(s['media']).first)),
            ),
      ],
    );
  }

  final int id;
  final String title;
  final bool canScore;
  final DateTime? deliberationEndsAt;
  final List<JudgeMatchArtist> artists;
  final List<Criterion> criteria;
  final Map<int, Map<int, double>> myScores;
}
