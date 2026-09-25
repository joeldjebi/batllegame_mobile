import 'package:battlegame/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Real app on a simulator against a local backend: sign in, open the profile.
/// Prints « SHOT:name » where a screenshot is worth taking (scratch tooling).
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

  testWidgets('sign in and see the profile', (tester) async {
    await app.main();
    await settle(tester);

    await tester.tap(find.text('Profil'));
    await settle(tester, 1);
    await tester.tap(find.text('Se connecter').last);
    await settle(tester, 2);

    await tester.enterText(find.byType(TextField).at(0), const String.fromEnvironment('PHONE', defaultValue: '0799000001'));
    await tester.enterText(find.byType(TextField).at(1), const String.fromEnvironment('PASSWORD', defaultValue: '12345678'));
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 1);
    await shot(tester, 'login-filled');

    await tester.tap(find.text('Se connecter').last);
    await settle(tester, 4);
    expect(find.text('Content de te revoir'), findsNothing); // signed in, back to the tabs
    await tester.tap(find.text('Profil'));
    await settle(tester, 3);
    await shot(tester, 'profile');

    await tester.tap(find.text('Activité'));
    await settle(tester, 1);
    await shot(tester, 'activity');

    expect(find.text('Se déconnecter'), findsNothing); // on the Activity tab
  });
}
