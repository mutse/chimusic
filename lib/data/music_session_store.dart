import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_models.dart';

const String _sessionStorageKey = 'chimusic.session.v1';

class MusicSessionSnapshot {
  const MusicSessionSnapshot({
    this.tracks = const <Track>[],
    this.likedTrackIds = const <String>{},
    this.savedCollectionIds = const <String>{},
    this.recentTrackIds = const <String>[],
    this.recentSearches = const <String>[],
    this.selectedTab = MusicTab.home,
    this.libraryFilter = LibraryFilter.all,
    this.librarySort = LibrarySort.recent,
    this.searchQuery = '',
    this.queueTrackIds = const <String>[],
    this.currentTrackId,
    this.currentCollectionId,
    this.positionMs = 0,
  });

  final List<Track> tracks;
  final Set<String> likedTrackIds;
  final Set<String> savedCollectionIds;
  final List<String> recentTrackIds;
  final List<String> recentSearches;
  final MusicTab selectedTab;
  final LibraryFilter libraryFilter;
  final LibrarySort librarySort;
  final String searchQuery;
  final List<String> queueTrackIds;
  final String? currentTrackId;
  final String? currentCollectionId;
  final int positionMs;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'tracks': tracks.map(_trackToJson).toList(growable: false),
      'likedTrackIds': likedTrackIds.toList(growable: false),
      'savedCollectionIds': savedCollectionIds.toList(growable: false),
      'recentTrackIds': recentTrackIds,
      'recentSearches': recentSearches,
      'selectedTab': selectedTab.name,
      'libraryFilter': libraryFilter.name,
      'librarySort': librarySort.name,
      'searchQuery': searchQuery,
      'queueTrackIds': queueTrackIds,
      'currentTrackId': currentTrackId,
      'currentCollectionId': currentCollectionId,
      'positionMs': positionMs,
    };
  }

  static MusicSessionSnapshot fromJson(Map<String, dynamic> json) {
    final tracks = (json['tracks'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_trackFromJson)
        .toList(growable: false);

    return MusicSessionSnapshot(
      tracks: tracks,
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
      queueTrackIds: _stringList(json['queueTrackIds']),
      currentTrackId: json['currentTrackId'] as String?,
      currentCollectionId: json['currentCollectionId'] as String?,
      positionMs: (json['positionMs'] as int?) ?? 0,
    );
  }

  static Map<String, Object?> _trackToJson(Track track) {
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
    };
  }

  static Track _trackFromJson(Map<String, dynamic> json) {
    final paletteValues =
        (json['palette'] as List<dynamic>? ?? const <dynamic>[])
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
          ? const <Color>[
              Color(0xFF1ED760),
              Color(0xFF0F5132),
              Color(0xFF111318),
            ]
          : paletteValues.map((value) => Color(value)).toList(growable: false),
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['importedAt'] as int?) ?? 0,
      ),
      duration: switch (json['durationMs']) {
        final int durationMs => Duration(milliseconds: durationMs),
        _ => null,
      },
      fileExtension: json['fileExtension'] as String?,
    );
  }

  static Set<String> _stringSet(Object? value) {
    return _stringList(value).toSet();
  }

  static List<String> _stringList(Object? value) {
    return (value as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
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
}

abstract class MusicSessionStore {
  Future<MusicSessionSnapshot> load();

  Future<void> save(MusicSessionSnapshot snapshot);
}

class SharedPreferencesMusicSessionStore implements MusicSessionStore {
  @override
  Future<MusicSessionSnapshot> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_sessionStorageKey);
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
