import 'package:flutter/material.dart';

import '../models/music_models.dart';
import '../screens/collection_detail_page.dart';
import '../state/chimusic_scope.dart';
import '../widgets/glass.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final desktop = isWideWidth(context);
    final featured = controller.featuredCollection;

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeHeader(featured: featured),
              const SizedBox(height: 24),
              if (desktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _FeaturedHero(collection: featured),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(flex: 2, child: _MoodPanel()),
                  ],
                )
              else ...[
                _FeaturedHero(collection: featured),
                const SizedBox(height: 18),
                const _MoodPanel(),
              ],
              const SizedBox(height: 28),
              const SectionHeader(
                title: 'Recently Played',
                subtitle: 'Jump back into what carried your last session',
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.recentCollections.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: desktop ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: desktop ? 2.3 : 1.55,
                ),
                itemBuilder: (context, index) {
                  final collection = controller.recentCollections[index];
                  return _QuickAccessCard(collection: collection);
                },
              ),
              const SizedBox(height: 32),
              for (final shelf in controller.catalog.shelves) ...[
                SectionHeader(title: shelf.title, subtitle: shelf.subtitle),
                const SizedBox(height: 16),
                SizedBox(
                  height: 286,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final collection = controller.collectionsForShelf(
                        shelf,
                      )[index];
                      return _ShelfCollectionCard(collection: collection);
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 14),
                    itemCount: controller.collectionsForShelf(shelf).length,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.featured});

  final MusicCollection featured;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good evening',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'A Spotify-style music home reimagined with liquid glass layers and adaptive Flutter layouts.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          borderRadius: BorderRadius.circular(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Featured Mix',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                featured.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedHero extends StatelessWidget {
  const _FeaturedHero({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(36),
      tintColors: [
        collection.palette.first.withValues(alpha: 0.22),
        collection.palette.last.withValues(alpha: 0.10),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (collection.badge != null) GlassPill(label: collection.badge!),
              GlassPill(label: collection.kind.label),
              GlassPill(label: '${collection.tracks.length} tracks'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtworkCover(
                title: collection.title,
                palette: collection.palette,
                size: isWideWidth(context) ? 184 : 138,
                showTitle: true,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.title,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      collection.subtitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      collection.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.66),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  onTap: () => controller.playCollection(collection),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  tintColors: [
                    collection.palette.first.withValues(alpha: 0.54),
                    collection.palette[1].withValues(alpha: 0.22),
                  ],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded),
                      const SizedBox(width: 10),
                      Text(
                        'Play',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.open_in_full_rounded,
                onTap: () => Navigator.of(
                  context,
                ).push(CollectionDetailPage.route(collection)),
                size: 56,
                iconSize: 24,
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: controller.isCollectionSaved(collection.id)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                onTap: () => controller.toggleSavedCollection(collection.id),
                selected: controller.isCollectionSaved(collection.id),
                size: 56,
                iconSize: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodPanel extends StatelessWidget {
  const _MoodPanel();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tonight\'s motion',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'A soft-cyan UI language, floating playback, and bold navigation surfaces keep the app feeling closer to a premium native player than a demo shell.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              GlassPill(label: 'Liquid'),
              GlassPill(label: 'Focus'),
              GlassPill(label: 'After Dark'),
              GlassPill(label: 'Wide Stereo'),
            ],
          ),
          const SizedBox(height: 18),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(24),
            tintColors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.04),
            ],
            withShadow: false,
            child: Text(
              'Responsive shell: bottom navigation on mobile, glass sidebar on macOS-sized layouts, and a persistent mini player on every platform.',
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

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: () =>
          Navigator.of(context).push(CollectionDetailPage.route(collection)),
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(28),
      child: Row(
        children: [
          ArtworkCover(
            title: collection.title,
            palette: collection.palette,
            size: 74,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  collection.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  collection.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfCollectionCard extends StatelessWidget {
  const _ShelfCollectionCard({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return SizedBox(
      width: 220,
      child: GlassPanel(
        onTap: () =>
            Navigator.of(context).push(CollectionDetailPage.route(collection)),
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkCover(
              title: collection.title,
              palette: collection.palette,
              size: 140,
              showTitle: true,
            ),
            const SizedBox(height: 14),
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
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.72),
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
