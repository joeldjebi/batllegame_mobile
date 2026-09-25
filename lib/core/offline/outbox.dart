import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../storage/database.dart';

/// Result of a queued action once the server answered.
class OutboxResult {
  const OutboxResult(this.id, {this.response, this.error});

  final String id;
  final ApiResponse? response;
  final ApiException? error;

  bool get succeeded => error == null;
}

/// Offline queue: writes (likes, votes, scores…) are stored, then sent in order
/// as soon as the server is reachable. Each action keeps its id as Idempotency-Key,
/// so a retry after a lost answer never counts twice. Transient failures (network,
/// 5xx) back off and retry; a refusal (4xx) is kept as failed for the user to see.
class Outbox {
  Outbox({required AppDatabase db, required ApiClient api, required String Function() account, DateTime Function()? clock})
    : _db = db,
      _api = api,
      _account = account,
      _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final ApiClient _api;
  final String Function() _account;
  final DateTime Function() _now;
  final _results = StreamController<OutboxResult>.broadcast();
  Timer? _timer;
  Future<void>? _current;
  bool _again = false;
  bool _forceNext = false;

  static const Duration _minDelay = Duration(seconds: 5);
  static const Duration _maxDelay = Duration(minutes: 5);

  Stream<OutboxResult> get results => _results.stream;

  /// Queues a write and tries to send it at once. Returns its id (Idempotency-Key).
  Future<String> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required String label,
  }) async {
    final id = const Uuid().v4();
    await _db
        .into(_db.outboxActions)
        .insert(
          OutboxActionsCompanion.insert(
            id: id,
            account: _account(),
            method: method,
            path: path,
            body: Value(body == null ? null : jsonEncode(body)),
            label: label,
            createdAt: _now(),
            nextAttemptAt: _now(),
          ),
        );
    unawaited(flush());
    return id;
  }

  /// Actions of the current account still waiting or refused.
  Stream<List<OutboxAction>> watch() =>
      (_db.select(_db.outboxActions)
            ..where((t) => t.account.equals(_account()))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<void> discard(String id) => (_db.delete(_db.outboxActions)..where((t) => t.id.equals(id))).go();

  /// Retry a refused action (after the user fixed the cause).
  Future<void> retry(String id) async {
    await (_db.update(_db.outboxActions)..where((t) => t.id.equals(id))).write(
      OutboxActionsCompanion(state: const Value('pending'), nextAttemptAt: Value(_now()), lastError: const Value(null)),
    );
    unawaited(flush());
  }

  /// Sends what is due, in order, and completes once done. A call during a run
  /// joins it and triggers one more pass (new actions are never left behind).
  Future<void> flush({bool force = false}) {
    _forceNext |= force;
    if (_current != null) {
      _again = true;
      return _current!;
    }
    return _current = _drain().whenComplete(() => _current = null);
  }

  Future<void> _drain() async {
    _timer?.cancel();
    do {
      _again = false;
      final force = _forceNext;
      _forceNext = false;
      await _sendDue(force);
    } while (_again);
    await _scheduleNext();
  }

  /// Stops at the first transient failure (keeps the order).
  Future<void> _sendDue(bool force) async {
    while (true) {
      // Strict order: the oldest pending action first; when it waits for its retry, so do the others.
      final action =
          await (_db.select(_db.outboxActions)
                ..where((t) => t.account.equals(_account()) & t.state.equals('pending'))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
                ..limit(1))
              .getSingleOrNull();
      if (action == null || (!force && action.nextAttemptAt.isAfter(_now()))) return;

      try {
        final response = await _api.send(
          action.method,
          action.path,
          data: action.body == null ? null : jsonDecode(action.body!),
          idempotencyKey: action.id,
        );
        await discard(action.id);
        _emit(OutboxResult(action.id, response: response));
      } on ApiException catch (error) {
        if (error.isTransient) {
          await _postpone(action, error);
          return;
        }
        if (error.kind == ApiErrorKind.unauthorized) return;
        await (_db.update(_db.outboxActions)..where((t) => t.id.equals(action.id))).write(
          OutboxActionsCompanion(state: const Value('failed'), lastError: Value(error.message)),
        );
        _emit(OutboxResult(action.id, error: error));
      }
    }
  }

  void _emit(OutboxResult result) {
    if (!_results.isClosed) _results.add(result);
  }

  Future<void> _postpone(OutboxAction action, ApiException error) async {
    final attempts = action.attempts + 1;
    final seconds = min(_maxDelay.inSeconds, _minDelay.inSeconds * pow(2, attempts - 1).toInt());
    await (_db.update(_db.outboxActions)..where((t) => t.id.equals(action.id))).write(
      OutboxActionsCompanion(
        attempts: Value(attempts),
        nextAttemptAt: Value(_now().add(Duration(seconds: seconds))),
        lastError: Value(error.message),
      ),
    );
  }

  Future<void> _scheduleNext() async {
    final next =
        await (_db.selectOnly(_db.outboxActions)
              ..addColumns([_db.outboxActions.nextAttemptAt.min()])
              ..where(_db.outboxActions.account.equals(_account()) & _db.outboxActions.state.equals('pending')))
            .map((row) => row.read(_db.outboxActions.nextAttemptAt.min()))
            .getSingleOrNull();
    if (next == null) return;
    final delay = next.difference(_now());
    _timer = Timer(delay.isNegative ? Duration.zero : delay, flush);
  }

  void dispose() {
    _timer?.cancel();
    _results.close();
  }
}
