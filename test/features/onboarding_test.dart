import 'package:battlegame/core/providers.dart';
import 'package:battlegame/core/theme/app_theme.dart';
import 'package:battlegame/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers.dart';

/// The animations loop (Lottie): pumpAndSettle would never return.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the welcome screens, the favorite disciplines, then remembered as done', (tester) async {
    final db = memoryDatabase();
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    container.read(onboardedProvider.notifier).state = false;
    final router = GoRouter(
      initialLocation: '/bienvenue',
      routes: [
        GoRoute(path: '/bienvenue', builder: (_, _) => const OnboardingScreen()),
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Accueil'))),
      ],
    );

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
    await settle(tester);
    expect(find.text('Des battles, votées par le public'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Suivant'));
      await settle(tester);
    }
    expect(find.text('Ce que tu aimes'), findsOneWidget);
    await tester.tap(find.text('Rap'));
    await settle(tester);
    expect(container.read(favoriteDisciplinesProvider), {'rap'});

    await tester.tap(find.text('C\'est parti'));
    await settle(tester);
    expect(find.text('Accueil'), findsOneWidget);
    expect(container.read(onboardedProvider), isTrue);
    expect(await db.readValue('onboarded'), isNotNull);
    expect(await db.readValue('favorite_disciplines'), 'rap');
    // Asked on the welcome screens, never again at sign-in.
    expect(await db.readValue('notifications_asked'), isNotNull);
  });
}
