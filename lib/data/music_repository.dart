import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/music_models.dart';
import 'music_session_store.dart';

const String _databaseFileName = 'chimusic_v1.db';
const String _legacyMigrationStateKey = 'chimusic.sqlite.migrated.v1';
const String _localSnapshotDirectoryName = 'chimusic';
const String _localSnapshotFileName = 'music_records_v1.json';
const int _databaseVersion = 2;

class MusicRepositorySnapshot {
  const MusicRepositorySnapshot({
    this.tracks = const <Track>[],
    this.trackSources = const <TrackSourceRecord>[],
    this.playbackStats = const <PlaybackHistoryEntry>[],
    this.playbackEvents = const <PlaybackEvent>[],
    this.playbackSession = const PlaybackSessionState(),
    this.likedTrackIds = const <String>{},
    this.savedCollectionIds = const <String>{},
    this.recentTrackIds = const <String>[],
    this.recentSearches = const <String>[],
    this.selectedTab = MusicTab.home,
    this.libraryFilter = LibraryFilter.all,
    this.librarySort = LibrarySort.recent,
    this.searchQuery = '',
    this.searchMode = SearchMode.standard,
    this.userProfile,
    this.aiSearchTrialsRemaining = 2,
    this.hasUnlockedAiUpsell = false,
    this.themeMode = AppThemeMode.dark,
    this.isShuffleEnabled = false,
    this.isRepeatEnabled = false,
  });

  final List<Track> tracks;
  final List<TrackSourceRecord> trackSources;
  final List<PlaybackHistoryEntry> playbackStats;
  final List<PlaybackEvent> playbackEvents;
  final PlaybackSessionState playbackSession;
  final Set<String> likedTrackIds;
  final Set<String> savedCollectionIds;
  final List<String> recentTrackIds;
  final List<String> recentSearches;
  final MusicTab selectedTab;
  final LibraryFilter libraryFilter;
  final LibrarySort librarySort;
  final String searchQuery;
  final SearchMode searchMode;
  final UserProfile? userProfile;
  final int aiSearchTrialsRemaining;
  final bool hasUnlockedAiUpsell;
  final AppThemeMode themeMode;
  final bool isShuffleEnabled;
  final bool isRepeatEnabled;
}

abstract class MusicRepository {
  Future<MusicRepositorySnapshot> load();

  Future<void> save(MusicRepositorySnapshot snapshot);

  Future<void> close();
}

