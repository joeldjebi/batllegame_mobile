import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/storage/database.dart';

/// Notes given by the judge and still waiting for the network (kept on the phone):
/// the lists show them « en attente d'envoi », the entry stays read-only. Removed
/// once the server confirms; on a refusal, removed and the reason kept for the UI.
class PendingScores extends StateNotifier<Map<String, Map<int, double>>> {
  PendingScores({required AppDatabase db, required Outbox outbox}) : _db = db, _outbox = outbox, super(const {}) {
    _subscription = _outbox.results.listen(_onResult);
    unawaited(_load());
  }

  final AppDatabase _db;
  final Outbox _outbox;
  late final StreamSubscription<OutboxResult> _subscription;

  /// Queued action id → pending key.
  Map<String, String> _actions = {};

  /// Last refusal (« note déjà enregistrée », deliberation closed…), for a toast.
  ApiException? lastError;

  /// Notes the server accepted during this session: the screens stay read-only
  /// even if their cached copy predates them.
  final Map<String, Map<int, double>> confirmed = {};

  static const String _storeKey = 'jury_pending_scores';

  static String entryKey(String slug, int entryId) => 'pre:$slug:$entryId';

  static String matchKey(String slug, int matchId, int participantId) => 'match:$slug:$matchId:$participantId';

  Future<void> _load() async {
    final raw = await _db.readValue(_storeKey);
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _actions = (json['actions'] as Map<String, dynamic>).cast<String, String>();
    state = {
      for (final e in (json['scores'] as Map<String, dynamic>).entries)
        e.key: {for (final s in (e.value as Map<String, dynamic>).entries) int.parse(s.key): (s.value as num).toDouble()},
    };
  }

  Future<void> _save() => _db.writeValue(_storeKey, jsonEncode({
        'actions': _actions,
        'scores': {for (final e in state.entries) e.key: {for (final s in e.value.entries) '${s.key}': s.value}},
      }));

  /// Queues the notes (sent in order with an Idempotency-Key) and shows them at once.
  Future<void> submit({required String key, required String path, required Map<String, dynamic> body, required Map<int, double> scores, required String label}) async {
    state = {...state, key: scores};
    final id = await _outbox.enqueue(method: 'POST', path: path, body: body, label: label);
    _actions = {..._actions, id: key};
    await _save();
  }

  void _onResult(OutboxResult result) {
    final key = _actions[result.id];
    if (key == null) return;
    _actions = {..._actions}..remove(result.id);
    if (result.succeeded) {
      final scores = state[key];
      if (scores != null) confirmed[key] = scores;
    } else {
      lastError = result.error;
    }
    state = {...state}..remove(key);
    unawaited(_save());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
