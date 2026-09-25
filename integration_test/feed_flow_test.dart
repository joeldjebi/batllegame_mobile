import 'package:battlegame/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Real app against a local backend: the feed, a swipe, a competition, a match,
/// Discover. Prints « SHOT:name » where a screenshot is worth taking.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 3]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    debugPrint('SHOT:$name');
    await settle(tester, 3);
  }

  testWidgets('feed, competition, match, discover', (tester) async {
    await app.main();
    await settle(tester, 8);
    await shot(tester, 'feed-1');

    await tester.fling(find.byType(PageView), const Offset(0, -500), 1500);
    await settle(tester, 4);
    await shot(tester, 'feed-2');

    // Competition chip of the current performance.
    await tester.tap(find.byIcon(Icons.emoji_events_outlined).last);
    await settle(tester, 4);
    await shot(tester, 'competition');

    await tester.tap(find.text('Phases'));
    await settle(tester, 3);
    await shot(tester, 'phases');

    final matchCards = find.text('Poule A');
    if (matchCards.evaluate().isNotEmpty) {
      await tester.tap(matchCards.first);
      await settle(tester, 4);
      await shot(tester, 'match');
      await tester.tap(find.byType(BackButton).first);
      await settle(tester, 2);
    }

    await tester.tap(find.byType(BackButton).first);
    await settle(tester, 2);
    await tester.tap(find.text('Découvrir').last);
    await settle(tester, 4);
    await shot(tester, 'discover');
  });
}
