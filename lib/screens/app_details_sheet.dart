import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../data/local_audio_importer.dart';
import '../state/chimusic_scope.dart';
import '../widgets/glass.dart';

class AppDetailsSheet extends StatelessWidget {
  const AppDetailsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AppDetailsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GlassPanel(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(36),
        tintColors: [
          LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
          LiquidPalette.surface.withValues(alpha: 0.96),
        ],
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Details',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Privacy, supported formats, and session controls for ChiMusic.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.64),
                              ),
                        ),
                      ],
                    ),
                  ),
                  GlassIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _DetailsSection(
                title: 'Privacy & Local Files',
                body:
                    'ChiMusic builds its library from filenames and folders on this device. Imported audio stays local to the device, and removing items from ChiMusic never deletes the original files from storage.',
              ),
              const SizedBox(height: 14),
              const _DetailsSection(
                title: 'Current Product Scope',
                body:
                    'This version focuses on local playback, personal library management, and on-device search. No account sign-in or cloud sync is required in the current build.',
              ),
              const SizedBox(height: 14),
              Text(
                'Supported Formats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final extension in supportedAudioExtensions)
                    GlassPill(label: extension.toUpperCase()),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Session Controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'Use these controls to manage only the in-app session. They do not alter the original files on disk.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.64),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  GlassPanel(
                    onTap: controller.hasPlaybackHistory
                        ? controller.clearPlaybackHistory
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    tintColors: [
                      LiquidPalette.surfaceSoft.withValues(alpha: 0.78),
                      LiquidPalette.surface.withValues(alpha: 0.92),
                    ],
                    withShadow: false,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          controller.hasPlaybackHistory
                              ? 'Clear Playback History'
                              : 'Playback History Already Clear',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  GlassPanel(
                    onTap: controller.recentSearches.isEmpty
                        ? null
                        : controller.clearRecentSearches,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    tintColors: [
                      LiquidPalette.surfaceSoft.withValues(alpha: 0.78),
                      LiquidPalette.surface.withValues(alpha: 0.92),
                    ],
                    withShadow: false,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.manage_search_rounded,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          controller.recentSearches.isEmpty
                              ? 'Recent Searches Already Clear'
                              : 'Clear Recent Searches',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  GlassPanel(
                    onTap: () async {
                      final shouldClear = await _confirmLibraryReset(context);
                      if (shouldClear != true) {
                        return;
                      }

                      await controller.clearLibrarySession();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    tintColors: const [Color(0xFF3B1919), Color(0xFF6A1F1F)],
                    borderColor: const Color(0x66F87171),
                    withShadow: false,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.delete_sweep_rounded),
                        const SizedBox(width: 10),
                        Text(
                          'Clear Imported Library',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmLibraryReset(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: LiquidPalette.surfaceRaised,
          title: const Text('Clear Imported Library?'),
          content: const Text(
            'This removes imported tracks, likes, saved collections, and recent searches from ChiMusic. Original audio files on your device will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear Session'),
            ),
          ],
        );
      },
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(28),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.76),
        LiquidPalette.surface.withValues(alpha: 0.92),
      ],
      withShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}
