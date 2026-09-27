import 'package:battlegame/core/network/resource.dart';
import 'package:battlegame/core/offline/network_status.dart';
import 'package:battlegame/core/providers.dart';
import 'package:battlegame/core/theme/app_theme.dart';
import 'package:battlegame/core/widgets/grouped_list.dart';
import 'package:battlegame/features/artists/data/artists.dart';
import 'package:battlegame/features/artists/presentation/artist_screen.dart';
import 'package:battlegame/features/battles/data/battles.dart';
import 'package:battlegame/features/battles/presentation/battles_view.dart';
import 'package:battlegame/features/competitions/data/models.dart';
import 'package:battlegame/features/competitions/data/providers.dart';
import 'package:battlegame/features/competitions/presentation/discover_screen.dart';
import 'package:battlegame/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';

/// Tap targets (48 px Android, 44 pt iOS), a label on every button (VoiceOver,
/// TalkBack) and text contrast, on the main screens; then the same screens with the
/// largest text on a small phone (any overflow fails).
Future<void> checkGuidelines(WidgetTester tester, Widget screen, {List<Override> overrides = const [], ThemeData? theme, bool bigText = false}) async {
  final handle = tester.ensureSemantics();
  if (bigText) {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(memoryDatabase()),
        networkStatusProvider.overrideWith((ref) => NetworkStatus(changes: const Stream.empty())),
        ...overrides,
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        builder: bigText
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              )
            : null,
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  if (!bigText) {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }
  await tester.pumpWidget(const SizedBox());
  handle.dispose();
}

const _competition = CompetitionSummary(
  slug: 'rap',
  name: 'Rap & Chant Battle Abidjan',
  status: 'inscriptions',
  discipline: 'rap',
  entryFee: 500,
  currency: 'XOF',
  registrationOpen: true,
  organizerName: 'Abidjan Urban Music',
);

final _artist = ArtistProfile.fromJson({
  'participant_id': 7,
  'stage_name': 'Maestro K le Magnifique',
  'avatar_url': null,
  'followers_count': 1250,
  'following': false,
  'is_me': false,
  'performances_count': 3,
  'participations': [
    {
      'participant_id': 7,
      'stage_name': 'Maestro K',
      'status': 'valide',
      'status_label': 'Validé',
      'competition': {'slug': 'rap', 'name': 'Rap & Chant Battle Abidjan', 'discipline': 'rap', 'status': 'en_cours', 'organizer': 'Abidjan Urban Music'},
    },
  ],
});

final _board = BattleBoard.fromJson({
  'data': [
    {
      'id': 1,
      'is_group': true,
      'title': 'Poule A',
      'stage': 'Poules',
      'voting_closes_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'competition': {'id': 1, 'slug': 'rap', 'name': 'Rap & Chant Battle Abidjan', 'discipline': 'rap'},
      'artists': [
        for (var i = 0; i < 4; i++) {'participant_id': 10 + i, 'stage_name': 'Artiste $i', 'media': null},
      ],
    },
    {
      'id': 2,
      'is_group': true,
      'title': 'Poule B',
      'competition': {'id': 1, 'slug': 'rap', 'name': 'Rap & Chant Battle Abidjan', 'discipline': 'rap'},
      'artists': [
        for (var i = 0; i < 3; i++) {'participant_id': 20 + i, 'stage_name': 'Artiste B$i', 'media': null},
      ],
    },
  ],
});

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  // Dark appearance: the same contrast rules.
  testWidgets(
    'Découvrir rows · dark',
    (tester) => checkGuidelines(
      tester,
      Builder(
        builder: (context) => Scaffold(
          backgroundColor: groupedBackground(context),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              GroupedSection(children: [CompetitionCard(competition: _competition)]),
            ],
          ),
        ),
      ),
      theme: AppTheme.dark(),
    ),
  );

  testWidgets(
    'artist page · dark',
    (tester) => checkGuidelines(
      tester,
      const ArtistScreen(participantId: 7),
      theme: AppTheme.dark(),
      overrides: [artistProvider.overrideWith((ref, id) async => _artist), artistVideosProvider.overrideWith((ref, id) async => const [])],
    ),
  );

  for (final bigText in [false, true]) {
    final mode = bigText ? 'with the largest text' : 'guidelines';

    testWidgets('onboarding · $mode', (tester) => checkGuidelines(tester, const OnboardingScreen(), bigText: bigText));

    testWidgets(
      'Découvrir rows · $mode',
      (tester) => checkGuidelines(
        tester,
        Builder(
          builder: (context) => Scaffold(
            backgroundColor: groupedBackground(context),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                GroupedSection(children: [CompetitionCard(competition: _competition)]),
              ],
            ),
          ),
        ),
        bigText: bigText,
      ),
    );

    testWidgets(
      'Découvrir with its carousels · $mode',
      (tester) => checkGuidelines(
        tester,
        const DiscoverScreen(),
        overrides: [
          competitionsProvider.overrideWith(
            (ref, status) => Stream.value(
              Resource(
                data: (
                  items: [
                    CompetitionSummary(
                      slug: 'rap',
                      name: 'Rap & Chant Battle Abidjan',
                      status: 'inscriptions',
                      discipline: 'rap',
                      entryFee: 500,
                      currency: 'XOF',
                      registrationOpen: true,
                      registrationEndsAt: DateTime.now().add(const Duration(days: 3)),
                      organizerName: 'Abidjan Urban Music',
                      participantsCount: 8,
                      maxParticipants: 20,
                      topPrize: const Prize('1er prix', '500 000 XOF'),
                    ),
                  ],
                  page: 1,
                  lastPage: 1,
                ),
              ),
            ),
          ),
          battlesProvider.overrideWith((ref) => Stream.value(Resource(data: _board))),
        ],
        bigText: bigText,
      ),
    );

    testWidgets(
      'artist page · $mode',
      (tester) => checkGuidelines(
        tester,
        const ArtistScreen(participantId: 7),
        overrides: [artistProvider.overrideWith((ref, id) async => _artist), artistVideosProvider.overrideWith((ref, id) async => const [])],
        bigText: bigText,
      ),
    );

    testWidgets(
      'Battles page · $mode',
      (tester) => checkGuidelines(
        tester,
        const Scaffold(backgroundColor: Colors.black, body: BattlesView(visible: false)),
        theme: AppTheme.dark(),
        overrides: [battlesProvider.overrideWith((ref) => Stream.value(Resource(data: _board)))],
        bigText: bigText,
      ),
    );
  }
}
