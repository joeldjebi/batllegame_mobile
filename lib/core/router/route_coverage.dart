import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Tells a playing screen when another page is opened over it (an artist, the
/// search…), whatever opened it: the top page of the router (pushed pages
/// included) is no longer the one this widget lives in. Videos pause on it, and
/// play again on the way back.
mixin RouteCoverage<T extends StatefulWidget> on State<T> {
  GoRouter? _router;
  String? _location;

  /// Another page is shown over this one (or another tab).
  bool routeCovered = false;

  /// Called when [routeCovered] changes.
  void onRouteCoverageChanged();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_onRoute);
    _router = router;
    if (router == null) return;
    try {
      _location = GoRouterState.of(context).matchedLocation;
    } on GoError {
      _location = null;
    }
    router.routerDelegate.addListener(_onRoute);
  }

  void _onRoute() {
    final router = _router;
    if (router == null || _location == null || !mounted) return;
    final top = router.routerDelegate.currentConfiguration;
    final covered = top.isEmpty || top.last.matchedLocation != _location;
    if (covered == routeCovered) return;
    routeCovered = covered;
    onRouteCoverageChanged();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }
}
