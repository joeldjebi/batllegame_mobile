import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_gate.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/toast.dart';
import '../data/feed_controller.dart';
import '../data/feed_item.dart';
import '../data/video_pool.dart';
import 'feed_tile.dart';

/// Vertical full-screen feed: « Pour toi » ([competition] null) or one competition's
/// performances. Plays only while [visible] and the app is in the foreground.
class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key, this.competition, this.title, required this.visible, this.onBack});

  final String? competition;
  final String? title;
  final bool visible;
  final VoidCallback? onBack;

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView> {
  late final VideoPool _pool = VideoPool(ref.read(mediaCacheProvider));
  late final AppLifecycleListener _lifecycle;
  final _pages = PageController();
  int _index = 0;
  bool _foreground = true;

  bool get _playing => widget.visible && _foreground && ModalRoute.of(context)?.isCurrent != false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (state) {
      _foreground = state == AppLifecycleState.resumed;
      _sync();
    });
  }

  @override
  void didUpdateWidget(FeedView old) {
    super.didUpdateWidget(old);
    if (old.visible != widget.visible) _sync();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _pages.dispose();
    _pool.dispose();
    super.dispose();
  }

  List<FeedItem> get _items => ref.read(feedProvider(widget.competition)).items;

  /// Players around the current page, and the one that plays.
  void _sync() {
    final items = _items;
    if (items.isEmpty) return;
    final index = min(_index, items.length - 1);
    final window = [index, index + 1, index - 1, index + 2].where((i) => i >= 0 && i < items.length).map((i) => items[i]).toList();
    unawaited(_pool.keep(window).then((_) {
      if (mounted) _pool.play(_playing ? items[index].key : null);
    }));
    _pool.play(_playing ? items[index].key : null);
  }

  void _onPage(int index) {
    setState(() => _index = index);
    _sync();
    if (index >= _items.length - 3) unawaited(ref.read(feedProvider(widget.competition).notifier).loadMore());
  }

  Future<void> _open(String location) async {
    _pool.pauseAll();
    await context.push(location);
    if (mounted) _sync();
  }

  void _like(FeedItem item) => requireVerifiedUser(context, ref,
      reason: 'liker', action: () => ref.read(feedProvider(widget.competition).notifier).toggleLike(item));

  Future<void> _share(FeedItem item) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: '${item.stageName} dans « ${item.competitionName} » sur Battle Game 🔥\n${item.shareUrl}',
      subject: item.competitionName,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedProvider(widget.competition));
    ref.listen<FeedState>(feedProvider(widget.competition), (previous, next) {
      if (previous?.items.isEmpty != false && next.items.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
      final error = next.error;
      if (error != null && error != previous?.error && next.items.isNotEmpty && error.kind != ApiErrorKind.offline && error.kind != ApiErrorKind.timeout) {
        showToast(context, error.message);
      }
    });

    final c = context.colors;
    final Widget body;
    if (state.items.isEmpty) {
      body = state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? EmptyState(
                  icon: AppIcons.offline,
                  title: 'Impossible de charger le fil',
                  message: state.error!.message,
                  action: AppButton(label: 'Réessayer', expand: false, onPressed: () => ref.read(feedProvider(widget.competition).notifier).refresh()),
                )
              : const EmptyState(icon: AppIcons.feed, title: 'Aucune prestation pour l\'instant', message: 'Les prestations validées apparaîtront ici.');
    } else {
      body = RefreshIndicator(
        color: c.primary,
        onRefresh: () => ref.read(feedProvider(widget.competition).notifier).refresh(),
        child: PageView.builder(
          controller: _pages,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPage,
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            final item = state.items[index];
            return FeedTile(
              key: ValueKey(item.key),
              item: item,
              pool: _pool,
              active: index == _index,
              onLike: () => _like(item),
              onShare: () => _share(item),
              onCompetition: () => _open('/competitions/${item.competitionSlug}'),
              onVote: () => item.vote == null ? null : _open('/competitions/${item.competitionSlug}/matchs/${item.vote!.matchId}'),
            );
          },
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            top: MediaQuery.paddingOf(context).top + Space.sm,
            left: Space.sm,
            right: Space.sm,
            child: Row(
              children: [
                if (widget.onBack != null)
                  IconButton(tooltip: 'Retour', onPressed: widget.onBack, icon: const Icon(AppIcons.back, color: Colors.white))
                else
                  const SizedBox(width: kMinTouchTarget),
                Expanded(
                  child: Text(
                    widget.title ?? 'Pour toi',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 6)]),
                  ),
                ),
                ListenableBuilder(
                  listenable: _pool,
                  builder: (context, _) => IconButton(
                    tooltip: _pool.muted ? 'Activer le son' : 'Couper le son',
                    onPressed: _pool.toggleMute,
                    icon: Icon(_pool.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          if (state.fromCache && state.items.isNotEmpty)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 56,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(Radii.pill)),
                  child: Text('Prestations enregistrées', style: context.text.labelSmall?.copyWith(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
