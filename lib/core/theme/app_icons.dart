import 'package:flutter/material.dart';

/// Every icon of the app, in one place (swap the set here). Material's rounded /
/// outlined glyphs: vector, tree-shaken to the few used (a few KB).
abstract final class AppIcons {
  static const IconData home = Icons.home_outlined;
  static const IconData homeActive = Icons.home_rounded;
  static const IconData discover = Icons.explore_outlined;
  static const IconData discoverActive = Icons.explore_rounded;
  static const IconData create = Icons.add_rounded;
  static const IconData activity = Icons.notifications_none_rounded;
  static const IconData activityActive = Icons.notifications_rounded;
  static const IconData profile = Icons.person_outline_rounded;
  static const IconData profileActive = Icons.person_rounded;

  static const IconData show = Icons.visibility_outlined;
  static const IconData hide = Icons.visibility_off_outlined;
  static const IconData offline = Icons.wifi_off_rounded;
  static const IconData expand = Icons.expand_more_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData back = Icons.arrow_back_rounded;

  static const IconData feed = Icons.movie_outlined;
  static const IconData trophy = Icons.emoji_events_outlined;
  static const IconData video = Icons.videocam_outlined;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData pending = Icons.schedule_rounded;
  static const IconData unverified = Icons.gpp_maybe_outlined;
  static const IconData jury = Icons.gavel_rounded;
  static const IconData password = Icons.key_outlined;
  static const IconData logout = Icons.logout_rounded;
}
