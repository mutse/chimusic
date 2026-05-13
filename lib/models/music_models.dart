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

enum LibraryFilter { all, tracks, folders, favorites }

extension LibraryFilterX on LibraryFilter {
  String get label => switch (this) {
    LibraryFilter.all => 'All',
    LibraryFilter.tracks => 'Tracks',
    LibraryFilter.folders => 'Folders',
    LibraryFilter.favorites => 'Favorites',
  };
}

enum LibrarySort { recent, title, length }

extension LibrarySortX on LibrarySort {
  String get label => switch (this) {
    LibrarySort.recent => 'Recent',
    LibrarySort.title => 'A-Z',
    LibrarySort.length => 'Length',
  };
}

enum MusicCollectionKind { playlist, folder }

extension MusicCollectionKindX on MusicCollectionKind {
  String get label => switch (this) {
    MusicCollectionKind.playlist => 'Playlist',
    MusicCollectionKind.folder => 'Folder',
  };
}

class Track {
  const Track({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.folderPath,
    required this.title,
    required this.artist,
    required this.album,
    required this.palette,
    required this.importedAt,
    this.duration,
    this.fileExtension,
  });

  final String id;
  final String filePath;
  final String fileName;
  final String folderPath;
  final String title;
  final String artist;
  final String album;
  final List<Color> palette;
  final DateTime importedAt;
  final Duration? duration;
  final String? fileExtension;

  String get typeLabel => (fileExtension == null || fileExtension!.isEmpty)
      ? 'Local Audio'
      : fileExtension!.toUpperCase();

  Track copyWith({
    String? id,
    String? filePath,
    String? fileName,
    String? folderPath,
    String? title,
    String? artist,
    String? album,
    List<Color>? palette,
    DateTime? importedAt,
    Duration? duration,
    bool clearDuration = false,
    String? fileExtension,
  }) {
    return Track(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      folderPath: folderPath ?? this.folderPath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      palette: palette ?? this.palette,
      importedAt: importedAt ?? this.importedAt,
      duration: clearDuration ? null : duration ?? this.duration,
      fileExtension: fileExtension ?? this.fileExtension,
    );
  }
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
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final MusicCollectionKind kind;
  final List<Color> palette;
  final List<Track> tracks;

  Duration get totalDuration => tracks.fold(
    Duration.zero,
    (total, track) => total + (track.duration ?? Duration.zero),
  );

  DateTime get latestImportAt => tracks.fold(
    DateTime.fromMillisecondsSinceEpoch(0),
    (latest, track) =>
        track.importedAt.isAfter(latest) ? track.importedAt : latest,
  );
}

class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({
    required this.trackId,
    required this.lastPlayedAt,
    this.lastPosition = Duration.zero,
    this.playCount = 1,
  });

  final String trackId;
  final DateTime lastPlayedAt;
  final Duration lastPosition;
  final int playCount;

  PlaybackHistoryEntry copyWith({
    String? trackId,
    DateTime? lastPlayedAt,
    Duration? lastPosition,
    int? playCount,
  }) {
    return PlaybackHistoryEntry(
      trackId: trackId ?? this.trackId,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      lastPosition: lastPosition ?? this.lastPosition,
      playCount: playCount ?? this.playCount,
    );
  }
}

String formatDuration(Duration? duration, {String placeholder = '--:--'}) {
  if (duration == null) {
    return placeholder;
  }

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '${duration.inMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatRuntime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }

  return '${duration.inMinutes}m';
}

String formatRelativePlayTime(DateTime value, {DateTime? now}) {
  final currentTime = now ?? DateTime.now();
  final difference = currentTime.difference(value);

  if (difference.inMinutes <= 0) {
    return 'Just now';
  }

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  }

  if (difference.inHours < 24 && currentTime.day == value.day) {
    return '${difference.inHours}h ago';
  }

  final startOfToday = DateTime(
    currentTime.year,
    currentTime.month,
    currentTime.day,
  );
  final startOfValueDay = DateTime(value.year, value.month, value.day);
  final dayDifference = startOfToday.difference(startOfValueDay).inDays;

  if (dayDifference == 1) {
    return 'Yesterday';
  }

  if (dayDifference < 7) {
    return '${dayDifference}d ago';
  }

  const monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${monthLabels[value.month - 1]} ${value.day}';
}
