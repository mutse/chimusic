import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_models.dart';

const String _sessionStorageKey = 'chimusic.session.v2';
const String _legacySessionStorageKey = 'chimusic.session.v1';

class MusicSessionSnapshot {
  const MusicSessionSnapshot({
    this.tracks = const <Track>[],
    this.playbackHistory = const <PlaybackHistoryEntry>[],
    this.likedTrackIds = const <String>{},
    this.savedCollectionIds = const <String>{},
    this.recentTrackIds = const <String>[],
    this.recentSearches = const <String>[],
    this.selectedTab = MusicTab.home,
    this.libraryFilter = LibraryFilter.all,
    this.librarySort = LibrarySort.recent,
    this.searchQuery = '',
    this.searchMode = SearchMode.standard,
    this.queueTrackIds = const <String>[],
    this.currentTrackId,
    this.currentCollectionId,
    this.positionMs = 0,
    this.userProfile,
    this.aiSearchTrialsRemaining = 2,
    this.hasUnlockedAiUpsell = false,
  });

  final List<Track> tracks;
  final List<PlaybackHistoryEntry> playbackHistory;
  final Set<String> likedTrackIds;
  final Set<String> savedCollectionIds;
  final List<String> recentTrackIds;
  final List<String> recentSearches;
  final MusicTab selectedTab;
  final LibraryFilter libraryFilter;
  final LibrarySort librarySort;
  final String searchQuery;
  final SearchMode searchMode;
  final List<String> queueTrackIds;
  final String? currentTrackId;
  final String? currentCollectionId;
  final int positionMs;
  final UserProfile? userProfile;
  final int aiSearchTrialsRemaining;
  final bool hasUnlockedAiUpsell;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'tracks': tracks.map(_trackToJson).toList(growable: false),
      'playbackHistory': playbackHistory
          .map(_playbackHistoryEntryToJson)
          .toList(growable: false),
      'likedTrackIds': likedTrackIds.toList(growable: false),
      'savedCollectionIds': savedCollectionIds.toList(growable: false),
      'recentTrackIds': recentTrackIds,
      'recentSearches': recentSearches,
      'selectedTab': selectedTab.name,
      'libraryFilter': libraryFilter.name,
      'librarySort': librarySort.name,
      'searchQuery': searchQuery,
      'searchMode': searchMode.name,
      'queueTrackIds': queueTrackIds,
      'currentTrackId': currentTrackId,
      'currentCollectionId': currentCollectionId,
      'positionMs': positionMs,
      'userProfile': userProfile == null
          ? null
          : _userProfileToJson(userProfile!),
      'aiSearchTrialsRemaining': aiSearchTrialsRemaining,
      'hasUnlockedAiUpsell': hasUnlockedAiUpsell,
    };
  }

  static MusicSessionSnapshot fromJson(Map<String, dynamic> json) {
    final tracks = (json['tracks'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_trackFromJson)
        .toList(growable: false);
    final playbackHistory =
        (json['playbackHistory'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_playbackHistoryEntryFromJson)
            .toList(growable: false);
    final rawUserProfile = json['userProfile'];

    return MusicSessionSnapshot(
      tracks: tracks,
      playbackHistory: playbackHistory,
      likedTrackIds: _stringSet(json['likedTrackIds']),
      savedCollectionIds: _stringSet(json['savedCollectionIds']),
      recentTrackIds: _stringList(json['recentTrackIds']),
      recentSearches: _stringList(json['recentSearches']),
      selectedTab: _enumByName(
        MusicTab.values,
        json['selectedTab'] as String?,
        MusicTab.home,
      ),
      libraryFilter: _enumByName(
        LibraryFilter.values,
        json['libraryFilter'] as String?,
        LibraryFilter.all,
      ),
      librarySort: _enumByName(
        LibrarySort.values,
        json['librarySort'] as String?,
        LibrarySort.recent,
      ),
      searchQuery: (json['searchQuery'] as String?) ?? '',
      searchMode: _enumByName(
        SearchMode.values,
        json['searchMode'] as String?,
        SearchMode.standard,
      ),
      queueTrackIds: _stringList(json['queueTrackIds']),
      currentTrackId: json['currentTrackId'] as String?,
      currentCollectionId: json['currentCollectionId'] as String?,
      positionMs: (json['positionMs'] as int?) ?? 0,
      userProfile: rawUserProfile is Map<String, dynamic>
          ? _userProfileFromJson(rawUserProfile)
          : null,
      aiSearchTrialsRemaining: (json['aiSearchTrialsRemaining'] as int?) ?? 2,
      hasUnlockedAiUpsell: (json['hasUnlockedAiUpsell'] as bool?) ?? false,
    );
  }
}

class MusicCloudSnapshot {
  const MusicCloudSnapshot({
    required this.userId,
    this.tracks = const <Track>[],
    this.playbackHistory = const <PlaybackHistoryEntry>[],
    this.likedTrackIds = const <String>{},
    this.savedCollectionIds = const <String>{},
    this.recentTrackIds = const <String>[],
    this.recentSearches = const <String>[],
    this.queueTrackIds = const <String>[],
    this.currentTrackId,
    this.currentCollectionId,
    this.positionMs = 0,
    this.syncedAt,
  });

  final String userId;
  final List<Track> tracks;
  final List<PlaybackHistoryEntry> playbackHistory;
  final Set<String> likedTrackIds;
  final Set<String> savedCollectionIds;
  final List<String> recentTrackIds;
  final List<String> recentSearches;
  final List<String> queueTrackIds;
  final String? currentTrackId;
  final String? currentCollectionId;
  final int positionMs;
  final DateTime? syncedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'userId': userId,
      'tracks': tracks.map(_trackToJson).toList(growable: false),
      'playbackHistory': playbackHistory
          .map(_playbackHistoryEntryToJson)
          .toList(growable: false),
      'likedTrackIds': likedTrackIds.toList(growable: false),
      'savedCollectionIds': savedCollectionIds.toList(growable: false),
      'recentTrackIds': recentTrackIds,
      'recentSearches': recentSearches,
      'queueTrackIds': queueTrackIds,
      'currentTrackId': currentTrackId,
      'currentCollectionId': currentCollectionId,
      'positionMs': positionMs,
      'syncedAt': syncedAt?.millisecondsSinceEpoch,
    };
  }

  static MusicCloudSnapshot fromJson(Map<String, dynamic> json) {
    return MusicCloudSnapshot(
      userId: (json['userId'] as String?) ?? '',
      tracks: (json['tracks'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_trackFromJson)
          .toList(growable: false),
      playbackHistory:
          (json['playbackHistory'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(_playbackHistoryEntryFromJson)
              .toList(growable: false),
      likedTrackIds: _stringSet(json['likedTrackIds']),
      savedCollectionIds: _stringSet(json['savedCollectionIds']),
      recentTrackIds: _stringList(json['recentTrackIds']),
      recentSearches: _stringList(json['recentSearches']),
      queueTrackIds: _stringList(json['queueTrackIds']),
      currentTrackId: json['currentTrackId'] as String?,
      currentCollectionId: json['currentCollectionId'] as String?,
      positionMs: (json['positionMs'] as int?) ?? 0,
      syncedAt: switch (json['syncedAt']) {
        final int value => DateTime.fromMillisecondsSinceEpoch(value),
        _ => null,
      },
    );
  }
}

abstract class MusicSessionStore {
  Future<MusicSessionSnapshot> load();

  Future<void> save(MusicSessionSnapshot snapshot);
}

abstract class MusicCloudSnapshotStore {
  Future<MusicCloudSnapshot?> load(String userId);

  Future<void> save(MusicCloudSnapshot snapshot);
}

class SharedPreferencesMusicSessionStore implements MusicSessionStore {
  @override
  Future<MusicSessionSnapshot> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw =
        preferences.getString(_sessionStorageKey) ??
        preferences.getString(_legacySessionStorageKey);
    if (raw == null || raw.isEmpty) {
      return const MusicSessionSnapshot();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const MusicSessionSnapshot();
      }

      return MusicSessionSnapshot.fromJson(decoded);
    } catch (_) {
      return const MusicSessionSnapshot();
    }
  }

  @override
  Future<void> save(MusicSessionSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = jsonEncode(snapshot.toJson());
    await preferences.setString(_sessionStorageKey, payload);
  }
}

