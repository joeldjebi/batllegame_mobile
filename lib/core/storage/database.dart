import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Last good response of each API read, revalidated with its ETag (304 = unchanged).
/// Key: account + method + URL, so two accounts on one phone never share data.
class HttpCacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get etag => text().nullable()();
  TextColumn get body => text()();
  DateTimeColumn get storedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Writes waiting for the network (likes, votes, scores…), sent in order with
/// their id as Idempotency-Key: a replay never counts twice.
class OutboxActions extends Table {
  TextColumn get id => text()();
  TextColumn get account => text()();
  TextColumn get method => text()();
  TextColumn get path => text()();
  TextColumn get body => text().nullable()();

  /// What the user sees in the queue (« Like · Artiste X »).
  TextColumn get label => text()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Notifications of the account (Activité tab), kept offline.
class ActivityItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get account => text()();
  TextColumn get type => text()();
  TextColumn get message => text()();

  /// Screen to open (go_router location), when there is one.
  TextColumn get link => text().nullable()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Small persistent values (device id, cached profile).
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [HttpCacheEntries, OutboxActions, KeyValues, ActivityItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'battlegame'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(activityItems);
        },
      );

  Future<String?> readValue(String key) =>
      (select(keyValues)..where((t) => t.key.equals(key))).map((row) => row.value).getSingleOrNull();

  Future<void> writeValue(String key, String value) =>
      into(keyValues).insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: value));

  Future<void> deleteValue(String key) => (delete(keyValues)..where((t) => t.key.equals(key))).go();

  /// Everything cached for an account (sign-out, account switch).
  Future<void> forgetAccount(String account) async {
    await (delete(httpCacheEntries)..where((t) => t.key.like('$account|%'))).go();
    await (delete(outboxActions)..where((t) => t.account.equals(account))).go();
    await (delete(activityItems)..where((t) => t.account.equals(account))).go();
  }
}
