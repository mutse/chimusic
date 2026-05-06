import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../screens/collection_detail_page.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/now_playing_sheet.dart';
import '../screens/search_screen.dart';
import '../state/chimusic_scope.dart';
import 'glass.dart';
import 'local_music_widgets.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final desktop = isDesktopWidth(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: LiquidBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (desktop)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 10, 20),
                      child: SizedBox(width: 242, child: _Sidebar()),
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(
                        key: ValueKey(controller.selectedTab),
                        child: _buildPage(controller.selectedTab),
                      ),
                    ),
                  ),
                  if (desktop)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 20, 20, 20),
                      child: SizedBox(width: 316, child: _RightDock()),
                    ),
                ],
              ),
              if (controller.hasCurrentTrack)
                if (desktop)
                  const Positioned(
                    left: 284,
                    right: 356,
                    bottom: 28,
                    child: _MiniPlayerBar(),
                  )
                else
                  const Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniPlayerBar(),
                        SizedBox(height: 12),
                        _BottomNavigationBar(),
                      ],
                    ),
                  )
              else if (!desktop)
                const Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: _BottomNavigationBar(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(MusicTab tab) {
    return switch (tab) {
      MusicTab.home => const HomeScreen(),
      MusicTab.search => const SearchScreen(),
      MusicTab.library => const LibraryScreen(),
    };
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final pinned = controller.pinnedCollections;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      tintColors: [
        LiquidPalette.surface.withValues(alpha: 0.98),
        LiquidPalette.surfaceRaised.withValues(alpha: 0.94),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      LiquidPalette.aqua.withValues(alpha: 0.96),
                      LiquidPalette.mint.withValues(alpha: 0.82),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.multitrack_audio_rounded,
                  color: LiquidPalette.ink,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ChiMusic',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    'Music for your files',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.54),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Menu',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
          const SizedBox(height: 12),
          for (final tab in MusicTab.values) ...[
            _SidebarDestination(tab: tab),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 24),
          Text(
            'Your Library',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
          const SizedBox(height: 12),
          if (pinned.isEmpty)
            Text(
              'Save folders or like tracks to build quick access here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.56),
              ),
            )
          else
            for (final collection in pinned) ...[
              _SidebarCollectionLink(collection: collection),
              const SizedBox(height: 10),
            ],
          const Spacer(),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(24),
            tintColors: [
              LiquidPalette.surfaceSoft.withValues(alpha: 0.76),
              LiquidPalette.surfaceRaised.withValues(alpha: 0.90),
            ],
            withShadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${controller.importedTrackCount} tracks',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${controller.collectionCount} folders • ${controller.likedTracksCount} favorites',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 14),
                ImportMusicActions(controller: controller, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({required this.tab});

  final MusicTab tab;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final selected = controller.selectedTab == tab;

    return GlassPanel(
      onTap: () => controller.selectTab(tab),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(22),
      tintColors: selected
          ? [
              LiquidPalette.deepCyan.withValues(alpha: 0.98),
              LiquidPalette.aqua.withValues(alpha: 0.22),
            ]
          : [
              LiquidPalette.surfaceSoft.withValues(alpha: 0.76),
              LiquidPalette.surface.withValues(alpha: 0.92),
            ],
      withShadow: false,
      child: Row(
        children: [
          Icon(
            tab.icon,
            color: selected
                ? LiquidPalette.mint
                : Colors.white.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tab.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected
                    ? LiquidPalette.softWhite
                    : Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarCollectionLink extends StatelessWidget {
  const _SidebarCollectionLink({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: () =>
          Navigator.of(context).push(CollectionDetailPage.route(collection)),
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(22),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.74),
        LiquidPalette.surface.withValues(alpha: 0.92),
      ],
      withShadow: false,
      child: Row(
        children: [
          ArtworkCover(
            title: collection.title,
            palette: collection.palette,
            size: 44,
            borderRadius: BorderRadius.circular(14),
            icon: Icons.folder_rounded,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  collection.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.52),
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

class _RightDock extends StatelessWidget {
  const _RightDock();

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = controller.currentTrack;
    final collection =
        controller.currentCollection ??
        (track == null ? null : controller.collectionForTrack(track));
    final pinned = controller.pinnedCollections;

    return Column(
      children: [
        if (track == null)
          GlassPanel(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to build your queue',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'Import files or a folder and this dock becomes a live music control surface with current playback and queue context.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.64),
                  ),
                ),
                const SizedBox(height: 14),
                ImportMusicActions(controller: controller, compact: true),
                if (pinned.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Pinned',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.50),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _QueueRow(
                    track: pinned.first.tracks.first,
                    queueCollection: pinned.first,
                  ),
                ],
              ],
            ),
          )
        else ...[
          GlassPanel(
            padding: const EdgeInsets.all(18),
            borderRadius: BorderRadius.circular(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Playing From',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ArtworkCover(
                      title: collection?.title ?? track.album,
                      palette: collection?.palette ?? track.palette,
                      size: 82,
                      showTitle: true,
                      icon: collection?.kind == MusicCollectionKind.folder
                          ? Icons.folder_rounded
                          : Icons.queue_music_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collection?.title ?? 'Current queue',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${controller.queue.length} tracks • ${collection?.kind.label ?? 'Queue'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.58),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GlassPanel(
                        onTap: collection == null
                            ? null
                            : () => Navigator.of(
                                context,
                              ).push(CollectionDetailPage.route(collection)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        tintColors: [
                          LiquidPalette.surfaceSoft.withValues(alpha: 0.76),
                          LiquidPalette.surface.withValues(alpha: 0.92),
                        ],
                        withShadow: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Open Queue',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GlassIconButton(
                      icon:
                          collection != null &&
                              controller.isCollectionSaved(collection.id)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      selected:
                          collection != null &&
                          controller.isCollectionSaved(collection.id),
                      onTap: collection == null
                          ? () {}
                          : () =>
                                controller.toggleSavedCollection(collection.id),
                      size: 48,
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            padding: const EdgeInsets.all(18),
            borderRadius: BorderRadius.circular(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Up Next', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(
                  controller.upNext.isEmpty
                      ? 'This queue ends with the current track.'
                      : 'Next up from your active listening flow.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.64),
                  ),
                ),
                const SizedBox(height: 14),
                if (controller.upNext.isEmpty)
                  Text(
                    'Nothing is queued after this track yet. Pick another song from Home, Search, or Library to keep playback flowing.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  )
                else
                  for (
                    var index = 0;
                    index < controller.upNext.length;
                    index++
                  ) ...[
                    _QueueRow(
                      track: controller.upNext[index],
                      queueCollection: collection,
                    ),
                    if (index != controller.upNext.length - 1)
                      const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            padding: const EdgeInsets.all(18),
            borderRadius: BorderRadius.circular(30),
            child: _CurrentTrackCard(track: track, collection: collection),
          ),
        ],
      ],
    );
  }
}

class _CurrentTrackCard extends StatelessWidget {
  const _CurrentTrackCard({required this.track, required this.collection});

  final Track track;
  final MusicCollection? collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current Detail', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        Row(
          children: [
            ArtworkCover(
              title: track.album,
              palette: track.palette,
              size: 82,
              showTitle: true,
              icon: Icons.music_note_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    track.artist,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    collection?.title ?? track.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            GlassIconButton(
              icon: controller.isTrackLiked(track.id)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              onTap: () => controller.toggleLikedTrack(track.id),
              selected: controller.isTrackLiked(track.id),
              size: 42,
              iconSize: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                track.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.50),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.track, this.queueCollection});

  final Track track;
  final MusicCollection? queueCollection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return GlassPanel(
      onTap: () {
        controller.playTrack(
          track,
          collection: queueCollection ?? controller.collectionForTrack(track),
        );
      },
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(22),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.76),
        LiquidPalette.surface.withValues(alpha: 0.92),
      ],
      withShadow: false,
      child: Row(
        children: [
          ArtworkCover(
            title: track.album,
            palette: track.palette,
            size: 48,
            borderRadius: BorderRadius.circular(14),
            icon: Icons.music_note_rounded,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.56),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDuration(track.duration),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigationBar extends StatelessWidget {
  const _BottomNavigationBar();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      borderRadius: BorderRadius.circular(30),
      child: Row(
        children: [
          for (final tab in MusicTab.values) ...[
            Expanded(child: _BottomNavigationItem(tab: tab)),
            if (tab != MusicTab.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({required this.tab});

  final MusicTab tab;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final selected = controller.selectedTab == tab;

    return GlassPanel(
      onTap: () => controller.selectTab(tab),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      borderRadius: BorderRadius.circular(22),
      tintColors: selected
          ? [
              LiquidPalette.deepCyan.withValues(alpha: 0.96),
              LiquidPalette.aqua.withValues(alpha: 0.22),
            ]
          : [
              LiquidPalette.surfaceSoft.withValues(alpha: 0.76),
              LiquidPalette.surface.withValues(alpha: 0.92),
            ],
      withShadow: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tab.icon, size: 22),
          const SizedBox(height: 6),
          Text(
            tab.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected
                  ? LiquidPalette.softWhite
                  : Colors.white.withValues(alpha: 0.76),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar();

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = controller.currentTrack;
    if (track == null) {
      return const SizedBox.shrink();
    }

    final collection =
        controller.currentCollection ?? controller.collectionForTrack(track);
    final narrow = MediaQuery.sizeOf(context).width < 470;

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: controller.playbackProgress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(
                track.palette.first.withValues(alpha: 0.94),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      Navigator.of(context).push(NowPlayingSheet.route()),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        ArtworkCover(
                          title: track.album,
                          palette: track.palette,
                          size: 52,
                          borderRadius: BorderRadius.circular(16),
                          icon: Icons.music_note_rounded,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${track.artist} • ${collection?.title ?? track.album}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.62,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!narrow) ...[
                GlassIconButton(
                  icon: Icons.skip_previous_rounded,
                  onTap: () {
                    controller.skipPrevious();
                  },
                  size: 42,
                  iconSize: 20,
                ),
                const SizedBox(width: 8),
              ],
              GlassIconButton(
                icon: controller.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: () {
                  controller.togglePlayPause();
                },
                selected: true,
                size: 50,
                iconSize: 26,
              ),
              const SizedBox(width: 8),
              if (!narrow)
                GlassIconButton(
                  icon: Icons.skip_next_rounded,
                  onTap: () {
                    controller.skipNext();
                  },
                  size: 42,
                  iconSize: 20,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