class SharedPreferencesCloudSnapshotStore implements MusicCloudSnapshotStore {
  @override
  Future<MusicCloudSnapshot?> load(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cloudStorageKey(userId));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return MusicCloudSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(MusicCloudSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = jsonEncode(snapshot.toJson());
    await preferences.setString(_cloudStorageKey(snapshot.userId), payload);
  }

  String _cloudStorageKey(String userId) => 'chimusic.cloud.v1.$userId';
}

Map<String, Object?> _trackToJson(Track track) {
  return <String, Object?>{
    'id': track.id,
    'filePath': track.filePath,
    'fileName': track.fileName,
    'folderPath': track.folderPath,
    'title': track.title,
    'artist': track.artist,
    'album': track.album,
    'palette': track.palette.map((color) => color.toARGB32()).toList(),
    'importedAt': track.importedAt.millisecondsSinceEpoch,
    'durationMs': track.duration?.inMilliseconds,
    'fileExtension': track.fileExtension,
    'artworkUri': track.artworkUri,
    'lyricsAvailability': track.lyricsAvailability.name,
    'albumArtist': track.albumArtist,
    'genre': track.genre,
    'year': track.year,
    'bitrate': track.bitrate,
    'trackNumber': track.trackNumber,
    'discNumber': track.discNumber,
    'fingerprint': track.fingerprint,
    'waveformUri': track.waveformUri,
    'availability': track.availability.name,
    'lastValidatedAt': track.lastValidatedAt?.millisecondsSinceEpoch,
    'cloudMatchStatus': track.cloudMatchStatus.name,
    'lastSyncedAt': track.lastSyncedAt?.millisecondsSinceEpoch,
    'credits': track.credits,
  };
}

