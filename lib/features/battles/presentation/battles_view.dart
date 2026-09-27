import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/video_source.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_gate.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hold_to_vote.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/vote_celebration.dart';
import '../data/battles.dart';

const _shadow = [Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1))];

/// Which battle of a competition is shown, how many are open (« 5 poules en vote »), and the next one.
typedef BattleNav = ({int index, int total, VoidCallback? onNext});

/// Battle shown per competition (the tab keeps it while you browse).
final battlePicksProvider = StateProvider<Map<String, int>>((ref) => const {});

/// Seed of the random order of competitions and groups: new at each launch and each
/// pull to refresh, stable in between (pages never move under the finger).
final battleShuffleProvider = StateProvider<int>((ref) => Random().nextInt(1 << 31));

/// « Battles »: one page per competition whose vote is open, in random order, each on
/// one of its battles in random order (the ones you have not voted in first), with
/// « Poule suivante » and the full program; then the battles coming next.
class BattlesView extends ConsumerStatefulWidget {
  const BattlesView({super.key, required this.visible});

  final bool visible;

  @override
  ConsumerState<BattlesView> createState() => _BattlesViewState();
}

class _BattlesViewState extends ConsumerState<BattlesView> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final resource = ref.watch(battlesProvider).valueOrNull;
    final board = resource?.data;
    final c = context.colors;

    if (board == null) {
      return resource?.error != null
          ? EmptyState(icon: AppIcons.offline, title: 'Battles indisponibles', message: resource!.error!.message)
          : const _BattleSkeleton();
    }
    if (board.isEmpty) {
      return EmptyState(
        icon: AppIcons.battle,
        title: 'Aucun vote ouvert en ce moment',
        message: 'Les battles apparaissent ici dès que le public peut voter.',
        action: AppButton(label: 'Voir les compétitions', expand: false, variant: AppButtonVariant.secondary, onPressed: () => context.go('/decouvrir')),
      );
    }

    // No vote open: what comes next, and when.
    if (board.open.isEmpty) return UpcomingView(upcoming: board.upcoming, nothingOpen: true);

    final seed = ref.watch(battleShuffleProvider);
    final competitions = shuffleBattles(board.open, seed);
    final picks = ref.watch(battlePicksProvider);

    return RefreshIndicator(
      color: c.primary,
      // A new draw: other competitions and groups first.
      onRefresh: () async {
        ref.read(battlePicksProvider.notifier).state = const {};
        ref.read(battleShuffleProvider.notifier).state = Random().nextInt(1 << 31);
        ref.invalidate(battlesProvider);
      },
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: competitions.length + (board.upcoming.isEmpty ? 0 : 1),
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          if (i == competitions.length) return UpcomingView(upcoming: board.upcoming);
          final battles = competitions[i];
          final slug = battles.first.competitionSlug;
          final picked = battles.indexWhere((b) => b.id == picks[slug]);
          final index = picked >= 0 ? picked : 0;
          final battle = battles[index];
          final nav = (
            index: index,
            total: battles.length,
            onNext: battles.length < 2
                ? null
                : () => ref.read(battlePicksProvider.notifier).update((m) => {...m, slug: battles[(index + 1) % battles.length].id}),
          );
          final active = widget.visible && i == _index;
          return battle.isDuel
              ? DuelTile(key: ValueKey('duel-${battle.id}'), battle: battle, active: active, nav: nav)
              : GroupTile(key: ValueKey('group-${battle.id}'), battle: battle, nav: nav);
        },
      ),
    );
  }

}

/// The open battles by competition, competitions and battles in a random order drawn
/// from [seed]; in each competition the battles you can still vote in come first.
List<List<Battle>> shuffleBattles(List<Battle> open, int seed) {
  final byCompetition = <String, List<Battle>>{};
  for (final battle in open) {
    byCompetition.putIfAbsent(battle.competitionSlug, () => []).add(battle);
  }
  final random = Random(seed);
  final slugs = byCompetition.keys.toList()..shuffle(random);
  return [
    for (final slug in slugs)
      () {
        final battles = [...byCompetition[slug]!]..shuffle(random);
        bool votable(Battle b) => !b.isMine && !b.votedInPhase && b.myVote == null;
        return [...battles.where(votable), ...battles.where((b) => !votable(b))];
      }(),
  ];
}

/// Top of a battle: the competition in full, then the group or stage and when the vote closes.
class _BattleHeader extends StatelessWidget {
  const _BattleHeader({required this.battle, this.nav});

  final Battle battle;
  final BattleNav? nav;