class MusicSnapshotFileStore {
  MusicSnapshotFileStore({
    Future<Directory> Function()? directoryProvider,
    this.directoryName = _localSnapshotDirectoryName,
    this.fileName = _localSnapshotFileName,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  final String directoryName;
  final String fileName;

  Future<File> resolveFile() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, directoryName, fileName));
  }

  Future<MusicRepositorySnapshot?> load() async {
    try {
      final file = await resolveFile();
      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      if (raw.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return _repositorySnapshotFromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(MusicRepositorySnapshot snapshot) async {
    final file = await resolveFile();
    await file.parent.create(recursive: true);
    final payload = jsonEncode(_repositorySnapshotToJson(snapshot));
    await file.writeAsString(payload, flush: true);
  }
}

class LegacySessionStoreRepository implements MusicRepository {
  LegacySessionStoreRepository(this._sessionStore);

  final MusicSessionStore _sessionStore;

  @override
  Future<MusicRepositorySnapshot> load() async {
    final snapshot = await _sessionStore.load();
    return MusicRepositorySnapshot(
      tracks: snapshot.tracks,
      trackSources: snapshot.tracks
          .map(
            (track) => TrackSourceRecord(
              trackId: track.id,
              platform: 'legacy',
              locator: track.filePath,
            ),
          )
          .toList(growable: false),
      playbackStats: snapshot.playbackHistory,
      playbackSession: PlaybackSessionState(
        queueTrackIds: snapshot.queueTrackIds,
        currentTrackId: snapshot.currentTrackId,
        currentCollectionId: snapshot.currentCollectionId,
        position: Duration(milliseconds: snapshot.positionMs),
      ),
      likedTrackIds: snapshot.likedTrackIds,
      savedCollectionIds: snapshot.savedCollectionIds,
      recentTrackIds: snapshot.recentTrackIds,
      recentSearches: snapshot.recentSearches,
      selectedTab: snapshot.selectedTab,
      libraryFilter: snapshot.libraryFilter,
      librarySort: snapshot.librarySort,
      searchQuery: snapshot.searchQuery,
      searchMode: snapshot.searchMode,
      userProfile: snapshot.userProfile,
      aiSearchTrialsRemaining: snapshot.aiSearchTrialsRemaining,
      hasUnlockedAiUpsell: snapshot.hasUnlockedAiUpsell,
      themeMode: snapshot.themeMode,
      isShuffleEnabled: snapshot.isShuffleEnabled,
      isRepeatEnabled: snapshot.isRepeatEnabled,
    );
  }

  @override
  Future<void> save(MusicRepositorySnapshot snapshot) {
    return _sessionStore.save(
      MusicSessionSnapshot(
        tracks: snapshot.tracks,
        playbackHistory: snapshot.playbackStats,
        likedTrackIds: snapshot.likedTrackIds,
        savedCollectionIds: snapshot.savedCollectionIds,
        recentTrackIds: snapshot.recentTrackIds,
        recentSearches: snapshot.recentSearches,
        selectedTab: snapshot.selectedTab,
        libraryFilter: snapshot.libraryFilter,
        librarySort: snapshot.librarySort,
        searchQuery: snapshot.searchQuery,
        searchMode: snapshot.searchMode,
        queueTrackIds: snapshot.playbackSession.queueTrackIds,
        currentTrackId: snapshot.playbackSession.currentTrackId,
        currentCollectionId: snapshot.playbackSession.currentCollectionId,
        positionMs: snapshot.playbackSession.position.inMilliseconds,
        userProfile: snapshot.userProfile,
        aiSearchTrialsRemaining: snapshot.aiSearchTrialsRemaining,
        hasUnlockedAiUpsell: snapshot.hasUnlockedAiUpsell,
        themeMode: snapshot.themeMode,
        isShuffleEnabled: snapshot.isShuffleEnabled,
        isRepeatEnabled: snapshot.isRepeatEnabled,
      ),
    );
  }

  @override
  Future<void> close() async {}
}

class SqliteMusicRepository implements MusicRepository {
  SqliteMusicRepository({
    MusicSessionStore? legacySessionStore,
    MusicSnapshotFileStore? snapshotFileStore,
  }) : _legacySessionStore =
           legacySessionStore ?? SharedPreferencesMusicSessionStore(),
       _snapshotFileStore = snapshotFileStore ?? MusicSnapshotFileStore();

  final MusicSessionStore _legacySessionStore;
  final MusicSnapshotFileStore _snapshotFileStore;
  Database? _database;

  @override
  Future<MusicRepositorySnapshot> load() async {
    final db = await _openDatabase();
    await _migrateLegacySnapshotIfNeeded(db);

    final fileSnapshot = await _snapshotFileStore.load();
    final databaseSnapshot = await _loadSnapshotFromDatabase(db);

    final resolvedSnapshot =
        _preferFileSnapshot(
          fileSnapshot: fileSnapshot,
          databaseSnapshot: databaseSnapshot,
        )
        ? (fileSnapshot ?? const MusicRepositorySnapshot())
        : databaseSnapshot;

    if (_isRepositorySnapshotEmpty(resolvedSnapshot)) {
      return resolvedSnapshot;
    }

    if (_preferFileSnapshot(
      fileSnapshot: fileSnapshot,
      databaseSnapshot: databaseSnapshot,
    )) {
      if (_isRepositorySnapshotEmpty(databaseSnapshot) ||
          _snapshotVersionStamp(fileSnapshot) >
              _snapshotVersionStamp(databaseSnapshot)) {
        await _writeSnapshotToDatabase(db, resolvedSnapshot);
      }
    } else if (fileSnapshot == null ||
        _snapshotVersionStamp(databaseSnapshot) >
            _snapshotVersionStamp(fileSnapshot)) {
      await _snapshotFileStore.save(resolvedSnapshot);
    }

    return resolvedSnapshot;
  }

  @override
  Future<void> save(MusicRepositorySnapshot snapshot) async {
    final db = await _openDatabase();
    await _writeSnapshotToDatabase(db, snapshot);
    await _snapshotFileStore.save(snapshot);
  }

  @override
  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  Future<MusicRepositorySnapshot> _loadSnapshotFromDatabase(Database db) async {
    final trackMaps = await db.query('tracks');
    final sourceMaps = await db.query('track_sources');
    final statMaps = await db.query('track_stats');
    final eventMaps = await db.query('playback_events');
    final sessionMaps = await db.query('playback_session', where: 'id = 1');
    final uiMaps = await db.query('ui_state', where: 'id = 1');

    final uiState = uiMaps.isEmpty ? const <String, Object?>{} : uiMaps.single;
    final sessionState = sessionMaps.isEmpty
        ? const <String, Object?>{}
        : sessionMaps.single;

    return MusicRepositorySnapshot(
      tracks: trackMaps.map(_trackFromRow).toList(growable: false),
      trackSources: sourceMaps.map(_trackSourceFromRow).toList(growable: false),
      playbackStats: statMaps.map(_playbackStatFromRow).toList(growable: false),
      playbackEvents: eventMaps
          .map(_playbackEventFromRow)
          .toList(growable: false),
      playbackSession: _playbackSessionFromRow(sessionState),
      likedTrackIds: _decodeStringSet(uiState['liked_track_ids_json']),
      savedCollectionIds: _decodeStringSet(
        uiState['saved_collection_ids_json'],
      ),
      recentTrackIds: _decodeStringList(uiState['recent_track_ids_json']),
      recentSearches: _decodeStringList(uiState['recent_searches_json']),
      selectedTab: _enumByName(
        MusicTab.values,
        uiState['selected_tab'] as String?,
        MusicTab.home,
      ),
      libraryFilter: _enumByName(
        LibraryFilter.values,
        uiState['library_filter'] as String?,
        LibraryFilter.all,
      ),
      librarySort: _enumByName(
        LibrarySort.values,
        uiState['library_sort'] as String?,
        LibrarySort.recent,
      ),
      searchQuery: (uiState['search_query'] as String?) ?? '',
      searchMode: _enumByName(
        SearchMode.values,
        uiState['search_mode'] as String?,
        SearchMode.standard,
      ),
      userProfile: _decodeUserProfile(uiState['user_profile_json']),
      aiSearchTrialsRemaining:
          (uiState['ai_search_trials_remaining'] as int?) ?? 2,
      hasUnlockedAiUpsell:
          (uiState['has_unlocked_ai_upsell'] as int? ?? 0) == 1,
      themeMode: _enumByName(
        AppThemeMode.values,
        uiState['theme_mode'] as String?,
        AppThemeMode.dark,
      ),
      isShuffleEnabled: (uiState['shuffle_enabled'] as int? ?? 0) == 1,
      isRepeatEnabled: (uiState['repeat_enabled'] as int? ?? 0) == 1,
    );
  }

  Future<void> _writeSnapshotToDatabase(
    Database db,
    MusicRepositorySnapshot snapshot,
  ) async {
    await db.transaction((transaction) async {
      await transaction.delete('tracks');
      await transaction.delete('track_sources');
      await transaction.delete('track_stats');
      await transaction.delete('playback_events');

      final batch = transaction.batch();
      for (final track in snapshot.tracks) {
        batch.insert('tracks', _trackToRow(track));
      }
      for (final source in snapshot.trackSources) {
        batch.insert('track_sources', _trackSourceToRow(source));
      }
      for (final stat in snapshot.playbackStats) {
        batch.insert('track_stats', _playbackStatToRow(stat));
      }
      for (final event in snapshot.playbackEvents) {
        batch.insert('playback_events', _playbackEventToRow(event));
      }
      batch.insert(
        'playback_session',
        _playbackSessionToRow(snapshot.playbackSession),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'ui_state',
        _uiStateToRow(snapshot),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);
    });
  }

  Future<Database> _openDatabase() async {
    final cached = _database;
    if (cached != null) {
      return cached;
    }

    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseFileName);
    final db = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tracks(
            id TEXT PRIMARY KEY,
            file_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            folder_path TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT NOT NULL,
            palette_json TEXT NOT NULL,
            imported_at INTEGER NOT NULL,
            duration_ms INTEGER,
            file_extension TEXT,
            artwork_uri TEXT,
            lyrics_availability TEXT NOT NULL,
            album_artist TEXT,
            genre TEXT,
            year INTEGER,
            bitrate INTEGER,
            track_number INTEGER,
            disc_number INTEGER,
            fingerprint TEXT,
            waveform_uri TEXT,
            availability TEXT NOT NULL,
            last_validated_at INTEGER,
            cloud_match_status TEXT NOT NULL,
            last_synced_at INTEGER,
            credits_json TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE track_sources(
            track_id TEXT PRIMARY KEY,
            platform TEXT NOT NULL,
            locator TEXT NOT NULL,
            bookmark_base64 TEXT,
            relative_path TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE playback_session(
            id INTEGER PRIMARY KEY CHECK (id = 1),
            queue_track_ids_json TEXT NOT NULL,
            current_track_id TEXT,
            current_collection_id TEXT,
            position_ms INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE playback_events(
            id TEXT PRIMARY KEY,
            track_id TEXT NOT NULL,
            collection_id TEXT,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            max_position_ms INTEGER NOT NULL,
            end_reason TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE track_stats(
            track_id TEXT PRIMARY KEY,
            last_played_at INTEGER NOT NULL,
            resume_position_ms INTEGER NOT NULL,
            play_count INTEGER NOT NULL,
            total_listened_ms INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE ui_state(
            id INTEGER PRIMARY KEY CHECK (id = 1),
            selected_tab TEXT NOT NULL,
            library_filter TEXT NOT NULL,
            library_sort TEXT NOT NULL,
            search_query TEXT NOT NULL,
            search_mode TEXT NOT NULL,
            liked_track_ids_json TEXT NOT NULL,
            saved_collection_ids_json TEXT NOT NULL,
            recent_track_ids_json TEXT NOT NULL,
            recent_searches_json TEXT NOT NULL,
            user_profile_json TEXT,
            ai_search_trials_remaining INTEGER NOT NULL,
            has_unlocked_ai_upsell INTEGER NOT NULL,
            theme_mode TEXT NOT NULL,
            shuffle_enabled INTEGER NOT NULL,
            repeat_enabled INTEGER NOT NULL
          )
        ''');
        await db.insert(
          'playback_session',
          _playbackSessionToRow(const PlaybackSessionState()),
        );
        await db.insert(
          'ui_state',
          _uiStateToRow(const MusicRepositorySnapshot()),
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE ui_state ADD COLUMN theme_mode TEXT NOT NULL DEFAULT \'dark\'',
          );
          await db.execute(
            'ALTER TABLE ui_state ADD COLUMN shuffle_enabled INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE ui_state ADD COLUMN repeat_enabled INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
    _database = db;
    return db;
  }

  Future<void> _migrateLegacySnapshotIfNeeded(Database db) async {
    final preferences = await SharedPreferences.getInstance();
    final alreadyMigrated =
        preferences.getBool(_legacyMigrationStateKey) ?? false;
    if (alreadyMigrated) {
      return;
    }

    final trackCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tracks'),
    );
    if ((trackCount ?? 0) > 0) {
      await preferences.setBool(_legacyMigrationStateKey, true);
      return;
    }

    final legacySnapshot = await _legacySessionStore.load();
    if (_isLegacySnapshotEmpty(legacySnapshot)) {
      await preferences.setBool(_legacyMigrationStateKey, true);
      return;
    }

    final migratedSnapshot = MusicRepositorySnapshot(
      tracks: legacySnapshot.tracks,
      trackSources: legacySnapshot.tracks
          .map(
            (track) => TrackSourceRecord(
              trackId: track.id,
              platform: 'legacy',
              locator: track.filePath,
            ),
          )
          .toList(growable: false),
      playbackStats: legacySnapshot.playbackHistory,
      playbackSession: PlaybackSessionState(
        queueTrackIds: legacySnapshot.queueTrackIds,
        currentTrackId: legacySnapshot.currentTrackId,
        currentCollectionId: legacySnapshot.currentCollectionId,
        position: Duration(milliseconds: legacySnapshot.positionMs),
      ),
      likedTrackIds: legacySnapshot.likedTrackIds,
      savedCollectionIds: legacySnapshot.savedCollectionIds,
      recentTrackIds: legacySnapshot.recentTrackIds,
      recentSearches: legacySnapshot.recentSearches,
      selectedTab: legacySnapshot.selectedTab,
      libraryFilter: legacySnapshot.libraryFilter,
      librarySort: legacySnapshot.librarySort,
      searchQuery: legacySnapshot.searchQuery,
      searchMode: legacySnapshot.searchMode,
      userProfile: legacySnapshot.userProfile,
      aiSearchTrialsRemaining: legacySnapshot.aiSearchTrialsRemaining,
      hasUnlockedAiUpsell: legacySnapshot.hasUnlockedAiUpsell,
      themeMode: legacySnapshot.themeMode,
      isShuffleEnabled: legacySnapshot.isShuffleEnabled,
      isRepeatEnabled: legacySnapshot.isRepeatEnabled,
    );
    await save(migratedSnapshot);
    await preferences.setBool(_legacyMigrationStateKey, true);
  }

  bool _isLegacySnapshotEmpty(MusicSessionSnapshot snapshot) {
    return snapshot.tracks.isEmpty &&
        snapshot.playbackHistory.isEmpty &&
        snapshot.likedTrackIds.isEmpty &&
        snapshot.savedCollectionIds.isEmpty &&
        snapshot.recentTrackIds.isEmpty &&
        snapshot.recentSearches.isEmpty &&
        snapshot.queueTrackIds.isEmpty &&
        snapshot.currentTrackId == null &&
        snapshot.positionMs == 0 &&
        snapshot.searchQuery.isEmpty;
  }
}

bool _preferFileSnapshot({
  required MusicRepositorySnapshot? fileSnapshot,
  required MusicRepositorySnapshot databaseSnapshot,
}) {
  if (fileSnapshot == null) {
    return false;
  }
  if (_isRepositorySnapshotEmpty(databaseSnapshot)) {
    return true;
  }
  return _snapshotVersionStamp(fileSnapshot) >=
      _snapshotVersionStamp(databaseSnapshot);
}

bool _isRepositorySnapshotEmpty(MusicRepositorySnapshot snapshot) {
  return snapshot.tracks.isEmpty &&
      snapshot.trackSources.isEmpty &&
      snapshot.playbackStats.isEmpty &&
      snapshot.playbackEvents.isEmpty &&
      snapshot.likedTrackIds.isEmpty &&
      snapshot.savedCollectionIds.isEmpty &&
      snapshot.recentTrackIds.isEmpty &&
      snapshot.recentSearches.isEmpty &&
      snapshot.playbackSession.queueTrackIds.isEmpty &&
      snapshot.playbackSession.currentTrackId == null &&
      snapshot.playbackSession.position == Duration.zero &&
      snapshot.searchQuery.isEmpty &&
      snapshot.userProfile == null;
}

int _snapshotVersionStamp(MusicRepositorySnapshot? snapshot) {
  if (snapshot == null) {
    return -1;
  }

  final candidates = <int>[
    if (snapshot.playbackSession.updatedAt case final updatedAt?)
      updatedAt.millisecondsSinceEpoch,
    for (final track in snapshot.tracks)
      track.importedAt.millisecondsSinceEpoch,
    for (final stat in snapshot.playbackStats)
      stat.lastPlayedAt.millisecondsSinceEpoch,
    for (final event in snapshot.playbackEvents)
      event.endedAt?.millisecondsSinceEpoch ??
          event.startedAt.millisecondsSinceEpoch,
    if (snapshot.userProfile case final userProfile?)
      userProfile.signedInAt.millisecondsSinceEpoch,
  ];

  if (candidates.isEmpty) {
    return 0;
  }

  return candidates.reduce((current, next) => current > next ? current : next);
}

class InMemoryMusicRepository implements MusicRepository {
  InMemoryMusicRepository([this.snapshot = const MusicRepositorySnapshot()]);

  MusicRepositorySnapshot snapshot;

  @override
  Future<MusicRepositorySnapshot> load() async => snapshot;

  @override
  Future<void> save(MusicRepositorySnapshot snapshot) async {
    this.snapshot = snapshot;
  }

  @override
  Future<void> close() async {}
}

Map<String, Object?> _repositorySnapshotToJson(
  MusicRepositorySnapshot snapshot,
) {
  return <String, Object?>{
    'tracks': snapshot.tracks.map(_trackToSnapshotJson).toList(growable: false),
    'trackSources': snapshot.trackSources
        .map(_trackSourceToSnapshotJson)
        .toList(growable: false),
    'playbackStats': snapshot.playbackStats
        .map(_playbackStatToSnapshotJson)
        .toList(growable: false),
    'playbackEvents': snapshot.playbackEvents
        .map(_playbackEventToSnapshotJson)
        .toList(growable: false),
    'playbackSession': _playbackSessionToSnapshotJson(snapshot.playbackSession),
    'likedTrackIds': snapshot.likedTrackIds.toList(growable: false),
    'savedCollectionIds': snapshot.savedCollectionIds.toList(growable: false),
    'recentTrackIds': snapshot.recentTrackIds,
    'recentSearches': snapshot.recentSearches,
    'selectedTab': snapshot.selectedTab.name,
    'libraryFilter': snapshot.libraryFilter.name,
    'librarySort': snapshot.librarySort.name,
    'searchQuery': snapshot.searchQuery,
    'searchMode': snapshot.searchMode.name,
    'userProfile': snapshot.userProfile == null
        ? null
        : _userProfileToSnapshotJson(snapshot.userProfile!),
    'aiSearchTrialsRemaining': snapshot.aiSearchTrialsRemaining,
    'hasUnlockedAiUpsell': snapshot.hasUnlockedAiUpsell,
    'themeMode': snapshot.themeMode.name,
    'isShuffleEnabled': snapshot.isShuffleEnabled,
    'isRepeatEnabled': snapshot.isRepeatEnabled,
  };
}

MusicRepositorySnapshot _repositorySnapshotFromJson(Map<String, dynamic> json) {
  final rawUserProfile = json['userProfile'];
  final rawPlaybackSession = json['playbackSession'];

  return MusicRepositorySnapshot(
    tracks: (json['tracks'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_trackFromSnapshotJson)
        .toList(growable: false),
    trackSources: (json['trackSources'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_trackSourceFromSnapshotJson)
        .toList(growable: false),
    playbackStats:
        (json['playbackStats'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_playbackStatFromSnapshotJson)
            .toList(growable: false),
    playbackEvents:
        (json['playbackEvents'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_playbackEventFromSnapshotJson)
            .toList(growable: false),
    playbackSession: rawPlaybackSession is Map<String, dynamic>
        ? _playbackSessionFromSnapshotJson(rawPlaybackSession)
        : const PlaybackSessionState(),
    likedTrackIds: _jsonStringSet(json['likedTrackIds']),
    savedCollectionIds: _jsonStringSet(json['savedCollectionIds']),
    recentTrackIds: _jsonStringList(json['recentTrackIds']),
    recentSearches: _jsonStringList(json['recentSearches']),
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
    userProfile: rawUserProfile is Map<String, dynamic>
        ? _userProfileFromSnapshotJson(rawUserProfile)
        : null,
    aiSearchTrialsRemaining: (json['aiSearchTrialsRemaining'] as int?) ?? 2,
    hasUnlockedAiUpsell: (json['hasUnlockedAiUpsell'] as bool?) ?? false,
    themeMode: _enumByName(
      AppThemeMode.values,
      json['themeMode'] as String?,
      AppThemeMode.dark,
    ),
    isShuffleEnabled: (json['isShuffleEnabled'] as bool?) ?? false,
    isRepeatEnabled: (json['isRepeatEnabled'] as bool?) ?? false,
  );
}

Map<String, Object?> _trackToSnapshotJson(Track track) {
  return <String, Object?>{
    'id': track.id,
    'filePath': track.filePath,
    'fileName': track.fileName,
    'folderPath': track.folderPath,
    'title': track.title,
    'artist': track.artist,
    'album': track.album,
    'palette': track.palette
        .map((color) => color.toARGB32())
        .toList(growable: false),
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

Track _trackFromSnapshotJson(Map<String, dynamic> json) {
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
      final int value => Duration(milliseconds: value),
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
    credits: _jsonStringList(json['credits']),
  );
}

Map<String, Object?> _trackSourceToSnapshotJson(TrackSourceRecord source) {
  return <String, Object?>{
    'trackId': source.trackId,
    'platform': source.platform,
    'locator': source.locator,
    'bookmarkBase64': source.bookmarkBase64,
    'relativePath': source.relativePath,
  };
}

TrackSourceRecord _trackSourceFromSnapshotJson(Map<String, dynamic> json) {
  return TrackSourceRecord(
    trackId: (json['trackId'] as String?) ?? '',
    platform: (json['platform'] as String?) ?? 'unknown',
    locator: (json['locator'] as String?) ?? '',
    bookmarkBase64: json['bookmarkBase64'] as String?,
    relativePath: json['relativePath'] as String?,
  );
}

Map<String, Object?> _playbackStatToSnapshotJson(PlaybackHistoryEntry stat) {
  return <String, Object?>{
    'trackId': stat.trackId,
    'lastPlayedAt': stat.lastPlayedAt.millisecondsSinceEpoch,
    'lastPositionMs': stat.lastPosition.inMilliseconds,
    'playCount': stat.playCount,
    'totalListenedMs': stat.totalListened.inMilliseconds,
  };
}

PlaybackHistoryEntry _playbackStatFromSnapshotJson(Map<String, dynamic> json) {
  return PlaybackHistoryEntry(
    trackId: (json['trackId'] as String?) ?? '',
    lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['lastPlayedAt'] as int?) ?? 0,
    ),
    lastPosition: Duration(milliseconds: (json['lastPositionMs'] as int?) ?? 0),
    playCount: (json['playCount'] as int?) ?? 0,
    totalListened: Duration(
      milliseconds: (json['totalListenedMs'] as int?) ?? 0,
    ),
  );
}

Map<String, Object?> _playbackEventToSnapshotJson(PlaybackEvent event) {
  return <String, Object?>{
    'id': event.id,
    'trackId': event.trackId,
    'collectionId': event.collectionId,
    'startedAt': event.startedAt.millisecondsSinceEpoch,
    'endedAt': event.endedAt?.millisecondsSinceEpoch,
    'maxPositionMs': event.maxPosition.inMilliseconds,
    'endReason': event.endReason?.name,
  };
}

PlaybackEvent _playbackEventFromSnapshotJson(Map<String, dynamic> json) {
  final endReasonName = json['endReason'] as String?;
  return PlaybackEvent(
    id: (json['id'] as String?) ?? '',
    trackId: (json['trackId'] as String?) ?? '',
    collectionId: json['collectionId'] as String?,
    startedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['startedAt'] as int?) ?? 0,
    ),
    endedAt: switch (json['endedAt']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
    maxPosition: Duration(milliseconds: (json['maxPositionMs'] as int?) ?? 0),
    endReason: endReasonName == null
        ? null
        : _enumByName(
            PlaybackEndReason.values,
            endReasonName,
            PlaybackEndReason.stopped,
          ),
  );
}

Map<String, Object?> _playbackSessionToSnapshotJson(
  PlaybackSessionState state,
) {
  return <String, Object?>{
    'queueTrackIds': state.queueTrackIds,
    'currentTrackId': state.currentTrackId,
    'currentCollectionId': state.currentCollectionId,
    'positionMs': state.position.inMilliseconds,
    'updatedAt': state.updatedAt?.millisecondsSinceEpoch,
  };
}

PlaybackSessionState _playbackSessionFromSnapshotJson(
  Map<String, dynamic> json,
) {
  return PlaybackSessionState(
    queueTrackIds: _jsonStringList(json['queueTrackIds']),
    currentTrackId: json['currentTrackId'] as String?,
    currentCollectionId: json['currentCollectionId'] as String?,
    position: Duration(milliseconds: (json['positionMs'] as int?) ?? 0),
    updatedAt: switch (json['updatedAt']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
  );
}

Map<String, Object?> _userProfileToSnapshotJson(UserProfile profile) {
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

UserProfile _userProfileFromSnapshotJson(Map<String, dynamic> json) {
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

Map<String, Object?> _trackToRow(Track track) {
  return <String, Object?>{
    'id': track.id,
    'file_path': track.filePath,
    'file_name': track.fileName,
    'folder_path': track.folderPath,
    'title': track.title,
    'artist': track.artist,
    'album': track.album,
    'palette_json': jsonEncode(
      track.palette.map((color) => color.toARGB32()).toList(growable: false),
    ),
    'imported_at': track.importedAt.millisecondsSinceEpoch,
    'duration_ms': track.duration?.inMilliseconds,
    'file_extension': track.fileExtension,
    'artwork_uri': track.artworkUri,
    'lyrics_availability': track.lyricsAvailability.name,
    'album_artist': track.albumArtist,
    'genre': track.genre,
    'year': track.year,
    'bitrate': track.bitrate,
    'track_number': track.trackNumber,
    'disc_number': track.discNumber,
    'fingerprint': track.fingerprint,
    'waveform_uri': track.waveformUri,
    'availability': track.availability.name,
    'last_validated_at': track.lastValidatedAt?.millisecondsSinceEpoch,
    'cloud_match_status': track.cloudMatchStatus.name,
    'last_synced_at': track.lastSyncedAt?.millisecondsSinceEpoch,
    'credits_json': jsonEncode(track.credits),
  };
}

Track _trackFromRow(Map<String, Object?> row) {
  final paletteValues = _decodeIntList(row['palette_json']);
  return Track(
    id: (row['id'] as String?) ?? '',
    filePath: (row['file_path'] as String?) ?? '',
    fileName: (row['file_name'] as String?) ?? '',
    folderPath: (row['folder_path'] as String?) ?? '',
    title: (row['title'] as String?) ?? 'Untitled',
    artist: (row['artist'] as String?) ?? 'Local Music',
    album: (row['album'] as String?) ?? 'Imported Audio',
    palette: paletteValues.isEmpty
        ? const <Color>[Color(0xFF1ED760), Color(0xFF0F5132), Color(0xFF111318)]
        : paletteValues.map((value) => Color(value)).toList(growable: false),
    importedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['imported_at'] as int?) ?? 0,
    ),
    duration: switch (row['duration_ms']) {
      final int durationMs => Duration(milliseconds: durationMs),
      _ => null,
    },
    fileExtension: row['file_extension'] as String?,
    artworkUri: row['artwork_uri'] as String?,
    lyricsAvailability: _enumByName(
      LyricsAvailability.values,
      row['lyrics_availability'] as String?,
      LyricsAvailability.unavailable,
    ),
    albumArtist: row['album_artist'] as String?,
    genre: row['genre'] as String?,
    year: row['year'] as int?,
    bitrate: row['bitrate'] as int?,
    trackNumber: row['track_number'] as int?,
    discNumber: row['disc_number'] as int?,
    fingerprint: row['fingerprint'] as String?,
    waveformUri: row['waveform_uri'] as String?,
    availability: _enumByName(
      TrackAvailability.values,
      row['availability'] as String?,
      TrackAvailability.available,
    ),
    lastValidatedAt: switch (row['last_validated_at']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
    cloudMatchStatus: _enumByName(
      CloudMatchStatus.values,
      row['cloud_match_status'] as String?,
      CloudMatchStatus.localOnly,
    ),
    lastSyncedAt: switch (row['last_synced_at']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
    credits: _decodeStringList(row['credits_json']),
  );
}

Map<String, Object?> _trackSourceToRow(TrackSourceRecord source) {
  return <String, Object?>{
    'track_id': source.trackId,
    'platform': source.platform,
    'locator': source.locator,
    'bookmark_base64': source.bookmarkBase64,
    'relative_path': source.relativePath,
  };
}

TrackSourceRecord _trackSourceFromRow(Map<String, Object?> row) {
  return TrackSourceRecord(
    trackId: (row['track_id'] as String?) ?? '',
    platform: (row['platform'] as String?) ?? 'unknown',
    locator: (row['locator'] as String?) ?? '',
    bookmarkBase64: row['bookmark_base64'] as String?,
    relativePath: row['relative_path'] as String?,
  );
}

Map<String, Object?> _playbackStatToRow(PlaybackHistoryEntry stat) {
  return <String, Object?>{
    'track_id': stat.trackId,
    'last_played_at': stat.lastPlayedAt.millisecondsSinceEpoch,
    'resume_position_ms': stat.lastPosition.inMilliseconds,
    'play_count': stat.playCount,
    'total_listened_ms': stat.totalListened.inMilliseconds,
  };
}

PlaybackHistoryEntry _playbackStatFromRow(Map<String, Object?> row) {
  return PlaybackHistoryEntry(
    trackId: (row['track_id'] as String?) ?? '',
    lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['last_played_at'] as int?) ?? 0,
    ),
    lastPosition: Duration(
      milliseconds: (row['resume_position_ms'] as int?) ?? 0,
    ),
    playCount: (row['play_count'] as int?) ?? 0,
    totalListened: Duration(
      milliseconds: (row['total_listened_ms'] as int?) ?? 0,
    ),
  );
}

Map<String, Object?> _playbackEventToRow(PlaybackEvent event) {
  return <String, Object?>{
    'id': event.id,
    'track_id': event.trackId,
    'collection_id': event.collectionId,
    'started_at': event.startedAt.millisecondsSinceEpoch,
    'ended_at': event.endedAt?.millisecondsSinceEpoch,
    'max_position_ms': event.maxPosition.inMilliseconds,
    'end_reason': event.endReason?.name,
  };
}

PlaybackEvent _playbackEventFromRow(Map<String, Object?> row) {
  final endReasonName = row['end_reason'] as String?;
  return PlaybackEvent(
    id: (row['id'] as String?) ?? '',
    trackId: (row['track_id'] as String?) ?? '',
    collectionId: row['collection_id'] as String?,
    startedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['started_at'] as int?) ?? 0,
    ),
    endedAt: switch (row['ended_at']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
    maxPosition: Duration(milliseconds: (row['max_position_ms'] as int?) ?? 0),
    endReason: endReasonName == null
        ? null
        : _enumByName(
            PlaybackEndReason.values,
            endReasonName,
            PlaybackEndReason.stopped,
          ),
  );
}

Map<String, Object?> _playbackSessionToRow(PlaybackSessionState state) {
  return <String, Object?>{
    'id': 1,
    'queue_track_ids_json': jsonEncode(state.queueTrackIds),
    'current_track_id': state.currentTrackId,
    'current_collection_id': state.currentCollectionId,
    'position_ms': state.position.inMilliseconds,
    'updated_at': state.updatedAt?.millisecondsSinceEpoch,
  };
}

PlaybackSessionState _playbackSessionFromRow(Map<String, Object?> row) {
  return PlaybackSessionState(
    queueTrackIds: _decodeStringList(row['queue_track_ids_json']),
    currentTrackId: row['current_track_id'] as String?,
    currentCollectionId: row['current_collection_id'] as String?,
    position: Duration(milliseconds: (row['position_ms'] as int?) ?? 0),
    updatedAt: switch (row['updated_at']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
  );
}

Map<String, Object?> _uiStateToRow(MusicRepositorySnapshot snapshot) {
  return <String, Object?>{
    'id': 1,
    'selected_tab': snapshot.selectedTab.name,
    'library_filter': snapshot.libraryFilter.name,
    'library_sort': snapshot.librarySort.name,
    'search_query': snapshot.searchQuery,
    'search_mode': snapshot.searchMode.name,
    'liked_track_ids_json': jsonEncode(
      snapshot.likedTrackIds.toList(growable: false),
    ),
    'saved_collection_ids_json': jsonEncode(
      snapshot.savedCollectionIds.toList(growable: false),
    ),
    'recent_track_ids_json': jsonEncode(snapshot.recentTrackIds),
    'recent_searches_json': jsonEncode(snapshot.recentSearches),
    'user_profile_json': _encodeUserProfile(snapshot.userProfile),
    'ai_search_trials_remaining': snapshot.aiSearchTrialsRemaining,
    'has_unlocked_ai_upsell': snapshot.hasUnlockedAiUpsell ? 1 : 0,
    'theme_mode': snapshot.themeMode.name,
    'shuffle_enabled': snapshot.isShuffleEnabled ? 1 : 0,
    'repeat_enabled': snapshot.isRepeatEnabled ? 1 : 0,
  };
}

String? _encodeUserProfile(UserProfile? profile) {
  if (profile == null) {
    return null;
  }

  return jsonEncode(<String, Object?>{
    'id': profile.id,
    'name': profile.name,
    'email': profile.email,
    'avatar_seed': profile.avatarSeed,
    'membership_tier': profile.membershipTier.name,
    'signed_in_at': profile.signedInAt.millisecondsSinceEpoch,
    'trial_ends_at': profile.trialEndsAt?.millisecondsSinceEpoch,
  });
}

UserProfile? _decodeUserProfile(Object? rawValue) {
  if (rawValue is! String || rawValue.isEmpty) {
    return null;
  }

  final decoded = jsonDecode(rawValue);
  if (decoded is! Map<String, dynamic>) {
    return null;
  }

  return UserProfile(
    id: (decoded['id'] as String?) ?? '',
    name: (decoded['name'] as String?) ?? 'Chi Listener',
    email: (decoded['email'] as String?) ?? '',
    avatarSeed: (decoded['avatar_seed'] as String?) ?? 'Chi Listener',
    membershipTier: _enumByName(
      MembershipTier.values,
      decoded['membership_tier'] as String?,
      MembershipTier.free,
    ),
    signedInAt: DateTime.fromMillisecondsSinceEpoch(
      (decoded['signed_in_at'] as int?) ?? 0,
    ),
    trialEndsAt: switch (decoded['trial_ends_at']) {
      final int value => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    },
  );
}

List<String> _decodeStringList(Object? rawValue) {
  if (rawValue is! String || rawValue.isEmpty) {
    return const <String>[];
  }

  final decoded = jsonDecode(rawValue);
  return (decoded as List<dynamic>? ?? const <dynamic>[])
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Set<String> _decodeStringSet(Object? rawValue) {
  return _decodeStringList(rawValue).toSet();
}

List<int> _decodeIntList(Object? rawValue) {
  if (rawValue is! String || rawValue.isEmpty) {
    return const <int>[];
  }

  final decoded = jsonDecode(rawValue);
  return (decoded as List<dynamic>? ?? const <dynamic>[])
      .whereType<int>()
      .toList(growable: false);
}

List<String> _jsonStringList(Object? value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Set<String> _jsonStringSet(Object? value) {
  return _jsonStringList(value).toSet();
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
