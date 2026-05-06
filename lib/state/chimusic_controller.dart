import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/local_audio_importer.dart';
import '../models/music_models.dart';

class MusicAppController extends ChangeNotifier {
  MusicAppController({AudioPlayer? player, bool enableAudio = true})
    : _audioEnabled = enableAudio,
      _player = enableAudio ? (player ?? AudioPlayer()) : null {
    _bindAudioStreams();
  }

  final bool _audioEnabled;
  final AudioPlayer? _player;
  final Set<String> _likedTrackIds = <String>{};
  final Set<String> _savedCollectionIds = <String>{};
  final List<String> _recentTrackIds = <String>[];
  final List<String> _recentSearches = <String>[];
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

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

  List<Track> get recentPlayedTracks {
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

  void selectTab(MusicTab tab) {
    if (_selectedTab == tab) {
      return;
    }

    _selectedTab = tab;
    notifyListeners();
  }

  void setLibraryFilter(LibraryFilter filter) {
    if (_libraryFilter == filter) {
      return;
    }

    _libraryFilter = filter;
    notifyListeners();
  }

  void setLibrarySort(LibrarySort sort) {
    if (_librarySort == sort) {
      return;
    }

    _librarySort = sort;
    notifyListeners();
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
  }

  void submitSearch([String? value]) {
    final candidate = (value ?? _searchQuery).trim();
    if (candidate.isEmpty) {
      return;
    }

    _rememberSearch(candidate);
    notifyListeners();
  }

  void applySearchSuggestion(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }

    _searchQuery = normalized;
    _rememberSearch(normalized);
    notifyListeners();
  }

  void openLibraryFilter(LibraryFilter filter) {
    final selectedChanged = _selectedTab != MusicTab.library;
    final filterChanged = _libraryFilter != filter;

    _selectedTab = MusicTab.library;
    _libraryFilter = filter;

    if (selectedChanged || filterChanged) {
      notifyListeners();
    }
  }

  void openSearch([String query = '']) {
    final selectedChanged = _selectedTab != MusicTab.search;
    final queryChanged = _searchQuery != query;

    _selectedTab = MusicTab.search;
    _searchQuery = query;

    if (selectedChanged || queryChanged) {
      notifyListeners();
    }
  }

  void toggleSavedCollection(String collectionId) {
    if (_savedCollectionIds.contains(collectionId)) {
      _savedCollectionIds.remove(collectionId);
    } else {
      _savedCollectionIds.add(collectionId);
    }

    notifyListeners();
  }

  void toggleLikedTrack(String trackId) {
    if (_likedTrackIds.contains(trackId)) {
      _likedTrackIds.remove(trackId);
    } else {
      _likedTrackIds.add(trackId);
    }

    notifyListeners();
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
      return;
    }

    final player = _player;

    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
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
    if (favoriteTracks.isEmpty) {
      return;
    }

    await _loadQueue(
      favoriteTracks,
      initialIndex: 0,
      collection: MusicCollection(
        id: 'favorites',
        title: 'Liked Songs',
        subtitle: '${favoriteTracks.length} liked tracks',
        description: 'Tracks you have liked in your local library.',
        kind: MusicCollectionKind.playlist,
        palette: favoriteTracks.first.palette,
        tracks: favoriteTracks,
      ),
      autoplay: true,
    );
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
      notifyListeners();
      return;
    }

    final player = _player;

    await player.seek(nextPosition);
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
        notifyListeners();
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

  Future<void> _importPaths(List<String> filePaths) async {
    if (filePaths.isEmpty) {
      return;
    }

    final knownPaths = _tracks.map((track) => track.filePath).toSet();
    final newTracks = filePaths
        .where((path) => isSupportedAudioPath(path))
        .where((path) => !knownPaths.contains(path))
        .map((path) => buildTrackFromPath(path))
        .toList(growable: false);

    if (newTracks.isEmpty) {
      _statusMessage = 'No new supported audio files were found.';
      notifyListeners();
      return;
    }

    _tracks = <Track>[...newTracks, ..._tracks];
    _statusMessage =
        'Imported ${newTracks.length} local audio file${newTracks.length == 1 ? '' : 's'}.';

    if (_currentTrack == null && hasMusic) {
      await _loadQueue(
        allTracksCollection.tracks,
        initialIndex: 0,
        collection: allTracksCollection,
        autoplay: false,
      );
      return;
    }

    notifyListeners();
  }

  Future<void> _loadQueue(
    List<Track> tracks, {
    required int initialIndex,
    required MusicCollection collection,
    required bool autoplay,
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
    _statusMessage = null;
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
      }),
    );

    _subscriptions.add(
      player.positionStream.listen((position) {
        _position = position;
        notifyListeners();
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
      notifyListeners();
    }
  }

  void _markTrackPlayed(Track track) {
    _recentTrackIds.remove(track.id);
    _recentTrackIds.insert(0, track.id);

    if (_recentTrackIds.length > 20) {
      _recentTrackIds.removeRange(20, _recentTrackIds.length);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player?.dispose();
    super.dispose();
  }
}
