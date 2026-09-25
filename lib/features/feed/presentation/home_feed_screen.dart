import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../battles/data/battles.dart';
import '../../battles/presentation/battles_view.dart';
import 'feed_view.dart';

/// Accueil: « Battles » (votes open now) and « Pour toi » (every performance), the
/// TikTok way: text tabs over the video. Plays only while this tab is shown.
class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    final shown = ref.watch(currentTabProvider) == 0;
    final open = ref.watch(battlesProvider).valueOrNull?.data?.length ?? 0;
    return DarkFeed(
      child: Builder(
        builder: (context) => ColoredBox(
          color: Colors.black,
          child: Stack(
            children: [
              IndexedStack(
                index: _tab,
                children: [
                  BattlesView(visible: shown && _tab == 0),
                  FeedView(visible: shown && _tab == 1, showTitle: false),
                ],
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + Space.sm + 4,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TopTab(label: 'Battles', count: open, selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                    const SizedBox(width: Space.xl),
                    _TopTab(label: 'Pour toi', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
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

class _TopTab extends StatelessWidget {
  const _TopTab({required this.label, required this.selected, required this.onTap, this.count = 0});

  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: count > 0 ? '$label, $count vote(s) ouvert(s)' : label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.text.titleMedium?.copyWith(
                    color: selected ? Colors.white : Colors.white60,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    shadows: const [Shadow(color: Color(0x99000000), blurRadius: 6)],
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: context.colors.like, borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Text(
                      '$count',
                      style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: context.motion(Motion.fast),
              width: selected ? 22 : 0,
              height: 2,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The performances of one competition, full screen (opened from its page).
class CompetitionFeedScreen extends StatelessWidget {
  const CompetitionFeedScreen({super.key, required this.slug, this.title});

  final String slug;
  final String? title;

  @override
  Widget build(BuildContext context) => DarkFeed(
    child: Scaffold(
      backgroundColor: Colors.black,
      body: FeedView(competition: slug, title: title ?? 'Prestations', visible: true, onBack: () => Navigator.of(context).maybePop()),
    ),
  );
}

/// Videos are watched on black, whatever the appearance: dark theme, light status bar.
class DarkFeed extends StatelessWidget {
  const DarkFeed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Theme(data: AppTheme.dark(), child: child),
  );
}
