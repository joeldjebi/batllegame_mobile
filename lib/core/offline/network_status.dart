import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Online = a network interface is up **and** the server answered the last call.
class NetworkStatus extends StateNotifier<bool> {
  /// [changes] replaces the platform's connectivity stream (tests).
  NetworkStatus({Stream<List<ConnectivityResult>>? changes}) : super(true) {
    _subscription = (changes ?? Connectivity().onConnectivityChanged).listen((results) {
      final linkUp = !results.every((r) => r == ConnectivityResult.none);
      // A link that comes back gives the server a new chance until a call fails.
      if (linkUp && !_linkUp) _serverReachable = true;
      _linkUp = linkUp;
      _update();
    });
  }

  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _linkUp = true;
  bool _serverReachable = true;

  /// Called by the API client after every call.
  void reportServer(bool reachable) {
    _serverReachable = reachable;
    _update();
  }

  void _update() {
    final online = _linkUp && _serverReachable;
    if (online != state) state = online;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
