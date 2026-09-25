import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/database.dart';
import 'activity_hub.dart';

final activityHubProvider = Provider<ActivityHub>((ref) {
  final hub = ActivityHub(ref);
  ref.onDispose(hub.dispose);
  return hub;
});

/// My notifications, newest first (kept offline).
final activityItemsProvider = StreamProvider.autoDispose<List<ActivityItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final account = ref.watch(sessionProvider.notifier).account;
  ref.watch(currentUserProvider);
  return (db.select(db.activityItems)
        ..where((t) => t.account.equals(account))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(100))
      .watch();
});

final unreadActivityProvider = Provider.autoDispose<int>((ref) => ref.watch(activityItemsProvider).valueOrNull?.where((i) => !i.read).length ?? 0);
