import 'package:flutter/material.dart';

import '../screens/collection_detail_page.dart';
import '../state/chimusic_controller.dart';

class NeteasePlaylistStrip extends StatelessWidget {
  const NeteasePlaylistStrip({super.key, required this.controller});
  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final playlists = controller.playlistCollections
        .where((p) => p.id.startsWith('netease:playlist:'))
        .toList();
    if (playlists.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '网易云歌单 · ${playlists.length}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: playlists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ActionChip(
                  avatar: const Icon(Icons.queue_music_rounded, size: 20),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      '${playlist.title} · ${playlist.tracks.length} 首',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(CollectionDetailPage.route(playlist)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
