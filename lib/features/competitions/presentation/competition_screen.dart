import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/live_channel.dart';
import '../../../core/widgets/resource_view.dart';
import '../../../core/widgets/rich_html.dart';
import '../../../core/widgets/status_chip.dart';
import '../../artist/data/providers.dart';
import '../../artist/presentation/registration.dart';
import '../data/models.dart';
import '../data/providers.dart';

/// A competition: header, its performances, and four tabs.
class CompetitionScreen extends ConsumerWidget {
  const CompetitionScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(competitionProvider(slug));
    return Scaffold(
      body: ResourceView(
        value: value,
        onRetry: () => ref.invalidate(competitionProvider(slug)),
        builder: (competition, _) => LiveChannel(
          channel: 'competition.${competition.id}',
          child: DefaultTabController(
            length: 4,
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverAppBar(pinned: true, title: Text(competition.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                SliverToBoxAdapter(child: _Header(competition: competition)),
                SliverPersistentHeader(pinned: true, delegate: _TabsHeader(context.colors)),
              ],
              body: TabBarView(
                children: [
                  _Presentation(competition: competition),
                  _Schedule(competition: competition),
                  _Phases(competition: competition),
                  _Regulations(competition: competition),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.competition});

  final CompetitionDetail competition;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: competition.organizerName ?? competition.name, url: competition.organizerLogoUrl, size: 40),
              const SizedBox(width: Space.md),
              Expanded(child: Text(competition.organizerName ?? '', style: context.text.titleSmall)),
            ],
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              StatusChip(Labels.competitionStatus(competition.status), tone: competition.status == 'en_cours' ? ChipTone.live : ChipTone.info),
              StatusChip(Labels.discipline(competition.discipline)),
              StatusChip(
                competition.mode == 'presentiel'
                    ? 'Sur scène'
                    : competition.mode == 'mixte'
                    ? 'En ligne et sur scène'
                    : 'En ligne',
              ),
              StatusChip(Labels.money(competition.entryFee, competition.currency)),
              if (competition.locationLabel != null) StatusChip(competition.locationLabel!),
            ],
          ),
          if (competition.registrationOpen) ...[
            const SizedBox(height: Space.md),
            Text(
              competition.registrationEndsAt == null
                  ? 'Inscriptions ouvertes'
                  : 'Inscriptions ouvertes jusqu\'au ${Labels.day(competition.registrationEndsAt)}',
              style: context.text.bodyMedium?.copyWith(color: c.accent, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: Space.lg),
          _ArtistAction(competition: competition),
          AppButton(
            label: 'Voir les prestations',
            icon: AppIcons.feed,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push('/competitions/${competition.slug}/prestations?titre=${Uri.encodeComponent(competition.name)}'),
          ),
        ],
      ),
    );
  }
}

/// « Mon parcours » for an artist of the competition, « Participer » while registrations are open.
class _ArtistAction extends ConsumerWidget {
  const _ArtistAction({required this.competition});

  final CompetitionDetail competition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(participationsProvider).valueOrNull?.data?.any((p) => p.slug == competition.slug) ?? false;
    if (!mine && !competition.registrationOpen) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: mine
          ? AppButton(label: 'Mon parcours', icon: AppIcons.journey, onPressed: () => context.push('/competitions/${competition.slug}/parcours'))
          : AppButton(label: 'Participer', icon: AppIcons.microphone, onPressed: () => startRegistration(context, ref, competition)),
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader(this.colors);

  final AppColors colors;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(
    color: colors.background,
    child: TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: colors.text,
      unselectedLabelColor: colors.textMuted,
      indicatorColor: colors.primary,
      dividerColor: colors.border,
      labelStyle: context.text.labelLarge,
      tabs: const [
        Tab(text: 'Présentation'),
        Tab(text: 'Programme'),
        Tab(text: 'Phases'),
        Tab(text: 'Règlement'),
      ],
    ),
  );

  @override
  bool shouldRebuild(_TabsHeader old) => old.colors != colors;
}

class _Presentation extends StatelessWidget {
  const _Presentation({required this.competition});

