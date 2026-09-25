import 'package:battlegame/core/network/resource.dart';
import 'package:battlegame/core/offline/network_status.dart';
import 'package:battlegame/core/providers.dart';
import 'package:battlegame/core/theme/app_theme.dart';
import 'package:battlegame/features/auth/data/models.dart';
import 'package:battlegame/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ci = Country(id: 1, name: "Côte d'Ivoire", iso2: 'CI', dialCode: '+225', flag: '🇨🇮');

void main() {
  testWidgets('shows the errors under the fields and the country prefix', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countriesProvider.overrideWith((ref) => Stream.value(const Resource(data: [_ci]))),
          networkStatusProvider.overrideWith((ref) => NetworkStatus(changes: const Stream.empty())),
          pendingActionsProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: MaterialApp(theme: AppTheme.fan(), home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+225'), findsOneWidget);
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Saisis ton numéro.'), findsOneWidget);
    expect(find.text('Saisis ton mot de passe.'), findsOneWidget);
  });
}
