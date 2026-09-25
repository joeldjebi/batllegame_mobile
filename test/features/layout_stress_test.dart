import 'package:battlegame/core/network/resource.dart';
import 'package:battlegame/core/notifications/local_notifier.dart';
import 'package:battlegame/core/offline/network_status.dart';
import 'package:battlegame/core/providers.dart';
import 'package:battlegame/core/theme/app_theme.dart';
import 'package:battlegame/features/artist/data/models.dart';
import 'package:battlegame/features/artist/data/providers.dart';
import 'package:battlegame/features/artist/presentation/journey_screen.dart';
import 'package:battlegame/features/auth/data/models.dart';
import 'package:battlegame/features/auth/presentation/login_screen.dart';
import 'package:battlegame/features/auth/presentation/register_screen.dart';
import 'package:battlegame/features/competitions/data/models.dart';
import 'package:battlegame/features/competitions/presentation/discover_screen.dart';
import 'package:battlegame/features/jury/data/models.dart';
import 'package:battlegame/features/jury/presentation/jury_scope.dart';
import 'package:battlegame/features/jury/presentation/score_form.dart';
import 'package:battlegame/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Every key screen on a small phone (320 pt wide) with the largest text size:
/// Flutter reports any overflow as a test failure.
const _ci = Country(id: 1, name: "Côte d'Ivoire", iso2: 'CI', dialCode: '+225', flag: '');

final _journey = Journey.fromJson({
  'data': {
    'competition': {'slug': 'abidjan-rap-2026', 'name': 'Abidjan Rap 2026 — Grande finale nationale'},
    'participant': {'stage_name': 'Kaaris Junior le Magnifique', 'status': 'valide', 'paid': true},
    'out': false,
    'champion': false,
    'next': {'type': 'submit', 'text': 'Envoie ta prestation avant la date limite, sinon forfait.', 'stage': 'Demi-finales', 'deadline': '2026-10-01T18:00:00+00:00', 'stage_id': 9},
    'preselection': {
      'state': 'publiee',
      'ends_at': '2026-09-20T18:00:00+00:00',
      'selection_size': 16,
      'can_submit': false,
      'media_rules': {'types': ['video'], 'max_duration_seconds': 150, 'max_size_mb': 200},
      'entry': {'id': 4, 'status': 'validee', 'likes': 1234, 'media': {'type': 'video'}},
      'result': {'selected': true, 'rank': 3},
    },
    'phases': [
      {
        'title': 'Phase 2 · Élimination simple',
        'state': 'current',
        'online': true,
        'stages': [
          {
            'id': 9,
            'name': 'Demi-finales',
            'state': 'current',
            'label': 'Prestation refusée : renvoie-la',
            'dates': {'submission': '2026-10-01T18:00:00+00:00', 'voting_closes': '2026-10-03T18:00:00+00:00'},
            'action': {'type': 'submit', 'text': '…'},
            'media_rules': {'types': ['video'], 'max_duration_seconds': 180, 'max_size_mb': 150},
            'match': {'id': 21, 'is_group': false, 'title': 'A vs B', 'others': [{'stage_name': 'Lady Kpakpato la Reine du Flow', 'avatar_url': null}], 'my_score': 87.5},
            'submission': {'id': 7, 'status': 'rejetee', 'rejection_reason': 'Le son est saturé et la vidéo coupe avant la fin du morceau.', 'media': {'type': 'video'}},
          },
        ],
      },
    ],
  },
});

/// No platform notifications in widget tests.
class _SilentNotifier extends LocalNotifier {
  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> schedule({required int id, required DateTime when, required String title, required String body, String? link}) async {}
}

Future<void> pumpStressed(WidgetTester tester, Widget screen, {List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(320 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      countriesProvider.overrideWith((ref) => Stream.value(const Resource(data: [_ci]))),
      networkStatusProvider.overrideWith((ref) => NetworkStatus(changes: const Stream.empty())),
      pendingActionsProvider.overrideWith((ref) => Stream.value(0)),
      localNotifierProvider.overrideWithValue(_SilentNotifier()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
      home: screen,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  // Let the screen's own timers (countdowns, retries) run out before the next test.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('login', (tester) => pumpStressed(tester, const LoginScreen()));

  testWidgets('register', (tester) => pumpStressed(tester, const RegisterScreen()));

  testWidgets('journey', (tester) => pumpStressed(
        tester,
        const JourneyScreen(slug: 'abidjan-rap-2026'),
        overrides: [journeyProvider.overrideWith((ref, slug) => Stream.value(Resource(data: _journey)))],
      ));

  testWidgets('competition card', (tester) => pumpStressed(
        tester,
        Scaffold(
          body: ListView(children: const [
            CompetitionCard(
              competition: CompetitionSummary(
                slug: 's',
                name: 'Abidjan Rap 2026 — Grande finale nationale des talents',
                status: 'inscriptions',
                discipline: 'freestyle',
                entryFee: 25000,
                currency: 'XOF',
                registrationOpen: true,
                organizerName: 'Yop City Battle Organisation Officielle',
              ),
            ),
          ]),
        ),
      ));

  testWidgets('settings', (tester) => pumpStressed(tester, const SettingsScreen()));

  testWidgets('jury score form', (tester) => pumpStressed(
        tester,
        JuryScope(
          child: Scaffold(
            body: ListView(children: [
              ScoreForm(
                criteria: const [Criterion(id: 1, name: 'Présence scénique et charisme', maxPoints: 10), Criterion(id: 2, name: 'Texte', maxPoints: 20)],
                values: const {1: 7.5, 2: 18},
                onChanged: (_, _) {},
              ),
            ]),
          ),
        ),
      ));
}
