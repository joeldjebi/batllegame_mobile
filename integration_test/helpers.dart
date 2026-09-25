import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps real frames for [seconds].
Future<void> settle(WidgetTester tester, [int seconds = 3]) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] matches at least [count] widgets (max [seconds]).
Future<void> waitFor(WidgetTester tester, Finder finder, {int count = 1, int seconds = 20}) async {
  for (var i = 0; i < seconds * 10 && finder.evaluate().length < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Profil → Se connecter → phone + password. Waits for both fields each time: the
/// iOS keyboard animation may rebuild the form between the two entries.
Future<void> signIn(WidgetTester tester, String phone, String password) async {
  await tester.tap(find.text('Profil'));
  await waitFor(tester, find.text('Se connecter'));
  await tester.tap(find.text('Se connecter').last);
  await waitFor(tester, find.byType(TextField), count: 2);
  await settle(tester, 1);
  await tester.enterText(find.byType(TextField).at(0), phone);
  await waitFor(tester, find.byType(TextField), count: 2);
  await tester.enterText(find.byType(TextField).at(1), password);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, 1);
  await tester.tap(find.text('Se connecter').last);
  await settle(tester, 4);
}
