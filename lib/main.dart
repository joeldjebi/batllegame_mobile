import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  // A vertical feed app: portrait only.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // The session opens from the vault + the cached profile: no network needed to start.
  final container = ProviderContainer();
  await container.read(sessionProvider.notifier).restore();
  // Uploads sent before the app was closed come back (does not delay the start).
  unawaited(container.read(uploadsProvider.notifier).start().catchError((Object _) {}));

  runApp(UncontrolledProviderScope(container: container, child: const BattleGameApp()));
}
