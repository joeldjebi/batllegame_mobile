import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/resource_view.dart';
import '../../battles/data/battles.dart';
import '../data/models.dart';
import '../data/providers.dart';

const _filters = [
  (label: 'Toutes', status: null),
  (label: 'En cours', status: 'en_cours'),
  (label: 'Inscriptions', status: 'inscriptions'),
  (label: 'Terminées', status: 'terminee'),
];

/// Découvrir: every public competition, filtered by status.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = ref.watch(competitionsProvider(_status));

    return ColoredBox(
      color: groupedBackground(context),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: LargeTitle(
                'Découvrir',
                trailing: IconButton(
                  tooltip: 'Rechercher',
                  onPressed: () => context.push('/recherche'),
                  icon: Icon(AppIcons.search, color: c.text),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
              child: _Segmented(selected: _status, onChanged: (status) => setState(() => _status = status)),
            ),
            Expanded(
              child: ResourceView(
                value: value,
                onRetry: () => ref.invalidate(competitionsProvider(_status)),
                builder: (page, resource) => RefreshIndicator(
                  color: c.primary,
                  onRefresh: () async => ref.invalidate(competitionsProvider(_status)),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: Space.xxl),
                    children: [
                      // « Toutes »: what happens now first, then the list.
                      if (_status == null) ...[
                        _LiveNow(competitions: page.items),
                        _OpenRegistrations(competitions: page.items, onSeeAll: () => setState(() => _status = 'inscriptions')),
                      ],
                      if (page.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(Space.gutter, Space.xxxl, Space.gutter, 0),
                          child: EmptyState(icon: AppIcons.trophy, title: 'Aucune compétition', message: 'Reviens bientôt : de nouvelles battles arrivent.'),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                          child: GroupedSection(
                            header: _status == null ? 'Toutes les compétitions' : '${page.items.length} compétition${page.items.length > 1 ? 's' : ''}',
                            children: [
                              for (final competition in _favoritesFirst(page.items, ref.watch(favoriteDisciplinesProvider)))
                                CompetitionCard(competition: competition),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The competitions of the favorite disciplines first (order kept otherwise).
List<CompetitionSummary> _favoritesFirst(List<CompetitionSummary> items, Set<String> favorites) =>
    favorites.isEmpty ? items : [...items.where((c) => favorites.contains(c.discipline)), ...items.where((c) => !favorites.contains(c.discipline))];

/// Status filter, the iOS segmented control way.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final light = Theme.of(context).brightness == Brightness.light;
    // 36 px control, 48 px touch area.
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Positioned.fill(
            top: 6,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(color: light ? const Color(0x1F767680) : c.surfaceRaised, borderRadius: BorderRadius.circular(Radii.md)),
            ),
          ),
          Row(
            children: [
              for (final filter in _filters)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: filter.status == selected,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(filter.status),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: filter.status == selected ? (light ? Colors.white : c.surface) : Colors.transparent,
                            borderRadius: BorderRadius.circular(Radii.md - 2),
                            boxShadow: filter.status == selected && light
                                ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 1))]
                                : null,
                          ),
                          child: Text(
                            filter.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelMedium?.copyWith(color: c.text, fontWeight: filter.status == selected ? FontWeight.w700 : FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One competition, as a row of a grouped section: logo, name, organizer, then its
/// status, discipline and price as three small tags, and the registration deadline.
class CompetitionCard extends StatelessWidget {
  const CompetitionCard({super.key, required this.competition});

  final CompetitionSummary competition;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = switch (competition.status) {
      'en_cours' => ('En cours', c.like),
      'inscriptions' => ('Inscriptions', c.success),
      'terminee' => ('Terminée', c.textMuted),
      _ => (Labels.competitionStatus(competition.status), c.textMuted),
    };
    final free = competition.entryFee <= 0;
    final deadline = competition.registrationOpen && competition.registrationEndsAt != null
        ? 'Inscriptions jusqu\'au ${DateFormat('d MMMM', 'fr').format(competition.registrationEndsAt!.toLocal())}'
        : null;

    return GroupedTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: Avatar(name: competition.organizerName ?? competition.name, url: competition.organizerLogoUrl, size: 48),
      ),
      title: competition.name,
      subtitle: competition.organizerName,
      detail: Padding(
        padding: const EdgeInsets.only(top: Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                _Tag(label: label, color: color, dot: true),
                _Tag(label: Labels.discipline(competition.discipline), icon: AppIcons.microphone),
                _Tag(
                  label: free ? 'Gratuit' : Labels.money(competition.entryFee, competition.currency),
                  color: free ? c.success : null,
                  icon: AppIcons.payment,
                ),
              ],
            ),
            if (deadline != null) ...[const SizedBox(height: Space.xs), Text(deadline, style: context.text.labelSmall?.copyWith(color: c.textMuted))],
          ],
        ),
      ),
      onTap: () => context.push('/competitions/${competition.slug}'),
    );
  }
}

/// Small tag: tinted when it carries a color (status, free), grey otherwise.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color, this.icon, this.dot = false});

  final String label;
  final Color? color;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: (color ?? c.textMuted).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          if (icon != null && !dot) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// « En vote maintenant »: the competitions whose public vote is open, as cards with
/// their cover and how many groups are open; a tap opens the full program.
class _LiveNow extends ConsumerWidget {
  const _LiveNow({required this.competitions});

  final List<CompetitionSummary> competitions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(battlesProvider).valueOrNull?.data?.open ?? const <Battle>[];
    if (open.isEmpty) return const SizedBox.shrink();
    final byCompetition = <String, List<Battle>>{};
    for (final battle in open) {
      byCompetition.putIfAbsent(battle.competitionSlug, () => []).add(battle);
    }
    final covers = {for (final c in competitions) c.slug: c.coverUrl};

    return _Carousel(
      title: 'En vote maintenant',
      children: [
        for (final battles in byCompetition.values)
          () {
            final first = battles.first;
            final closes = battles.map((b) => b.closesAt).whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
            final poster = battles.expand((b) => b.artists).map((a) => a.media?.posterUrl).whereType<String>().firstOrNull;
            return _CoverCard(
              imageKey: 'cover-${first.competitionSlug}',
              imageUrl: covers[first.competitionSlug] ?? poster,
              badge: 'En vote',
              title: first.competitionName,
              lines: [
                '${battles.length} ${first.isGroup ? (battles.length > 1 ? 'poules' : 'poule') : (battles.length > 1 ? 'battles' : 'battle')} en vote',
                if (closes != null) 'Ferme ${Labels.remaining(closes)}',
              ],
              onTap: () => context.push('/competitions/${first.competitionSlug}?onglet=phases'),
            );
          }(),
      ],
    );
  }
}

