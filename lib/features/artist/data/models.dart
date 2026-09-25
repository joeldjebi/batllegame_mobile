import '../../../core/utils/labels.dart';
import '../../feed/data/feed_item.dart';

List<Map<String, dynamic>> _list(Object? value) => (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

/// What an upload must respect (per pre-selection or stage).
class MediaRules {
  const MediaRules({required this.types, required this.maxDurationSeconds, required this.maxSizeMb});

  factory MediaRules.fromJson(Map<String, dynamic> json) => MediaRules(
        types: [for (final t in (json['types'] as List<dynamic>? ?? const ['video'])) '$t'],
        maxDurationSeconds: (json['max_duration_seconds'] as int?) ?? 180,
        maxSizeMb: (json['max_size_mb'] as int?) ?? 200,
      );

  final List<String> types;
  final int maxDurationSeconds;
  final int maxSizeMb;

  bool get acceptsVideo => types.contains('video');

  String get summary {
    final minutes = maxDurationSeconds ~/ 60, seconds = maxDurationSeconds % 60;
    final duration = seconds == 0 ? '$minutes min' : '$minutes min ${seconds.toString().padLeft(2, '0')} s';
    return '${acceptsVideo ? 'Vidéo' : 'Audio'} · $duration max · $maxSizeMb Mo max';
  }
}

/// One of my competitions (GET /me/participations).
class Participation {
  const Participation({required this.id, required this.competitionId, required this.stageName, required this.status, required this.slug, required this.competitionName, required this.competitionStatus, this.organizer});

  factory Participation.fromJson(Map<String, dynamic> json) {
    final competition = json['competition'] as Map<String, dynamic>;
    return Participation(
      id: json['id'] as int,
      competitionId: (competition['id'] as int?) ?? 0,
      stageName: json['stage_name'] as String,
      status: json['status'] as String,
      slug: competition['slug'] as String,
      competitionName: competition['name'] as String,
      competitionStatus: competition['status'] as String,
      organizer: competition['organizer'] as String?,
    );
  }

  final int id;
  final int competitionId;
  final String stageName;
  final String status;
  final String slug;
  final String competitionName;
  final String competitionStatus;
  final String? organizer;
}

class SubmittedMedia {
  const SubmittedMedia({required this.id, required this.status, this.rejectionReason, this.media, this.likes});

  factory SubmittedMedia.fromJson(Map<String, dynamic> json) => SubmittedMedia(
        id: json['id'] as int,
        status: json['status'] as String,
        rejectionReason: json['rejection_reason'] as String?,
        likes: json['likes'] as int?,
        media: json['media'] is Map<String, dynamic> ? MediaInfo.fromJson(json['media'] as Map<String, dynamic>) : null,
      );

  final int id;
  final String status;
  final String? rejectionReason;
  final MediaInfo? media;
  final int? likes;
}

class NextAction {
  const NextAction({required this.type, required this.text, this.deadline, this.stageId, this.matchId, this.stage});

  factory NextAction.fromJson(Map<String, dynamic> json) => NextAction(
        type: json['type'] as String,
        text: json['text'] as String,
        stage: json['stage'] as String?,
        deadline: parseDate(json['deadline']),
        stageId: json['stage_id'] as int?,
        matchId: json['match_id'] as int?,
      );

  /// `submit`, `sent`, `vote`, `wait`, `stage`.
  final String type;
  final String text;
  final String? stage;
  final DateTime? deadline;
  final int? stageId;
  final int? matchId;
}

class JourneyPreselection {
  const JourneyPreselection({required this.state, required this.canSubmit, required this.selectionSize, required this.rules, this.endsAt, this.entry, this.selected, this.rank});

  factory JourneyPreselection.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>?;
    return JourneyPreselection(
      state: json['state'] as String,
      canSubmit: json['can_submit'] == true,
      selectionSize: (json['selection_size'] as int?) ?? 0,
      rules: MediaRules.fromJson(json['media_rules'] as Map<String, dynamic>? ?? const {}),
      endsAt: parseDate(json['ends_at']),
      entry: json['entry'] is Map<String, dynamic> ? SubmittedMedia.fromJson(json['entry'] as Map<String, dynamic>) : null,
      selected: result?['selected'] as bool?,
      rank: result?['rank'] as int?,
    );
  }

  final String state;
  final bool canSubmit;
  final int selectionSize;
  final MediaRules rules;
  final DateTime? endsAt;
  final SubmittedMedia? entry;
  final bool? selected;
  final int? rank;

  bool get published => state == 'publiee';
}

class JourneyStage {
  const JourneyStage({
    required this.name,
    required this.state,
    required this.label,
    this.id,
    this.submissionDeadline,
    this.votingClosesAt,
    this.action,
    this.rules,
    this.matchId,
    this.matchTitle,
    this.isGroup = false,
    this.others = const [],
    this.myScore,
    this.myRank,
    this.votingOpen = false,
    this.submission,
  });

