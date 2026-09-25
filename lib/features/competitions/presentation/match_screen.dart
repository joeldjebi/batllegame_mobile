import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/offline/outbox.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/auth_gate.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/live_channel.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/toast.dart';
import '../../feed/data/feed_item.dart';
import '../data/models.dart';
import '../data/providers.dart';
import 'video_holder.dart';

/// A match or a group: the artists, their performances, the public vote.
class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key, required this.slug, required this.id});

  final String slug;
  final int id;

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  /// My vote in this match (remembered on the phone), and whether it is still queued.
  int? _votedFor;
  String? _pendingId;
  StreamSubscription<OutboxResult>? _results;

  String get _voteKey => 'vote:${widget.slug}:${widget.id}';

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider).readValue(_voteKey).then((value) {
      if (mounted && value != null) setState(() => _votedFor = int.tryParse(value));
    });
    _results = ref.read(outboxProvider).results.listen((result) {
      if (result.id != _pendingId || !mounted) return;
      setState(() => _pendingId = null);
      if (result.succeeded) {
        showToast(context, 'Vote enregistré.');
      } else {
        setState(() => _votedFor = null);
        ref.read(databaseProvider).deleteValue(_voteKey);
        showToast(context, result.error!.message);
      }
    });
  }

  @override
  void dispose() {
    _results?.cancel();
    super.dispose();
  }

  Future<void> _vote(MatchDetail match, MatchSlot slot) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _VoteSheet(artist: slot.stageName, needsCode: match.voteCodeRequired),
    );
    if (code == null || slot.participantId == null) return;

    unawaited(HapticFeedback.mediumImpact());
    final id = await ref.read(outboxProvider).enqueue(
          method: 'POST',
          path: '/competitions/${widget.slug}/matches/${match.id}/votes',
          body: {'participant_id': slot.participantId, if (code.isNotEmpty) 'vote_code': code},
          label: 'Vote · ${slot.stageName}',
        );
    await ref.read(databaseProvider).writeValue(_voteKey, '${slot.participantId}');
    if (!mounted) return;
    setState(() {
      _votedFor = slot.participantId;
      _pendingId = id;
    });
    if (!ref.read(networkStatusProvider)) showToast(context, 'Hors ligne : ton vote sera envoyé au retour du réseau.');
  }

  @override
  Widget build(BuildContext context) {
    final key = (slug: widget.slug, id: widget.id);
    final c = context.colors;

    final competitionId = ref.watch(competitionProvider(widget.slug)).valueOrNull?.data?.id;
    final page = Scaffold(
      body: ResourceView(
        value: ref.watch(matchProvider(key)),
        onRetry: () => ref.invalidate(matchProvider(key)),
        builder: (match, _) => RefreshIndicator(
          color: c.primary,
          onRefresh: () async => ref.invalidate(matchProvider(key)),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Text(match.isGroup ? match.title : (match.stage ?? 'Battle')),
                actions: [
                  if (match.shareUrl.isNotEmpty)
                    IconButton(
                      tooltip: 'Partager',
                      icon: const Icon(AppIcons.share),
                      onPressed: () => SharePlus.instance.share(ShareParams(text: 'Vote sur Battle Game : ${match.shareUrl}')),
                    ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
                sliver: SliverToBoxAdapter(child: _VoteBanner(match: match, votedFor: _votedFor, pending: _pendingId != null)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
                sliver: SliverList.separated(
                  itemCount: match.slots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (context, i) {
                    final slot = match.slots[i];
                    return _SlotCard(
                      slot: slot,
                      isWinner: slot.participantId != null && slot.participantId == match.winnerId,
                      voted: _votedFor != null && _votedFor == slot.participantId,
                      canVote: match.votingOpen && _votedFor == null && slot.participantId != null && !slot.isForfeit,
                      onVote: () => requireVerifiedUser(context, ref, reason: 'voter', action: () => _vote(match, slot)),
                      onPlay: (media) => context.push('/lecture', extra: (key: 'media-${media.id}', media: media.media, title: slot.stageName)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Votes and statuses of this competition, live.
    return competitionId == null ? page : LiveChannel(channel: 'competition.$competitionId', child: page);
  }
}

class _VoteBanner extends StatelessWidget {
  const _VoteBanner({required this.match, required this.votedFor, required this.pending});

  final MatchDetail match;
  final int? votedFor;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (String title, String message, ChipTone tone) = switch (match) {
      _ when votedFor != null => (pending ? 'Vote en attente d\'envoi' : 'Tu as voté', pending ? 'Il partira dès que le réseau revient.' : 'Merci ! Un seul vote par personne.', ChipTone.success),
      MatchDetail(votingOpen: true) => (
          'Vote ouvert',
          match.isGroup ? 'Un seul vote pour toute la phase : choisis bien.' : 'Choisis l\'artiste qui a le mieux performé.',
          ChipTone.live
        ),
      MatchDetail(status: 'cloture') => ('Résultats', 'Le vote est terminé.', ChipTone.success),
      _ => ('Vote pas encore ouvert', 'Regarde les prestations en attendant.', ChipTone.neutral),
    };
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusChip(title, tone: tone),
                const SizedBox(height: Space.sm),
                Text(message, style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
                if (match.votingOpen && match.votingClosesAt != null)
                  Text('Fermeture ${Labels.remaining(match.votingClosesAt!)} · ${Labels.date(match.votingClosesAt)}', style: context.text.bodySmall?.copyWith(color: c.accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.isWinner, required this.voted, required this.canVote, required this.onVote, required this.onPlay});

  final MatchSlot slot;
  final bool isWinner;
  final bool voted;
  final bool canVote;
  final VoidCallback onVote;
  final void Function(({int id, MediaInfo media})) onPlay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = slot.media.firstOrNull;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: voted ? c.primary : c.border, width: voted ? 2 : 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (media != null)
            Semantics(
              button: true,
              label: 'Regarder la prestation de ${slot.stageName}',
              child: GestureDetector(
                onTap: () => onPlay(media),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: Colors.black, child: CachedImage(cacheKey: 'media-${media.id}-poster', url: media.media.posterUrl)),
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(AppIcons.play, color: Colors.white, size: 36),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                Avatar(name: slot.stageName, url: slot.avatarUrl, size: 40),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.stageName, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if (slot.isForfeit) Text('Forfait', style: context.text.bodySmall?.copyWith(color: c.danger)),
                      if (isWinner) Text('Vainqueur', style: context.text.bodySmall?.copyWith(color: c.success, fontWeight: FontWeight.w600)),
                      if (media == null && !slot.isForfeit) Text('Prestation pas encore publiée', style: context.text.bodySmall),
                    ],
                  ),
                ),
                if (slot.finalScore != null)
                  Text('${slot.finalScore!.toStringAsFixed(1).replaceAll('.', ',')} / 100', style: context.text.titleSmall),
                if (voted) Icon(AppIcons.done, color: c.primary),
              ],
            ),
          ),
          if (canVote)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
              child: AppButton(label: 'Voter pour ${slot.stageName}', icon: AppIcons.vote, onPressed: onVote),
            ),
        ],
      ),
    );
  }
}

