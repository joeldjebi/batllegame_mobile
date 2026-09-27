import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/brand.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/labels.dart';

const _disciplines = ['rap', 'chant', 'freestyle', 'slam', 'beatbox', 'autre'];

const _pages = [
  (
    icon: AppIcons.battle,
    title: 'Des battles, votées par le public',
    text: 'Dans « Battles », les poules et les duels en cours. Regarde les prestations et choisis ton artiste.',
  ),
  (
    icon: AppIcons.vote,
    title: 'Ton vote compte',
    text: 'Maintiens le bouton « Voter » pour voter : un vote par phase, et le jury note de son côté. Partage pour soutenir tes favoris.',
  ),
  (
    icon: AppIcons.microphone,
    title: 'À toi la scène',
    text: 'Inscris-toi à une compétition, envoie ta prestation depuis l\'app et suis ton parcours jusqu\'à la finale.',
  ),
];

/// First launch: three screens on what the app does, then the favorite disciplines
/// and, with an explanation, the notifications permission. Shown once.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  int get _count => _pages.length + 1;

  Future<void> _next() async {
    unawaited(HapticFeedback.selectionClick());
    if (_page < _count - 1) {
      await _pager.nextPage(duration: context.motion(Motion.base), curve: Curves.easeOutCubic);
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    // The notifications permission is asked on the last screen (or never, if skipped): not at sign-in.
    await ref.read(databaseProvider).writeValue('notifications_asked', DateTime.now().toIso8601String());
    await ref.read(databaseProvider).writeValue('onboarded', DateTime.now().toIso8601String());
    ref.read(onboardedProvider.notifier).state = true;
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Brand.primary,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Passer', style: text.titleSmall?.copyWith(color: Colors.white70)),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pager,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    for (final page in _pages) _Intro(icon: page.icon, title: page.title, text: page.text),
                    const _Preferences(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xl),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Écran ${_page + 1} sur $_count',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _count; i++)
                            AnimatedContainer(
                              duration: context.motion(Motion.fast),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 22 : 7,
                              height: 7,
                              decoration: BoxDecoration(color: i == _page ? Colors.white : Colors.white38, borderRadius: BorderRadius.circular(Radii.pill)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.primary, shape: const StadiumBorder()),
                        onPressed: _next,
                        child: Text(_page == _count - 1 ? 'C\'est parti' : 'Suivant', style: text.titleMedium?.copyWith(color: Brand.primary, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: Space.xxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: Space.md),
          Text(text, textAlign: TextAlign.center, style: theme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85), height: 1.4)),
        ],
      ),
    );
  }
}

/// Last screen: favorite disciplines, then the notifications, explained.
class _Preferences extends ConsumerStatefulWidget {
  const _Preferences();

  @override
  ConsumerState<_Preferences> createState() => _PreferencesState();
}

class _PreferencesState extends ConsumerState<_Preferences> {
  bool? _notifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final favorites = ref.watch(favoriteDisciplinesProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      children: [
        const SizedBox(height: Space.xl),
        Text('Ce que tu aimes', textAlign: TextAlign.center, style: theme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: Space.sm),
        Text(
          'Les compétitions de ces disciplines passent en premier. Tu pourras changer plus tard.',
          textAlign: TextAlign.center,
          style: theme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
        ),
        const SizedBox(height: Space.xl),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final d in _disciplines)
              _Choice(
                label: Labels.discipline(d),
                selected: favorites.contains(d),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(favoriteDisciplinesProvider.notifier).toggle(d);
                },
              ),
          ],
        ),
        const SizedBox(height: Space.xxl),
        Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.xl)),
          child: Column(
            children: [
              const Icon(AppIcons.activity, color: Colors.white, size: 28),
              const SizedBox(height: Space.sm),
              Text('Reste informé', style: theme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: Space.xs),
              Text(
                'Rappels avant la fin d\'un vote ou d\'un envoi, validation de tes prestations, résultats.',
                textAlign: TextAlign.center,
                style: theme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: Space.md),
              if (_notifications == null)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70), shape: const StadiumBorder()),
                  onPressed: () async {
                    final granted = await ref.read(localNotifierProvider).requestPermission();
                    if (mounted) setState(() => _notifications = granted);
                  },
                  child: const Text('Activer les notifications'),
                )
              else
                Text(
                  _notifications! ? 'Notifications activées' : 'Tu pourras les activer dans les réglages du téléphone.',
                  style: theme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A discipline to pick: white when chosen, outlined otherwise (on the violet page).
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: context.motion(Motion.fast),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? Colors.white : Colors.white54),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[const Icon(AppIcons.done, size: 16, color: Brand.primary), const SizedBox(width: Space.xs)],
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: selected ? Brand.primary : Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}
