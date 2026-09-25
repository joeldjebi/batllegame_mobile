import 'package:battlegame/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// Real app against a local backend: a judge opens the jury space, scores two
/// entries (final notes), sees the list move to « Notées ».
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    debugPrint('SHOT:$name');
    await settle(tester, 3);
  }

  Future<void> scoreCurrent(WidgetTester tester, List<int> plusTaps) async {
    final plus = find.byTooltip('Plus');
    for (var i = 0; i < plusTaps.length; i++) {
      for (var t = 0; t < plusTaps[i]; t++) {
        await tester.ensureVisible(plus.at(i));
        await tester.tap(plus.at(i));
        await tester.pump(const Duration(milliseconds: 60));
      }
    }
    await settle(tester, 1);
  }

  testWidgets('judge scores the pre-selection', (tester) async {
    await app.main();
    await settle(tester, 4);

    await signIn(tester, '0100000002', '12345678');

    await tester.tap(find.text('Profil'));
    await waitFor(tester, find.text('Ouvrir l\'espace jury'));
    await tester.tap(find.text('Ouvrir l\'espace jury'));
    await settle(tester, 4);
    await shot(tester, 'jury-home');

    await tester.tap(find.text('Test App Mobile'));
    await settle(tester, 1);
    final start = find.textContaining('la notation').first;
    await tester.ensureVisible(start);
    await tester.tap(start);
    await settle(tester, 4);
    await shot(tester, 'jury-list');

    await tester.tap(find.textContaining('la notation').first);
    await waitFor(tester, find.byTooltip('Plus'), count: 3);
    await settle(tester, 2);
    await scoreCurrent(tester, [15, 12, 16]);
    await shot(tester, 'jury-entry');

    await tester.tap(find.text('Valider et suivante'));
    await settle(tester, 1);
    await shot(tester, 'jury-confirm');
    await tester.tap(find.widgetWithText(FilledButton, 'Valider'));
    await settle(tester, 3);
    await waitFor(tester, find.byTooltip('Plus'), count: 3);
    await settle(tester, 2);
    await scoreCurrent(tester, [10, 10, 10]);
    await tester.tap(find.textContaining('Valider').last);
    await settle(tester, 1);
    await tester.tap(find.widgetWithText(FilledButton, 'Valider'));
    await settle(tester, 5);

    await tester.tap(find.byType(BackButton).first);
    await settle(tester, 4);
    await tester.tap(find.text('Notées'));
    await settle(tester, 4);
    await shot(tester, 'jury-scored');
    expect(find.textContaining('pts'), findsNWidgets(2));
  });
}
