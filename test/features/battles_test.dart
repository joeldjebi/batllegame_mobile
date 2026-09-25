import 'package:battlegame/core/theme/app_theme.dart';
import 'package:battlegame/core/utils/labels.dart';
import 'package:battlegame/core/widgets/hold_to_vote.dart';
import 'package:battlegame/features/battles/data/battles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  test('reads a battle of the API (duel, my vote)', () {
    final battle = Battle.fromJson({
      'id': 5,
      'is_group': false,
      'title': 'Awa vs Bob',
      'stage': 'Demi-finales',
      'competition': {'id': 1, 'slug': 'abidjan', 'name': 'Abidjan Rap'},
      'voting_closes_at': '2026-10-01T18:00:00+00:00',
      'vote_code_required': false,
      'share_url': 'https://x/#match-5',
      'my_vote': 12,
      'voted_in_phase': false,
      'is_mine': false,
      'artists': [
        {
          'participant_id': 12,
          'stage_name': 'Awa',
          'media': {'id': 3, 'type': 'video', 'url': 'u', 'poster_url': 'p'},
        },
        {'participant_id': 13, 'stage_name': 'Bob', 'media': null},
      ],
    });

    expect(battle.isDuel, isTrue);
    expect(battle.myVote, 12);
    expect(battle.artists.first.mediaId, 3);
    expect(battle.artists.last.media, isNull);
  });

  test('reads the upcoming battles, and an older API without them', () {
    final board = BattleBoard.fromJson({
      'data': <dynamic>[],
      'upcoming': [
        {
          'id': 9,
          'is_group': true,
          'title': 'Poule A',
          'stage': 'Poules',
          'competition': {'id': 1, 'slug': 'abidjan', 'name': 'Abidjan Rap'},
          'voting_opens_at': '2026-10-01T18:00:00+00:00',
          'submissions_open': true,
          'is_mine': false,
          'artists': [
            {'participant_id': 12, 'stage_name': 'Awa', 'avatar_url': null},
          ],
        },
      ],
    });

    expect(board.open, isEmpty);
    expect(board.isEmpty, isFalse);
    expect(board.upcoming.single.submissionsOpen, isTrue);
    expect(board.upcoming.single.opensAt, DateTime.utc(2026, 10, 1, 18));
    expect(BattleBoard.fromJson({'data': <dynamic>[]}).isEmpty, isTrue);
  });

  test('says when a vote opens', () async {
    await initializeDateFormatting('fr');
    expect(Labels.voteOpens(DateTime.now().add(const Duration(minutes: 18, seconds: 30))), 'Vote dans 18 min');
    expect(Labels.voteOpens(DateTime.now().subtract(const Duration(seconds: 5))), 'Vote imminent');
    expect(Labels.voteOpens(DateTime.now().add(const Duration(days: 3))), startsWith('Vote le '));
  });

  testWidgets('votes only after holding, never on a quick tap', (tester) async {
    var votes = 0, hints = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: HoldToVote(label: 'Voter', onVote: () => votes++, onQuickTap: () => hints++),
            ),
          ),
        ),
      ),
    );

    final quick = await tester.startGesture(tester.getCenter(find.byType(HoldToVote)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await quick.up();
    await tester.pump(const Duration(seconds: 1));
    expect(votes, 0);
    expect(hints, 1); // « Maintiens le bouton appuyé pour voter ».

    final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToVote)));
    await tester.pump(); // First frame: the hold animation starts counting.
    await tester.pump(const Duration(milliseconds: 400));
    expect(votes, 0); // Not yet: still holding.
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    expect(votes, 1);
  });

  testWidgets('shows « Ton vote » and ignores holds once voted', (tester) async {
    var votes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: HoldToVote(label: 'Maintenir', voted: true, onVote: () => votes++),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ton vote'), findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToVote)));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    expect(votes, 0);
  });
}