  @override
  Widget build(BuildContext context) {
    final where = battle.isGroup ? {battle.title, ?battle.stage}.join(' · ') : (battle.stage ?? 'Battle');
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.lg, MediaQuery.paddingOf(context).top + 52, Space.lg, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(Radii.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              battle.competitionName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Flexible(
                  child: Text(
                    where,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(color: Colors.white70),
                  ),
                ),
                if (battle.closesAt != null) ...[
                  const SizedBox(width: Space.md),
                  const Icon(AppIcons.pending, size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text('Ferme ${Labels.remaining(battle.closesAt!)}', style: context.text.labelMedium?.copyWith(color: Colors.white70)),
                ],
              ],
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                if (nav != null && nav!.total > 1) ...[
                  Text(
                    '${nav!.total} ${battle.isGroup ? 'poules' : 'battles'} en vote',
                    style: context.text.labelSmall?.copyWith(color: Colors.white60),
                  ),
                  const Spacer(),
                  _HeaderButton(label: battle.isGroup ? 'Poule suivante' : 'Battle suivante', onTap: nav!.onNext),
                  const SizedBox(width: Space.sm),
                ] else
                  const Spacer(),
                _HeaderButton(
                  label: 'Programme complet',
                  filled: true,
                  onTap: () => context.push('/competitions/${battle.competitionSlug}?onglet=phases'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            onTap!();
          },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(label, style: context.text.labelMedium?.copyWith(color: filled ? Colors.black : Colors.white, fontWeight: FontWeight.w700)),
    ),
  );
}

/// Casts a vote from a battle: account and verified phone first, room code battles on
/// their match page.
Future<void> voteIn(BuildContext context, WidgetRef ref, Battle battle, BattleArtist artist) async {
  if (battle.voteCodeRequired) {
    await context.push('/competitions/${battle.competitionSlug}/matchs/${battle.id}');
    return;
  }
  await requireVerifiedUser(
    context,
    ref,
    reason: 'voter',
    action: () async {
      await ref.read(battleVotesProvider.notifier).vote(battle, artist);
      if (context.mounted) {
        await celebrateVote(
          context,
          artist: artist.stageName,
          competition: battle.competitionName,
          shareUrl: battle.shareUrl,
          offline: !ref.read(networkStatusProvider),
        );
      }
    },
  );
}

/// Two artists face to face: two halves, « VS » between them; the touched half plays
/// with sound, the other waits on its poster.
class DuelTile extends ConsumerStatefulWidget {
  const DuelTile({super.key, required this.battle, required this.active, this.nav});

  final Battle battle;
  final bool active;
  final BattleNav? nav;

  @override
  ConsumerState<DuelTile> createState() => _DuelTileState();
}

class _DuelTileState extends ConsumerState<DuelTile> {
  final Map<int, VideoPlayerController> _players = {};
  int _playing = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _open();
  }

  @override
  void didUpdateWidget(DuelTile old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _open();
    if (!widget.active && old.active) _close();
  }

  @override
  void dispose() {
    _disposed = true;
    _close();
    super.dispose();
  }

  Future<void> _open() async {
    final cache = ref.read(mediaCacheProvider);
    for (final (i, artist) in widget.battle.artists.indexed) {
      final media = artist.media;
      if (media == null || _players.containsKey(i)) continue;
      final source = await pickVideoSource(cache, 'media-${artist.mediaId}', media, ref.read(videoQualityProvider));
      if (source == null) continue;
      final (:key, :url, :file) = source;
      final player = file != null ? VideoPlayerController.file(file) : VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await player.initialize();
      } catch (_) {
        await player.dispose();
        continue;
      }
      if (_disposed || !widget.active) {
        await player.dispose();
        return;
      }
      await player.setLooping(true);
      if (file == null) cache.prefetch(key, url);
      setState(() => _players[i] = player);
      if (i == _playing) unawaited(player.play());
    }
  }

  void _close() {
    for (final player in _players.values) {
      unawaited(player.dispose());
    }
    _players.clear();
  }

  void _focus(int i) {
    if (i == _playing) {
      final player = _players[i];
      if (player != null) player.value.isPlaying ? player.pause() : player.play();
      return;
    }
    HapticFeedback.selectionClick();
    _players[_playing]?.pause();
    setState(() => _playing = i);
    _players[i]?.play();
  }

  @override
  Widget build(BuildContext context) {
    final battle = widget.battle;
    final voted = ref.watch(battleVotesProvider)[battle.id] ?? battle.myVote;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Column(
            children: [
              for (final (i, artist) in battle.artists.indexed) ...[
                if (i == 1) const SizedBox(height: 2),
                Expanded(
                  child: _Half(artist: artist, battle: battle, player: _players[i], playing: i == _playing, voted: voted, onTap: () => _focus(i)),
                ),
              ],
            ],
          ),
          // « VS » on the seam.
          Center(
            child: ExcludeSemantics(
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 3),
                ),
                child: Text(
                  'VS',
                  style: context.text.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
          _BattleHeader(battle: battle, nav: widget.nav),
        ],
      ),
    );
  }
}

