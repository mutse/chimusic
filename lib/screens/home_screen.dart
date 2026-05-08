import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../screens/collection_detail_page.dart';
import '../state/chimusic_controller.dart';
import '../state/chimusic_scope.dart';
import '../widgets/glass.dart';
import '../widgets/local_music_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeHeader(controller: controller),
              const SizedBox(height: 24),
              if (controller.statusMessage != null) ...[
                StatusBanner(
                  message: controller.statusMessage!,
                  onDismiss: controller.clearStatusMessage,
                ),
                const SizedBox(height: 18),
              ],
              if (!controller.hasMusic)
                _HomeOnboarding(controller: controller)
              else
                _HomeContent(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final greeting = _buildGreeting();
    final wide = isWideWidth(context);

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
        LiquidPalette.deepCyan.withValues(alpha: 0.80),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      LiquidPalette.aqua.withValues(alpha: 0.92),
                      LiquidPalette.mint.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.multitrack_audio_rounded,
                  color: LiquidPalette.ink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.hasMusic
                          ? 'Your local library is ready.'
                          : 'Import music to build your home feed.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.search_rounded,
                onTap: controller.openSearch,
                size: 48,
                iconSize: 22,
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: wide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: wide ? 1.55 : 1.18,
            children: [
              MetricGlassCard(
                value: '${controller.importedTrackCount}',
                label: 'Tracks',
                icon: Icons.music_note_rounded,
                onTap: () => controller.openLibraryFilter(LibraryFilter.tracks),
                accent: const [Color(0xFF153C2A), Color(0xFF1ED760)],
              ),
              MetricGlassCard(
                value: '${controller.collectionCount}',
                label: 'Folders',
                icon: Icons.folder_rounded,
                onTap: () =>
                    controller.openLibraryFilter(LibraryFilter.folders),
                accent: const [Color(0xFF3A280F), Color(0xFFF4A259)],
              ),
              MetricGlassCard(
                value: '${controller.likedTracksCount}',
                label: 'Liked',
                icon: Icons.favorite_rounded,
                onTap: () =>
                    controller.openLibraryFilter(LibraryFilter.favorites),
                accent: const [Color(0xFF3B1E3A), Color(0xFF8B5CF6)],
              ),
              MetricGlassCard(
                value: controller.hasMusic ? 'Open' : 'Import',
                label: controller.hasMusic ? 'Search' : 'Files',
                icon: controller.hasMusic
                    ? Icons.travel_explore_rounded
                    : Icons.audio_file_rounded,
                onTap: controller.hasMusic
                    ? controller.openSearch
                    : () {
                        controller.importLocalFiles();
                      },
                accent: const [Color(0xFF10233E), Color(0xFF4B7BFF)],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }
}

class _HomeOnboarding extends StatelessWidget {
  const _HomeOnboarding({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final wide = isWideWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _OnboardingHero(controller: controller)),
              const SizedBox(width: 18),
              const Expanded(flex: 2, child: _OnboardingFeatureStack()),
            ],
          )
        else ...[
          _OnboardingHero(controller: controller),
          const SizedBox(height: 18),
          const _OnboardingFeatureStack(),
        ],
      ],
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(36),
      tintColors: [
        LiquidPalette.deepCyan.withValues(alpha: 0.86),
        LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              GlassPill(label: 'Home'),
              GlassPill(label: 'Search'),
              GlassPill(label: 'Library'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Turn local files into a full music app experience.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Import once, then browse Home, Search, and Library as clean music surfaces built from your own files.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 24),
          ImportMusicActions(controller: controller),
        ],
      ),
    );
  }
}

