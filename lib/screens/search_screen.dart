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
    final activeTracks = controller.activeSearchTracks;
    final topTrack = activeTracks.isEmpty ? null : activeTracks.first;

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassPanel(
                padding: const EdgeInsets.all(20),
                borderRadius: BorderRadius.circular(34),
                tintColors: [
                  LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
                  LiquidPalette.deepCyan.withValues(alpha: 0.78),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Search',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ),
                        const GlassPill(label: '本地搜索'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        GlassPill(
                          label: '${controller.importedTrackCount} tracks',
                        ),
                        GlassPill(label: '${controller.artistCount} artists'),
                        GlassPill(label: '${controller.albumCount} albums'),
                        const GlassPill(label: '离线可用'),
                      ],
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
                      'Import local files first, then search by track title, artist, album, folder, genre, or year.',
                  controller: controller,
                  icon: Icons.search_off_rounded,
                )
              else ...[
                if (controller.recentSearches.isNotEmpty) ...[
                  SectionCard(
                    title: 'Recent Searches',
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
                  title: hasQuery ? 'Suggestions' : 'Trending',
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
                  title: 'Browse',
                  child: _BrowseGrid(terms: controller.browseSuggestions),
                ),
                if (hasQuery && topTrack != null) ...[
                  const SizedBox(height: 30),
                  SectionCard(
                    title: 'Top Result',
                    child: _TopResultCard(track: topTrack),
                  ),
                ],
                const SizedBox(height: 30),
                SectionCard(
                  title: hasQuery ? 'Tracks' : 'Recent Tracks',
                  child: activeTracks.isEmpty
                      ? const _SearchPlaceholder(
                          message: 'No matching tracks were found.',
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < activeTracks.length;
                              index++
                            ) ...[
                              TrackRow(
                                track: activeTracks[index],
                                onTap: () {
                                  controller.playTrack(
                                    activeTracks[index],
                                    collection: controller.collectionForTrack(
                                      activeTracks[index],
                                    ),
                                  );
                                },
                                trailing: _SearchTrackActions(
                                  track: activeTracks[index],
                                ),
                              ),
                              if (index != activeTracks.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 30),
                SectionCard(
                  title: 'Collections',
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
          Text(
            hasQuery ? '本地结果' : '搜索本地音乐',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
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
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration.collapsed(
                      hintText: '搜索歌曲、歌手、专辑、文件夹或格式',
                      hintStyle: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(
                            color: Colors.white.withValues(alpha: 0.42),
                          ),
                    ),
                  ),
                ),
                if (controller.searchQuery.trim().isNotEmpty) ...[
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
          const SizedBox(height: 16),
          if (isWideWidth(context))
            const Row(
              children: [
                Expanded(
                  child: _SearchHeroHint(
                    icon: Icons.library_music_rounded,
                    label: '搜索只读取本机音乐资料库，离线也能立即使用。',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SearchHeroHint(
                    icon: Icons.history_rounded,
                    label: '最近搜索会保存在本机，方便继续找歌。',
                  ),
                ),
              ],
            )
          else
            const Column(
              children: [
                _SearchHeroHint(
                  icon: Icons.library_music_rounded,
                  label: '搜索只读取本机音乐资料库，离线也能立即使用。',
                ),
                SizedBox(height: 12),
                _SearchHeroHint(
                  icon: Icons.history_rounded,
                  label: '最近搜索会保存在本机，方便继续找歌。',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SearchHeroHint extends StatelessWidget {
  const _SearchHeroHint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(22),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.66),
        LiquidPalette.surface.withValues(alpha: 0.90),
      ],
      withShadow: false,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.82)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
              ),
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
    final controller = ChiMusicScope.read(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final term in terms)
          GlassPanel(
            onTap: () => controller.applySearchSuggestion(term),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            borderRadius: BorderRadius.circular(24),
            tintColors: [
              LiquidPalette.surfaceSoft.withValues(alpha: 0.62),
              LiquidPalette.surface.withValues(alpha: 0.92),
            ],
            withShadow: false,
            child: Text(term, style: Theme.of(context).textTheme.titleMedium),
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
    final controller = ChiMusicScope.read(context);

    return GlassPanel(
      onTap: () {
        controller.playTrack(
          track,
          collection: controller.collectionForTrack(track),
        );
      },
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(30),
      tintColors: [
        track.palette.first.withValues(alpha: 0.28),
        LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
      ],
      withShadow: false,
      child: Row(
        children: [
          ArtworkCover(
            title: track.album,
            palette: track.palette,
            size: 92,
            showTitle: true,
            icon: Icons.music_note_rounded,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${track.artist} • ${track.album}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (track.genre case final genre?) GlassPill(label: genre),
                    if (track.year case final year?) GlassPill(label: '$year'),
                    GlassPill(label: formatDuration(track.duration)),
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (track.genre case final genre?) GlassPill(label: genre),
        GlassPill(
          label: controller.isTrackLiked(track.id) ? 'Liked' : 'Like',
          onTap: () => controller.toggleLikedTrack(track.id),
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
    return SizedBox(
      width: isWideWidth(context) ? 250 : double.infinity,
      child: GlassPanel(
        onTap: () {
          Navigator.of(context).push(CollectionDetailPage.route(collection));
        },
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(28),
        tintColors: [
          collection.palette.first.withValues(alpha: 0.26),
          LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
        ],
        withShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkCover(
              title: collection.title,
              palette: collection.palette,
              size: 96,
              showTitle: true,
              icon: collection.kind == MusicCollectionKind.folder
                  ? Icons.folder_rounded
                  : Icons.queue_music_rounded,
            ),
            const SizedBox(height: 14),
            Text(
              collection.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              collection.subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
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
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Colors.white.withValues(alpha: 0.66),
      ),
    );
  }
}
