import 'package:flutter/material.dart';

import '../models/music_models.dart';
import '../screens/collection_detail_page.dart';
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
                'Search across imported local files and the folders they came from.',
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
                          hintText: 'Title, artist, folder, file name',
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
              const SizedBox(height: 24),
              if (controller.statusMessage != null) ...[
                StatusBanner(message: controller.statusMessage!),
                const SizedBox(height: 18),
              ],
              if (!controller.hasMusic)
                EmptyMusicState(
                  title: 'Nothing to search yet',
                  body:
                      'Import a set of local audio files first, then search by title, folder, or file name.',
                  controller: controller,
                  icon: Icons.search_off_rounded,
                )
              else ...[
                SectionHeader(
                  title: hasQuery ? 'Matching Tracks' : 'Recent Tracks',
                  subtitle: hasQuery
                      ? 'Results update as you type'
                      : 'Your newest imports are ready to play',
                ),
                const SizedBox(height: 16),
                if (controller.searchTrackResults.isEmpty)
                  const _SearchPlaceholder(
                    message: 'No matching tracks were found.',
                  )
                else
                  Column(
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
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formatDuration(
                                  controller.searchTrackResults[index].duration,
                                ),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.68,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                controller.searchTrackResults[index].typeLabel,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.50,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (index != controller.searchTrackResults.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                const SizedBox(height: 30),
                SectionHeader(
                  title: hasQuery ? 'Matching Folders' : 'Imported Folders',
                  subtitle: hasQuery
                      ? 'Open a folder to browse its queue'
                      : 'Folders are generated from your imported file paths',
                ),
                const SizedBox(height: 16),
                if (controller.searchCollectionResults.isEmpty)
                  const _SearchPlaceholder(
                    message: 'No matching folders were found.',
                  )
                else
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final collection
                          in controller.searchCollectionResults)
                        _SearchCollectionCard(collection: collection),
                    ],
                  ),
              ],
            ],
          ),
        ),
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
              icon: Icons.folder_rounded,
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
              collection.subtitle,
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
