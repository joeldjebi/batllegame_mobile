import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../activity/data/providers.dart';

/// Five tabs, the TikTok way: Accueil · Découvrir · + · Activité · Profil.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = [
    (icon: AppIcons.home, active: AppIcons.homeActive, label: 'Accueil'),
    (icon: AppIcons.discover, active: AppIcons.discoverActive, label: 'Découvrir'),
    (icon: AppIcons.create, active: AppIcons.create, label: 'Publier'),
    (icon: AppIcons.activity, active: AppIcons.activityActive, label: 'Activité'),
    (icon: AppIcons.profile, active: AppIcons.profileActive, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The feed plays only while its tab is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(currentTabProvider) != shell.currentIndex) ref.read(currentTabProvider.notifier).state = shell.currentIndex;
    });
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: shell),
        ],
      ),
      // Over the video feed the bar is dark, like the feed itself.
      bottomNavigationBar: Theme(
        data: shell.currentIndex == 0 ? AppTheme.dark() : Theme.of(context),
        child: Builder(
          builder: (context) {
            final c = context.colors;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: c.background,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      for (final (index, tab) in _tabs.indexed)
                        Expanded(
                          child: index == 2
                              ? _CreateButton(onTap: () => _go(index))
                              : _TabItem(
                                  icon: shell.currentIndex == index ? tab.active : tab.icon,
                                  label: tab.label,
                                  selected: shell.currentIndex == index,
                                  badge: index == 3 ? ref.watch(unreadActivityProvider) : 0,
                                  onTap: () => _go(index),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _go(int index) {
    HapticFeedback.selectionClick();
    // Tapping the current tab goes back to its root.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.selected, required this.onTap, this.badge = 0});

  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.text : c.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, $badge nouveau(x)' : label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 9 ? '9+' : '$badge'),
              backgroundColor: c.like,
              child: AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: context.motion(Motion.fast),
                child: Icon(icon, size: 22, color: color),
              ),
            ),
            const SizedBox(height: 3),
            Text(label, style: context.text.labelSmall?.copyWith(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Publier une prestation',
      excludeSemantics: true,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 32,
            decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.md)),
            child: Icon(AppIcons.create, color: c.onPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}
