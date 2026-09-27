import 'package:battlegame/core/network/resource.dart';
import 'package:battlegame/core/theme/app_theme.dart';
import 'package:battlegame/core/utils/labels.dart';
import 'package:battlegame/core/widgets/hold_to_vote.dart';
import 'package:battlegame/features/battles/data/battles.dart';
import 'package:battlegame/features/battles/presentation/battles_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  test('shuffles competitions and groups, the groups still to vote in first', () {
    Map<String, dynamic> battle(int id, String slug, {int? myVote}) => {
      'id': id,
      'is_group': true,
      'title': 'Poule $id',
      'competition': {'id': 1, 'slug': slug, 'name': slug},
      'my_vote': myVote,
      'artists': <dynamic>[],
    };
    final open = BattleBoard.fromJson({
      'data': [
        for (var i = 1; i <= 5; i++) battle(i, 'a', myVote: i == 1 ? 10 : null),
        for (var i = 6; i <= 8; i++) battle(i, 'b'),
        battle(9, 'c'),
      ],
    }).open;

    final draw = shuffleBattles(open, 7);
    expect(draw.expand((c) => c).map((b) => b.id).toSet(), {1, 2, 3, 4, 5, 6, 7, 8, 9});
    expect(draw.firstWhere((c) => c.first.competitionSlug == 'a').last.id, 1); // Already voted: last.
    expect(shuffleBattles(open, 7).map((c) => c.first.competitionSlug), draw.map((c) => c.first.competitionSlug)); // Same seed, same draw.

    final firstCompetitions = {for (var seed = 0; seed < 30; seed++) shuffleBattles(open, seed).first.first.competitionSlug};
    final firstGroupsOfA = {for (var seed = 0; seed < 30; seed++) shuffleBattles(open, seed).firstWhere((c) => c.first.competitionSlug == 'a').first.id};
    expect(firstCompetitions.length, greaterThan(1));
    expect(firstGroupsOfA.length, greaterThan(1));
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

  testWidgets('one page per competition: a swipe moves to the next, « Poule suivante » to another group', (tester) async {
    Map<String, dynamic> group(int id, String slug, String title, int artists) => {
      'id': id,
      'is_group': true,
      'title': title,
      'competition': {'id': id, 'slug': slug, 'name': 'Compétition $slug'},
      'artists': [
        for (var i = 0; i < artists; i++) {'participant_id': id * 10 + i, 'stage_name': 'Artiste $id-$i', 'media': null},
      ],
    };
    final board = BattleBoard.fromJson({
      'data': [group(1, 'a', 'Poule A', 3), group(2, 'a', 'Poule B', 4), group(3, 'b', 'Poule A', 8)],
    });

    // A draw where competition « a » comes first.
    final seed = [for (var i = 0; i < 100; i++) i].firstWhere((s) => shuffleBattles(board.open, s).first.first.competitionSlug == 'a');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          battlesProvider.overrideWith((ref) => Stream.value(Resource(data: board))),
          battleShuffleProvider.overrideWith((ref) => seed),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: BattlesView(visible: false))),
      ),
    );
    await tester.pumpAndSettle();

    // Competition « a »: one of its two groups, then the other one.
    expect(find.text('Compétition a'), findsOneWidget);
    expect(find.text('2 poules en vote'), findsOneWidget);
    final firstShown = find.text('Artiste 1-0').evaluate().isNotEmpty ? 1 : 2;
    await tester.tap(find.text('Poule suivante'));
    await tester.pumpAndSettle();
    expect(find.text('Artiste ${firstShown == 1 ? 2 : 1}-0'), findsOneWidget);
    expect(find.text('Programme complet'), findsOneWidget);

    // A swipe from the middle of the grid moves to the next competition; a big group fits on the page.
    await tester.fling(find.textContaining('Artiste ').first, const Offset(0, -500), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Compétition b'), findsOneWidget);
    expect(find.text('Poule suivante'), findsNothing);
    expect(find.text('Artiste 3-7').hitTestable(), findsOneWidget);
  });
}
