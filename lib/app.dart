import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/activity/data/providers.dart';

final _messenger = GlobalKey<ScaffoldMessengerState>();

class BattleGameApp extends ConsumerStatefulWidget {
  const BattleGameApp({super.key});

  @override
  ConsumerState<BattleGameApp> createState() => _BattleGameAppState();
}

class _BattleGameAppState extends ConsumerState<BattleGameApp> {
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    // Starts the offline queue (it listens to the network and the session).
    ref.read(outboxProvider);
    final hub = ref.read(activityHubProvider);
    unawaited(hub.start());
    // A realtime message while the app is open: a banner that opens its screen.
    _subscriptions.add(hub.banners.listen((banner) {
      _messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(banner.message),
          duration: const Duration(seconds: 5),
          action: banner.link == null ? null : SnackBarAction(label: 'Voir', onPressed: () => ref.read(routerProvider).push(banner.link!)),
        ));
    }));
    // A tapped notification (app in background or closed): its screen.
    _subscriptions.add(ref.read(localNotifierProvider).taps.listen((link) => ref.read(routerProvider).push(link)));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: Env.appName,
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messenger,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ref.watch(themeModeProvider),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: ref.watch(routerProvider),
        // Status bar icons readable on every screen (the video feed sets its own).
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).brightness == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
          child: child!,
        ),
      );
}
