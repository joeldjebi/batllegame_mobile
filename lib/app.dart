import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class BattleGameApp extends ConsumerWidget {
  const BattleGameApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts the offline queue (it listens to the network and the session).
    ref.watch(outboxProvider);

    return MaterialApp.router(
      title: Env.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fan(),
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.fan(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