  final CompetitionDetail competition;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        if (competition.description != null && competition.description!.trim().isNotEmpty) RichHtml(competition.description!),
        if (competition.prizes.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Text('À gagner', style: context.text.titleLarge),
          const SizedBox(height: Space.md),
          for (final prize in competition.prizes)
            Container(
              margin: const EdgeInsets.only(bottom: Space.sm),
              padding: const EdgeInsets.all(Space.lg),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.trophy, color: c.warning),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prize.rank, style: context.text.bodySmall),
                        Text(prize.reward, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Schedule extends StatelessWidget {
  const _Schedule({required this.competition});

  final CompetitionDetail competition;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (competition.schedule.isEmpty) {
      return const EmptyState(icon: AppIcons.pending, title: 'Programme bientôt disponible');
    }
    final now = DateTime.now();
    return ListView.builder(
      padding: const EdgeInsets.all(Space.gutter),
      itemCount: competition.schedule.length,
      itemBuilder: (context, i) {
        final step = competition.schedule[i];
        final past = step.date != null && step.date!.isBefore(now);
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: past ? c.success : c.surfaceRaised,
                      shape: BoxShape.circle,
                      border: Border.all(color: past ? c.success : c.primary, width: 2),
                    ),
                  ),
                  if (i < competition.schedule.length - 1) Expanded(child: Container(width: 2, color: c.border)),
                ],
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.title, style: context.text.titleMedium),
                      if (step.date != null) Text(Labels.date(step.date), style: context.text.bodySmall?.copyWith(color: c.accent)),
                      if (step.details != null && step.details!.isNotEmpty) ...[
                        const SizedBox(height: Space.xs),
                        Text(step.details!, style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Phases extends ConsumerStatefulWidget {
  const _Phases({required this.competition});

  final CompetitionDetail competition;

  @override
  ConsumerState<_Phases> createState() => _PhasesState();
}

class _PhasesState extends ConsumerState<_Phases> {
  int? _phase;

  @override
  Widget build(BuildContext context) {
    final phases = widget.competition.phases;
    if (phases.isEmpty) {
      return const EmptyState(icon: AppIcons.trophy, title: 'Phases bientôt annoncées', message: 'L\'organisateur prépare les poules et le tableau.');
    }
    final phase = phases.firstWhere(
      (p) => p.id == _phase,
      orElse: () => phases.firstWhere((p) => p.status == 'en_cours', orElse: () => phases.first),
    );
    final key = (slug: widget.competition.slug, phase: phase.id);
    final c = context.colors;

    return Column(
      children: [
        if (phases.length > 1)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
              children: [
                for (final p in phases)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: ChoiceChip(
                      label: Text(p.title),
                      selected: p.id == phase.id,
                      showCheckmark: false,
                      selectedColor: c.primary,
                      backgroundColor: c.surfaceRaised,
                      labelStyle: context.text.labelMedium?.copyWith(color: p.id == phase.id ? c.onPrimary : c.text),
                      side: BorderSide(color: p.id == phase.id ? c.primary : c.border),
                      shape: const StadiumBorder(),
                      onSelected: (_) => setState(() => _phase = p.id),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ResourceView(
            value: ref.watch(phaseMatchesProvider(key)),
            onRetry: () => ref.invalidate(phaseMatchesProvider(key)),
            builder: (matches, _) => matches.isEmpty
                ? const EmptyState(icon: AppIcons.pending, title: 'Matchs bientôt tirés')
                : ListView.separated(
                    padding: const EdgeInsets.all(Space.gutter),
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                    itemBuilder: (context, i) =>
                        MatchCard(slug: widget.competition.slug, match: matches[i], showRound: i == 0 || matches[i - 1].stage != matches[i].stage),
                  ),
          ),
        ),
      ],
    );
  }
}

/// A group (all its artists) or a battle (two artists), with the scores once public.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.slug, required this.match, this.showRound = false});

  final String slug;
  final MatchSummary match;
  final bool showRound;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showRound && !match.isGroup && match.stage != null) ...[
          Text(match.stage!, style: context.text.titleSmall?.copyWith(color: c.textMuted)),
          const SizedBox(height: Space.sm),
        ],
        Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.lg),
            onTap: () => context.push('/competitions/$slug/matchs/${match.id}'),
            child: Container(
              padding: const EdgeInsets.all(Space.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: match.votingOpen ? c.primary : c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.isGroup ? (match.group ?? match.title) : 'Battle',
                          style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      StatusChip(
                        Labels.matchStatus(match.status),
                        tone: match.votingOpen
                            ? ChipTone.live
                            : match.status == 'cloture'
                            ? ChipTone.success
                            : ChipTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  for (final slot in match.slots)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: Row(
                        children: [
                          Avatar(name: slot.stageName, url: slot.avatarUrl, size: 32),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Text(
                              slot.stageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyLarge?.copyWith(
                                fontWeight: slot.participantId != null && slot.participantId == match.winnerId ? FontWeight.w700 : null,
                                decoration: slot.isForfeit ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (slot.rank != null) Text('${slot.rank}e', style: context.text.labelMedium?.copyWith(color: c.textMuted)),
                          if (slot.finalScore != null) ...[
                            const SizedBox(width: Space.md),
                            Text(
                              slot.finalScore!.toStringAsFixed(1).replaceAll('.', ','),
                              style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (match.votingOpen && match.votingClosesAt != null)
                    Text(
                      'Vote ouvert · ferme ${Labels.remaining(match.votingClosesAt!)}',
                      style: context.text.bodySmall?.copyWith(color: c.accent, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Regulations extends StatelessWidget {
  const _Regulations({required this.competition});

  final CompetitionDetail competition;

  @override
  Widget build(BuildContext context) => competition.regulations == null || competition.regulations!.trim().isEmpty
      ? const EmptyState(icon: AppIcons.pending, title: 'Règlement bientôt publié')
      : ListView(padding: const EdgeInsets.all(Space.gutter), children: [RichHtml(competition.regulations!)]);
}
