import 'package:battlegame/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// Real app + local backend + Socket.IO: the artist keeps the journey open while the
/// organizer refuses the performance (triggered from outside on « TRIGGER:reject »).
/// The banner, the new status and the Activité entry arrive without any refresh.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a refusal arrives live', (tester) async {
    await app.main();
    await settle(tester, 4);

    await signIn(tester, '0799000003', '12345678');

    await tester.tap(find.text('Découvrir').last);
    await waitFor(tester, find.text('Test App Mobile'));
    await tester.tap(find.text('Test App Mobile'));
    await waitFor(tester, find.text('Mon parcours'));
    await tester.tap(find.text('Mon parcours'));
    await waitFor(tester, find.text('Validée'));
    expect(find.text('Validée'), findsOneWidget);
    await settle(tester, 4); // socket connected and subscribed

    debugPrint('TRIGGER:reject');
    await waitFor(tester, find.text('Refusée'), seconds: 30);
    await settle(tester, 1);
    debugPrint('SHOT:live-refused');
    await settle(tester, 3);
    expect(find.text('Refusée'), findsOneWidget);
    expect(find.textContaining('Son trop faible'), findsWidgets);

    await tester.tap(find.byType(BackButton).first);
    await settle(tester, 2);
    await tester.tap(find.byType(BackButton).first);
    await settle(tester, 2);
    await tester.tap(find.text('Activité'));
    await settle(tester, 3);
    debugPrint('SHOT:activity');
    await settle(tester, 3);
    expect(find.textContaining('refusée'), findsWidgets);
  });
}