Track _trackFromJson(Map<String, dynamic> json) {
  final paletteValues = (json['palette'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<int>()
      .toList(growable: false);

  return Track(
    id: (json['id'] as String?) ?? '',
    filePath: (json['filePath'] as String?) ?? '',
    fileName: (json['fileName'] as String?) ?? '',
    folderPath: (json['folderPath'] as String?) ?? '',
    title: (json['title'] as String?) ?? 'Untitled',
    artist: (json['artist'] as String?) ?? 'Local Music',
    album: (json['album'] as String?) ?? 'Imported Audio',
    palette: paletteValues.isEmpty
        ? const <Color>[Color(0xFF1ED760), Color(0xFF0F5132), Color(0xFF111318)]
        : paletteValues.map((value) => Color(value)).toList(growable: false),
    importedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['importedAt'] as int?) ?? 0,
    ),
    duration: switch (json['durationMs']) {
      final int durationMs => Duration(milliseconds: durationMs),
      _ => null,
    },
    fileExtension: json['fileExtension'] as String?,
    artworkUri: json['artworkUri'] as String?,
    lyricsAvailability: _enumByName(
      LyricsAvailability.values,
      json['lyricsAvailability'] as String?,
      LyricsAvailability.unavailable,
    ),
    albumArtist: json['albumArtist'] as String?,
    genre: json['genre'] as String?,
    year: json['year'] as int?,
    bitrate: json['bitrate'] as int?,
    trackNumber: json['trackNumber'] as int?,
    discNumber: json['discNumber'] as int?,
    fingerprint: json['fingerprint'] as String?,
    waveformUri: json['waveformUri'] as String?,
    availability: _enumByName(
      TrackAvailability.values,
      json['availability'] as String?,
      TrackAvailability.available,
    ),
    lastValidatedAt: switch (json['lastValidatedAt']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
    cloudMatchStatus: _enumByName(
      CloudMatchStatus.values,
      json['cloudMatchStatus'] as String?,
      CloudMatchStatus.localOnly,
    ),
    lastSyncedAt: switch (json['lastSyncedAt']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
    credits: _stringList(json['credits']),
  );
}

Map<String, Object?> _playbackHistoryEntryToJson(PlaybackHistoryEntry entry) {
  return <String, Object?>{
    'trackId': entry.trackId,
    'lastPlayedAt': entry.lastPlayedAt.millisecondsSinceEpoch,
    'lastPositionMs': entry.lastPosition.inMilliseconds,
    'playCount': entry.playCount,
    'totalListenedMs': entry.totalListened.inMilliseconds,
  };
}

PlaybackHistoryEntry _playbackHistoryEntryFromJson(Map<String, dynamic> json) {
  return PlaybackHistoryEntry(
    trackId: (json['trackId'] as String?) ?? '',
    lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['lastPlayedAt'] as int?) ?? 0,
    ),
    lastPosition: Duration(milliseconds: (json['lastPositionMs'] as int?) ?? 0),
    playCount: (json['playCount'] as int?) ?? 1,
    totalListened: Duration(
      milliseconds: (json['totalListenedMs'] as int?) ?? 0,
    ),
  );
}

Map<String, Object?> _userProfileToJson(UserProfile profile) {
  return <String, Object?>{
    'id': profile.id,
    'name': profile.name,
    'email': profile.email,
    'avatarSeed': profile.avatarSeed,
    'membershipTier': profile.membershipTier.name,
    'signedInAt': profile.signedInAt.millisecondsSinceEpoch,
    'trialEndsAt': profile.trialEndsAt?.millisecondsSinceEpoch,
  };
}

UserProfile _userProfileFromJson(Map<String, dynamic> json) {
  return UserProfile(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? 'Chi Listener',
    email: (json['email'] as String?) ?? '',
    avatarSeed: (json['avatarSeed'] as String?) ?? 'Chi Listener',
    membershipTier: _enumByName(
      MembershipTier.values,
      json['membershipTier'] as String?,
      MembershipTier.free,
    ),
    signedInAt: DateTime.fromMillisecondsSinceEpoch(
      (json['signedInAt'] as int?) ?? 0,
    ),
    trialEndsAt: switch (json['trialEndsAt']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
  );
}

Set<String> _stringSet(Object? value) {
  return _stringList(value).toSet();
}

List<String> _stringList(Object? value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null || name.isEmpty) {
    return fallback;
  }

  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }

  return fallback;
}
