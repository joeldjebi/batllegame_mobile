import '../../../core/utils/labels.dart';
import '../../feed/data/feed_item.dart';

List<Map<String, dynamic>> _list(Object? value) => (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

/// A competition in lists (GET /competitions).
class CompetitionSummary {
  const CompetitionSummary({
    required this.slug,
    required this.name,
    required this.status,
    required this.discipline,
    required this.entryFee,
    required this.currency,
    required this.registrationOpen,
    this.registrationEndsAt,
    this.organizerName,
    this.organizerLogoUrl,
    this.locationLabel,
  });

  factory CompetitionSummary.fromJson(Map<String, dynamic> json) {
    final organizer = json['organizer'] as Map<String, dynamic>?;
    final location = json['location'] as Map<String, dynamic>?;
    return CompetitionSummary(
      slug: json['slug'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      discipline: (json['discipline'] as String?) ?? 'autre',
      entryFee: (json['entry_fee'] as int?) ?? 0,
      currency: (json['currency'] as String?) ?? 'XOF',
      registrationOpen: json['registration_open'] == true,
      registrationEndsAt: parseDate(json['registration_ends_at']),
      organizerName: organizer?['name'] as String?,
      organizerLogoUrl: organizer?['logo_url'] as String?,
      locationLabel: location?['label'] as String?,
    );
  }

  final String slug;
  final String name;
  final String status;
  final String discipline;
  final int entryFee;
  final String currency;
  final bool registrationOpen;
  final DateTime? registrationEndsAt;
  final String? organizerName;
  final String? organizerLogoUrl;
  final String? locationLabel;
}

class Prize {
  const Prize(this.rank, this.reward);

  final String rank;
  final String reward;
}

class ScheduleStep {
  const ScheduleStep({required this.title, this.date, this.details});

  final String title;
  final DateTime? date;
  final String? details;
}

class PhaseInfo {
  const PhaseInfo({required this.id, required this.position, required this.type, required this.status});

  final int id;
  final int position;
  final String type;
  final String status;

  String get title => 'Phase $position · ${Labels.phaseType(type)}';
}

/// GET /competitions/{slug}.
class CompetitionDetail extends CompetitionSummary {
  const CompetitionDetail({
    required super.slug,
    required super.name,
    required super.status,
    required super.discipline,
    required super.entryFee,
    required super.currency,
    required super.registrationOpen,
    super.registrationEndsAt,
    super.organizerName,
    super.organizerLogoUrl,
    super.locationLabel,
    required this.id,
    required this.mode,
    this.description,
    this.regulations,
    this.prizes = const [],
    this.schedule = const [],
    this.phases = const [],
    this.maxParticipants,
  });

  factory CompetitionDetail.fromJson(Map<String, dynamic> json) {
    final summary = CompetitionSummary.fromJson(json);
    return CompetitionDetail(
      slug: summary.slug,
      name: summary.name,
      status: summary.status,
      discipline: summary.discipline,
      entryFee: summary.entryFee,
      currency: summary.currency,
      registrationOpen: summary.registrationOpen,
      registrationEndsAt: summary.registrationEndsAt,
      organizerName: summary.organizerName,
      organizerLogoUrl: summary.organizerLogoUrl,
      locationLabel: summary.locationLabel,
      id: json['id'] as int,
      mode: (json['mode'] as String?) ?? 'en_ligne',
      description: json['description'] as String?,
      regulations: json['regulations'] as String?,
      maxParticipants: json['max_participants'] as int?,
      prizes: [for (final p in _list(json['prizes'])) Prize('${p['rank']}', '${p['reward']}')],
      schedule: [
        for (final s in _list(json['schedule']))
          ScheduleStep(title: '${s['title']}', date: parseDate(s['date']), details: s['details'] as String?),
      ],
      phases: [
        for (final p in _list(json['phases']))
          PhaseInfo(id: p['id'] as int, position: p['position'] as int, type: p['type'] as String, status: p['status'] as String),
      ],
    );
  }

  final int id;
  final String mode;
  final String? description;
  final String? regulations;
  final List<Prize> prizes;
  final List<ScheduleStep> schedule;
  final List<PhaseInfo> phases;
  final int? maxParticipants;
}

class SlotSummary {
  const SlotSummary({this.participantId, required this.stageName, this.avatarUrl, this.finalScore, this.rank, this.isForfeit = false});

  factory SlotSummary.fromJson(Map<String, dynamic> json) => SlotSummary(
        participantId: json['participant_id'] as int?,
        stageName: (json['stage_name'] as String?) ?? 'À déterminer',
        avatarUrl: json['avatar_url'] as String?,
        finalScore: (json['final_score'] as num?)?.toDouble(),
        rank: json['rank'] as int?,
        isForfeit: json['is_forfeit'] == true,
      );

  final int? participantId;
  final String stageName;
  final String? avatarUrl;
  final double? finalScore;
  final int? rank;
  final bool isForfeit;
}

/// A match of a phase (GET /competitions/{slug}/matches).
class MatchSummary {
  const MatchSummary({
    required this.id,
    required this.isGroup,
    required this.title,
    required this.status,
    required this.votingOpen,
    required this.slots,
    this.group,
    this.round,
    this.stage,
    this.votingClosesAt,
    this.winnerId,
  });

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
        id: json['id'] as int,
        isGroup: json['is_group'] == true,
        title: json['title'] as String,
        status: json['status'] as String,
        votingOpen: json['voting_open'] == true,
        group: json['group'] as String?,
        round: json['round'] as int?,
        stage: json['stage'] as String?,
        votingClosesAt: parseDate(json['voting_closes_at']),
        winnerId: json['winner_id'] as int?,
        slots: [for (final s in _list(json['slots'])) SlotSummary.fromJson(s)],
      );

  final int id;
  final bool isGroup;
  final String title;
  final String status;
  final bool votingOpen;
  final String? group;
  final int? round;
  final String? stage;
  final DateTime? votingClosesAt;
  final int? winnerId;
  final List<SlotSummary> slots;
}

class MatchSlot {
  const MatchSlot({this.participantId, required this.stageName, this.avatarUrl, this.finalScore, this.rank, this.isForfeit = false, this.media = const []});

  final int? participantId;
  final String stageName;
  final String? avatarUrl;
  final double? finalScore;
  final int? rank;
  final bool isForfeit;
  final List<({int id, MediaInfo media})> media;
}

/// GET /competitions/{slug}/matches/{id}: the performances and the vote.
class MatchDetail {
  const MatchDetail({
    required this.id,
    required this.isGroup,
    required this.title,
    required this.status,
    required this.votingOpen,
    required this.voteCodeRequired,
    required this.slots,
    required this.shareUrl,
    this.stage,
    this.votingClosesAt,
    this.winnerId,
  });

  factory MatchDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return MatchDetail(
      id: data['id'] as int,
      isGroup: data['is_group'] == true,
      title: data['title'] as String,
      status: data['status'] as String,
      votingOpen: data['voting_open'] == true,
      voteCodeRequired: data['vote_code_required'] == true,
      stage: (data['stage'] as Map<String, dynamic>?)?['name'] as String?,
      votingClosesAt: parseDate(data['voting_closes_at']),
      winnerId: data['winner_id'] as int?,
      shareUrl: (data['share_url'] as String?) ?? '',
      slots: [
        for (final s in _list(data['slots']))
          MatchSlot(
            participantId: (s['participant'] as Map<String, dynamic>?)?['id'] as int?,
            stageName: ((s['participant'] as Map<String, dynamic>?)?['stage_name'] as String?) ?? 'À déterminer',
            avatarUrl: (s['participant'] as Map<String, dynamic>?)?['avatar_url'] as String?,
            finalScore: (s['final_score'] as num?)?.toDouble(),
            rank: s['rank'] as int?,
            isForfeit: s['is_forfeit'] == true,
            media: [for (final m in _list(s['media'])) (id: m['id'] as int, media: MediaInfo.fromJson(m))],
          ),
      ],
    );
  }

  final int id;
  final bool isGroup;
  final String title;
  final String status;
  final bool votingOpen;
  final bool voteCodeRequired;
  final String? stage;
  final DateTime? votingClosesAt;
  final int? winnerId;
  final String shareUrl;
  final List<MatchSlot> slots;
}
