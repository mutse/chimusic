import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../state/chimusic_scope.dart';
import '../widgets/glass.dart';

class CollectionDetailPage extends StatelessWidget {
  const CollectionDetailPage({super.key, required this.collection});

  final MusicCollection collection;

  static Route<void> route(MusicCollection collection) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          CollectionDetailPage(collection: collection),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final wide = isWideWidth(context);
    final likedInCollection = collection.tracks
        .where((track) => controller.isTrackLiked(track.id))
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: pagePadding(context, bottom: 52),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 46),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _CollectionHero(collection: collection),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                flex: 2,
                                child: _CollectionInsights(
                                  collection: collection,
                                  likedCount: likedInCollection,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _CollectionHero(collection: collection),
                          const SizedBox(height: 18),
                          _CollectionInsights(
                            collection: collection,
                            likedCount: likedInCollection,
                          ),
                        ],
                        const SizedBox(height: 30),
                        const SectionHeader(
                          title: 'Track List',
                          subtitle:
                              'Queue this collection front to back or jump straight into a specific track',
                        ),
                        const SizedBox(height: 16),
                        GlassPanel(
                          padding: const EdgeInsets.all(14),
                          borderRadius: BorderRadius.circular(32),
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < collection.tracks.length;
                                index++
                              ) ...[
                                _CollectionTrackRow(
                                  collection: collection,
                                  track: collection.tracks[index],
                                  index: index,
                                ),
                                if (index != collection.tracks.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    GlassIconButton(
                      icon: controller.isCollectionSaved(collection.id)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      selected: controller.isCollectionSaved(collection.id),
                      onTap: () =>
                          controller.toggleSavedCollection(collection.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionHero extends StatelessWidget {
  const _CollectionHero({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final isSaved = controller.isCollectionSaved(collection.id);

    return GlassPanel(
      padding: const EdgeInsets.all(26),
      borderRadius: BorderRadius.circular(38),
      tintColors: [
        collection.palette.first.withValues(alpha: 0.36),
        LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(label: collection.kind.label),
              GlassPill(label: '${collection.tracks.length} tracks'),
              GlassPill(label: formatRuntime(collection.totalDuration)),
            ],
          ),
          const SizedBox(height: 20),
          if (isWideWidth(context))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArtworkCover(
                  title: collection.title,
                  palette: collection.palette,
                  size: 200,
                  showTitle: true,
                  icon: collection.kind == MusicCollectionKind.folder
                      ? Icons.folder_rounded
                      : Icons.queue_music_rounded,
                ),
                const SizedBox(width: 18),
                Expanded(child: _HeroCopy(collection: collection)),
              ],
            )
          else ...[
            Center(
              child: ArtworkCover(
                title: collection.title,
                palette: collection.palette,
                size: 220,
                showTitle: true,
                icon: collection.kind == MusicCollectionKind.folder
                    ? Icons.folder_rounded
                    : Icons.queue_music_rounded,
              ),
            ),
            const SizedBox(height: 20),
            _HeroCopy(collection: collection),
          ],
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
                    LiquidPalette.aqua.withValues(alpha: 0.95),
                    LiquidPalette.mint.withValues(alpha: 0.72),
                  ],
                  borderColor: LiquidPalette.mint.withValues(alpha: 0.26),
                  withShadow: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: LiquidPalette.ink,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Play Collection',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: LiquidPalette.ink),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: isSaved ? Icons.check_rounded : Icons.add_rounded,
                selected: isSaved,
                onTap: () => controller.toggleSavedCollection(collection.id),
                size: 56,
                iconSize: 24,
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.search_rounded,
                onTap: () {
                  controller.openSearch(collection.title);
                  Navigator.of(context).pop();
                },
                size: 56,
                iconSize: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(collection.title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 10),
        Text(
          collection.subtitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          collection.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.70),
          ),
        ),
      ],
    );
  }
}

class _CollectionInsights extends StatelessWidget {
  const _CollectionInsights({
    required this.collection,
    required this.likedCount,
  });

  final MusicCollection collection;
  final int likedCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collection Stats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const _InsightLabel(
                icon: Icons.graphic_eq_rounded,
                title: 'Tracks',
              ),
              const SizedBox(height: 6),
              Text(
                '${collection.tracks.length}',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              const _InsightLabel(
                icon: Icons.schedule_rounded,
                title: 'Total Runtime',
              ),
              const SizedBox(height: 6),
              Text(
                formatRuntime(collection.totalDuration),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              const _InsightLabel(
                icon: Icons.favorite_rounded,
                title: 'Liked Inside This Collection',
              ),
              const SizedBox(height: 6),
              Text(
                '$likedCount',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassPanel(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(32),
          tintColors: [
            LiquidPalette.surfaceSoft.withValues(alpha: 0.78),
            LiquidPalette.surfaceRaised.withValues(alpha: 0.92),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About This View',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'This detail page is tied to your live local library. Save it, play it as one queue, or bounce back into Search with the collection title prefilled.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightLabel extends StatelessWidget {
  const _InsightLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.70)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.52),
          ),
        ),
      ],
    );
  }
}

class _CollectionTrackRow extends StatelessWidget {
  const _CollectionTrackRow({
    required this.collection,
    required this.track,
    required this.index,
  });

  final MusicCollection collection;
  final Track track;
  final int index;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return TrackRow(
      track: track,
      onTap: () => controller.playTrack(track, collection: collection),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${index + 1}'.padLeft(2, '0'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.48),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatDuration(track.duration),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.64),
            ),
          ),
          const SizedBox(width: 10),
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
      ),
    );
  }
}
