import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/demo_music.dart';
import '../models/music_models.dart';

class MusicAppController extends ChangeNotifier {
  MusicAppController({DemoCatalog? catalog})
    : catalog = catalog ?? buildDemoCatalog() {
    _savedCollectionIds.addAll({'tidal_bloom', 'glass_focus', 'moon_signals'});
    _likedTrackIds.addAll({'tidal_bloom_02', 'moon_signals_03'});

    _currentCollection = this.catalog.collectionById(
      this.catalog.featuredCollectionId,
    );
    _queue = List<Track>.from(_currentCollection!.tracks);
    _currentTrack = _queue.first;
    _position = const Duration(seconds: 44);
    _ticker = Timer.periodic(const Duration(seconds: 1), _handleTick);
  }

  final DemoCatalog catalog;
  final Set<String> _savedCollectionIds = <String>{};
  final Set<String> _likedTrackIds = <String>{};

  late final Timer _ticker;
  late List<Track> _queue;
  late Track _currentTrack;
  MusicCollection? _currentCollection;
  Duration _position = Duration.zero;
  MusicTab _selectedTab = MusicTab.home;
  LibraryFilter _libraryFilter = LibraryFilter.all;
  String _searchQuery = '';
  bool _isPlaying = true;

  MusicTab get selectedTab => _selectedTab;
  LibraryFilter get libraryFilter => _libraryFilter;
  String get searchQuery => _searchQuery;
  bool get isPlaying => _isPlaying;
  Track get currentTrack => _currentTrack;
  MusicCollection get featuredCollection =>
      catalog.collectionById(catalog.featuredCollectionId);
  MusicCollection? get currentCollection => _currentCollection;
  Duration get position => _position;
  List<Track> get queue => List<Track>.unmodifiable(_queue);
  List<String> get savedCollectionIds =>
      List<String>.unmodifiable(_savedCollectionIds);
  int get likedTracksCount => _likedTrackIds.length;

  double get playbackProgress {
    if (_currentTrack.duration.inMilliseconds == 0) {
      return 0;
    }

    return _position.inMilliseconds / _currentTrack.duration.inMilliseconds;
  }

  List<MusicCollection> get recentCollections => [
    for (final id in catalog.recentlyPlayedIds) catalog.collectionById(id),
  ];

  List<MusicCollection> collectionsForShelf(HomeShelf shelf) => [
    for (final id in shelf.collectionIds) catalog.collectionById(id),
  ];

  List<MusicCollection> get savedCollections => catalog.collections
      .where((collection) => _savedCollectionIds.contains(collection.id))
      .toList(growable: false);

  int get downloadedCollectionCount =>
      catalog.collections.where((collection) => collection.downloaded).length;

  List<MusicCollection> get filteredLibraryCollections {
    final source = savedCollections;
    return source
        .where((collection) {
          return switch (_libraryFilter) {
            LibraryFilter.all => true,
            LibraryFilter.playlists =>
              collection.kind == MusicCollectionKind.playlist ||
                  collection.kind == MusicCollectionKind.mix,
            LibraryFilter.albums =>
              collection.kind == MusicCollectionKind.album,
            LibraryFilter.downloads => collection.downloaded,
          };
        })
        .toList(growable: false);
  }

  List<Track> get searchTrackResults {
    final query = _normalizedQuery;
    if (query.isEmpty) {
      return trendingTracks;
    }

    return catalog.allTracks
        .where((track) {
          final haystack = '${track.title} ${track.artist} ${track.album}'
              .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  List<MusicCollection> get searchCollectionResults {
    final query = _normalizedQuery;
    if (query.isEmpty) {
      return catalog.collections.take(4).toList(growable: false);
    }

    return catalog.collections
        .where((collection) {
          final haystack =
              '${collection.title} ${collection.subtitle} ${collection.description}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  List<Track> get trendingTracks =>
      catalog.allTracks.take(6).toList(growable: false);

  List<Track> get upNext {
    if (_queue.isEmpty) {
      return const [];
    }

    final currentIndex = _queue.indexWhere(
      (track) => track.id == _currentTrack.id,
    );
    if (currentIndex < 0) {
      return _queue.take(3).toList(growable: false);
    }

    final reordered = [
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

  void updateSearchQuery(String value) {
    if (_searchQuery == value) {
      return;
    }

    _searchQuery = value;
    notifyListeners();
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

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void playCollection(MusicCollection collection, {Track? startWith}) {
    _currentCollection = collection;
    _queue = List<Track>.from(collection.tracks);
    _currentTrack = startWith ?? collection.tracks.first;
    _position = Duration.zero;
    _isPlaying = true;
    notifyListeners();
  }

  void playTrack(Track track, {MusicCollection? collection}) {
    final owner = collection ?? collectionForTrack(track) ?? _currentCollection;
    if (owner != null) {
      _currentCollection = owner;
      _queue = List<Track>.from(owner.tracks);
    } else if (_queue.isEmpty) {
      _queue = [track];
    }

    _currentTrack = track;
    _position = Duration.zero;
    _isPlaying = true;
    notifyListeners();
  }

  void seekToFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    _position = Duration(
      milliseconds: (_currentTrack.duration.inMilliseconds * clamped).round(),
    );
    notifyListeners();
  }

  void skipNext() {
    if (_queue.isEmpty) {
      return;
    }

    final index = _queue.indexWhere((track) => track.id == _currentTrack.id);
    final nextIndex = index < 0 ? 0 : (index + 1) % _queue.length;
    _currentTrack = _queue[nextIndex];
    _position = Duration.zero;
    _isPlaying = true;
    notifyListeners();
  }

  void skipPrevious() {
    if (_queue.isEmpty) {
      return;
    }

    if (_position.inSeconds > 5) {
      _position = Duration.zero;
      notifyListeners();
      return;
    }

    final index = _queue.indexWhere((track) => track.id == _currentTrack.id);
    final previousIndex = index <= 0 ? _queue.length - 1 : index - 1;
    _currentTrack = _queue[previousIndex];
    _position = Duration.zero;
    _isPlaying = true;
    notifyListeners();
  }

  MusicCollection? collectionForTrack(Track track) {
    for (final collection in catalog.collections) {
      final containsTrack = collection.tracks.any(
        (item) => item.id == track.id,
      );
      if (containsTrack) {
        return collection;
      }
    }

    return null;
  }

  String get _normalizedQuery => _searchQuery.trim().toLowerCase();

  void _handleTick(Timer timer) {
    if (!_isPlaying) {
      return;
    }

    final nextPosition = _position + const Duration(seconds: 1);
    if (nextPosition >= _currentTrack.duration) {
      skipNext();
      return;
    }

    _position = nextPosition;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }
}
