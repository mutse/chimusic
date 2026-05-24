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

enum LibraryFilter {
  all,
  tracks,
  albums,
  artists,
  playlists,
  folders,
  favorites,
}

extension LibraryFilterX on LibraryFilter {
  String get label => switch (this) {
    LibraryFilter.all => 'All',
    LibraryFilter.tracks => 'Tracks',
    LibraryFilter.albums => 'Albums',
    LibraryFilter.artists => 'Artists',
    LibraryFilter.playlists => 'Playlists',
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

enum MusicCollectionKind { playlist, folder, album, artist, smartPlaylist }

extension MusicCollectionKindX on MusicCollectionKind {
  String get label => switch (this) {
    MusicCollectionKind.playlist => 'Playlist',
    MusicCollectionKind.folder => 'Folder',
    MusicCollectionKind.album => 'Album',
    MusicCollectionKind.artist => 'Artist',
    MusicCollectionKind.smartPlaylist => 'Smart Playlist',
  };
}

enum SearchMode { standard, ai }

extension SearchModeX on SearchMode {
  String get label => switch (this) {
    SearchMode.standard => 'On Device',
    SearchMode.ai => 'AI',
  };
}

enum MembershipTier { free, pro }

extension MembershipTierX on MembershipTier {
  String get label => switch (this) {
    MembershipTier.free => 'Free',
    MembershipTier.pro => 'Pro',
  };
}

enum CloudMatchStatus { localOnly, matched, enriched }

extension CloudMatchStatusX on CloudMatchStatus {
  String get label => switch (this) {
    CloudMatchStatus.localOnly => 'Local only',
    CloudMatchStatus.matched => 'Matched',
    CloudMatchStatus.enriched => 'Enhanced',
  };
}

enum LyricsAvailability { unavailable, available }

enum LyricsStatus { idle, loading, available, unavailable, error }

enum SyncPhase { offline, idle, syncing, synced, error }

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
    this.artworkUri,
    this.lyricsAvailability = LyricsAvailability.unavailable,
    this.genre,
    this.year,
    this.bitrate,
    this.fingerprint,
    this.cloudMatchStatus = CloudMatchStatus.localOnly,
    this.lastSyncedAt,
    this.credits = const <String>[],
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
  final String? artworkUri;
  final LyricsAvailability lyricsAvailability;
  final String? genre;
  final int? year;
  final int? bitrate;
  final String? fingerprint;
  final CloudMatchStatus cloudMatchStatus;
  final DateTime? lastSyncedAt;
  final List<String> credits;

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
    String? artworkUri,
    bool clearArtworkUri = false,
    LyricsAvailability? lyricsAvailability,
    String? genre,
    bool clearGenre = false,
    int? year,
    bool clearYear = false,
    int? bitrate,
    bool clearBitrate = false,
    String? fingerprint,
    bool clearFingerprint = false,
    CloudMatchStatus? cloudMatchStatus,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    List<String>? credits,
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
      artworkUri: clearArtworkUri ? null : artworkUri ?? this.artworkUri,
      lyricsAvailability: lyricsAvailability ?? this.lyricsAvailability,
      genre: clearGenre ? null : genre ?? this.genre,
      year: clearYear ? null : year ?? this.year,
      bitrate: clearBitrate ? null : bitrate ?? this.bitrate,
      fingerprint: clearFingerprint ? null : fingerprint ?? this.fingerprint,
      cloudMatchStatus: cloudMatchStatus ?? this.cloudMatchStatus,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : lastSyncedAt ?? this.lastSyncedAt,
      credits: credits ?? this.credits,
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
    this.artworkUri,
    this.prompt,
    this.reason,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final MusicCollectionKind kind;
  final List<Color> palette;
  final List<Track> tracks;
  final String? artworkUri;
  final String? prompt;
  final String? reason;

  Duration get totalDuration => tracks.fold(
    Duration.zero,
    (total, track) => total + (track.duration ?? Duration.zero),
  );

  DateTime get latestImportAt => tracks.fold(
    DateTime.fromMillisecondsSinceEpoch(0),
    (latest, track) =>
        track.importedAt.isAfter(latest) ? track.importedAt : latest,
  );

  MusicCollection copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    MusicCollectionKind? kind,
    List<Color>? palette,
    List<Track>? tracks,
    String? artworkUri,
    bool clearArtworkUri = false,
    String? prompt,
    bool clearPrompt = false,
    String? reason,
    bool clearReason = false,
  }) {
    return MusicCollection(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      palette: palette ?? this.palette,
      tracks: tracks ?? this.tracks,
      artworkUri: clearArtworkUri ? null : artworkUri ?? this.artworkUri,
      prompt: clearPrompt ? null : prompt ?? this.prompt,
      reason: clearReason ? null : reason ?? this.reason,
    );
  }
}

