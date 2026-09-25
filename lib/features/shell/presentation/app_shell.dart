import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/offline_banner.dart';

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
    final c = context.colors;
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
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: c.background,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
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
                            onTap: () => _go(index),
                          ),
                  ),
              ],
            ),
          ),
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
  const _TabItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.text : c.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: Motion.fast,
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 3),
            Text(label, style: context.text.labelSmall?.copyWith(color: color, fontSize: 11)),
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
            width: 52,
            height: 36,
            decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.md)),
            child: Icon(AppIcons.create, color: c.onPrimary, size: 24),
          ),
        ),
      ),
    );
  }
}
