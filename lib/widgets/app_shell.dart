import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/now_playing_sheet.dart';
import '../screens/search_screen.dart';
import '../state/chimusic_scope.dart';
import 'glass.dart';

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

    return GlassPanel(
      padding: const EdgeInsets.all(20),
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
                      LiquidPalette.aqua.withValues(alpha: 0.90),
                      LiquidPalette.mint.withValues(alpha: 0.74),
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
                    'Liquid edition',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (final tab in MusicTab.values) ...[
            _SidebarDestination(tab: tab),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 24),
          Text(
            'Pinned Mood',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlassPill(label: 'Focus'),
              GlassPill(label: 'Neon'),
              GlassPill(label: 'Soft'),
            ],
          ),
          const Spacer(),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(24),
            tintColors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.05),
            ],
            withShadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.60),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${controller.savedCollections.length} collections',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Adaptive shell for macOS keeps navigation and queue visible while you browse.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
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
              LiquidPalette.aqua.withValues(alpha: 0.42),
              LiquidPalette.mint.withValues(alpha: 0.16),
            ]
          : [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.04),
            ],
      withShadow: false,
      child: Row(
        children: [
          Icon(tab.icon),
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

class _RightDock extends StatelessWidget {
  const _RightDock();

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final collection =
        controller.currentCollection ??
        controller.collectionForTrack(controller.currentTrack);

    return Column(
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Up Next', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(
                collection?.title ?? 'Current queue',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.64),
                ),
              ),
              const SizedBox(height: 14),
              for (
                var index = 0;
                index < controller.upNext.length;
                index++
              ) ...[
                _QueueRow(track: controller.upNext[index]),
                if (index != controller.upNext.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Detail',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              if (collection != null)
                Row(
                  children: [
                    ArtworkCover(
                      title: collection.title,
                      palette: collection.palette,
                      size: 82,
                      showTitle: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collection.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            collection.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.62),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return GlassPanel(
      onTap: () => controller.playTrack(
        track,
        collection: controller.collectionForTrack(track),
      ),
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(22),
      tintColors: [
        Colors.white.withValues(alpha: 0.10),
        Colors.white.withValues(alpha: 0.04),
      ],
      withShadow: false,
      child: Row(
        children: [
          ArtworkCover(
            title: track.album,
            palette: track.palette,
            size: 48,
            borderRadius: BorderRadius.circular(14),
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
              LiquidPalette.aqua.withValues(alpha: 0.42),
              LiquidPalette.mint.withValues(alpha: 0.16),
            ]
          : [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.04),
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
                  onTap: controller.skipPrevious,
                  size: 42,
                  iconSize: 20,
                ),
                const SizedBox(width: 8),
              ],
              GlassIconButton(
                icon: controller.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: controller.togglePlayPause,
                selected: true,
                size: 50,
                iconSize: 26,
              ),
              const SizedBox(width: 8),
              if (!narrow)
                GlassIconButton(
                  icon: Icons.skip_next_rounded,
                  onTap: controller.skipNext,
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
