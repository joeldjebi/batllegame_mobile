import 'package:battlegame/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Real app against a local backend: sign in (verified demo artist), like the
/// first performance of the feed, see the heart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 3]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('sign in and like', (tester) async {
    await app.main();
    await settle(tester, 4);

    await tester.tap(find.text('Profil'));
    await settle(tester, 1);
    await tester.tap(find.text('Se connecter').last);
    await settle(tester, 2);
    await tester.enterText(find.byType(TextField).at(0), '0799000001');
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 1);
    await tester.tap(find.text('Se connecter').last);
    await settle(tester, 4);

    await tester.tap(find.text('Accueil'));
    await settle(tester, 5);
    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await settle(tester, 4);
    debugPrint('SHOT:liked');
    await settle(tester, 3);

    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
  });
}
