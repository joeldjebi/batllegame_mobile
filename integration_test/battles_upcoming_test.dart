import 'package:battlegame/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// Real app against a local backend with open votes and a stage in submissions:
/// after the open battles, the last page lists what comes next and when.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('battles: upcoming after the open votes', (tester) async {
    await app.main();
    await settle(tester, 5);

    await tester.tap(find.text('Battles'));
    await waitFor(tester, find.text('VS'));
    await settle(tester, 3);

    for (var i = 0; i < 4 && find.text('À venir').evaluate().isEmpty; i++) {
      // From the header: a group page scrolls its own grid below it.
      await tester.flingFrom(const Offset(200, 150), const Offset(0, -500), 1500);
      await settle(tester, 3);
    }
    debugPrint('SHOT:upcoming');
    await settle(tester, 3);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.textContaining('Vote dans'), findsWidgets);
  });
}
