import 'package:flutter/material.dart';

import '../app/chimusic_theme.dart';
import '../state/chimusic_controller.dart';
import 'glass.dart';

class ImportMusicActions extends StatelessWidget {
  const ImportMusicActions({
    super.key,
    required this.controller,
    this.center = false,
    this.compact = false,
  });

  final MusicAppController controller;
  final bool center;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      _ActionButton(
        icon: controller.isImporting
            ? Icons.sync_rounded
            : Icons.audio_file_rounded,
        label: controller.isImporting ? 'Importing...' : 'Import Files',
        onTap: controller.isImporting
            ? null
            : () {
                controller.importLocalFiles();
              },
        compact: compact,
        accent: true,
      ),
      if (controller.supportsDirectoryImport)
        _ActionButton(
          icon: Icons.folder_open_rounded,
          label: 'Import Folder',
          onTap: controller.isImporting
              ? null
              : () {
                  controller.importLocalFolder();
                },
          compact: compact,
          accent: false,
        ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      children: buttons,
    );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(22),
      tintColors: [
        LiquidPalette.surfaceSoft.withValues(alpha: 0.72),
        LiquidPalette.surface.withValues(alpha: 0.90),
      ],
      withShadow: false,
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.white.withValues(alpha: 0.82),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.76),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyMusicState extends StatelessWidget {
  const EmptyMusicState({
    super.key,
    required this.title,
    required this.body,
    required this.controller,
    this.icon = Icons.library_music_rounded,
  });

  final String title;
  final String body;
  final MusicAppController controller;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(26),
      borderRadius: BorderRadius.circular(34),
      tintColors: [
        LiquidPalette.surfaceRaised.withValues(alpha: 0.98),
        LiquidPalette.surface.withValues(alpha: 0.95),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  LiquidPalette.aqua.withValues(alpha: 0.96),
                  LiquidPalette.mint.withValues(alpha: 0.82),
                ],
              ),
            ),
            child: Icon(icon, size: 32, color: LiquidPalette.ink),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Import files to unlock Home recommendations, Search discovery, and a real Library flow based on your own audio.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.52),
            ),
          ),
          const SizedBox(height: 20),
          ImportMusicActions(controller: controller),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.compact,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compact;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 12 : 14,
      ),
      borderRadius: BorderRadius.circular(22),
      tintColors: accent
          ? [
              LiquidPalette.aqua.withValues(alpha: 0.94),
              LiquidPalette.mint.withValues(alpha: 0.72),
            ]
          : [
              LiquidPalette.surfaceSoft.withValues(alpha: 0.76),
              LiquidPalette.surface.withValues(alpha: 0.92),
            ],
      borderColor: accent
          ? LiquidPalette.mint.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.06),
      withShadow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 18 : 20,
            color: accent ? LiquidPalette.ink : LiquidPalette.softWhite,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent ? LiquidPalette.ink : LiquidPalette.softWhite,
            ),
          ),
        ],
      ),
    );
  }
}
