import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../data/local_audio_importer.dart';
import '../models/music_models.dart';
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
    final user = controller.userProfile;
    final syncState = controller.syncState;

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
                          'Profile & Settings',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage sign-in, Pro access, cloud sync, privacy, and local session controls.',
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
              GlassPanel(
                padding: const EdgeInsets.all(18),
                borderRadius: BorderRadius.circular(30),
                tintColors: [
                  LiquidPalette.deepCyan.withValues(alpha: 0.88),
                  LiquidPalette.surfaceRaised.withValues(alpha: 0.96),
                ],
                withShadow: false,
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            LiquidPalette.aqua.withValues(alpha: 0.92),
                            LiquidPalette.mint.withValues(alpha: 0.70),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: LiquidPalette.ink,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Local-only listening',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ??
                                'Sign in to unlock cloud sync, AI continuity, and Pro upgrades.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.68),
                                ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              GlassPill(
                                label: controller.membershipTier.label,
                                selected: controller.hasPro,
                              ),
                              GlassPill(label: syncState.phase.name),
                              if (syncState.lastSyncedAt != null)
                                GlassPill(
                                  label:
                                      'Synced ${formatRelativePlayTime(syncState.lastSyncedAt!)}',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Membership & Sync',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionTile(
                    icon: user == null
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                    label: user == null ? 'Sign In' : 'Sign Out',
                    onTap: () async {
                      if (user == null) {
                        await controller.signIn();
                      } else {
                        await controller.signOut();
                      }
                    },
                  ),
                  _ActionTile(
                    icon: controller.hasPro
                        ? Icons.workspace_premium_rounded
                        : Icons.auto_awesome_rounded,
                    label: controller.hasPro ? 'Pro Active' : 'Upgrade to Pro',
                    onTap: controller.hasPro
                        ? null
                        : () async {
                            await controller.upgradeToPro();
                          },
                    accent: !controller.hasPro,
                  ),
                  _ActionTile(
                    icon: Icons.sync_rounded,
                    label: syncState.isBusy ? 'Syncing…' : 'Sync Library',
                    onTap: syncState.isBusy
                        ? null
                        : () async {
                            await controller.syncLibraryNow();
                          },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _DetailsSection(
                title: 'AI & Cloud Boundaries',
                body:
                    'This prototype keeps local playback available without any account. Sign-in unlocks cloud snapshot sync, metadata enhancement, and AI-driven organization. Original audio files are not deleted when you clear the in-app library.',
              ),
              const SizedBox(height: 14),
              const _DetailsSection(
                title: 'Supported Formats',
                body:
                    'ChiMusic scans common local music formats first, then enriches what it can with cover art, lyrics availability, and lightweight metadata.',
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
                'These actions manage only the app session and synced metadata. They never delete the original files on disk.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.64),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionTile(
                    icon: Icons.history_rounded,
                    label: controller.hasPlaybackHistory
                        ? 'Clear Playback History'
                        : 'History Already Clear',
                    onTap: controller.hasPlaybackHistory
                        ? controller.clearPlaybackHistory
                        : null,
                  ),
                  _ActionTile(
                    icon: Icons.manage_search_rounded,
                    label: controller.recentSearches.isEmpty
                        ? 'Searches Already Clear'
                        : 'Clear Recent Searches',
                    onTap: controller.recentSearches.isEmpty
                        ? null
                        : controller.clearRecentSearches,
                  ),
                  _ActionTile(
                    icon: Icons.delete_sweep_rounded,
                    label: 'Clear Imported Library',
                    accent: true,
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
            'This removes imported tracks, likes, saved collections, AI suggestions, and recent searches from ChiMusic. Original audio files on your device will not be deleted.',
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(24),
      tintColors: accent
          ? const [Color(0xFF123340), Color(0xFF1C6E8C)]
          : [
              LiquidPalette.surfaceSoft.withValues(alpha: 0.78),
              LiquidPalette.surface.withValues(alpha: 0.92),
            ],
      borderColor: accent
          ? LiquidPalette.aqua.withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.06),
      withShadow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: accent
                ? LiquidPalette.mint
                : Colors.white.withValues(alpha: 0.82),
          ),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
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