class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.palette,
    required this.tracks,
    this.year,
  });

  final String id;
  final String title;
  final String artist;
  final List<Color> palette;
  final List<Track> tracks;
  final int? year;

  MusicCollection toCollection() {
    return MusicCollection(
      id: id,
      title: title,
      subtitle: '$artist • ${tracks.length} tracks',
      description: 'Album view generated from your imported library.',
      kind: MusicCollectionKind.album,
      palette: palette,
      tracks: tracks,
      reason: year == null ? null : 'Released in $year',
    );
  }
}

class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.palette,
    required this.tracks,
  });

  final String id;
  final String name;
  final List<Color> palette;
  final List<Track> tracks;

  MusicCollection toCollection() {
    final albumCount = tracks.map((track) => track.album.toLowerCase()).toSet();

    return MusicCollection(
      id: id,
      title: name,
      subtitle:
          '${tracks.length} tracks • ${albumCount.length} album${albumCount.length == 1 ? '' : 's'}',
      description: 'Artist view built from the music on this device.',
      kind: MusicCollectionKind.artist,
      palette: palette,
      tracks: tracks,
    );
  }
}

class SmartPlaylist {
  const SmartPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.prompt,
    required this.palette,
    required this.tracks,
    this.reason,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String prompt;
  final List<Color> palette;
  final List<Track> tracks;
  final String? reason;

  MusicCollection toCollection() {
    return MusicCollection(
      id: id,
      title: title,
      subtitle: subtitle,
      description: description,
      kind: MusicCollectionKind.smartPlaylist,
      palette: palette,
      tracks: tracks,
      prompt: prompt,
      reason: reason,
    );
  }
}

class RecommendationCard {
  const RecommendationCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.reason,
    required this.palette,
    required this.tracks,
    this.callToActionLabel,
    this.callToActionQuery,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String reason;
  final List<Color> palette;
  final List<Track> tracks;
  final String? callToActionLabel;
  final String? callToActionQuery;
}

class LyricsState {
  const LyricsState({
    this.status = LyricsStatus.idle,
    this.title = '',
    this.lines = const <String>[],
    this.source,
    this.errorMessage,
  });

  final LyricsStatus status;
  final String title;
  final List<String> lines;
  final String? source;
  final String? errorMessage;

  bool get hasLyrics => status == LyricsStatus.available && lines.isNotEmpty;

  LyricsState copyWith({
    LyricsStatus? status,
    String? title,
    List<String>? lines,
    String? source,
    bool clearSource = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return LyricsState(
      status: status ?? this.status,
      title: title ?? this.title,
      lines: lines ?? this.lines,
      source: clearSource ? null : source ?? this.source,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}

class SyncState {
  const SyncState({
    this.phase = SyncPhase.offline,
    this.message = 'Sign in to sync your library.',
    this.lastSyncedAt,
  });

  final SyncPhase phase;
  final String message;
  final DateTime? lastSyncedAt;

  bool get isBusy => phase == SyncPhase.syncing;

  SyncState copyWith({
    SyncPhase? phase,
    String? message,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      message: message ?? this.message,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarSeed,
    required this.membershipTier,
    required this.signedInAt,
    this.trialEndsAt,
  });

  final String id;
  final String name;
  final String email;
  final String avatarSeed;
  final MembershipTier membershipTier;
  final DateTime signedInAt;
  final DateTime? trialEndsAt;

  bool get isPro => membershipTier == MembershipTier.pro;

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarSeed,
    MembershipTier? membershipTier,
    DateTime? signedInAt,
    DateTime? trialEndsAt,
    bool clearTrialEndsAt = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      membershipTier: membershipTier ?? this.membershipTier,
      signedInAt: signedInAt ?? this.signedInAt,
      trialEndsAt: clearTrialEndsAt ? null : trialEndsAt ?? this.trialEndsAt,
    );
  }
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
