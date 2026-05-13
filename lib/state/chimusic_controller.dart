import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/local_audio_importer.dart';
import '../data/music_session_store.dart';
import '../models/music_models.dart';

class MusicAppController extends ChangeNotifier {
  MusicAppController({
    AudioPlayer? player,
    bool enableAudio = true,
    MusicSessionStore? sessionStore,
    List<Track> initialTracks = const <Track>[],
    List<PlaybackHistoryEntry> initialPlaybackHistory =
        const <PlaybackHistoryEntry>[],
    Set<String> initialLikedTrackIds = const <String>{},
    Set<String> initialSavedCollectionIds = const <String>{},
    List<String> initialRecentTrackIds = const <String>[],
    List<String> initialRecentSearches = const <String>[],
    MusicTab initialSelectedTab = MusicTab.home,
    LibraryFilter initialLibraryFilter = LibraryFilter.all,
    LibrarySort initialLibrarySort = LibrarySort.recent,
    String initialSearchQuery = '',
  }) : _audioEnabled = enableAudio,
       _sessionStore = sessionStore,
       _player = enableAudio ? (player ?? AudioPlayer()) : null {
    _tracks = List<Track>.from(initialTracks);
    for (final entry in initialPlaybackHistory) {
      _playbackHistoryByTrackId[entry.trackId] = entry;
    }
    _likedTrackIds.addAll(initialLikedTrackIds);
    _savedCollectionIds.addAll(initialSavedCollectionIds);
    _recentTrackIds.addAll(initialRecentTrackIds);
    _recentSearches.addAll(initialRecentSearches);
    _selectedTab = initialSelectedTab;
    _libraryFilter = initialLibraryFilter;
    _librarySort = initialLibrarySort;
    _searchQuery = initialSearchQuery;
    _bindAudioStreams();
  }

  final bool _audioEnabled;
  final MusicSessionStore? _sessionStore;
  final AudioPlayer? _player;
  final Set<String> _likedTrackIds = <String>{};
  final Set<String> _savedCollectionIds = <String>{};
  final Map<String, PlaybackHistoryEntry> _playbackHistoryByTrackId =
      <String, PlaybackHistoryEntry>{};
  final List<String> _recentTrackIds = <String>[];
  final List<String> _recentSearches = <String>[];
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  Future<void> _persistOperation = Future<void>.value();
  bool _hasRestoredSession = false;
  int? _lastPersistedPositionBucket;

  List<Track> _tracks = <Track>[];
  List<Track> _queue = <Track>[];
  Track? _currentTrack;
  MusicCollection? _currentCollection;
  Duration _position = Duration.zero;
  MusicTab _selectedTab = MusicTab.home;
  LibraryFilter _libraryFilter = LibraryFilter.all;
  LibrarySort _librarySort = LibrarySort.recent;
  String _searchQuery = '';
  bool _isPlaying = false;
  bool _isImporting = false;
  bool _isPreparingPlayback = false;
  String? _statusMessage;

  MusicTab get selectedTab => _selectedTab;
  LibraryFilter get libraryFilter => _libraryFilter;
  LibrarySort get librarySort => _librarySort;
  String get searchQuery => _searchQuery;
  bool get isPlaying => _isPlaying;
  bool get isImporting => _isImporting;
  bool get isPreparingPlayback => _isPreparingPlayback;
  bool get hasMusic => _tracks.isNotEmpty;
  bool get hasCurrentTrack => _currentTrack != null;
  bool get supportsDirectoryImport =>
      !kIsWeb && (Platform.isAndroid || Platform.isMacOS);
  Track? get currentTrack => _currentTrack;
  MusicCollection? get currentCollection => _currentCollection;
  Duration get position => _position;
  List<Track> get queue => List<Track>.unmodifiable(_queue);
  String? get statusMessage => _statusMessage;
  List<String> get recentSearches => List<String>.unmodifiable(_recentSearches);
  int get importedTrackCount => _tracks.length;
  int get collectionCount => importedCollections.length;
  int get likedTracksCount => _likedTrackIds.length;
  int get savedCollectionCount => savedCollections.length;
  bool get hasPlaybackHistory => _playbackHistoryByTrackId.isNotEmpty;
  int get playbackHistoryCount => playbackHistoryTracks.length;
  int get totalPlayCount => _playbackHistoryByTrackId.values.fold(
    0,
    (total, entry) => total + entry.playCount,
  );
  int get artistCount =>
      _tracks.map((track) => track.artist.toLowerCase()).toSet().length;
  int get albumCount =>
      _tracks.map((track) => track.album.toLowerCase()).toSet().length;

  double get playbackProgress {
    final duration = _currentTrack?.duration;
    if (duration == null || duration.inMilliseconds == 0) {
      return 0;
    }

    return _position.inMilliseconds / duration.inMilliseconds;
  }

  List<Track> get importedTracks => List<Track>.unmodifiable(_tracks);

  List<Track> get recentImportedTracks {
    final sorted = List<Track>.from(_tracks)
      ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return sorted.take(8).toList(growable: false);
  }

