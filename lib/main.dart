import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // The session opens from the vault + the cached profile: no network needed to start.
  final container = ProviderContainer();
  await container.read(sessionProvider.notifier).restore();

  runApp(UncontrolledProviderScope(container: container, child: const BattleGameApp()));
}
