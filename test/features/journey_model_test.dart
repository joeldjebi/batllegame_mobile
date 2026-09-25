import 'package:battlegame/features/artist/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the journey of the API (next action, pre-selection, stages to submit)', () {
    final journey = Journey.fromJson({
      'data': {
        'competition': {'id': 1, 'slug': 'abidjan-rap', 'name': 'Abidjan Rap', 'status': 'en_cours', 'organizer': 'Yop City'},
        'participant': {'id': 3, 'stage_name': 'Awa', 'status': 'valide', 'paid': true, 'payment_required': false, 'awaits_approval': false},
        'out': false,
        'champion': false,
        'next': {'type': 'submit', 'text': 'Envoie ta prestation.', 'stage': 'Poules', 'phase': 1, 'deadline': '2026-10-01T18:00:00+00:00', 'stage_id': 9, 'match_id': null},
        'preselection': {
          'state': 'publiee',
          'ends_at': '2026-09-20T18:00:00+00:00',
          'selection_size': 16,
          'can_submit': false,
          'media_rules': {'types': ['video'], 'max_duration_seconds': 150, 'max_size_mb': 200},
          'entry': {'id': 4, 'status': 'validee', 'rejection_reason': null, 'likes': 12, 'media': {'type': 'video', 'url': 'u', 'poster_url': 'p'}},
          'result': {'selected': true, 'rank': 3},
        },
        'phases': [
          {
            'title': 'Phase 1 · Poules',
            'state': 'current',
            'online': true,
            'qualifiers_per_group': 2,
            'stages': [
              {
                'id': 9,
                'name': 'Poules',
                'state': 'current',
                'label': 'Prestation à envoyer',
                'dates': {'submission': '2026-10-01T18:00:00+00:00', 'voting_opens': null, 'voting_closes': null},
                'action': {'type': 'submit', 'text': 'Envoie.', 'deadline': '2026-10-01T18:00:00+00:00'},
                'media_rules': {'types': ['video'], 'max_duration_seconds': 180, 'max_size_mb': 150},
                'match': {'id': 21, 'is_group': true, 'title': 'Poule A', 'others': [{'participant_id': 5, 'stage_name': 'Bob', 'avatar_url': null}], 'my_score': null, 'my_rank': null, 'voting_open': false},
                'submission': null,
              },
            ],
          },
        ],
      },
    });

    expect(journey.next?.type, 'submit');
    expect(journey.next?.stageId, 9);
    expect(journey.preselection?.published, isTrue);
    expect(journey.preselection?.selected, isTrue);
    expect(journey.preselection?.entry?.likes, 12);
    final stage = journey.phases.single.stages.single;
    expect(stage.canSubmit, isTrue);
    expect(stage.rules?.summary, 'Vidéo · 3 min max · 150 Mo max');
    expect(stage.isGroup, isTrue);
    expect(stage.others.single.name, 'Bob');
  });
}