/// Confirmation (a vote is final) and the room code of on-site battles.
class _VoteSheet extends StatefulWidget {
  const _VoteSheet({required this.artist, required this.needsCode});

  final String artist;
  final bool needsCode;

  @override
  State<_VoteSheet> createState() => _VoteSheetState();
}

class _VoteSheetState extends State<_VoteSheet> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, MediaQuery.viewInsetsOf(context).bottom + Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Voter pour ${widget.artist} ?', textAlign: TextAlign.center, style: context.text.titleLarge),
            const SizedBox(height: Space.sm),
            Text('Ton vote est définitif.', textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted)),
            if (widget.needsCode) ...[
              const SizedBox(height: Space.lg),
              AppTextField(
                label: 'Code affiché dans la salle',
                controller: _code,
                error: _error,
                autofocus: true,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), LengthLimitingTextInputFormatter(12)],
              ),
            ],
            const SizedBox(height: Space.xl),
            AppButton(
              label: 'Confirmer mon vote',
              onPressed: () {
                if (widget.needsCode && _code.text.trim().isEmpty) {
                  setState(() => _error = 'Saisis le code affiché à l\'écran.');
                  return;
                }
                Navigator.pop(context, _code.text.trim().toUpperCase());
              },
            ),
            const SizedBox(height: Space.sm),
            AppButton(label: 'Annuler', variant: AppButtonVariant.ghost, onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
}

/// Full-screen player of one performance (cached on disk by its id).
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.cacheKey, required this.media, this.title});

  final String cacheKey;
  final MediaInfo media;
  final String? title;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.title ?? 'Prestation')),
        body: Center(child: MediaPlayer(cacheKey: widget.cacheKey, media: widget.media)),
      );
}

/// A single video with play/pause and a scrubbable progress bar.
class MediaPlayer extends ConsumerStatefulWidget {
  const MediaPlayer({super.key, required this.cacheKey, required this.media});

  final String cacheKey;
  final MediaInfo media;

  @override
  ConsumerState<MediaPlayer> createState() => _MediaPlayerState();
}

class _MediaPlayerState extends ConsumerState<MediaPlayer> {
  VideoPlayerControllerHolder? _holder;

  @override
  void initState() {
    super.initState();
    VideoPlayerControllerHolder.open(ref.read(mediaCacheProvider), widget.cacheKey, widget.media).then((holder) {
      if (!mounted) {
        holder?.dispose();
        return;
      }
      setState(() => _holder = holder);
      holder?.controller.play();
    });
  }

  @override
  void dispose() {
    _holder?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final holder = _holder;
    if (holder == null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          if (widget.media.posterUrl != null) AspectRatio(aspectRatio: 16 / 9, child: CachedImage(cacheKey: '${widget.cacheKey}-poster', url: widget.media.posterUrl, fit: BoxFit.contain)),
          const CircularProgressIndicator(color: Colors.white70),
        ],
      );
    }
    return holder.build(context);
  }
}