/// « Inscriptions ouvertes »: places left, the first prize and a countdown near the deadline.
class _OpenRegistrations extends StatelessWidget {
  const _OpenRegistrations({required this.competitions, required this.onSeeAll});

  final List<CompetitionSummary> competitions;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final open = competitions.where((c) => c.registrationOpen).toList();
    if (open.isEmpty) return const SizedBox.shrink();
    return _Carousel(
      title: 'Inscriptions ouvertes',
      onSeeAll: onSeeAll,
      children: [
        for (final c in open)
          _CoverCard(
            imageKey: 'cover-${c.slug}',
            imageUrl: c.coverUrl,
            badge: _deadline(c.registrationEndsAt),
            urgent: c.registrationEndsAt != null && c.registrationEndsAt!.difference(DateTime.now()).inDays < 7,
            title: c.name,
            lines: [
              [?c.organizerName, if (c.placesLeft != null) '${c.placesLeft} place${c.placesLeft! > 1 ? 's' : ''} sur ${c.maxParticipants}'].join(' · '),
              if (c.topPrize != null) '${c.topPrize!.rank} : ${c.topPrize!.reward}',
            ],
            action: 'S\'inscrire${c.entryFee > 0 ? ' · ${Labels.money(c.entryFee, c.currency)}' : ''}',
            onTap: () => context.push('/competitions/${c.slug}'),
          ),
      ],
    );
  }

  static String? _deadline(DateTime? ends) {
    if (ends == null) return null;
    final days = ends.difference(DateTime.now()).inDays;
    if (days < 1) return 'Dernier jour';
    if (days < 7) return 'Plus que $days jour${days > 1 ? 's' : ''}';
    return 'Jusqu\'au ${DateFormat('d MMM', 'fr').format(ends.toLocal())}';
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({required this.title, required this.children, this.onSeeAll});

  final String title;
  final List<Widget> children;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xs, 0, Space.gutter, Space.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (onSeeAll != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: TextButton(
                    onPressed: onSeeAll,
                    child: const Text('Tout voir', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
            ],
          ),
        ),
        // Full width (the page list has no side padding): the cards scroll to the edges.
        // As tall as the tallest card (any text size), all cards the same height.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: Space.md), children[i]],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// A card of a carousel: 16:9 cover with a badge, title, two lines and an optional action.
class _CoverCard extends StatelessWidget {
  const _CoverCard({
    required this.imageKey,
    required this.title,
    required this.lines,
    required this.onTap,
    this.imageUrl,
    this.badge,
    this.urgent = false,
    this.action,
  });

  final String imageKey;
  final String? imageUrl;
  final String? badge;
  final bool urgent;
  final String title;
  final List<String> lines;
  final String? action;
  final VoidCallback onTap;

  static const double width = 264;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: width,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: c.primary.withValues(alpha: 0.15),
                      child: imageUrl == null ? Icon(AppIcons.trophy, color: c.primary, size: 36) : CachedImage(cacheKey: imageKey, url: imageUrl),
                    ),
                    if (badge != null)
                      Positioned(
                        left: Space.sm,
                        top: Space.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
                          decoration: BoxDecoration(
                            color: urgent || badge == 'En vote' ? c.like : Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Text(
                            badge!,
                            style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      for (final line in lines.where((l) => l.isNotEmpty))
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(color: c.textMuted),
                        ),
                      if (action != null) ...[const Spacer(), const SizedBox(height: Space.md)],
                      if (action != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: Space.sm),
                          decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.pill)),
                          alignment: Alignment.center,
                          child: Text(
                            action!,
                            style: context.text.labelLarge?.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
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
