import 'package:battlegame/core/theme/app_icons.dart';
import 'package:battlegame/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// Real app against a local backend: sign in (verified demo artist), like the
/// first performance of the feed, see the heart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in and like', (tester) async {
    await app.main();
    await settle(tester, 4);

    await signIn(tester, '0799000001', '12345678');

    await tester.tap(find.text('Accueil'));
    await settle(tester, 5);
    await tester.tap(find.byIcon(AppIcons.like).first);
    await settle(tester, 4);
    debugPrint('SHOT:liked');
    await settle(tester, 3);

    expect(find.byIcon(AppIcons.liked), findsWidgets);
  });
}
