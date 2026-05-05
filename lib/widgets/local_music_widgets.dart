import 'package:flutter/material.dart';

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
        Colors.white.withValues(alpha: 0.14),
        Colors.white.withValues(alpha: 0.05),
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
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 30),
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
              color: Colors.white.withValues(alpha: 0.68),
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
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 12 : 14,
      ),
      borderRadius: BorderRadius.circular(22),
      tintColors: [
        Colors.white.withValues(alpha: 0.18),
        Colors.white.withValues(alpha: 0.06),
      ],
      withShadow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 18 : 20),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
