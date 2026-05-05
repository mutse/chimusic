import 'package:flutter/material.dart';

import '../models/music_models.dart';
import '../screens/collection_detail_page.dart';
import '../state/chimusic_scope.dart';
import '../widgets/glass.dart';

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

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Find tracks, albums, moods, and ready-made collections instantly.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 20),
              GlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                borderRadius: BorderRadius.circular(28),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onChanged: controller.updateSearchQuery,
                        style: Theme.of(context).textTheme.titleMedium,
                        decoration: const InputDecoration(
                          hintText: 'Artists, songs, playlists, moods',
                        ),
                      ),
                    ),
                    if (hasQuery)
                      GlassIconButton(
                        icon: Icons.close_rounded,
                        size: 38,
                        iconSize: 18,
                        onTap: () {
                          _textController.clear();
                          controller.updateSearchQuery('');
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              if (!hasQuery) ...[
                const SectionHeader(
                  title: 'Browse All',
                  subtitle: 'Quick doors into the mood-driven catalog',
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.catalog.categories.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWideWidth(context) ? 3 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isWideWidth(context) ? 1.8 : 1.35,
                  ),
                  itemBuilder: (context, index) {
                    final category = controller.catalog.categories[index];
                    return _SearchCategoryCard(category: category);
                  },
                ),
              ],
              const SizedBox(height: 28),
              SectionHeader(
                title: hasQuery ? 'Best Matches' : 'Trending Tracks',
                subtitle: hasQuery
                    ? 'Live results across your music space'
                    : 'The current six-track rotation',
              ),
              const SizedBox(height: 16),
              for (
                var index = 0;
                index < controller.searchTrackResults.length;
                index++
              ) ...[
                TrackRow(
                  track: controller.searchTrackResults[index],
                  onTap: () => controller.playTrack(
                    controller.searchTrackResults[index],
                    collection: controller.collectionForTrack(
                      controller.searchTrackResults[index],
                    ),
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        formatDuration(
                          controller.searchTrackResults[index].duration,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.searchTrackResults[index].album,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.50),
                        ),
                      ),
                    ],
                  ),
                ),
                if (index != controller.searchTrackResults.length - 1)
                  const SizedBox(height: 12),
              ],
              const SizedBox(height: 30),
              const SectionHeader(
                title: 'Collections',
                subtitle: 'Albums, playlists, and mixes that match the search',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final collection in controller.searchCollectionResults)
                    _SearchCollectionCard(collection: collection),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchCategoryCard extends StatelessWidget {
  const _SearchCategoryCard({required this.category});

  final SearchCategory category;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(28),
      tintColors: [
        category.palette.first.withValues(alpha: 0.36),
        category.palette.last.withValues(alpha: 0.16),
      ],
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(
              category.icon,
              size: 82,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(category.icon, color: Colors.white.withValues(alpha: 0.86)),
              const Spacer(),
              Text(
                category.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchCollectionCard extends StatelessWidget {
  const _SearchCollectionCard({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final cardWidth = isWideWidth(context) ? 220.0 : 160.0;

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
            ),
            const SizedBox(height: 12),
            Text(
              collection.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              collection.kind.label,
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