class _OnboardingFeatureStack extends StatelessWidget {
  const _OnboardingFeatureStack();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _FeatureCard(
          icon: Icons.play_circle_fill_rounded,
          title: 'Continue Listening',
          body: 'Recent plays surface automatically.',
        ),
        SizedBox(height: 14),
        _FeatureCard(
          icon: Icons.travel_explore_rounded,
          title: 'Search Discovery',
          body: 'Artists, albums, folders, and formats.',
        ),
        SizedBox(height: 14),
        _FeatureCard(
          icon: Icons.bookmark_rounded,
          title: 'Saved Library',
          body: 'Pins, likes, and quick access stay close.',
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: LiquidPalette.aqua.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: LiquidPalette.mint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.66),
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

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final featured = controller.featuredCollection;
    final wide = isWideWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featured != null)
          SectionCard(
            title: 'Featured',
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _FeaturedCollectionHero(collection: featured),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 2,
                        child: _SessionSnapshot(controller: controller),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _FeaturedCollectionHero(collection: featured),
                      const SizedBox(height: 18),
                      _SessionSnapshot(controller: controller),
                    ],
                  ),
          ),
        const SizedBox(height: 30),
        SectionCard(
          title: 'Recently Played',
          child: _ListeningGrid(controller: controller),
        ),
        const SizedBox(height: 30),
        SectionCard(
          title: 'Collections',
          child: SizedBox(
            height: 286,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.spotlightCollections.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) => _CollectionCard(
                collection: controller.spotlightCollections[index],
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        SectionCard(
          title: 'Quick Picks',
          child: _QuickAccessGrid(controller: controller),
        ),
        const SizedBox(height: 30),
        SectionCard(
          title: 'Fresh Finds',
          child: Column(
            children: [
              for (
                var index = 0;
                index < controller.spotlightTracks.length;
                index++
              ) ...[
                TrackRow(
                  track: controller.spotlightTracks[index],
                  onTap: () {
                    controller.playTrack(
                      controller.spotlightTracks[index],
                      collection: controller.collectionForTrack(
                        controller.spotlightTracks[index],
                      ),
                    );
                  },
                  trailing: _TrackActions(
                    track: controller.spotlightTracks[index],
                  ),
                ),
                if (index != controller.spotlightTracks.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedCollectionHero extends StatelessWidget {
  const _FeaturedCollectionHero({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final wide = isWideWidth(context);

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(32),
      tintColors: [
        collection.palette.first.withValues(alpha: 0.22),
        LiquidPalette.surfaceRaised.withValues(alpha: 0.95),
      ],
      withShadow: false,
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
          wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ArtworkCover(
                      title: collection.title,
                      palette: collection.palette,
                      size: 184,
                      showTitle: true,
                      icon: Icons.graphic_eq_rounded,
                    ),
                    const SizedBox(width: 18),
                    Expanded(child: _FeaturedCollectionDetails(collection)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ArtworkCover(
                      title: collection.title,
                      palette: collection.palette,
                      size: 164,
                      showTitle: true,
                      icon: Icons.graphic_eq_rounded,
                    ),
                    const SizedBox(height: 18),
                    _FeaturedCollectionDetails(collection),
                  ],
                ),
        ],
      ),
    );
  }
}

class _FeaturedCollectionDetails extends StatelessWidget {
  const _FeaturedCollectionDetails(this.collection);

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          collection.title,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 10),
        Text(
          collection.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.74),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GlassPanel(
                onTap: () => controller.playCollection(collection),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                borderRadius: BorderRadius.circular(24),
                tintColors: [
                  LiquidPalette.aqua.withValues(alpha: 0.95),
                  LiquidPalette.mint.withValues(alpha: 0.72),
                ],
                borderColor: LiquidPalette.mint.withValues(alpha: 0.30),
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
                      'Play Collection',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: LiquidPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            GlassIconButton(
              icon: controller.isCollectionSaved(collection.id)
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              selected: controller.isCollectionSaved(collection.id),
              onTap: () => controller.toggleSavedCollection(collection.id),
              size: 56,
              iconSize: 24,
            ),
            const SizedBox(width: 12),
            GlassIconButton(
              icon: Icons.arrow_forward_rounded,
              onTap: () => Navigator.of(
                context,
              ).push(CollectionDetailPage.route(collection)),
              size: 56,
              iconSize: 22,
            ),
          ],
        ),
      ],
    );
  }
}

