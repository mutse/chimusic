import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../models/music_models.dart';
import '../screens/app_details_sheet.dart';
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
                          ? 'Your local library now carries AI context, sync status, and faster rediscovery.'
                          : 'Import music to build a smarter home feed.',
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
              const SizedBox(width: 10),
              GlassIconButton(
                icon: controller.isSignedIn
                    ? Icons.account_circle_rounded
                    : Icons.person_add_alt_rounded,
                onTap: () {
                  AppDetailsSheet.show(context);
                },
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
                value: '${controller.albumCount}',
                label: 'Albums',
                icon: Icons.album_rounded,
                onTap: () => controller.openLibraryFilter(LibraryFilter.albums),
                accent: const [Color(0xFF1B2948), Color(0xFF4B7BFF)],
              ),
              MetricGlassCard(
                value: '${controller.artistCount}',
                label: 'Artists',
                icon: Icons.mic_external_on_rounded,
                onTap: () =>
                    controller.openLibraryFilter(LibraryFilter.artists),
                accent: const [Color(0xFF31231A), Color(0xFFF4A259)],
              ),
              MetricGlassCard(
                value: controller.membershipTier.label,
                label: controller.syncState.phase == SyncPhase.synced
                    ? 'Synced'
                    : controller.syncState.phase == SyncPhase.syncing
                    ? 'Syncing'
                    : 'Membership',
                icon: controller.hasPro
                    ? Icons.workspace_premium_rounded
                    : Icons.auto_awesome_rounded,
                onTap: () {
                  AppDetailsSheet.show(context);
                },
                accent: const [Color(0xFF3B1E3A), Color(0xFF8B5CF6)],
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
              GlassPill(label: 'AI'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Turn local files into a full music app experience.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Import once, then browse Home, Search, and Library as clean music surfaces built from your own files, with optional sync, smarter playlists, and AI discovery layered on top.',
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
          body: 'Recent plays surface automatically the moment you import.',
        ),
        SizedBox(height: 14),
        _FeatureCard(
          icon: Icons.auto_awesome_rounded,
          title: 'AI Search',
          body: 'Search by title, mood, use case, artist, or genre.',
        ),
        SizedBox(height: 14),
        _FeatureCard(
          icon: Icons.sync_rounded,
          title: 'Lightweight Sync',
          body: 'Sign in later to carry library context and history forward.',
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
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(28),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.72),
        LiquidPalette.surface.withValues(alpha: 0.92),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.9)),
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
                    color: Colors.white.withValues(alpha: 0.68),
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
    final wide = isWideWidth(context);
    final featured = controller.featuredCollection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!controller.isSignedIn) ...[
          GlassPanel(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(32),
            tintColors: const [Color(0xFF143845), Color(0xFF1D5366)],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local listening is ready. Sign in when you want more.',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cloud sync, AI continuity, and Pro upgrades stay optional until you have already imported and played music.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                GlassPanel(
                  onTap: () async {
                    await controller.signIn();
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  tintColors: [
                    LiquidPalette.aqua.withValues(alpha: 0.96),
                    LiquidPalette.mint.withValues(alpha: 0.72),
                  ],
                  borderColor: LiquidPalette.mint.withValues(alpha: 0.22),
                  withShadow: false,
                  child: Text(
                    'Sign In',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: LiquidPalette.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (controller.shouldShowAiUpsell) ...[
          GlassPanel(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(32),
            tintColors: const [Color(0xFF2C2042), Color(0xFF4A3270)],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have felt the AI layer. Pro keeps it always on.',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unlock unlimited AI search, smarter playlists, listening recaps, and cross-device continuity without affecting core local playback.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                GlassPanel(
                  onTap: () async {
                    await controller.upgradeToPro();
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  tintColors: [
                    LiquidPalette.aqua.withValues(alpha: 0.96),
                    LiquidPalette.mint.withValues(alpha: 0.72),
                  ],
                  borderColor: LiquidPalette.mint.withValues(alpha: 0.22),
                  withShadow: false,
                  child: Text(
                    'Upgrade',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: LiquidPalette.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (wide && featured != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _ContinueHero(
                  controller: controller,
                  collection: featured,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 2,
                child: _SessionInsightCard(controller: controller),
              ),
            ],
          )
        else ...[
          if (featured != null)
            _ContinueHero(controller: controller, collection: featured),
          if (featured != null) const SizedBox(height: 18),
          _SessionInsightCard(controller: controller),
        ],
        const SizedBox(height: 30),
        SectionCard(
          title: 'Continue Listening',
          subtitle:
              'Resume the latest queue, favorite, or imported set without rebuilding context.',
          child: controller.continueListeningTracks.isEmpty
              ? const _EmptySectionCopy(
                  message:
                      'Play a track once and ChiMusic will keep the thread warm here.',
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < controller.continueListeningTracks.length;
                      index++
                    ) ...[
                      TrackRow(
                        track: controller.continueListeningTracks[index],
                        onTap: () {
                          controller.playTrack(
                            controller.continueListeningTracks[index],
                            collection: controller.collectionForTrack(
                              controller.continueListeningTracks[index],
                            ),
                          );
                        },
                        trailing: Text(
                          formatDuration(
                            controller.continueListeningTracks[index].duration,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.66),
                              ),
                        ),
                      ),
                      if (index !=
                          controller.continueListeningTracks.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 30),
        SectionCard(
          title: 'Smart Playlists',
          subtitle:
              'Generated from import recency, track shape, likes, and listening behavior.',
          trailing: GlassPill(label: '${controller.playlistCount} playlists'),
          child: controller.smartPlaylistCollections.isEmpty
              ? const _EmptySectionCopy(
                  message:
                      'Import more music and ChiMusic will build mood and utility playlists automatically.',
                )
              : Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final collection
                        in controller.smartPlaylistCollections)
                      _CollectionFeatureCard(collection: collection),
                  ],
                ),
        ),
        const SizedBox(height: 30),
        SectionCard(
          title: 'For You',
          subtitle:
              'AI cards that react to favorites, recent playback, and your strongest local clusters.',
          child: controller.recommendationCards.isEmpty
              ? const _EmptySectionCopy(
                  message:
                      'Recommendations will appear after you play, like, or import a bit more music.',
                )
              : Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final card in controller.recommendationCards)
                      _RecommendationFeatureCard(card: card),
                  ],
                ),
        ),
        const SizedBox(height: 30),
        SectionCard(
          title: 'Rediscover',
          subtitle:
              'Songs worth another pass, based on likes and what has gone quiet recently.',
          child: controller.rediscoveryTracks.isEmpty
              ? const _EmptySectionCopy(
                  message:
                      'Like a few tracks to build a stronger rediscovery lane.',
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < controller.rediscoveryTracks.length;
                      index++
                    ) ...[
                      TrackRow(
                        track: controller.rediscoveryTracks[index],
                        onTap: () {
                          controller.playTrack(
                            controller.rediscoveryTracks[index],
                            collection: controller.collectionForTrack(
                              controller.rediscoveryTracks[index],
                            ),
                          );
                        },
                        trailing: GlassPill(
                          label: controller.recommendationReasonForTrack(
                            controller.rediscoveryTracks[index],
                          ),
                        ),
                      ),
                      if (index != controller.rediscoveryTracks.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ContinueHero extends StatelessWidget {
  const _ContinueHero({required this.controller, required this.collection});

  final MusicAppController controller;
  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    final track = controller.currentTrack ?? collection.tracks.first;
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        collection.palette.first.withValues(alpha: 0.34),
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
              if (collection.reason case final reason?)
                GlassPill(label: reason),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtworkCover(
                title: collection.title,
                palette: collection.palette,
                size: 126,
                showTitle: true,
                icon: Icons.queue_music_rounded,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pick up where you left off',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      collection.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current anchor: ${track.title} • ${track.artist}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      collection.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GlassPanel(
                  onTap: () => controller.playCollection(collection),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  tintColors: [
                    LiquidPalette.aqua.withValues(alpha: 0.96),
                    LiquidPalette.mint.withValues(alpha: 0.72),
                  ],
                  borderColor: LiquidPalette.mint.withValues(alpha: 0.22),
                  withShadow: false,
                  child: Text(
                    'Play',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: LiquidPalette.ink),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.chevron_right_rounded,
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(CollectionDetailPage.route(collection));
                },
                size: 56,
                iconSize: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionInsightCard extends StatelessWidget {
  const _SessionInsightCard({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
        LiquidPalette.surface.withValues(alpha: 0.95),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Signals',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          _InsightRow(
            label: 'Cloud sync',
            value: controller.syncState.message,
            icon: Icons.sync_rounded,
          ),
          const SizedBox(height: 12),
          _InsightRow(
            label: 'AI access',
            value: controller.hasPro
                ? 'Unlimited'
                : '${controller.aiSearchTrialsRemaining} free searches left',
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 12),
          _InsightRow(
            label: 'Metadata',
            value: controller.isEnhancingLibrary
                ? 'Refreshing enriched fields…'
                : 'Artwork, lyrics readiness, year, genre, and bitrate loaded.',
            icon: Icons.auto_fix_high_rounded,
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionFeatureCard extends StatelessWidget {
  const _CollectionFeatureCard({required this.collection});

  final MusicCollection collection;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isWideWidth(context) ? 260 : double.infinity,
      child: GlassPanel(
        onTap: () {
          Navigator.of(context).push(CollectionDetailPage.route(collection));
        },
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(28),
        tintColors: [
          collection.palette.first.withValues(alpha: 0.28),
          LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
        ],
        withShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkCover(
              title: collection.title,
              palette: collection.palette,
              size: 100,
              showTitle: true,
              icon: Icons.auto_awesome_rounded,
            ),
            const SizedBox(height: 16),
            Text(
              collection.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              collection.subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.66),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              collection.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationFeatureCard extends StatelessWidget {
  const _RecommendationFeatureCard({required this.card});

  final RecommendationCard card;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.read(context);

    return SizedBox(
      width: isWideWidth(context) ? 260 : double.infinity,
      child: GlassPanel(
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(28),
        tintColors: [
          card.palette.first.withValues(alpha: 0.28),
          LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
        ],
        withShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GlassPill(label: 'AI'),
                GlassPill(label: '${card.tracks.length} tracks'),
              ],
            ),
            const SizedBox(height: 16),
            Text(card.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              card.subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              card.reason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
            if (card.tracks.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '${card.tracks.first.title} • ${card.tracks.first.artist}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            if (card.callToActionQuery != null) ...[
              const SizedBox(height: 14),
              GlassPanel(
                onTap: () {
                  controller.setSearchMode(SearchMode.ai);
                  controller.openSearch(card.callToActionQuery!);
                  controller.applySearchSuggestion(card.callToActionQuery!);
                },
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                borderRadius: BorderRadius.circular(22),
                tintColors: [
                  LiquidPalette.surfaceSoft.withValues(alpha: 0.70),
                  LiquidPalette.surface.withValues(alpha: 0.90),
                ],
                withShadow: false,
                child: Text(
                  card.callToActionLabel ?? 'Open',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptySectionCopy extends StatelessWidget {
  const _EmptySectionCopy({required this.message});

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
