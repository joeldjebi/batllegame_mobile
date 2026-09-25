import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../features/auth/data/models.dart';
import '../features/auth/data/session.dart';
import 'network/api_client.dart';
import 'network/resource.dart';
import 'offline/network_status.dart';
import 'offline/outbox.dart';
import 'storage/database.dart';
import 'storage/token_store.dart';

/// Composition root: every service of the app, overridable in tests.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final networkStatusProvider = StateNotifierProvider<NetworkStatus, bool>((ref) => NetworkStatus());

final StateNotifierProvider<SessionController, SessionState> sessionProvider = StateNotifierProvider(
  (ref) => SessionController(
    api: () => ref.read(apiClientProvider),
    tokens: ref.read(tokenStoreProvider),
    db: ref.read(databaseProvider),
  ),
);

final currentUserProvider = Provider<User?>((ref) => ref.watch(sessionProvider).user);

String? _deviceId;

final Provider<ApiClient> apiClientProvider = Provider((ref) {
  final db = ref.read(databaseProvider);
  return ApiClient(
    db: db,
    tokens: ref.read(tokenStoreProvider),
    account: () => ref.read(sessionProvider.notifier).account,
    deviceId: () async {
      if (_deviceId != null) return _deviceId!;
      final stored = await db.readValue('device_id');
      if (stored != null) return _deviceId = stored;
      final created = const Uuid().v4();
      await db.writeValue('device_id', created);
      return _deviceId = created;
    },
    onUnauthorized: () => ref.read(sessionProvider.notifier).expire(),
    onReachability: (reachable) => ref.read(networkStatusProvider.notifier).reportServer(reachable),
  );
});

final outboxProvider = Provider<Outbox>((ref) {
  final outbox = Outbox(
    db: ref.read(databaseProvider),
    api: ref.read(apiClientProvider),
    account: () => ref.read(sessionProvider.notifier).account,
  );
  // Back online or new account: send what waits.
  ref.listen<bool>(networkStatusProvider, (previous, online) {
    if (online && previous == false) outbox.flush(force: true);
  });
  ref.listen<SessionState>(sessionProvider, (_, _) => outbox.flush());
  ref.onDispose(outbox.dispose);
  return outbox;
});

/// Actions waiting for the network (offline banner, profile).
final pendingActionsProvider = StreamProvider<int>(
  (ref) => ref.watch(outboxProvider).watch().map((actions) => actions.where((a) => a.state == 'pending').length),
);

final countriesProvider = StreamProvider<Resource<List<Country>>>(
  (ref) => watchResource(
    ref.watch(apiClientProvider),
    '/countries',
    (json) => ((json! as Map<String, dynamic>)['data'] as List<dynamic>)
        .map((c) => Country.fromJson(c as Map<String, dynamic>))
        .toList(),
  ),
);