class _SessionSnapshot extends StatelessWidget {
  const _SessionSnapshot({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(32),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.70),
        LiquidPalette.surface.withValues(alpha: 0.94),
      ],
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          SizedBox(
            height: 192,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.32,
              children: [
                MetricGlassCard(
                  value: '${controller.importedTrackCount}',
                  label: 'Tracks',
                  icon: Icons.graphic_eq_rounded,
                  onTap: () =>
                      controller.openLibraryFilter(LibraryFilter.tracks),
                ),
                MetricGlassCard(
                  value: '${controller.artistCount}',
                  label: 'Artists',
                  icon: Icons.person_rounded,
                  onTap: controller.openSearch,
                ),
                MetricGlassCard(
                  value: '${controller.likedTracksCount}',
                  label: 'Likes',
                  icon: Icons.favorite_rounded,
                  onTap: () =>
                      controller.openLibraryFilter(LibraryFilter.favorites),
                ),
                MetricGlassCard(
                  value: '${controller.savedCollectionCount}',
                  label: 'Saved',
                  icon: Icons.bookmark_rounded,
                  onTap: () =>
                      controller.openLibraryFilter(LibraryFilter.folders),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  onTap: () {
                    controller.playImportedTracks();
                  },
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
                        'Play All',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: LiquidPalette.ink),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.favorite_rounded,
                onTap: () =>
                    controller.openLibraryFilter(LibraryFilter.favorites),
                size: 52,
                iconSize: 22,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ImportMusicActions(controller: controller),
        ],
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final items = <_QuickAccessItem>[
      _QuickAccessItem(
        title: 'Imported',
        subtitle: '${controller.importedTrackCount} tracks',
        icon: Icons.audio_file_rounded,
        accent: const [Color(0xFF153C2A), Color(0xFF1ED760)],
        onTap: () {
          controller.playImportedTracks();
        },
      ),
      _QuickAccessItem(
        title: 'Liked Songs',
        subtitle: '${controller.likedTracksCount} favorites',
        icon: Icons.favorite_rounded,
        accent: const [Color(0xFF3B1E3A), Color(0xFF8B5CF6)],
        onTap: () => controller.openLibraryFilter(LibraryFilter.favorites),
      ),
      _QuickAccessItem(
        title: 'Search',
        subtitle: 'Artists, albums, folders',
        icon: Icons.search_rounded,
        accent: const [Color(0xFF10233E), Color(0xFF4B7BFF)],
        onTap: controller.openSearch,
      ),
      _QuickAccessItem(
        title: 'Saved',
        subtitle: '${controller.savedCollectionCount} collections',
        icon: Icons.folder_special_rounded,
        accent: const [Color(0xFF3A280F), Color(0xFFF4A259)],
        onTap: () => controller.openLibraryFilter(LibraryFilter.folders),
      ),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final item in items)
          SizedBox(
            width: isWideWidth(context) ? 220 : 160,
            child: _QuickAccessCard(item: item),
          ),
      ],
    );
  }
}

class _QuickAccessItem {
  const _QuickAccessItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> accent;
  final VoidCallback onTap;
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({required this.item});

  final _QuickAccessItem item;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: item.onTap,
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(28),
      tintColors: [
        item.accent.first.withValues(alpha: 0.54),
        item.accent.last.withValues(alpha: 0.14),
      ],
      borderColor: item.accent.last.withValues(alpha: 0.10),
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(item.icon),
          ),
          const SizedBox(height: 28),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListeningGrid extends StatelessWidget {
  const _ListeningGrid({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = isWideWidth(context);
        final columns = wide ? 3 : 2;
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final track in controller.continueListeningTracks)
              SizedBox(
                width: width,
                child: _ListeningCard(track: track),
              ),
          ],
        );
      },
    );
  }
}

class _ListeningCard extends StatelessWidget {
  const _ListeningCard({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final collection = controller.collectionForTrack(track);

    return GlassPanel(
      onTap: () => controller.playTrack(track, collection: collection),
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(28),
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final coverSize = constraints.maxWidth;

              return Stack(
                children: [
                  ArtworkCover(
                    title: track.album,
                    palette: track.palette,
                    size: coverSize,
                    borderRadius: BorderRadius.circular(22),
                    showTitle: true,
                    icon: Icons.music_note_rounded,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GlassIconButton(
                      icon: controller.isTrackLiked(track.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      selected: controller.isTrackLiked(track.id),
                      onTap: () => controller.toggleLikedTrack(track.id),
                      size: 40,
                      iconSize: 18,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  collection?.title ?? track.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.48),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatDuration(track.duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return SizedBox(
      width: 228,
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
              size: 144,
              showTitle: true,
              icon: Icons.queue_music_rounded,
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
                      : Icons.folder_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.66),
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
            const Spacer(),
            Text(
              formatRuntime(collection.totalDuration),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackActions extends StatelessWidget {
  const _TrackActions({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatDuration(track.duration),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.56),
          ),
        ),
        const SizedBox(width: 10),
        GlassIconButton(
          icon: controller.isTrackLiked(track.id)
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          selected: controller.isTrackLiked(track.id),
          onTap: () => controller.toggleLikedTrack(track.id),
          size: 40,
          iconSize: 18,
        ),
      ],
    );
  }
}
