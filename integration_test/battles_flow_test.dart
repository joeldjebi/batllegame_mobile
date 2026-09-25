import 'package:battlegame/core/widgets/hold_to_vote.dart';
import 'package:battlegame/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// Real app against a local backend with open votes: the Battles tab (duel, group),
/// then a signed-in fan votes in the duel by holding the button.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    debugPrint('SHOT:$name');
    await settle(tester, 3);
  }

  testWidgets('battles: duel, group, hold to vote', (tester) async {
    await app.main();
    await settle(tester, 5);
    await shot(tester, 'home-pour-toi');

    await tester.tap(find.text('Battles'));
    await waitFor(tester, find.text('VS'));
    await settle(tester, 4);
    await shot(tester, 'duel');

    // Listen to the second artist.
    await tester.tapAt(tester.getCenter(find.byType(Scaffold).first) + const Offset(0, 200));
    await settle(tester, 3);
    await shot(tester, 'duel-second');

    await tester.fling(find.byType(PageView).first, const Offset(0, -500), 1500);
    await settle(tester, 4);
    await shot(tester, 'group');

    await signIn(tester, '0799000001', '12345678');
    await tester.tap(find.text('Accueil'));
    await settle(tester, 2);
    await tester.tap(find.text('Battles'));
    await waitFor(tester, find.text('VS'));
    await settle(tester, 3);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToVote).first));
    await settle(tester, 1);
    await gesture.up();
    await settle(tester, 4);
    await shot(tester, 'voted');
    expect(find.text('Ton vote'), findsOneWidget);
  });
}
