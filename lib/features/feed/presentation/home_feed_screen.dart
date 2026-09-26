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
import '../../battles/data/battles.dart';
import '../../battles/presentation/battles_view.dart';
import 'feed_view.dart';

/// Accueil: « Battles » (votes open now) and « Pour toi » (every performance), the
/// TikTok way: text tabs over the video, a horizontal swipe from one to the other.
/// Plays only while this tab is shown.
class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  int _tab = 1;
  final _pages = PageController(initialPage: 1);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _show(int tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    _pages.animateToPage(tab, duration: context.motion(Motion.base), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final shown = ref.watch(currentTabProvider) == 0;
    final open = ref.watch(battlesProvider).valueOrNull?.data?.open.length ?? 0;
    return DarkFeed(
      child: Builder(
        builder: (context) => ColoredBox(
          color: Colors.black,
          child: Stack(
            children: [
              PageView(
                controller: _pages,
                onPageChanged: (tab) => setState(() => _tab = tab),
                children: [
                  _KeepAlive(child: BattlesView(visible: shown && _tab == 0)),
                  _KeepAlive(child: FeedView(visible: shown && _tab == 1, showTitle: false)),
                ],
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + Space.sm + 4,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TopTab(label: 'Battles', count: open, selected: _tab == 0, onTap: () => _show(0)),
                    const SizedBox(width: Space.xl),
                    _TopTab(label: 'Pour toi', selected: _tab == 1, onTap: () => _show(1)),
                  ],
                ),
              ),
              // Search, top right as on TikTok.
              Positioned(
                top: MediaQuery.paddingOf(context).top + Space.xs,
                right: Space.sm,
                child: IconButton(
                  tooltip: 'Rechercher',
                  onPressed: () => context.push('/recherche'),
                  icon: const Icon(
                    AppIcons.search,
                    color: Colors.white,
                    size: 24,
                    shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps a home page (its position, its player) while the other one is shown.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
