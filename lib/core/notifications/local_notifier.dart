import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Local notifications (no push service yet): instant ones for realtime events while
/// the app runs in background, and reminders scheduled on the phone (deadlines).
/// Scheduling uses an absolute UTC instant: right whatever the phone's time zone.
class LocalNotifier {
  LocalNotifier([FlutterLocalNotificationsPlugin? plugin]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  bool _ready = false;

  /// Location (route) of a tapped notification.
  Stream<String> get taps => _taps.stream;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('battlegame', 'Battle Game', channelDescription: 'Compétitions, votes, prestations et rappels', importance: Importance.high, priority: Priority.high),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission asked later, at a moment that makes sense (see requestPermission).
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _taps.add(payload);
      },
    );
    _ready = true;
    // Opened by tapping a notification while the app was closed.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null && payload.isNotEmpty) _taps.add(payload);
  }

  /// Asks once (iOS alert, Android 13+) — after sign-in, when reminders become useful.
  Future<bool> requestPermission() async {
    await init();
    final ios = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    final android = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    return ios ?? android ?? false;
  }

  Future<void> show({required int id, required String title, required String body, String? link}) async {
    await init();
    await _plugin.show(id: id, title: title, body: body, notificationDetails: _details, payload: link);
  }

  /// A reminder at [when] (ignored when already past).
  Future<void> schedule({required int id, required DateTime when, required String title, required String body, String? link}) async {
    if (!when.isAfter(DateTime.now())) return;
    await init();
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(when.toUtc(), tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: link,
    );
  }

  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}

/// Stable 31-bit id from a string (notification ids are ints).
int notificationId(String key) {
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}