class _Half extends ConsumerWidget {
  const _Half({required this.artist, required this.battle, required this.player, required this.playing, required this.voted, required this.onTap});

  final BattleArtist artist;
  final Battle battle;
  final VideoPlayerController? player;
  final bool playing;
  final int? voted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = player != null && player!.value.isInitialized;
    final canVote = voted == null && !battle.isMine;

    return Semantics(
      label: 'Prestation de ${artist.stageName}',
      hint: playing ? 'Toucher pour mettre en pause' : 'Toucher pour écouter',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (artist.media?.posterUrl != null) CachedImage(cacheKey: 'media-${artist.mediaId}-poster', url: artist.media!.posterUrl),
            if (ready && playing)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(width: player!.value.size.width, height: player!.value.size.height, child: VideoPlayer(player!)),
              ),
            // The half not being listened to steps back.
            if (!playing) ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            if (artist.media == null)
              Center(
                child: Text('Prestation pas encore publiée', style: context.text.bodySmall?.copyWith(color: Colors.white70)),
              ),
            Positioned(
              left: Space.lg,
              right: Space.lg,
              bottom: Space.lg,
              child: Row(
                children: [
                  Avatar(name: artist.stageName, url: artist.avatarUrl, size: 34),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          artist.stageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(color: Colors.white, shadows: _shadow),
                        ),
                        Row(
                          children: [
                            Icon(playing ? AppIcons.soundOn : AppIcons.soundOff, size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              playing ? 'En écoute' : 'Toucher pour écouter',
                              style: context.text.labelSmall?.copyWith(color: Colors.white70, shadows: _shadow),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  SizedBox(
                    width: 132,
                    child: HoldToVote(
                      compact: true,
                      label: battle.isMine ? 'Ta battle' : 'Voter',
                      onQuickTap: () => showToast(context, 'Maintiens le bouton appuyé pour voter.'),
                      voted: voted == artist.participantId,
                      enabled: canVote,
                      onVote: () => voteIn(context, ref, battle, artist),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A group: every artist of the pool, one vote for the whole phase.
class GroupTile extends ConsumerWidget {
  const GroupTile({super.key, required this.battle, this.nav});

  final Battle battle;
  final BattleNav? nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voted = ref.watch(battleVotesProvider)[battle.id] ?? battle.myVote;
    final canVote = voted == null && !battle.votedInPhase && !battle.isMine;

    return ColoredBox(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BattleHeader(battle: battle, nav: nav),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.sm),
            child: Text(
              battle.votedInPhase ? 'Tu as déjà voté dans cette phase.' : 'Un seul vote pour toute la phase : touche une prestation pour la regarder.',
              style: context.text.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
          Expanded(
            // The whole group fits on the page: the grid never scrolls, so a vertical
            // swipe anywhere moves to the next battle.
            child: LayoutBuilder(
              builder: (context, box) {
                final count = battle.artists.length;
                final columns = count > 6 ? 3 : (count > 1 ? 2 : 1);
                final rows = (count / columns).ceil().clamp(1, 99);
                const padding = EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl);
                final width = (box.maxWidth - padding.horizontal - (columns - 1) * Space.md) / columns;
                final height = (box.maxHeight - padding.vertical - (rows - 1) * Space.md) / rows;
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: padding,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: Space.md,
                    crossAxisSpacing: Space.md,
                    childAspectRatio: height > 0 ? (width / height).clamp(0.45, 4.0) : 0.62,
                  ),
                  itemCount: count,
                  itemBuilder: (context, i) => _groupCell(context, ref, battle, battle.artists[i], voted, canVote),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCell(BuildContext context, WidgetRef ref, Battle battle, BattleArtist artist, int? voted, bool canVote) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFF1E1E2A),
            child: artist.media?.posterUrl == null ? null : CachedImage(cacheKey: 'media-${artist.mediaId}-poster', url: artist.media!.posterUrl),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: artist.media == null
                    ? null
                    : () => context.push('/lecture', extra: (key: 'media-${artist.mediaId}', media: artist.media!, title: artist.stageName)),
                child: const Center(
                  child: Icon(AppIcons.play, color: Colors.white, size: 30, shadows: _shadow),
                ),
              ),
            ),
          ),
          Positioned(
            left: Space.sm,
            right: Space.sm,
            bottom: Space.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  artist.stageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(color: Colors.white, shadows: _shadow),
                ),
                const SizedBox(height: Space.xs),
                HoldToVote(
                  compact: true,
                  label: 'Voter',
                  onQuickTap: () => showToast(context, 'Maintiens le bouton appuyé pour voter.'),
                  voted: voted == artist.participantId,
                  enabled: canVote,
                  onVote: () => voteIn(context, ref, battle, artist),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The battles whose vote opens later, soonest first. Ticks every 30 s; once an
/// opening time is past, reloads so the battle moves to the votes.
class UpcomingView extends ConsumerStatefulWidget {
  const UpcomingView({super.key, required this.upcoming, this.nothingOpen = false});

  final List<UpcomingBattle> upcoming;
  final bool nothingOpen;

  @override
  ConsumerState<UpcomingView> createState() => _UpcomingViewState();
}

class _UpcomingViewState extends ConsumerState<UpcomingView> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final due = widget.upcoming.any((b) => DateTime.now().difference(b.opensAt).inSeconds > 45);
      due ? ref.invalidate(battlesProvider) : setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.background,
      child: RefreshIndicator(
        color: c.primary,
        onRefresh: () async => ref.invalidate(battlesProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(Space.gutter, MediaQuery.paddingOf(context).top + 60, Space.gutter, Space.xxl),
          children: [
            if (widget.nothingOpen) ...[
              Text('Aucun vote ouvert en ce moment', style: context.text.titleMedium?.copyWith(color: c.text)),
              const SizedBox(height: Space.xs),
              Text('Voici les prochaines battles et l\'heure d\'ouverture de leur vote.', style: context.text.bodySmall?.copyWith(color: c.textMuted)),
            ] else
              Text('À venir', style: context.text.titleMedium?.copyWith(color: c.text)),
            const SizedBox(height: Space.lg),
            for (final battle in widget.upcoming) ...[_UpcomingCard(battle: battle), const SizedBox(height: Space.md)],
          ],
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.battle});

  final UpcomingBattle battle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = battle.artists.take(4).toList();
    final more = battle.artists.length - shown.length;

    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/competitions/${battle.competitionSlug}'),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [battle.competitionName, if (battle.stage != null && !battle.isGroup) battle.stage!].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: c.textMuted),
                    ),
                  ),
                  if (battle.isMine) ...[
                    const SizedBox(width: Space.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
                      decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(Radii.pill)),
                      child: Text('Ta battle', style: context.text.labelSmall?.copyWith(color: c.primary)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                battle.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(color: c.text),
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  // Artists, overlapping.
                  SizedBox(
                    height: 28,
                    width: shown.isEmpty ? 0 : 28 + (shown.length - 1) * 18.0,
                    child: Stack(
                      children: [
                        for (final (i, artist) in shown.indexed)
                          Positioned(
                            left: i * 18.0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: c.surface, width: 2),
                              ),
                              child: Avatar(name: artist.stageName, url: artist.avatarUrl, size: 24),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (more > 0) Text(' +$more', style: context.text.labelSmall?.copyWith(color: c.textMuted)),
                  const Spacer(),
                  Icon(AppIcons.pending, size: 14, color: c.textMuted),
                  const SizedBox(width: 4),
                  Text(Labels.voteOpens(battle.opensAt), style: context.text.labelMedium?.copyWith(color: c.text)),
                ],
              ),
              if (battle.submissionsOpen) ...[
                const SizedBox(height: Space.sm),
                Text('Envois des prestations en cours', style: context.text.labelSmall?.copyWith(color: c.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The shape of a battle page while it loads: the header, then the group grid.
class _BattleSkeleton extends StatelessWidget {
  const _BattleSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Chargement des battles',
    liveRegion: true,
    child: Padding(
      padding: EdgeInsets.fromLTRB(Space.lg, MediaQuery.paddingOf(context).top + 60, Space.lg, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 230, height: 18),
          const SizedBox(height: Space.sm),
          const Skeleton(width: 170, height: 12),
          const SizedBox(height: Space.lg),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Space.md,
              crossAxisSpacing: Space.md,
              childAspectRatio: 0.62,
              children: [for (var i = 0; i < 4; i++) const Skeleton(radius: Radii.lg)],
            ),
          ),
        ],
      ),
    ),
  );
}