  List<Track> get playbackHistoryTracks {
    final tracksById = {for (final track in _tracks) track.id: track};
    final entries = _playbackHistoryByTrackId.values.toList(growable: false)
      ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));

    return entries
        .map((entry) => tracksById[entry.trackId])
        .whereType<Track>()
        .toList(growable: false);
  }

  PlaybackHistoryEntry? playbackHistoryEntryForTrack(String trackId) =>
      _playbackHistoryByTrackId[trackId];

  double playbackHistoryProgressForTrack(Track track) {
    final entry = playbackHistoryEntryForTrack(track.id);
    final duration = track.duration;
    if (entry == null || duration == null || duration.inMilliseconds <= 0) {
      return 0;
    }

    final progress =
        entry.lastPosition.inMilliseconds / duration.inMilliseconds;
    return progress.clamp(0.0, 1.0).toDouble();
  }

  List<Track> get recentPlayedTracks {
    final historyTracks = playbackHistoryTracks;
    if (historyTracks.isNotEmpty) {
      return historyTracks.take(20).toList(growable: false);
    }

    final tracksById = {for (final track in _tracks) track.id: track};
    return _recentTrackIds
        .map((id) => tracksById[id])
        .whereType<Track>()
        .toList(growable: false);
  }

  List<Track> get favoriteTracks => _tracks
      .where((track) => _likedTrackIds.contains(track.id))
      .toList(growable: false);

  MusicCollection? get featuredCollection {
    if (!hasMusic) {
      return null;
    }

    return _currentCollection ??
        (savedCollections.isNotEmpty ? savedCollections.first : null) ??
        (recentCollections.isNotEmpty ? recentCollections.first : null) ??
        importedCollections.first;
  }

  MusicCollection get allTracksCollection {
    final tracks = List<Track>.from(_tracks)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return MusicCollection(
      id: 'all_tracks',
      title: 'All Tracks',
      subtitle: '${tracks.length} imported files',
      description:
          'Every local audio file imported into this ChiMusic session.',
      kind: MusicCollectionKind.playlist,
      palette: tracks.isEmpty
          ? const <Color>[
              Color(0xFF4CC9D9),
              Color(0xFF0E3A4C),
              Color(0xFF07111E),
            ]
          : tracks.first.palette,
      tracks: tracks,
    );
  }

  List<MusicCollection> get importedCollections {
    final groupedTracks = <String, List<Track>>{};

    for (final track in _tracks) {
      groupedTracks.putIfAbsent(track.folderPath, () => <Track>[]).add(track);
    }

    final collections =
        groupedTracks.entries
            .map((entry) {
              final tracks = List<Track>.from(entry.value)
                ..sort(
                  (a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()),
                );
              final firstTrack = tracks.first;

              return MusicCollection(
                id: entry.key,
                title: firstTrack.album,
                subtitle:
                    '${tracks.length} file${tracks.length == 1 ? '' : 's'}',
                description:
                    'Imported from ${firstTrack.folderPath}. Play the folder as one local queue.',
                kind: MusicCollectionKind.folder,
                palette: firstTrack.palette,
                tracks: tracks,
              );
            })
            .toList(growable: false)
          ..sort((a, b) => b.latestImportAt.compareTo(a.latestImportAt));

    return collections;
  }

  List<MusicCollection> get recentCollections {
    final recentTrackGroups = <String>{};
    final recent = <MusicCollection>[];
    final collectionsById = {
      for (final collection in importedCollections) collection.id: collection,
    };

    for (final track in recentPlayedTracks) {
      if (recentTrackGroups.add(track.folderPath)) {
        final collection = collectionsById[track.folderPath];
        if (collection != null) {
          recent.add(collection);
        }
      }
    }

    if (recent.isNotEmpty) {
      return recent.take(4).toList(growable: false);
    }

    return importedCollections.take(4).toList(growable: false);
  }

  List<MusicCollection> get savedCollections => importedCollections
      .where((collection) => _savedCollectionIds.contains(collection.id))
      .toList(growable: false);

  List<MusicCollection> get spotlightCollections {
    final collections = <MusicCollection>[];
    final seen = <String>{};

    void addMany(Iterable<MusicCollection> source) {
      for (final collection in source) {
        if (seen.add(collection.id)) {
          collections.add(collection);
        }
      }
    }

    addMany(savedCollections);
    addMany(recentCollections);
    addMany(importedCollections);

    return collections.take(6).toList(growable: false);
  }

  List<MusicCollection> get pinnedCollections {
    final source = savedCollections.isNotEmpty
        ? savedCollections
        : recentCollections;
    if (source.isNotEmpty) {
      return source.take(4).toList(growable: false);
    }

    return importedCollections.take(4).toList(growable: false);
  }

  List<Track> get continueListeningTracks {
    if (recentPlayedTracks.isNotEmpty) {
      return recentPlayedTracks.take(6).toList(growable: false);
    }

    return recentImportedTracks.take(6).toList(growable: false);
  }

  List<Track> get spotlightTracks {
    final tracks = <Track>[];
    final seen = <String>{};

    void addMany(Iterable<Track> source) {
      for (final track in source) {
        if (seen.add(track.id)) {
          tracks.add(track);
        }
      }
    }

    addMany(favoriteTracks);
    addMany(recentPlayedTracks);
    addMany(recentImportedTracks);

    return tracks.take(8).toList(growable: false);
  }

  List<Track> get filteredLibraryTracks {
    final tracks = switch (_libraryFilter) {
      LibraryFilter.all => importedTracks,
      LibraryFilter.tracks => importedTracks,
      LibraryFilter.folders => const <Track>[],
      LibraryFilter.favorites => favoriteTracks,
    };

    final sorted = List<Track>.from(tracks);
    switch (_librarySort) {
      case LibrarySort.recent:
        sorted.sort((a, b) => b.importedAt.compareTo(a.importedAt));
        break;
      case LibrarySort.title:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case LibrarySort.length:
        sorted.sort(
          (a, b) => (b.duration ?? Duration.zero).compareTo(
            a.duration ?? Duration.zero,
          ),
        );
        break;
    }

    return sorted;
  }

  List<MusicCollection> get filteredLibraryCollections {
    final collections = switch (_libraryFilter) {
      LibraryFilter.all => importedCollections,
      LibraryFilter.tracks => const <MusicCollection>[],
      LibraryFilter.folders => importedCollections,
      LibraryFilter.favorites => savedCollections,
    };

    final sorted = List<MusicCollection>.from(collections);
    switch (_librarySort) {
      case LibrarySort.recent:
        sorted.sort((a, b) => b.latestImportAt.compareTo(a.latestImportAt));
        break;
      case LibrarySort.title:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case LibrarySort.length:
        sorted.sort((a, b) => b.totalDuration.compareTo(a.totalDuration));
        break;
    }

    return sorted;
  }

  List<Track> get searchTrackResults {
    final query = _normalizedQuery;
    if (query.isEmpty) {
      return continueListeningTracks;
    }

    final matches =
        _tracks
            .map(
              (track) => (track: track, score: _scoreTrackMatch(track, query)),
            )
            .where((entry) => entry.score > 0)
            .toList(growable: false)
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            return b.track.importedAt.compareTo(a.track.importedAt);
          });

    return matches.map((entry) => entry.track).toList(growable: false);
  }

  List<MusicCollection> get searchCollectionResults {
    final collections = importedCollections;
    final query = _normalizedQuery;

    if (query.isEmpty) {
      return collections.take(6).toList(growable: false);
    }

    final matches =
        collections
            .map(
              (collection) => (
                collection: collection,
                score: _scoreCollectionMatch(collection, query),
              ),
            )
            .where((entry) => entry.score > 0)
            .toList(growable: false)
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            return b.collection.latestImportAt.compareTo(
              a.collection.latestImportAt,
            );
          });

    return matches.map((entry) => entry.collection).toList(growable: false);
  }

  List<String> get trendingSearches {
    final suggestions = <String>[];
    final seen = <String>{};

    void add(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        return;
      }
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        suggestions.add(normalized);
      }
    }

    for (final value in _recentSearches) {
      add(value);
    }

    for (final track in recentPlayedTracks.take(4)) {
      add(track.title);
      add(track.artist);
    }

    for (final collection in importedCollections.take(4)) {
      add(collection.title);
    }

    return suggestions.take(8).toList(growable: false);
  }

  List<String> get browseSuggestions {
    final suggestions = <String>[];
    final seen = <String>{};

    void add(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        return;
      }
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        suggestions.add(normalized);
      }
    }

    for (final track in recentImportedTracks.take(4)) {
      add(track.artist);
      add(track.album);
    }

    for (final collection in importedCollections.take(4)) {
      add(collection.title);
    }

    for (final track in importedTracks) {
      if (track.fileExtension case final extension?) {
        add(extension.toUpperCase());
      }
      if (suggestions.length >= 8) {
        break;
      }
    }

    return suggestions.take(8).toList(growable: false);
  }

  List<Track> get upNext {
    final currentTrack = _currentTrack;
    if (_queue.isEmpty || currentTrack == null) {
      return const <Track>[];
    }

    final currentIndex = _queue.indexWhere(
      (track) => track.id == currentTrack.id,
    );
    if (currentIndex < 0) {
      return _queue.take(3).toList(growable: false);
    }

    final reordered = <Track>[
      ..._queue.skip(currentIndex + 1),
      ..._queue.take(currentIndex),
    ];
    return reordered.take(3).toList(growable: false);
  }

  bool isCollectionSaved(String collectionId) =>
      _savedCollectionIds.contains(collectionId);

  bool isTrackLiked(String trackId) => _likedTrackIds.contains(trackId);

  Future<void> restoreSession() async {
    final sessionStore = _sessionStore;
    if (_hasRestoredSession || sessionStore == null) {
      return;
    }

    _hasRestoredSession = true;

    try {
      final snapshot = await sessionStore.load();
      final tracks = snapshot.tracks
          .where((track) => track.filePath.isNotEmpty)
          .toList(growable: false);
      final trackIds = tracks.map((track) => track.id).toSet();

      _tracks = tracks;
      _likedTrackIds
        ..clear()
        ..addAll(snapshot.likedTrackIds.where(trackIds.contains));
      final playbackHistory = _restorePlaybackHistory(snapshot, trackIds);
      _playbackHistoryByTrackId
        ..clear()
        ..addEntries(
          playbackHistory.map((entry) => MapEntry(entry.trackId, entry)),
        );
      _savedCollectionIds
        ..clear()
        ..addAll(snapshot.savedCollectionIds);
      _recentTrackIds
        ..clear()
        ..addAll(snapshot.recentTrackIds.where(trackIds.contains));
      _recentSearches
        ..clear()
        ..addAll(snapshot.recentSearches.take(8));
      _selectedTab = snapshot.selectedTab;
      _libraryFilter = snapshot.libraryFilter;
      _librarySort = snapshot.librarySort;
      _searchQuery = snapshot.searchQuery;
      _savedCollectionIds.removeWhere(
        (collectionId) => !importedCollections.any(
          (collection) => collection.id == collectionId,
        ),
      );
      await _restorePlaybackSnapshot(snapshot);
      notifyListeners();
    } catch (_) {
      _statusMessage =
          'Unable to restore your last ChiMusic session. You can import your music again.';
      notifyListeners();
    }
  }

  void selectTab(MusicTab tab) {
    if (_selectedTab == tab) {
      return;
    }

    _selectedTab = tab;
    notifyListeners();
    _persistSession();
  }

  void setLibraryFilter(LibraryFilter filter) {
    if (_libraryFilter == filter) {
      return;
    }

    _libraryFilter = filter;
    notifyListeners();
    _persistSession();
  }

  void setLibrarySort(LibrarySort sort) {
    if (_librarySort == sort) {
      return;
    }

    _librarySort = sort;
    notifyListeners();
    _persistSession();
  }

  void updateSearchQuery(String value) {
    if (_searchQuery == value) {
      return;
    }

    _searchQuery = value;
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) {
      return;
    }

    _searchQuery = '';
    notifyListeners();
    _persistSession();
  }

  void clearRecentSearches() {
    if (_recentSearches.isEmpty) {
      return;
    }

    _recentSearches.clear();
    notifyListeners();
    _persistSession();
  }

  void clearPlaybackHistory() {
    if (_playbackHistoryByTrackId.isEmpty && _recentTrackIds.isEmpty) {
      _statusMessage = 'Playback history is already clear.';
      notifyListeners();
      return;
    }

    _playbackHistoryByTrackId.clear();
    _recentTrackIds.clear();
    _statusMessage = 'Cleared saved playback history from ChiMusic.';
    notifyListeners();
    _persistSession();
  }

  void clearStatusMessage() {
    if (_statusMessage == null) {
      return;
    }

    _statusMessage = null;
    notifyListeners();
  }

  void submitSearch([String? value]) {
    final candidate = (value ?? _searchQuery).trim();
    if (candidate.isEmpty) {
      return;
    }

    _rememberSearch(candidate);
    notifyListeners();
    _persistSession();
  }

  void applySearchSuggestion(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }

    _searchQuery = normalized;
    _rememberSearch(normalized);
    notifyListeners();
    _persistSession();
  }

  void openLibraryFilter(LibraryFilter filter) {
    final selectedChanged = _selectedTab != MusicTab.library;
    final filterChanged = _libraryFilter != filter;

    _selectedTab = MusicTab.library;
    _libraryFilter = filter;

    if (selectedChanged || filterChanged) {
      notifyListeners();
      _persistSession();
    }
  }

  void openSearch([String query = '']) {
    final selectedChanged = _selectedTab != MusicTab.search;
    final queryChanged = _searchQuery != query;

    _selectedTab = MusicTab.search;
    _searchQuery = query;

    if (selectedChanged || queryChanged) {
      notifyListeners();
      _persistSession();
    }
  }

  void toggleSavedCollection(String collectionId) {
    if (_savedCollectionIds.contains(collectionId)) {
      _savedCollectionIds.remove(collectionId);
    } else {
      _savedCollectionIds.add(collectionId);
    }

    notifyListeners();
    _persistSession();
  }

  void toggleLikedTrack(String trackId) {
    if (_likedTrackIds.contains(trackId)) {
      _likedTrackIds.remove(trackId);
    } else {
      _likedTrackIds.add(trackId);
    }

    notifyListeners();
    _persistSession();
  }

  Future<void> importLocalFiles() async {
    if (_isImporting) {
      return;
    }

    try {
      _isImporting = true;
      _statusMessage = null;
      notifyListeners();

      final pickedFiles = await openFiles(
        acceptedTypeGroups: <XTypeGroup>[localAudioTypeGroup],
      );
      final filePaths = pickedFiles
          .map((file) => file.path)
          .where((path) => path.isNotEmpty)
          .toList(growable: false);

      await _importPaths(filePaths);
    } catch (_) {
      _statusMessage = 'Unable to import files from the system picker.';
      notifyListeners();
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> importLocalFolder() async {
    if (_isImporting || !supportsDirectoryImport) {
      return;
    }

    try {
      _isImporting = true;
      _statusMessage = null;
      notifyListeners();

      final directoryPath = await getDirectoryPath();
      if (directoryPath == null || directoryPath.isEmpty) {
        return;
      }

      final audioPaths = await collectAudioFilesFromDirectory(directoryPath);
      await _importPaths(audioPaths);
    } catch (_) {
      _statusMessage =
          'Unable to scan the selected folder. Try choosing a smaller audio directory.';
      notifyListeners();
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (!hasMusic) {
      return;
    }

    if (_currentTrack == null) {
      await _loadQueue(
        allTracksCollection.tracks,
        initialIndex: 0,
        collection: allTracksCollection,
        autoplay: true,
      );
      return;
    }

    if (!_audioEnabled || _player == null) {
      _isPlaying = !_isPlaying;
      notifyListeners();
      _persistSession();
      return;
    }

    final player = _player;

    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }

    _persistSession();
  }

  Future<void> playImportedTracks() async {
    if (!hasMusic) {
      return;
    }

    await _loadQueue(
      allTracksCollection.tracks,
      initialIndex: 0,
      collection: allTracksCollection,
      autoplay: true,
    );
  }

  Future<void> playCollection(
    MusicCollection collection, {
    Track? startWith,
  }) async {
    final initialTrack = startWith ?? collection.tracks.first;
    final initialIndex = collection.tracks.indexWhere(
      (track) => track.id == initialTrack.id,
    );

    await _loadQueue(
      collection.tracks,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      collection: collection,
      autoplay: true,
    );
  }

  Future<void> playTrack(Track track, {MusicCollection? collection}) async {
    final ownerCollection =
        collection ?? collectionForTrack(track) ?? allTracksCollection;
    final queueTracks = ownerCollection.tracks;
    final initialIndex = queueTracks.indexWhere((item) => item.id == track.id);

    await _loadQueue(
      queueTracks,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      collection: ownerCollection,
      autoplay: true,
    );
  }

  Future<void> playFavoriteTracks() async {
    final favorites = favoriteTracks;
    if (favorites.isEmpty) {
      return;
    }

    await _loadQueue(
      favorites,
      initialIndex: 0,
      collection: _buildLikedSongsCollection(favorites),
      autoplay: true,
    );
  }

  Future<void> removeCollectionFromLibrary(String collectionId) async {
    MusicCollection? target;
    for (final collection in importedCollections) {
      if (collection.id == collectionId) {
        target = collection;
        break;
      }
    }

    if (target == null) {
      return;
    }

    final removedTrackIds = target.tracks.map((track) => track.id).toSet();
    _savedCollectionIds.remove(collectionId);

    await _removeTracksFromLibrary(
      removedTrackIds,
      successMessage:
          'Removed ${target.tracks.length} track${target.tracks.length == 1 ? '' : 's'} from ChiMusic. Original files were not deleted.',
    );
  }

  Future<void> clearLibrarySession() async {
    final hadAnyData =
        _tracks.isNotEmpty ||
        _playbackHistoryByTrackId.isNotEmpty ||
        _likedTrackIds.isNotEmpty ||
        _savedCollectionIds.isNotEmpty ||
        _recentTrackIds.isNotEmpty ||
        _recentSearches.isNotEmpty ||
        _currentTrack != null;

    if (!hadAnyData) {
      _statusMessage = 'Your ChiMusic session is already clear.';
      notifyListeners();
      return;
    }

    await _stopPlayback();
    _tracks = <Track>[];
    _queue = <Track>[];
    _currentTrack = null;
    _currentCollection = null;
    _position = Duration.zero;
    _searchQuery = '';
    _likedTrackIds.clear();
    _savedCollectionIds.clear();
    _playbackHistoryByTrackId.clear();
    _recentTrackIds.clear();
    _recentSearches.clear();
    _isPlaying = false;
    _isPreparingPlayback = false;
    _lastPersistedPositionBucket = null;
    _statusMessage =
        'Cleared imported items from ChiMusic. Original audio files were not deleted.';
    notifyListeners();
    _persistSession();
  }

  Future<void> seekToFraction(double fraction) async {
    final duration = _currentTrack?.duration;
    if (_currentTrack == null || duration == null) {
      return;
    }

    final clamped = fraction.clamp(0.0, 1.0);
    final nextPosition = Duration(
      milliseconds: (duration.inMilliseconds * clamped).round(),
    );

    if (!_audioEnabled || _player == null) {
      _position = nextPosition;
      _syncCurrentTrackHistoryPosition(nextPosition);
      notifyListeners();
      _persistSession();
      return;
    }

    final player = _player;

    _position = nextPosition;
    _syncCurrentTrackHistoryPosition(nextPosition);
    notifyListeners();
    await player.seek(nextPosition);
    _persistSession();
  }

  Future<void> skipNext() async {
    final currentTrack = _currentTrack;
    if (_queue.isEmpty || currentTrack == null) {
      return;
    }

    final currentIndex = _queue.indexWhere(
      (track) => track.id == currentTrack.id,
    );
    final nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % _queue.length;

    if (!_audioEnabled || _player == null) {
      final nextTrack = _queue[nextIndex];
      _currentTrack = nextTrack;
      _position = Duration.zero;
      _isPlaying = true;
      _lastPersistedPositionBucket = 0;
      _markTrackPlayed(nextTrack);
      notifyListeners();
      return;
    }

    final player = _player;

    await player.seek(Duration.zero, index: nextIndex);
    if (!player.playing) {
      await player.play();
    }
  }

  Future<void> skipPrevious() async {
    final currentTrack = _currentTrack;
    if (_queue.isEmpty || currentTrack == null) {
      return;
    }

    if (_position.inSeconds > 5) {
      if (!_audioEnabled || _player == null) {
        _position = Duration.zero;
        _syncCurrentTrackHistoryPosition(Duration.zero);
        notifyListeners();
        _persistSession();
        return;
      }

      final player = _player;

      await player.seek(Duration.zero);
      return;
    }

    final currentIndex = _queue.indexWhere(
      (track) => track.id == currentTrack.id,
    );
    final previousIndex = currentIndex <= 0
        ? _queue.length - 1
        : currentIndex - 1;

    if (!_audioEnabled || _player == null) {
      final previousTrack = _queue[previousIndex];
      _currentTrack = previousTrack;
      _position = Duration.zero;
      _isPlaying = true;
      _lastPersistedPositionBucket = 0;
      _markTrackPlayed(previousTrack);
      notifyListeners();
      return;
    }

    final player = _player;

    await player.seek(Duration.zero, index: previousIndex);
    if (!player.playing) {
      await player.play();
    }
  }

  MusicCollection? collectionForTrack(Track track) {
    for (final collection in importedCollections) {
      final containsTrack = collection.tracks.any(
        (item) => item.id == track.id,
      );
      if (containsTrack) {
        return collection;
      }
    }

    return null;
  }

  int _scoreTrackMatch(Track track, String query) {
    var score = 0;
    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();
    final album = track.album.toLowerCase();
    final fileName = track.fileName.toLowerCase();

    if (title.startsWith(query)) {
      score += 120;
    } else if (title.contains(query)) {
      score += 90;
    }

    if (artist.startsWith(query)) {
      score += 80;
    } else if (artist.contains(query)) {
      score += 60;
    }

    if (album.startsWith(query)) {
      score += 55;
    } else if (album.contains(query)) {
      score += 40;
    }

    if (fileName.contains(query)) {
      score += 24;
    }

    if (_likedTrackIds.contains(track.id)) {
      score += 8;
    }

    if (_recentTrackIds.contains(track.id)) {
      score += 6;
    }

    return score;
  }

  int _scoreCollectionMatch(MusicCollection collection, String query) {
    var score = 0;
    final title = collection.title.toLowerCase();
    final subtitle = collection.subtitle.toLowerCase();
    final description = collection.description.toLowerCase();

    if (title.startsWith(query)) {
      score += 110;
    } else if (title.contains(query)) {
      score += 80;
    }

    if (subtitle.contains(query)) {
      score += 34;
    }

    if (description.contains(query)) {
      score += 22;
    }

    if (_savedCollectionIds.contains(collection.id)) {
      score += 6;
    }

    return score;
  }

  MusicCollection _buildLikedSongsCollection(List<Track> favorites) {
    return MusicCollection(
      id: 'favorites',
      title: 'Liked Songs',
      subtitle: '${favorites.length} liked tracks',
      description: 'Tracks you have liked in your local library.',
      kind: MusicCollectionKind.playlist,
      palette: favorites.first.palette,
      tracks: favorites,
    );
  }

  void _rememberSearch(String value) {
    _recentSearches.removeWhere(
      (entry) => entry.toLowerCase() == value.toLowerCase(),
    );
    _recentSearches.insert(0, value);

    if (_recentSearches.length > 8) {
      _recentSearches.removeRange(8, _recentSearches.length);
    }
  }

  String get _normalizedQuery => _searchQuery.trim().toLowerCase();

  Future<void> _removeTracksFromLibrary(
    Set<String> removedTrackIds, {
    required String successMessage,
  }) async {
    if (removedTrackIds.isEmpty) {
      return;
    }

    final removedCurrentTrack =
        _currentTrack != null && removedTrackIds.contains(_currentTrack!.id);

    if (removedCurrentTrack) {
      await _stopPlayback();
    }

    _tracks = _tracks
        .where((track) => !removedTrackIds.contains(track.id))
        .toList(growable: false);
    _queue = _queue
        .where((track) => !removedTrackIds.contains(track.id))
        .toList(growable: false);
    _likedTrackIds.removeWhere(removedTrackIds.contains);
    _recentTrackIds.removeWhere(removedTrackIds.contains);
    _playbackHistoryByTrackId.removeWhere(
      (trackId, _) => removedTrackIds.contains(trackId),
    );

    if (_tracks.isEmpty || removedCurrentTrack) {
      _queue = <Track>[];
      _currentTrack = null;
      _currentCollection = null;
      _position = Duration.zero;
      _isPlaying = false;
      _isPreparingPlayback = false;
      _lastPersistedPositionBucket = null;
    } else if (_currentTrack != null) {
      final currentTrack = _currentTrack!;
      if (_currentCollection?.id == 'favorites') {
        final favorites = favoriteTracks;
        _currentCollection = favorites.isEmpty
            ? null
            : _buildLikedSongsCollection(favorites);
      } else if (_currentCollection?.id == 'all_tracks') {
        _currentCollection = allTracksCollection;
      } else {
        _currentCollection =
            collectionForTrack(currentTrack) ?? allTracksCollection;
      }
    }

    _savedCollectionIds.removeWhere(
      (collectionId) => !importedCollections.any(
        (collection) => collection.id == collectionId,
      ),
    );
    _statusMessage = successMessage;
    notifyListeners();
    _persistSession();
  }

  Future<void> _stopPlayback() async {
    if (!_audioEnabled || _player == null) {
      return;
    }

    await _player.stop();
  }

  Future<void> _importPaths(List<String> filePaths) async {
    if (filePaths.isEmpty) {
      return;
    }

    final knownPaths = _tracks.map((track) => track.filePath).toSet();
    final supportedPaths = filePaths
        .where((path) => isSupportedAudioPath(path))
        .toList(growable: false);
    final duplicateCount = supportedPaths
        .where((path) => knownPaths.contains(path))
        .length;
    final newTracks = supportedPaths
        .where((path) => !knownPaths.contains(path))
        .map((path) => buildTrackFromPath(path))
        .toList(growable: false);

    if (newTracks.isEmpty) {
      _statusMessage = duplicateCount > 0
          ? 'Everything you picked is already in your ChiMusic library.'
          : 'No supported audio files were found in that selection.';
      notifyListeners();
      return;
    }

    _tracks = <Track>[...newTracks, ..._tracks];
    final skippedMessage = duplicateCount > 0
        ? ' Skipped $duplicateCount item${duplicateCount == 1 ? '' : 's'} already in your library.'
        : '';
    _statusMessage =
        'Imported ${newTracks.length} local audio file${newTracks.length == 1 ? '' : 's'}.$skippedMessage';

    if (_currentTrack == null && hasMusic) {
      await _loadQueue(
        allTracksCollection.tracks,
        initialIndex: 0,
        collection: allTracksCollection,
        autoplay: false,
        clearStatusMessage: false,
      );
      await flushSession();
      return;
    }

    notifyListeners();
    await flushSession();
  }

  Future<void> _loadQueue(
    List<Track> tracks, {
    required int initialIndex,
    required MusicCollection collection,
    required bool autoplay,
    bool clearStatusMessage = true,
  }) async {
    if (tracks.isEmpty) {
      return;
    }

    final clampedIndex = initialIndex.clamp(0, tracks.length - 1);
    _queue = List<Track>.from(tracks);
    _currentCollection = collection;
    final currentTrack = _queue[clampedIndex];
    _currentTrack = currentTrack;
    _position = Duration.zero;
    _lastPersistedPositionBucket = 0;
    if (clearStatusMessage) {
      _statusMessage = null;
    }
    _isPreparingPlayback = true;
    _isPlaying = autoplay && !_audioEnabled;
    _markTrackPlayed(currentTrack);
    notifyListeners();

    if (!_audioEnabled || _player == null) {
      _isPreparingPlayback = false;
      notifyListeners();
      return;
    }

    try {
      final sources = _queue
          .map((track) => AudioSource.uri(Uri.file(track.filePath), tag: track))
          .toList(growable: false);

      final player = _player;

      await player.setAudioSources(
        sources,
        initialIndex: clampedIndex,
        initialPosition: Duration.zero,
      );

      _isPreparingPlayback = false;
      notifyListeners();

      if (autoplay) {
        await player.play();
      } else {
        await player.pause();
      }
    } on PlayerException {
      _isPreparingPlayback = false;
      _isPlaying = false;
      _statusMessage = 'Unable to play the selected file in this environment.';
      notifyListeners();
    } catch (_) {
      _isPreparingPlayback = false;
      _isPlaying = false;
      _statusMessage = 'Playback setup failed. Try importing the file again.';
      notifyListeners();
    }
  }

  void _bindAudioStreams() {
    if (!_audioEnabled || _player == null) {
      return;
    }

    final player = _player;

    _subscriptions.add(
      player.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        notifyListeners();
        _persistSession();
      }),
    );

    _subscriptions.add(
      player.positionStream.listen((position) {
        _position = position;
        notifyListeners();
        _persistProgressIfNeeded();
      }),
    );

    _subscriptions.add(
      player.currentIndexStream.listen((index) {
        if (index == null || index < 0 || index >= _queue.length) {
          return;
        }

        final nextTrack = _queue[index];
        if (_currentTrack?.id == nextTrack.id) {
          return;
        }

        _currentTrack = nextTrack;
        _markTrackPlayed(nextTrack);
        notifyListeners();
      }),
    );

    _subscriptions.add(
      player.durationStream.listen((duration) {
        final currentTrack = _currentTrack;
        if (currentTrack == null || duration == null) {
          return;
        }

        _replaceTrackDuration(currentTrack.id, duration);
      }),
    );
  }

  void _replaceTrackDuration(String trackId, Duration duration) {
    var changed = false;

    _tracks = _tracks
        .map((track) {
          if (track.id != trackId || track.duration == duration) {
            return track;
          }

          changed = true;
          return track.copyWith(duration: duration);
        })
        .toList(growable: false);

    _queue = _queue
        .map((track) {
          if (track.id != trackId || track.duration == duration) {
            return track;
          }

          return track.copyWith(duration: duration);
        })
        .toList(growable: false);

    if (_currentTrack?.id == trackId) {
      final currentTrack = _currentTrack;
      if (currentTrack != null) {
        _currentTrack = currentTrack.copyWith(duration: duration);
      }
      changed = true;
    }

    if (changed) {
      if (_currentTrack?.id == trackId) {
        _syncCurrentTrackHistoryPosition(_position);
      }
      notifyListeners();
      _persistSession();
    }
  }

  void _markTrackPlayed(Track track) {
    _rememberRecentTrack(track.id);
    final existingEntry = _playbackHistoryByTrackId[track.id];
    _playbackHistoryByTrackId[track.id] = PlaybackHistoryEntry(
      trackId: track.id,
      lastPlayedAt: DateTime.now(),
      lastPosition: Duration.zero,
      playCount: (existingEntry?.playCount ?? 0) + 1,
    );

    _persistSession();
  }

  Future<void> flushSession() async {
    _syncCurrentTrackHistoryPosition(_position);
    await _persistSession();
  }

  Future<void> _persistSession() {
    final sessionStore = _sessionStore;
    if (sessionStore == null) {
      return Future<void>.value();
    }

    final snapshot = MusicSessionSnapshot(
      tracks: List<Track>.from(_tracks),
      playbackHistory: _playbackHistoryByTrackId.values.toList(growable: false),
      likedTrackIds: Set<String>.from(_likedTrackIds),
      savedCollectionIds: Set<String>.from(_savedCollectionIds),
      recentTrackIds: List<String>.from(_recentTrackIds),
      recentSearches: List<String>.from(_recentSearches),
      selectedTab: _selectedTab,
      libraryFilter: _libraryFilter,
      librarySort: _librarySort,
      searchQuery: _searchQuery,
      queueTrackIds: _queue.map((track) => track.id).toList(growable: false),
      currentTrackId: _currentTrack?.id,
      currentCollectionId: _currentCollection?.id,
      positionMs: _position.inMilliseconds,
    );

    _persistOperation = _persistOperation.then((_) async {
      try {
        await sessionStore.save(snapshot);
      } catch (_) {
        // Best-effort persistence keeps the UI responsive even if storage fails.
      }
    });

    return _persistOperation;
  }

  List<PlaybackHistoryEntry> _restorePlaybackHistory(
    MusicSessionSnapshot snapshot,
    Set<String> validTrackIds,
  ) {
    final restoredHistory = snapshot.playbackHistory
        .where(
          (entry) =>
              entry.trackId.isNotEmpty && validTrackIds.contains(entry.trackId),
        )
        .toList(growable: false);

    if (restoredHistory.isNotEmpty) {
      return restoredHistory;
    }

    final migratedHistory = <PlaybackHistoryEntry>[];
    final now = DateTime.now();
    for (var index = 0; index < snapshot.recentTrackIds.length; index++) {
      final trackId = snapshot.recentTrackIds[index];
      if (!validTrackIds.contains(trackId)) {
        continue;
      }

      migratedHistory.add(
        PlaybackHistoryEntry(
          trackId: trackId,
          lastPlayedAt: now.subtract(Duration(minutes: index + 1)),
        ),
      );
    }

    return migratedHistory;
  }

  Future<void> _restorePlaybackSnapshot(MusicSessionSnapshot snapshot) async {
    final tracksById = {for (final track in _tracks) track.id: track};
    final queue = snapshot.queueTrackIds
        .map((trackId) => tracksById[trackId])
        .whereType<Track>()
        .toList(growable: false);
    if (queue.isEmpty) {
      return;
    }

    Track currentTrack = queue.first;
    for (final track in queue) {
      if (track.id == snapshot.currentTrackId) {
        currentTrack = track;
        break;
      }
    }
    final currentIndex = queue.indexWhere(
      (track) => track.id == currentTrack.id,
    );
    final initialPosition = _clampedPositionForTrack(
      currentTrack,
      Duration(milliseconds: snapshot.positionMs),
    );

    _queue = queue;
    _currentTrack = currentTrack;
    _currentCollection = _restoreCollectionFromId(snapshot.currentCollectionId);
    _position = initialPosition;
    _isPlaying = false;
    _isPreparingPlayback = _audioEnabled && _player != null;
    _lastPersistedPositionBucket = initialPosition.inSeconds ~/ 5;
    _syncCurrentTrackHistoryPosition(initialPosition);

    if (!_audioEnabled || _player == null) {
      _isPreparingPlayback = false;
      return;
    }

    try {
      final sources = queue
          .map((track) => AudioSource.uri(Uri.file(track.filePath), tag: track))
          .toList(growable: false);

      final player = _player;

      await player.setAudioSources(
        sources,
        initialIndex: currentIndex < 0 ? 0 : currentIndex,
        initialPosition: initialPosition,
      );
      await player.pause();
      _isPreparingPlayback = false;
    } on PlayerException {
      _isPreparingPlayback = false;
      _isPlaying = false;
      _statusMessage =
          'Unable to restore the last playback queue in this environment.';
    } catch (_) {
      _isPreparingPlayback = false;
      _isPlaying = false;
      _statusMessage =
          'Playback queue restore failed. Your library is still available.';
    }
  }

  MusicCollection? _restoreCollectionFromId(String? collectionId) {
    if (collectionId == null || collectionId.isEmpty) {
      return null;
    }

    if (collectionId == 'all_tracks') {
      return allTracksCollection;
    }

    if (collectionId == 'favorites') {
      final favorites = favoriteTracks;
      if (favorites.isEmpty) {
        return null;
      }
      return _buildLikedSongsCollection(favorites);
    }

    for (final collection in importedCollections) {
      if (collection.id == collectionId) {
        return collection;
      }
    }

    return null;
  }

  Duration _clampedPositionForTrack(Track track, Duration position) {
    final duration = track.duration;
    if (duration == null) {
      return position;
    }

    if (position < Duration.zero) {
      return Duration.zero;
    }

    if (position > duration) {
      return duration;
    }

    return position;
  }

  void _rememberRecentTrack(String trackId) {
    _recentTrackIds.remove(trackId);
    _recentTrackIds.insert(0, trackId);

    if (_recentTrackIds.length > 20) {
      _recentTrackIds.removeRange(20, _recentTrackIds.length);
    }
  }

  void _syncCurrentTrackHistoryPosition(Duration position) {
    final currentTrack = _currentTrack;
    if (currentTrack == null) {
      return;
    }

    final existingEntry = _playbackHistoryByTrackId[currentTrack.id];
    _playbackHistoryByTrackId[currentTrack.id] = PlaybackHistoryEntry(
      trackId: currentTrack.id,
      lastPlayedAt: existingEntry?.lastPlayedAt ?? DateTime.now(),
      lastPosition: _clampedPositionForTrack(currentTrack, position),
      playCount: existingEntry?.playCount ?? 1,
    );
  }

  void _persistProgressIfNeeded() {
    final currentTrack = _currentTrack;
    if (currentTrack == null) {
      return;
    }

    final bucket = _position.inSeconds ~/ 5;
    if (_lastPersistedPositionBucket == bucket) {
      return;
    }

    _lastPersistedPositionBucket = bucket;
    _syncCurrentTrackHistoryPosition(_position);
    _persistSession();
  }

  @override
  void dispose() {
    unawaited(flushSession());
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player?.dispose();
    super.dispose();
  }
}
