import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../competitions/presentation/discover_screen.dart';
import '../../feed/data/feed_item.dart';
import '../data/search.dart';

const _tabs = ['Top', 'Vidéos', 'Artistes', 'Compétitions'];

/// Search, the TikTok way: a rounded field at the top, recent searches and
/// suggestions while it is empty, then results by tab (live while typing).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with SingleTickerProviderStateMixin {
  late final _field = TextEditingController(text: widget.initialQuery);
  late final _tabsController = TabController(length: _tabs.length, vsync: this);
  final _focus = FocusNode();
  Timer? _debounce;
  late String _query = widget.initialQuery.trim();

  @override
  void initState() {
    super.initState();
    if (_query.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    _tabsController.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  /// Search now (keyboard « Rechercher », a recent search, an artist…) and remember it.
  void _search(String value, {int? tab}) {
    final query = value.trim();
    _debounce?.cancel();
    _field.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _focus.unfocus();
    setState(() => _query = query);
    if (tab != null) _tabsController.animateTo(tab);
    unawaited(ref.read(searchHistoryProvider.notifier).add(query));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.gutter, Space.sm),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Retour',
                    onPressed: () => context.pop(),
                    icon: Icon(AppIcons.back, color: c.text),
                  ),
                  Expanded(
                    child: _Field(controller: _field, focus: _focus, onChanged: _onChanged, onSubmitted: _search),
                  ),
                  const SizedBox(width: Space.md),
                  GestureDetector(
                    onTap: () => _search(_field.text),
                    child: Text(
                      'Rechercher',
                      style: context.text.titleSmall?.copyWith(color: c.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _Suggestions(onSearch: _search)
                  : Column(
                      children: [
                        TabBar(
                          controller: _tabsController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelColor: c.text,
                          unselectedLabelColor: c.textMuted,
                          labelStyle: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          unselectedLabelStyle: context.text.titleSmall,
                          indicatorColor: c.text,
                          indicatorSize: TabBarIndicatorSize.label,
                          dividerColor: c.border,
                          tabs: [for (final tab in _tabs) Tab(text: tab)],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabsController,
                            children: [
                              _TopResults(query: _query, onArtist: (a) => _search(a.stageName, tab: 1), onMore: _tabsController.animateTo),
                              _VideosGrid(query: _query),
                              _ArtistsList(query: _query, onArtist: (a) => _search(a.stageName, tab: 1)),
                              _CompetitionsList(query: _query),
                            ],
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

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.focus, required this.onChanged, required this.onSubmitted});

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      height: 40,
      decoration: BoxDecoration(color: light ? const Color(0xFFF1F1F2) : c.surfaceRaised, borderRadius: BorderRadius.circular(Radii.sm)),
      child: Row(
        children: [
          const SizedBox(width: Space.md),
          Icon(AppIcons.search, size: 18, color: c.textMuted),
          const SizedBox(width: Space.sm),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: context.text.bodyLarge,
              cursorColor: c.primary,
              decoration: InputDecoration(
                hintText: 'Artistes, compétitions…',
                hintStyle: context.text.bodyLarge?.copyWith(color: c.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: Space.md)
                : IconButton(
                    tooltip: 'Effacer',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(AppIcons.close, size: 16, color: c.textMuted),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                      focus.requestFocus();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Empty field: recent searches, then suggested artists and competitions.
class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.onSearch});

  final void Function(String query, {int? tab}) onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final history = ref.watch(searchHistoryProvider);
    final suggestions = ref.watch(searchProvider('')).valueOrNull;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text('Recherches récentes', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              TextButton(onPressed: () => ref.read(searchHistoryProvider.notifier).clear(), child: const Text('Tout effacer')),
            ],
          ),
          for (final query in history)
            InkWell(
              onTap: () => onSearch(query),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Row(
                  children: [
                    Icon(AppIcons.pending, size: 18, color: c.textMuted),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyLarge),
                    ),
                    GestureDetector(
                      onTap: () => ref.read(searchHistoryProvider.notifier).remove(query),
                      child: Padding(
                        padding: const EdgeInsets.all(Space.xs),
                        child: Icon(AppIcons.close, size: 16, color: c.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Space.xl),
        ],
        if (suggestions != null && suggestions.artists.isNotEmpty) ...[
          Text('Artistes à découvrir', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: Space.md),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.artists.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.lg),
              itemBuilder: (context, i) => _ArtistBubble(artist: suggestions.artists[i], onTap: () => onSearch(suggestions.artists[i].stageName, tab: 1)),
            ),
          ),
          const SizedBox(height: Space.xl),
        ],
        if (suggestions != null && suggestions.competitions.isNotEmpty) ...[
          Text('Compétitions du moment', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: Space.sm),
          for (final competition in suggestions.competitions)
            InkWell(
              onTap: () => context.push('/competitions/${competition.slug}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Row(
                  children: [
                    Icon(AppIcons.search, size: 18, color: c.textMuted),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(competition.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyLarge),
                    ),
                    Icon(AppIcons.forward, size: 14, color: c.textMuted),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ArtistBubble extends StatelessWidget {
  const _ArtistBubble({required this.artist, required this.onTap});

  final SearchArtist artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 68,
      child: Column(
        children: [
          Avatar(name: artist.stageName, url: artist.avatarUrl, size: 60),
          const SizedBox(height: Space.xs),
          Text(artist.stageName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: context.text.labelSmall),
        ],
      ),
    ),
  );
}

/// « Top »: a few artists, competitions and videos, each with a link to its tab.
class _TopResults extends ConsumerWidget {
  const _TopResults({required this.query, required this.onArtist, required this.onMore});

  final String query;
  final ValueChanged<SearchArtist> onArtist;
  final ValueChanged<int> onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchProvider(query));
    final videos = ref.watch(searchVideosProvider(query));
    if (results.isLoading && videos.isLoading) return const Center(child: CircularProgressIndicator());
    final data = results.valueOrNull ?? const SearchResults();
    final items = videos.valueOrNull ?? const <FeedItem>[];
    if (data.artists.isEmpty && data.competitions.isEmpty && items.isEmpty) return _NoResult(query: query);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(0, Space.lg, 0, Space.xxl),
      children: [
        if (data.artists.isNotEmpty) ...[
          _SectionTitle('Artistes', onMore: () => onMore(2)),
          for (final artist in data.artists.take(3)) _ArtistRow(artist: artist, onTap: () => onArtist(artist)),
          const SizedBox(height: Space.lg),
        ],
        if (data.competitions.isNotEmpty) ...[
          _SectionTitle('Compétitions', onMore: () => onMore(3)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: GroupedSection(children: [for (final competition in data.competitions.take(3)) CompetitionCard(competition: competition)]),
          ),
        ],
        if (items.isNotEmpty) ...[_SectionTitle('Vidéos', onMore: () => onMore(1)), _Grid(items: items.take(6).toList(), shrink: true)],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {required this.onMore});

  final String title;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.sm, Space.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        TextButton(onPressed: onMore, child: const Text('Tout voir')),
      ],
    ),
  );
}

class _VideosGrid extends ConsumerWidget {
  const _VideosGrid({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(searchVideosProvider(query))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: AppIcons.offline, title: 'Recherche indisponible', message: 'Vérifie ta connexion et réessaie.'),
        data: (items) => items.isEmpty ? _NoResult(query: query) : _Grid(items: items),
      );
}

/// Three columns of vertical posters, the artist on each; a tap plays the video.
class _Grid extends StatelessWidget {
  const _Grid({required this.items, this.shrink = false});

  final List<FeedItem> items;
  final bool shrink;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: shrink,
    physics: shrink ? const NeverScrollableScrollPhysics() : null,
    padding: const EdgeInsets.all(2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 0.66),
    itemCount: items.length,
    itemBuilder: (context, i) {
      final item = items[i];
      return GestureDetector(
        onTap: () => context.push('/lecture', extra: (key: item.key, media: item.media, title: item.stageName)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xFF1E1E2A),
              child: item.media.posterUrl == null ? null : CachedImage(cacheKey: '${item.key}-poster', url: item.media.posterUrl),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.sm, Space.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.stageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      item.competitionName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: Colors.white70),
                    ),
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

class _ArtistsList extends ConsumerWidget {
  const _ArtistsList({required this.query, required this.onArtist});

  final String query;
  final ValueChanged<SearchArtist> onArtist;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(searchProvider(query))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: AppIcons.offline, title: 'Recherche indisponible', message: 'Vérifie ta connexion et réessaie.'),
        data: (results) => results.artists.isEmpty
            ? _NoResult(query: query)
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: Space.md),
                children: [for (final artist in results.artists) _ArtistRow(artist: artist, onTap: () => onArtist(artist))],
              ),
      );
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.artist, required this.onTap});

  final SearchArtist artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
      child: Row(
        children: [
          Avatar(name: artist.stageName, url: artist.avatarUrl, size: 52),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artist.stageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  artist.competitionName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                ),
              ],
            ),
          ),
          Icon(AppIcons.forward, size: 14, color: context.colors.textMuted),
        ],
      ),
    ),
  );
}

class _CompetitionsList extends ConsumerWidget {
  const _CompetitionsList({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(searchProvider(query))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: AppIcons.offline, title: 'Recherche indisponible', message: 'Vérifie ta connexion et réessaie.'),
        data: (results) => results.competitions.isEmpty
            ? _NoResult(query: query)
            : ListView(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xxl),
                children: [
                  GroupedSection(children: [for (final competition in results.competitions) CompetitionCard(competition: competition)]),
                ],
              ),
      );
}

class _NoResult extends StatelessWidget {
  const _NoResult({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: Space.xxxl),
      EmptyState(icon: AppIcons.search, title: 'Aucun résultat', message: 'Rien ne correspond à « $query ». Essaie un nom d\'artiste ou de compétition.'),
    ],
  );
}
