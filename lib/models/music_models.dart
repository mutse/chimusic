import 'package:flutter/material.dart';

enum MusicTab { home, search, library }

extension MusicTabX on MusicTab {
  String get label => switch (this) {
    MusicTab.home => 'Home',
    MusicTab.search => 'Search',
    MusicTab.library => 'Library',
  };

  IconData get icon => switch (this) {
    MusicTab.home => Icons.home_rounded,
    MusicTab.search => Icons.search_rounded,
    MusicTab.library => Icons.library_music_rounded,
  };
}

enum LibraryFilter { all, playlists, albums, downloads }

extension LibraryFilterX on LibraryFilter {
  String get label => switch (this) {
    LibraryFilter.all => 'All',
    LibraryFilter.playlists => 'Playlists',
    LibraryFilter.albums => 'Albums',
    LibraryFilter.downloads => 'Downloads',
  };
}

enum MusicCollectionKind { playlist, album, mix }

extension MusicCollectionKindX on MusicCollectionKind {
  String get label => switch (this) {
    MusicCollectionKind.playlist => 'Playlist',
    MusicCollectionKind.album => 'Album',
    MusicCollectionKind.mix => 'Mix',
  };
}

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.palette,
    required this.moodTag,
    this.lyricLine,
    this.explicit = false,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final List<Color> palette;
  final String moodTag;
  final String? lyricLine;
  final bool explicit;
}

class MusicCollection {
  const MusicCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.kind,
    required this.palette,
    required this.tracks,
    this.badge,
    this.downloaded = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final MusicCollectionKind kind;
  final List<Color> palette;
  final List<Track> tracks;
  final String? badge;
  final bool downloaded;

  Duration get totalDuration =>
      tracks.fold(Duration.zero, (total, track) => total + track.duration);
}

class SearchCategory {
  const SearchCategory({
    required this.title,
    required this.icon,
    required this.palette,
  });

  final String title;
  final IconData icon;
  final List<Color> palette;
}

class HomeShelf {
  const HomeShelf({
    required this.title,
    required this.subtitle,
    required this.collectionIds,
  });

  final String title;
  final String subtitle;
  final List<String> collectionIds;
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatRuntime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }

  return '${duration.inMinutes}m';
}
