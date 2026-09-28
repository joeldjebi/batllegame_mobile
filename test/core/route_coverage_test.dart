import 'dart:async';


import 'package:battlegame/core/router/route_coverage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Player extends StatefulWidget {
  const _Player({required this.log});

  final List<bool> log;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> with RouteCoverage {
  @override
  void onRouteCoverageChanged() => widget.log.add(routeCovered);

  @override
  Widget build(BuildContext context) => const Text('lecteur');
}

void main() {
  testWidgets('a page opened over the player covers it, going back uncovers it', (tester) async {
    final log = <bool>[];
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => Scaffold(body: _Player(log: log))),
        GoRoute(path: '/artistes/:id', builder: (_, _) => const Scaffold(body: Text('artiste'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    unawaited(router.push('/artistes/7'));
    await tester.pumpAndSettle();
    expect(log, [true]);

    router.pop();
    await tester.pumpAndSettle();
    expect(log, [true, false]);
  });
}
