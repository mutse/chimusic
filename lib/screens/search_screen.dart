import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../screens/collection_detail_page.dart';
import '../state/chimusic_controller.dart';
import '../state/chimusic_scope.dart';
import '../widgets/glass.dart';
import '../widgets/local_music_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final query = ChiMusicScope.read(context).searchQuery;
    if (_textController.text != query) {
      _textController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final hasQuery = controller.searchQuery.trim().isNotEmpty;
    final topTrack = controller.searchTrackResults.isEmpty
        ? null
        : controller.searchTrackResults.first;

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassPanel(
                padding: const EdgeInsets.all(22),
                borderRadius: BorderRadius.circular(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explore your imported artists, folders, albums, and audio formats from one fast search surface.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SearchHero(
                controller: controller,
                textController: _textController,
              ),
              const SizedBox(height: 24),
              if (controller.statusMessage != null) ...[
                StatusBanner(
                  message: controller.statusMessage!,
                  onDismiss: controller.clearStatusMessage,
                ),
                const SizedBox(height: 18),
              ],
              if (!controller.hasMusic)
                EmptyMusicState(
                  title: 'Nothing to search yet',
                  body:
                      'Import local files first, then search by track title, artist, album, folder, or file extension.',
                  controller: controller,
                  icon: Icons.search_off_rounded,
                )
              else ...[
                if (controller.recentSearches.isNotEmpty) ...[
                  SectionCard(
                    title: 'Recent Searches',
                    subtitle:
                        'Reusable jumps back into the terms you searched most recently',
                    trailing: GlassPill(
                      label: 'Clear',
                      leading: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                      ),
                      onTap: controller.clearRecentSearches,
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final term in controller.recentSearches)
                          GlassPill(
                            label: term,
                            leading: const Icon(
                              Icons.history_rounded,
                              size: 16,
                            ),
                            onTap: () => controller.applySearchSuggestion(term),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
                SectionCard(
                  title: hasQuery
                      ? 'Matching Suggestions'
                      : 'Trending in Your Library',
                  subtitle: hasQuery
                      ? 'Tap a term to refine the current search direction'
                      : 'Artists, titles, and folders that are showing up most often',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final term in controller.trendingSearches)
                        GlassPill(
                          label: term,
                          leading: const Icon(
                            Icons.trending_up_rounded,
                            size: 16,
                          ),
                          onTap: () => controller.applySearchSuggestion(term),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SectionCard(
                  title: 'Browse All',
                  subtitle:
                      'Discovery cards generated from the strongest metadata inside your local collection',
                  child: _BrowseGrid(terms: controller.browseSuggestions),
                ),
                if (hasQuery && topTrack != null) ...[
                  const SizedBox(height: 30),
                  SectionCard(
                    title: 'Top Result',
                    subtitle:
                        'Best ranked match across your current local music library',
                    child: _TopResultCard(track: topTrack),
                  ),
                ],
                const SizedBox(height: 30),
                SectionCard(
                  title: hasQuery ? 'Tracks' : 'Recent Tracks',
                  subtitle: hasQuery
                      ? 'Search results update while you type'
                      : 'Fresh imports and continue-listening tracks ready to play',
                  child: controller.searchTrackResults.isEmpty
                      ? const _SearchPlaceholder(
                          message: 'No matching tracks were found.',
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < controller.searchTrackResults.length;
                              index++
                            ) ...[
                              TrackRow(
                                track: controller.searchTrackResults[index],
                                onTap: () {
                                  controller.playTrack(
                                    controller.searchTrackResults[index],
                                    collection: controller.collectionForTrack(
                                      controller.searchTrackResults[index],
                                    ),
                                  );
                                },
                                trailing: _SearchTrackActions(
                                  track: controller.searchTrackResults[index],
                                ),
                              ),
                              if (index !=
                                  controller.searchTrackResults.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 30),
                SectionCard(
                  title: hasQuery ? 'Collections' : 'Browse Collections',
                  subtitle: hasQuery
                      ? 'Open a folder or saved mix directly from results'
                      : 'Collections created from your folder structure and saved picks',
                  child: controller.searchCollectionResults.isEmpty
                      ? const _SearchPlaceholder(
                          message: 'No matching collections were found.',
                        )
                      : Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final collection
                                in controller.searchCollectionResults)
                              _SearchCollectionCard(collection: collection),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHero extends StatelessWidget {
  const _SearchHero({required this.controller, required this.textController});

  final MusicAppController controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.searchQuery.trim().isNotEmpty;

    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
        LiquidPalette.surface.withValues(alpha: 0.94),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              GlassPill(label: 'Artists'),
              GlassPill(label: 'Albums'),
              GlassPill(label: 'Folders'),
              GlassPill(label: 'Formats'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Search stays on device and only scans the library you imported into ChiMusic.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.52),
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            borderRadius: BorderRadius.circular(28),
            tintColors: [
              LiquidPalette.surfaceSoft.withValues(alpha: 0.82),
              LiquidPalette.surface.withValues(alpha: 0.92),
            ],
            withShadow: false,
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: textController,
                    onChanged: controller.updateSearchQuery,
                    onSubmitted: controller.submitSearch,
                    textInputAction: TextInputAction.search,
                    style: Theme.of(context).textTheme.titleMedium,
                    decoration: const InputDecoration(
                      hintText:
                          'Search title, artist, album, folder, or file type',
                    ),
                  ),
                ),
                if (hasQuery) ...[
                  const SizedBox(width: 10),
                  GlassIconButton(
                    icon: Icons.close_rounded,
                    size: 38,
                    iconSize: 18,
                    onTap: () {
                      textController.clear();
                      controller.clearSearch();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseGrid extends StatelessWidget {
  const _BrowseGrid({required this.terms});

  final List<String> terms;

  @override
  Widget build(BuildContext context) {
    final palettes = <List<Color>>[
      const [Color(0xFF153C2A), Color(0xFF1ED760)],
      const [Color(0xFF3A280F), Color(0xFFF4A259)],
      const [Color(0xFF10233E), Color(0xFF4B7BFF)],
      const [Color(0xFF3B1E3A), Color(0xFF8B5CF6)],
      const [Color(0xFF3A1628), Color(0xFFE879F9)],
      const [Color(0xFF113643), Color(0xFF2DD4BF)],
    ];
    final controller = ChiMusicScope.watch(context);

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (var index = 0; index < terms.length; index++)
          SizedBox(
            width: isWideWidth(context) ? 220 : double.infinity,
            child: GlassPanel(
              onTap: () => controller.applySearchSuggestion(terms[index]),
              padding: const EdgeInsets.all(18),
              borderRadius: BorderRadius.circular(28),
              tintColors: [
                palettes[index % palettes.length].first.withValues(alpha: 0.72),
                palettes[index % palettes.length].last.withValues(alpha: 0.18),
              ],
              borderColor: palettes[index % palettes.length].last.withValues(
                alpha: 0.12,
              ),
              withShadow: false,
              child: SizedBox(
                height: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                    const Spacer(),
                    Text(
                      terms[index],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search now',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
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

class _TopResultCard extends StatelessWidget {
  const _TopResultCard({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final collection = controller.collectionForTrack(track);

    return GlassPanel(
      onTap: () => controller.playTrack(track, collection: collection),
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        track.palette.first.withValues(alpha: 0.20),
        LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArtworkCover(
            title: track.album,
            palette: track.palette,
            size: 132,
            showTitle: true,
            icon: Icons.music_note_rounded,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${track.artist} • ${collection?.title ?? track.album}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    GlassPill(label: track.typeLabel),
                    if (collection != null)
                      GlassPill(label: collection.kind.label),
                    GlassPill(label: formatDuration(track.duration)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    GlassIconButton(
                      icon: controller.isTrackLiked(track.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      selected: controller.isTrackLiked(track.id),
                      onTap: () => controller.toggleLikedTrack(track.id),
                      size: 48,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassPanel(
                        onTap: () =>
                            controller.playTrack(track, collection: collection),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        tintColors: [
                          LiquidPalette.aqua.withValues(alpha: 0.95),
                          LiquidPalette.mint.withValues(alpha: 0.72),
                        ],
                        borderColor: LiquidPalette.mint.withValues(alpha: 0.24),
                        withShadow: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: LiquidPalette.ink,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Play Result',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: LiquidPalette.ink),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTrackActions extends StatelessWidget {
  const _SearchTrackActions({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          formatDuration(track.duration),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 6),
        GlassIconButton(
          icon: controller.isTrackLiked(track.id)
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          onTap: () => controller.toggleLikedTrack(track.id),
          selected: controller.isTrackLiked(track.id),
          size: 38,
          iconSize: 16,
        ),
      ],
    );
  }
}

class _SearchCollectionCard extends StatelessWidget {
  const _SearchCollectionCard({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final cardWidth = isWideWidth(context) ? 220.0 : 170.0;
    final controller = ChiMusicScope.watch(context);

    return SizedBox(
      width: cardWidth,
      child: GlassPanel(
        onTap: () =>
            Navigator.of(context).push(CollectionDetailPage.route(collection)),
        padding: const EdgeInsets.all(14),
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkCover(
              title: collection.title,
              palette: collection.palette,
              size: cardWidth - 28,
              showTitle: true,
              icon: Icons.folder_rounded,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    collection.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Icon(
                  controller.isCollectionSaved(collection.id)
                      ? Icons.bookmark_rounded
                      : Icons.folder_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              collection.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.64),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.white.withValues(alpha: 0.70),
        ),
      ),
    );
  }
}
