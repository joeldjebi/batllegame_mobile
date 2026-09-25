import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/notifications/local_notifier.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/storage/database.dart';
import '../../artist/data/models.dart';
import '../../artist/data/providers.dart';
import '../../artist/data/reminders.dart';
import '../../auth/data/session.dart';
import '../../battles/data/battles.dart';
import '../../competitions/data/providers.dart';
import '../../jury/data/providers.dart';

/// Glue between the realtime signals and the app: reloads what changed (debounced),
/// keeps the personal messages in the Activité history, notifies when the app is in
/// background (a banner when it is open), and keeps the reminders up to date.
class ActivityHub {
  ActivityHub(this._ref);

  final Ref _ref;
  final _banners = StreamController<({String message, String? link})>.broadcast();
  final Map<String, Timer> _debounce = {};
  StreamSubscription<RealtimeEvent>? _events;
  bool _foreground = true;
  AppLifecycleListener? _lifecycle;

  /// Messages to show on top of the open app.
  Stream<({String message, String? link})> get banners => _banners.stream;

  RealtimeClient get _realtime => _ref.read(realtimeClientProvider);

  LocalNotifier get _notifier => _ref.read(localNotifierProvider);

  Future<void> start() async {
    _lifecycle = AppLifecycleListener(onStateChange: (state) => _foreground = state == AppLifecycleState.resumed);
    _events = _realtime.events.listen(_onEvent);
    await _notifier.init();
    _ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (previous?.user?.id != next.user?.id) unawaited(_restart(next));
    }, fireImmediately: true);
  }

  Future<void> _restart(SessionState session) async {
    _realtime.stop();
    final user = session.user;
    if (user == null) {
      await _realtime.start(signedIn: false);
      return;
    }
    await _askPermissionOnce();
    final private = <String>{};
    if (user.isJudge) {
      try {
        final json = (await _ref.read(apiClientProvider).get('/judge/competitions')).json;
        for (final c in (json['data'] as List<dynamic>)) {
          private.add('jury.competition.${(c as Map<String, dynamic>)['id']}');
        }
      } on ApiException {
        // Offline: the personal channel is enough until the next start.
      }
    }
    await _realtime.start(signedIn: true, privateChannels: private);
    unawaited(_syncReminders());
  }

  Future<void> _askPermissionOnce() async {
    final db = _ref.read(databaseProvider);
    if (await db.readValue('notifications_asked') != null) return;
    await db.writeValue('notifications_asked', DateTime.now().toIso8601String());
    await _notifier.requestPermission();
  }

  /// Reminders of my running competitions (their journey says what is due).
  Future<void> _syncReminders() async {
    final api = _ref.read(apiClientProvider);
    final scheduler = ReminderScheduler(_notifier);
    try {
      final list = (await api.get('/me/participations')).json['data'] as List<dynamic>;
      for (final raw in list) {
        final p = Participation.fromJson(raw as Map<String, dynamic>);
        if (p.competitionStatus == 'terminee' || p.competitionStatus == 'annulee') continue;
        final journey = Journey.fromJson((await api.get('/me/participations/${p.slug}')).json);
        await scheduler.sync(journey).catchError((Object _) {});
      }
    } on ApiException {
      // Offline: reminders already scheduled stay in place.
    }
  }

  void _onEvent(RealtimeEvent event) {
    // Reload what the signal is about (grouped: a burst of votes reloads once).
    if (event.competitionId != null) {
      _later('competition', () {
        _ref
          ..invalidate(competitionProvider)
          ..invalidate(phaseMatchesProvider)
          ..invalidate(matchProvider)
          ..invalidate(battlesProvider);
      });
    }
    if (event.isPersonal) {
      _later('personal', () {
        _ref
          ..invalidate(participationsProvider)
          ..invalidate(journeyProvider);
        unawaited(_syncReminders());
      });
    }
    if (event.isJury) {
      _later('jury', () {
        _ref
          ..invalidate(judgeCompetitionsProvider)
          ..invalidate(juryListProvider)
          ..invalidate(judgeMatchesProvider)
          ..invalidate(judgeMatchProvider)
          ..invalidate(juryEntryProvider);
      });
    }

    final message = event.message;
    if (message == null || !(event.isPersonal || event.isJury)) return;
    unawaited(_record(event, message));
  }

  Future<void> _record(RealtimeEvent event, String message) async {
    final link = await _linkFor(event);
    final db = _ref.read(databaseProvider);
    await db.into(db.activityItems).insert(ActivityItemsCompanion.insert(
          account: _ref.read(sessionProvider.notifier).account,
          type: event.type,
          message: message,
          link: Value(link),
          createdAt: DateTime.now(),
        ));
    if (_foreground) {
      _banners.add((message: message, link: link));
    } else {
      await _notifier.show(id: notificationId('${event.type}:${DateTime.now().millisecondsSinceEpoch}'), title: 'Battle Game', body: message, link: link);
    }
  }

  Future<String?> _linkFor(RealtimeEvent event) async {
    if (event.isJury) return '/jury';
    final id = event.competitionId;
    if (id == null) return '/activite';
    final participations = _ref.read(participationsProvider).valueOrNull?.data ?? const [];
    final slug = participations.where((p) => p.competitionId == id).firstOrNull?.slug;
    return slug == null ? '/publier' : '/competitions/$slug/parcours';
  }

  void _later(String group, VoidCallback run) {
    _debounce[group]?.cancel();
    _debounce[group] = Timer(const Duration(milliseconds: 800), run);
  }

  Future<void> markAllRead() async {
    final db = _ref.read(databaseProvider);
    await (db.update(db.activityItems)..where((t) => t.account.equals(_ref.read(sessionProvider.notifier).account))).write(const ActivityItemsCompanion(read: Value(true)));
  }

  void dispose() {
    _events?.cancel();
    _lifecycle?.dispose();
    for (final timer in _debounce.values) {
      timer.cancel();
    }
    _banners.close();
  }
}
