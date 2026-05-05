import 'package:flutter/material.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: pagePadding(context, bottom: 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 44),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ArtworkCover(
                                title: collection.title,
                                palette: collection.palette,
                                size: 280,
                                showTitle: true,
                                icon: Icons.folder_rounded,
                              ),
                              const SizedBox(width: 28),
                              Expanded(
                                child: _CollectionHero(collection: collection),
                              ),
                            ],
                          )
                        else ...[
                          Center(
                            child: ArtworkCover(
                              title: collection.title,
                              palette: collection.palette,
                              size: 260,
                              showTitle: true,
                              icon: Icons.folder_rounded,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _CollectionHero(collection: collection),
                        ],
                        const SizedBox(height: 28),
                        SectionHeader(
                          title: 'Track List',
                          subtitle:
                              '${collection.tracks.length} files • ${formatRuntime(collection.totalDuration)}',
                        ),
                        const SizedBox(height: 16),
                        GlassPanel(
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < collection.tracks.length;
                                index++
                              ) ...[
                                TrackRow(
                                  track: collection.tracks[index],
                                  onTap: () {
                                    controller.playTrack(
                                      collection.tracks[index],
                                      collection: collection,
                                    );
                                  },
                                  trailing: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        formatDuration(
                                          collection.tracks[index].duration,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.66,
                                              ),
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        collection.tracks[index].typeLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.50,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
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

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(label: collection.kind.label),
              GlassPill(label: '${collection.tracks.length} files'),
              GlassPill(label: formatRuntime(collection.totalDuration)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            collection.title,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
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
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  onTap: () {
                    controller.playCollection(collection);
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  tintColors: [
                    collection.palette.first.withValues(alpha: 0.54),
                    collection.palette[1].withValues(alpha: 0.20),
                  ],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded),
                      const SizedBox(width: 10),
                      Text(
                        'Play Folder',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: controller.isCollectionSaved(collection.id)
                    ? Icons.check_rounded
                    : Icons.add_rounded,
                selected: controller.isCollectionSaved(collection.id),
                onTap: () => controller.toggleSavedCollection(collection.id),
                size: 56,
                iconSize: 26,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
