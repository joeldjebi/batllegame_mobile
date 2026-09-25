import 'dart:io';

import 'package:battlegame/core/offline/uploads.dart';
import 'package:battlegame/core/providers.dart';
import 'package:battlegame/core/theme/app_icons.dart';
import 'package:battlegame/features/artist/presentation/journey_screen.dart';
import 'package:battlegame/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// Real app against a local backend: an artist registers, pays, opens the journey
/// and sends a performance with the background uploader.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    debugPrint('SHOT:$name');
    await settle(tester, 3);
  }

  testWidgets('register, pay, journey, upload', (tester) async {
    const slug = 'test-app-mobile';
    await app.main();
    await settle(tester, 4);

    await signIn(tester, '0799000003', '12345678');

    await tester.tap(find.text('Découvrir').last);
    await settle(tester, 3);
    await tester.tap(find.text('Test App Mobile'));
    await settle(tester, 4);
    if (find.text('Participer').evaluate().isNotEmpty) {
      await tester.tap(find.text('Participer'));
      await settle(tester, 2);
      await shot(tester, 'register');
      await tester.tap(find.text('Continuer vers le paiement'));
      await settle(tester, 4);
      await shot(tester, 'payment');
      await tester.tap(find.textContaining('Payer 500'));
      await settle(tester, 5);
    } else {
      await tester.tap(find.text('Mon parcours'));
      await settle(tester, 4);
    }
    await shot(tester, 'journey-before');

    // A real background upload of a 10 s video.
    final container = ProviderScope.containerOf(tester.element(find.byType(JourneyScreen)));
    final file = File('${Directory.systemTemp.path}/take.mp4');
    final request = await HttpClient().getUrl(Uri.parse('http://127.0.0.1:8001/storage/test-upload.mp4'));
    await (await request.close()).pipe(file.openWrite());
    await container
        .read(uploadsProvider.notifier)
        .send(file: file, path: '/competitions/$slug/preselection/submission', target: 'preselection:$slug', label: 'Présélection · Test App Mobile');
    await settle(tester, 1);
    await shot(tester, 'uploading');

    for (var i = 0; i < 60 && !container.read(uploadsProvider).values.any((u) => u.phase == UploadPhase.done || u.phase == UploadPhase.failed); i++) {
      await settle(tester, 1);
    }
    final upload = container.read(uploadsProvider).values.last;
    debugPrint('UPLOAD ${upload.phase} ${upload.error ?? ''}');
    expect(upload.phase, UploadPhase.done);

    // The server checks and optimizes it (queue), then the journey shows its status.
    // The journey polls while the server checks it (no manual refresh).
    for (var i = 0; i < 30 && find.text('En attente de validation').evaluate().isEmpty; i++) {
      await settle(tester, 1);
    }
    await shot(tester, 'journey-after');
    expect(find.text('En attente de validation'), findsOneWidget);

    // The « + » tab and the profile editor.
    await tester.tap(find.byType(BackButton).first);
    await settle(tester, 2);
    await tester.tap(find.byType(BackButton).first);
    await settle(tester, 2);
    await tester.tap(find.byIcon(AppIcons.create));
    await settle(tester, 3);
    await shot(tester, 'my-competitions');
    await tester.tap(find.text('Profil'));
    await settle(tester, 2);
    await tester.tap(find.text('Modifier mon profil'));
    await settle(tester, 2);
    await shot(tester, 'edit-profile');
  });
}