  factory JourneyStage.fromJson(Map<String, dynamic> json) {
    final dates = json['dates'] as Map<String, dynamic>? ?? const {};
    final match = json['match'] as Map<String, dynamic>?;
    return JourneyStage(
      id: json['id'] as int?,
      name: json['name'] as String,
      state: json['state'] as String,
      label: json['label'] as String,
      submissionDeadline: parseDate(dates['submission']),
      votingClosesAt: parseDate(dates['voting_closes']),
      action: json['action'] is Map<String, dynamic> ? NextAction.fromJson(json['action'] as Map<String, dynamic>) : null,
      rules: json['media_rules'] is Map<String, dynamic> ? MediaRules.fromJson(json['media_rules'] as Map<String, dynamic>) : null,
      matchId: match?['id'] as int?,
      matchTitle: match?['title'] as String?,
      isGroup: match?['is_group'] == true,
      others: [for (final o in _list(match?['others'])) (name: '${o['stage_name']}', avatarUrl: o['avatar_url'] as String?)],
      myScore: (match?['my_score'] as num?)?.toDouble(),
      myRank: match?['my_rank'] as int?,
      votingOpen: match?['voting_open'] == true,
      submission: json['submission'] is Map<String, dynamic> ? SubmittedMedia.fromJson(json['submission'] as Map<String, dynamic>) : null,
    );
  }

  final int? id;
  final String name;

  /// `won`, `done`, `current`, `waiting`, `lost`, `upcoming`, `skipped`.
  final String state;
  final String label;
  final DateTime? submissionDeadline;
  final DateTime? votingClosesAt;
  final NextAction? action;
  final MediaRules? rules;
  final int? matchId;
  final String? matchTitle;
  final bool isGroup;
  final List<({String name, String? avatarUrl})> others;
  final double? myScore;
  final int? myRank;
  final bool votingOpen;
  final SubmittedMedia? submission;

  bool get canSubmit => id != null && rules != null && (action?.type == 'submit' || action?.type == 'sent');
}

class JourneyPhase {
  const JourneyPhase({required this.title, required this.state, required this.online, required this.stages, this.qualifiersPerGroup});

  final String title;
  final String state;
  final bool online;
  final int? qualifiersPerGroup;
  final List<JourneyStage> stages;
}

/// « Mon parcours » (GET /me/participations/{slug}).
class Journey {
  const Journey({
    required this.slug,
    required this.competitionName,
    required this.stageName,
    required this.status,
    required this.paid,
    required this.paymentRequired,
    required this.awaitsApproval,
    required this.out,
    required this.champion,
    required this.phases,
    this.next,
    this.preselection,
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final competition = data['competition'] as Map<String, dynamic>;
    final participant = data['participant'] as Map<String, dynamic>;
    return Journey(
      slug: competition['slug'] as String,
      competitionName: competition['name'] as String,
      stageName: participant['stage_name'] as String,
      status: participant['status'] as String,
      paid: participant['paid'] == true,
      paymentRequired: participant['payment_required'] == true,
      awaitsApproval: participant['awaits_approval'] == true,
      out: data['out'] == true,
      champion: data['champion'] == true,
      next: data['next'] is Map<String, dynamic> ? NextAction.fromJson(data['next'] as Map<String, dynamic>) : null,
      preselection: data['preselection'] is Map<String, dynamic> ? JourneyPreselection.fromJson(data['preselection'] as Map<String, dynamic>) : null,
      phases: [
        for (final p in _list(data['phases']))
          JourneyPhase(
            title: p['title'] as String,
            state: p['state'] as String,
            online: p['online'] == true,
            qualifiersPerGroup: p['qualifiers_per_group'] as int?,
            stages: [for (final s in _list(p['stages'])) JourneyStage.fromJson(s)],
          ),
      ],
    );
  }

  /// The one thing to do: the server's next step (it covers the phases), or before
  /// them the pre-selection entry (to send, refused, sent, online).
  NextAction? get effectiveNext {
    if (next != null) return next;
    final pre = preselection;
    if (pre == null || pre.published) return null;
    final entry = pre.entry;
    if (pre.canSubmit && (entry == null || entry.status == 'rejetee')) {
      return NextAction(
        type: 'submit',
        stage: 'Présélection',
        text: entry == null
            ? 'Envoie ta prestation avant la date limite pour tenter ta place parmi les ${pre.selectionSize} retenus.'
            : 'Ta prestation a été refusée : envoies-en une nouvelle avant la date limite.',
        deadline: pre.endsAt,
      );
    }
    if (entry != null && entry.status != 'rejetee') {
      return NextAction(
        type: 'wait',
        stage: 'Présélection',
        text: entry.status == 'validee' ? 'Ta prestation est en ligne. Partage-la pour recevoir des likes.' : 'Ta prestation est envoyée : l\'organisateur la vérifie.',
      );
    }
    return null;
  }

  final String slug;
  final String competitionName;
  final String stageName;
  final String status;
  final bool paid;
  final bool paymentRequired;
  final bool awaitsApproval;
  final bool out;
  final bool champion;
  final NextAction? next;
  final JourneyPreselection? preselection;
  final List<JourneyPhase> phases;
}
