import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show Color;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' hide PlaybackEvent;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../data/apple_media_access_channel.dart';
import '../data/local_audio_importer.dart';
import '../data/music_repository.dart';
import '../data/music_session_store.dart';
import '../models/music_models.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/metadata_enrichment_service.dart';
import '../services/recommendation_service.dart';
import '../services/subscription_service.dart';

class MusicAppController extends ChangeNotifier {
  MusicAppController({
    AudioPlayer? player,
    bool enableAudio = true,
    MusicRepository? repository,
    MusicSessionStore? sessionStore,
    AuthService? authService,
    MetadataEnrichmentService? metadataEnrichmentService,
    RecommendationService? recommendationService,
    CloudSyncService? cloudSyncService,
    SubscriptionService? subscriptionService,
    AppleMediaAccessChannel? appleMediaAccessChannel,
    List<Track> initialTracks = const <Track>[],
    List<TrackSourceRecord> initialTrackSources = const <TrackSourceRecord>[],
    List<PlaybackHistoryEntry> initialPlaybackHistory =
        const <PlaybackHistoryEntry>[],
    List<PlaybackEvent> initialPlaybackEvents = const <PlaybackEvent>[],
    Set<String> initialLikedTrackIds = const <String>{},
    Set<String> initialSavedCollectionIds = const <String>{},
    List<String> initialRecentTrackIds = const <String>[],
    List<String> initialRecentSearches = const <String>[],
    MusicTab initialSelectedTab = MusicTab.home,
    LibraryFilter initialLibraryFilter = LibraryFilter.all,
    LibrarySort initialLibrarySort = LibrarySort.recent,
    String initialSearchQuery = '',
    SearchMode initialSearchMode = SearchMode.standard,
    UserProfile? initialUserProfile,
    int initialAiSearchTrialsRemaining = 2,
    AppThemeMode initialThemeMode = AppThemeMode.dark,
    bool initialShuffleEnabled = false,
    bool initialRepeatEnabled = false,
  }) : _audioEnabled = enableAudio,
       _repository =
           repository ??
           (sessionStore == null
               ? null
               : LegacySessionStoreRepository(sessionStore)),
       _authService = authService ?? MockAuthService(),
       _metadataEnrichmentService =
           metadataEnrichmentService ?? MockMetadataEnrichmentService(),
       _recommendationService =
           recommendationService ?? MockRecommendationService(),
       _cloudSyncService = cloudSyncService ?? MockCloudSyncService(),
       _subscriptionService = subscriptionService ?? MockSubscriptionService(),
       _appleMediaAccessChannel =
           appleMediaAccessChannel ?? AppleMediaAccessChannel(),
       _player = enableAudio ? (player ?? AudioPlayer()) : null {
    _tracks = List<Track>.from(initialTracks);
    for (final source in initialTrackSources) {
      _trackSourcesByTrackId[source.trackId] = source;
    }
    for (final entry in initialPlaybackHistory) {
      _playbackHistoryByTrackId[entry.trackId] = entry;
    }
    _playbackEvents = List<PlaybackEvent>.from(initialPlaybackEvents);
    _likedTrackIds.addAll(initialLikedTrackIds);
    _savedCollectionIds.addAll(initialSavedCollectionIds);
    _recentTrackIds.addAll(initialRecentTrackIds);
    _recentSearches.addAll(initialRecentSearches);
    _selectedTab = initialSelectedTab;
    _libraryFilter = initialLibraryFilter;
    _librarySort = initialLibrarySort;
    _searchQuery = initialSearchQuery;
    _searchMode = initialSearchMode;
    _userProfile = initialUserProfile;
    _aiSearchTrialsRemaining = initialAiSearchTrialsRemaining;
    _themeMode = initialThemeMode;
    _isShuffleEnabled = initialShuffleEnabled;
    _isRepeatEnabled = initialRepeatEnabled;
    _syncState = _buildDefaultSyncState();
    _primeLyricsStates();
    _bindAudioStreams();
    if (_player case final player?) {
      unawaited(player.setVolume(_volume));
      unawaited(
        player.setLoopMode(_isRepeatEnabled ? LoopMode.all : LoopMode.off),
      );
    }
  }

  final bool _audioEnabled;
  final MusicRepository? _repository;
  final AuthService _authService;
  final MetadataEnrichmentService _metadataEnrichmentService;
  final RecommendationService _recommendationService;
  final CloudSyncService _cloudSyncService;
  final SubscriptionService _subscriptionService;
  final AppleMediaAccessChannel _appleMediaAccessChannel;
  final AudioPlayer? _player;
  final Set<String> _likedTrackIds = <String>{};
  final Set<String> _savedCollectionIds = <String>{};
  final Map<String, TrackSourceRecord> _trackSourcesByTrackId =
      <String, TrackSourceRecord>{};
  final Map<String, PlaybackHistoryEntry> _playbackHistoryByTrackId =
      <String, PlaybackHistoryEntry>{};
  final List<String> _recentTrackIds = <String>[];
  final List<String> _recentSearches = <String>[];
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  final Map<String, LyricsState> _lyricsByTrackId = <String, LyricsState>{};
  final Map<String, Waveform> _waveformsByTrackId = <String, Waveform>{};
  final Map<String, ScopedTrackAccess> _activeTrackAccesses =
      <String, ScopedTrackAccess>{};
  final Map<String, Duration> _activePlaybackEventStartPositions =
      <String, Duration>{};

  Future<void> _persistOperation = Future<void>.value();
  bool _hasRestoredSession = false;
  bool _isDisposed = false;
  int? _lastPersistedPositionBucket;
  String? _activePlaybackEventId;
  Future<void>? _cacheDirectoryPreparation;
  String? _artworkCacheDirectory;
  String? _waveformCacheDirectory;

  List<Track> _tracks = <Track>[];
  List<Track> _queue = <Track>[];
  List<PlaybackEvent> _playbackEvents = <PlaybackEvent>[];
  Track? _currentTrack;
  MusicCollection? _currentCollection;
  Duration _position = Duration.zero;
  double _volume = 0.8;
  MusicTab _selectedTab = MusicTab.home;
  LibraryFilter _libraryFilter = LibraryFilter.all;
  LibrarySort _librarySort = LibrarySort.recent;
  String _searchQuery = '';
  SearchMode _searchMode = SearchMode.standard;
  bool _isPlaying = false;
  bool _isImporting = false;
  bool _isPreparingPlayback = false;
  bool _isEnhancingLibrary = false;
  bool _isSigningIn = false;
  bool _isRunningAiSearch = false;
  String? _statusMessage;
  String? _aiSearchSummary;
  UserProfile? _userProfile;
  SyncState _syncState = const SyncState();
  int _aiSearchTrialsRemaining = 2;
  bool _hasUnlockedAiUpsell = false;
  List<Track> _aiSearchResults = <Track>[];
  List<SmartPlaylist> _smartPlaylists = <SmartPlaylist>[];
  List<RecommendationCard> _recommendationCards = <RecommendationCard>[];
  AppThemeMode _themeMode = AppThemeMode.dark;
  bool _isShuffleEnabled = false;
  bool _isRepeatEnabled = false;

  MusicTab get selectedTab => _selectedTab;
  LibraryFilter get libraryFilter => _libraryFilter;
  LibrarySort get librarySort => _librarySort;
  String get searchQuery => _searchQuery;
  SearchMode get searchMode => _searchMode;
  bool get isPlaying => _isPlaying;
  bool get isImporting => _isImporting;
  bool get isPreparingPlayback => _isPreparingPlayback;
  bool get isEnhancingLibrary => _isEnhancingLibrary;
  bool get isSigningIn => _isSigningIn;
  bool get isRunningAiSearch => _isRunningAiSearch;
  bool get hasMusic => _tracks.isNotEmpty;
  bool get hasCurrentTrack => _currentTrack != null;
  bool get isSignedIn => _userProfile != null;
  bool get hasPro =>
      (_userProfile?.membershipTier ?? MembershipTier.free) ==
      MembershipTier.pro;
  MembershipTier get membershipTier =>
      _userProfile?.membershipTier ?? MembershipTier.free;
  bool get supportsDirectoryImport =>
      !kIsWeb && (Platform.isAndroid || Platform.isMacOS);
  Track? get currentTrack => _currentTrack;
  MusicCollection? get currentCollection => _currentCollection;
  Duration get position => _position;
  double get volume => _volume;
  AppThemeMode get themeMode => _themeMode;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isRepeatEnabled => _isRepeatEnabled;
  List<Track> get queue => List<Track>.unmodifiable(_queue);
  bool get canSkipNext {
    final currentTrack = _currentTrack;
    if (_queue.isEmpty || currentTrack == null) {
      return false;
    }

    return _queue.length > 1 || _isRepeatEnabled;
  }

  String? get statusMessage => _statusMessage;
  String? get aiSearchSummary => _aiSearchSummary;
  UserProfile? get userProfile => _userProfile;
  SyncState get syncState => _syncState;
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
  int get artistCount => artists.length;
  int get albumCount => albums.length;
  int get playlistCount => playlistCollections.length;
  int get aiSearchTrialsRemaining => _aiSearchTrialsRemaining;
  bool get canUseAiSearch => hasPro || _aiSearchTrialsRemaining > 0;
  bool get shouldShowAiUpsell => _hasUnlockedAiUpsell && !hasPro;
  List<Track> get aiSearchResults => List<Track>.unmodifiable(_aiSearchResults);
  List<SmartPlaylist> get smartPlaylists =>
      List<SmartPlaylist>.unmodifiable(_smartPlaylists);
  List<MusicCollection> get smartPlaylistCollections => _smartPlaylists
      .map((playlist) => playlist.toCollection())
      .toList(growable: false);
  List<RecommendationCard> get recommendationCards =>
      List<RecommendationCard>.unmodifiable(_recommendationCards);

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
    return sorted.take(10).toList(growable: false);
  }

  List<Album> get albums {
    final grouped = <String, List<Track>>{};
    for (final track in _tracks) {
      final key =
          'album::${track.artist.toLowerCase()}::${track.album.toLowerCase()}';
      grouped.putIfAbsent(key, () => <Track>[]).add(track);
    }

    return grouped.entries
        .map((entry) {
          final tracks = List<Track>.from(entry.value)
            ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            );
          final first = tracks.first;
          return Album(
            id: entry.key,
            title: first.album,
            artist: first.artist,
            palette: first.palette,
            tracks: tracks,
            year: first.year,
          );
        })
        .toList(growable: false)
      ..sort(
        (a, b) =>
            b.tracks.first.importedAt.compareTo(a.tracks.first.importedAt),
      );
  }

  List<Artist> get artists {
    final grouped = <String, List<Track>>{};
    for (final track in _tracks) {
      final key = 'artist::${track.artist.toLowerCase()}';
      grouped.putIfAbsent(key, () => <Track>[]).add(track);
    }

    return grouped.entries
        .map((entry) {
          final tracks = List<Track>.from(entry.value)
            ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
          final first = tracks.first;
          return Artist(
            id: entry.key,
            name: first.artist,
            palette: first.palette,
            tracks: tracks,
          );
        })
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  TrackSourceRecord? trackSourceForTrack(String trackId) =>
      _trackSourcesByTrackId[trackId];

  List<PlaybackEvent> get playbackEvents {
    final events = List<PlaybackEvent>.from(_playbackEvents);
    events.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return events;
  }

  List<PlaybackEvent> playbackEventsForTrack(String trackId) {
    final events = playbackEvents.where((event) => event.trackId == trackId);
    return events.toList(growable: false);
  }

  List<Track> get resumeTracks {
    final tracksById = {for (final track in _tracks) track.id: track};
    final entries =
        _playbackHistoryByTrackId.values
            .where((entry) => entry.lastPosition > Duration.zero)
            .toList(growable: false)
          ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));

    return entries
        .map((entry) => tracksById[entry.trackId])
        .whereType<Track>()
        .toList(growable: false);
  }

  List<Track> get mostPlayedTracks {
    final tracksById = {for (final track in _tracks) track.id: track};
    final entries = _playbackHistoryByTrackId.values.toList(growable: false)
      ..sort((a, b) {
        final playCountCompare = b.playCount.compareTo(a.playCount);
        if (playCountCompare != 0) {
          return playCountCompare;
        }
        return b.lastPlayedAt.compareTo(a.lastPlayedAt);
      });

    return entries
        .map((entry) => tracksById[entry.trackId])
        .whereType<Track>()
        .toList(growable: false);
  }

  List<({DateTime day, List<PlaybackEvent> events})> get recentSessionGroups {
    final grouped = <DateTime, List<PlaybackEvent>>{};
    for (final event in playbackEvents) {
      final key = DateTime(
        event.startedAt.year,
        event.startedAt.month,
        event.startedAt.day,
      );
      grouped.putIfAbsent(key, () => <PlaybackEvent>[]).add(event);
    }

    final days = grouped.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    return days
        .map((day) => (day: day, events: grouped[day]!))
        .toList(growable: false);
  }

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
        (smartPlaylistCollections.isNotEmpty
            ? smartPlaylistCollections.first
            : null) ??
        (savedCollections.isNotEmpty ? savedCollections.first : null) ??
        (recentCollections.isNotEmpty ? recentCollections.first : null) ??
        allTracksCollection;
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
      reason: 'A full-library playback entry point.',
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
                artworkUri: firstTrack.artworkUri,
              );
            })
            .toList(growable: false)
          ..sort((a, b) => b.latestImportAt.compareTo(a.latestImportAt));

    return collections;
  }

  List<MusicCollection> get albumCollections =>
      albums.map((album) => album.toCollection()).toList(growable: false);

  List<MusicCollection> get artistCollections =>
      artists.map((artist) => artist.toCollection()).toList(growable: false);

  List<MusicCollection> get playlistCollections {
    final collections = <MusicCollection>[];
    if (favoriteTracks.isNotEmpty) {
      collections.add(_buildLikedSongsCollection(favoriteTracks));
    }
    collections.addAll(smartPlaylistCollections);
    return collections;
  }

  List<MusicCollection> get allBrowsableCollections {
    final collections = <MusicCollection>[
      allTracksCollection,
      ...playlistCollections,
      ...albumCollections,
      ...artistCollections,
      ...importedCollections,
    ];
    final seen = <String>{};
    return collections
        .where((collection) => seen.add(collection.id))
        .toList(growable: false);
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

  List<MusicCollection> get savedCollections {
    final collections = {
      for (final collection in allBrowsableCollections)
        collection.id: collection,
    };
    return _savedCollectionIds
        .map((collectionId) => collections[collectionId])
        .whereType<MusicCollection>()
        .toList(growable: false);
  }

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

    addMany(playlistCollections);
    addMany(savedCollections);
    addMany(recentCollections);
    addMany(importedCollections);

    return collections.take(8).toList(growable: false);
  }

  List<MusicCollection> get pinnedCollections {
    final source = savedCollections.isNotEmpty
        ? savedCollections
        : playlistCollections.isNotEmpty
        ? playlistCollections
        : recentCollections;
    if (source.isNotEmpty) {
      return source.take(4).toList(growable: false);
    }

    return importedCollections.take(4).toList(growable: false);
  }

  List<Track> get continueListeningTracks {
    if (resumeTracks.isNotEmpty) {
      return resumeTracks.take(6).toList(growable: false);
    }

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
    for (final card in _recommendationCards) {
      addMany(card.tracks);
    }

    return tracks.take(8).toList(growable: false);
  }

  List<Track> get rediscoveryTracks {
    final favorites = favoriteTracks;
    if (favorites.isNotEmpty) {
      return favorites.take(6).toList(growable: false);
    }
    return recentImportedTracks.take(6).toList(growable: false);
  }

  List<Track> get filteredLibraryTracks {
    final tracks = switch (_libraryFilter) {
      LibraryFilter.all => importedTracks,
      LibraryFilter.tracks => importedTracks,
      LibraryFilter.favorites => favoriteTracks,
      LibraryFilter.albums ||
      LibraryFilter.artists ||
      LibraryFilter.playlists ||
      LibraryFilter.folders => const <Track>[],
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
      LibraryFilter.all => allBrowsableCollections.where(
        (collection) => collection.id != 'all_tracks',
      ),
      LibraryFilter.albums => albumCollections,
      LibraryFilter.artists => artistCollections,
      LibraryFilter.playlists => playlistCollections,
      LibraryFilter.folders => importedCollections,
      LibraryFilter.favorites => savedCollections,
      LibraryFilter.tracks => const <MusicCollection>[],
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

  List<Track> get activeSearchTracks => _searchMode == SearchMode.ai
      ? (_normalizedQuery.isEmpty ? continueListeningTracks : _aiSearchResults)
      : searchTrackResults;

  List<MusicCollection> get searchCollectionResults {
    final collections = allBrowsableCollections.where(
      (collection) => collection.id != 'all_tracks',
    );
    final query = _normalizedQuery;

    if (query.isEmpty) {
      return collections.take(8).toList(growable: false);
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

  List<MusicCollection> get aiSearchCollections {
    final seen = <String>{};
    return _aiSearchResults
        .map(collectionForTrack)
        .whereType<MusicCollection>()
        .where((collection) => seen.add(collection.id))
        .toList(growable: false);
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
      if (track.genre case final genre?) {
        add(genre);
      }
    }

    for (final collection in playlistCollections.take(3)) {
      add(collection.title);
    }

    for (final collection in importedCollections.take(3)) {
      add(collection.title);
    }

    return suggestions.take(10).toList(growable: false);
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

    for (final track in recentImportedTracks.take(5)) {
      add(track.artist);
      add(track.album);
      if (track.genre case final genre?) {
        add(genre);
      }
    }

    for (final collection in smartPlaylistCollections.take(3)) {
      add(collection.title);
    }

    for (final track in importedTracks) {
      if (track.fileExtension case final extension?) {
        add(extension.toUpperCase());
      }
      if (suggestions.length >= 10) {
        break;
      }
    }

    return suggestions.take(10).toList(growable: false);
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
      return _queue.take(6).toList(growable: false);
    }

    final reordered = <Track>[
      ..._queue.skip(currentIndex + 1),
      ..._queue.take(currentIndex),
    ];
    return reordered.take(6).toList(growable: false);
  }

  bool isCollectionSaved(String collectionId) =>
      _savedCollectionIds.contains(collectionId);

  bool isTrackLiked(String trackId) => _likedTrackIds.contains(trackId);

  List<Track> _orderedQueueForCurrentContext({
    List<Track>? baseQueue,
    Track? currentTrack,
  }) {
    final current = currentTrack ?? _currentTrack;
    final tracks =
        baseQueue ??
        (() {
          final collection = _currentCollection;
          if (collection == null) {
            return _queue;
          }

          final availableTrackIds = _queue.map((track) => track.id).toSet();
          return collection.tracks
              .where((track) => availableTrackIds.contains(track.id))
              .toList(growable: false);
        })();

    final ordered = List<Track>.from(tracks);
    if (!_isShuffleEnabled || current == null || ordered.length <= 1) {
      return ordered;
    }

    final remaining = ordered
        .where((track) => track.id != current.id)
        .toList(growable: false);
    remaining.shuffle(Random(DateTime.now().microsecondsSinceEpoch));
    return <Track>[current, ...remaining];
  }

  LyricsState lyricsStateForTrack(Track track) {
    return _lyricsByTrackId[track.id] ??
        LyricsState(
          status: track.lyricsAvailability == LyricsAvailability.available
              ? LyricsStatus.idle
              : LyricsStatus.unavailable,
          title: track.lyricsAvailability == LyricsAvailability.available
              ? 'Lyrics ready to load'
              : 'No synced lyrics yet',
          source: 'ChiMusic Metadata',
        );
  }

  List<Track> similarTracksFor(Track track) {
    final genre = (track.genre ?? '').toLowerCase();
    final matches = _tracks
        .where((candidate) {
          if (candidate.id == track.id) {
            return false;
          }
          if (candidate.artist.toLowerCase() == track.artist.toLowerCase()) {
            return true;
          }
          return genre.isNotEmpty &&
              (candidate.genre ?? '').toLowerCase() == genre;
        })
        .toList(growable: false);

    if (matches.isNotEmpty) {
      return matches.take(6).toList(growable: false);
    }

    return recentImportedTracks
        .where((candidate) => candidate.id != track.id)
        .take(6)
        .toList(growable: false);
  }

  String recommendationReasonForTrack(Track track) {
    final pieces = <String>[];
    if (track.genre case final genre?) {
      pieces.add(genre);
    }
    if (track.year case final year?) {
      pieces.add('$year');
    }
    if (_likedTrackIds.contains(track.id)) {
      pieces.add('liked');
    }
    if (_recentTrackIds.contains(track.id)) {
      pieces.add('recent');
    }

    if (pieces.isEmpty) {
      return 'Matched from your local library structure.';
    }

    return 'Matched from ${pieces.join(' • ')} signals in your local library.';
  }

  Waveform? waveformForTrack(Track track) => _waveformsByTrackId[track.id];

  Future<void> _ensureCacheDirectoriesReady() async {
    final inFlight = _cacheDirectoryPreparation;
    if (inFlight != null) {
      return inFlight;
    }

    _cacheDirectoryPreparation = () async {
      try {
        final supportDirectory = await getApplicationSupportDirectory();
        final temporaryDirectory = await getTemporaryDirectory();
        _artworkCacheDirectory = path.join(
          supportDirectory.path,
          'chimusic_artwork',
        );
        _waveformCacheDirectory = path.join(
          temporaryDirectory.path,
          'chimusic_waveforms',
        );
        await Directory(_artworkCacheDirectory!).create(recursive: true);
        await Directory(_waveformCacheDirectory!).create(recursive: true);
      } catch (_) {
        _artworkCacheDirectory = null;
        _waveformCacheDirectory = null;
      }
    }();
    return _cacheDirectoryPreparation!;
  }

  Future<void> _prepareWaveformForTrack(Track track) async {
    await _ensureCacheDirectoriesReady();
    final waveformCacheDirectory = _waveformCacheDirectory;
    if (waveformCacheDirectory == null) {
      return;
    }

    final waveformPath =
        track.waveformUri ??
        path.join(waveformCacheDirectory, '${track.id.hashCode.abs()}.wave');
    final waveformFile = File(waveformPath);

    try {
      if (await waveformFile.exists()) {
        _waveformsByTrackId[track.id] = await JustWaveform.parse(waveformFile);
        _replaceTrackWaveformUri(track.id, waveformPath);
        return;
      }
    } catch (_) {
      // Fall through and attempt a fresh extraction.
    }

    final access = await _beginTrackAccess(track);
    if (access == null) {
      return;
    }

    try {
      await for (final progress in JustWaveform.extract(
        audioInFile: File(access.path),
        waveOutFile: waveformFile,
        zoom: const WaveformZoom.pixelsPerSecond(64),
      )) {
        if (progress.waveform case final waveform?) {
          _waveformsByTrackId[track.id] = waveform;
          _replaceTrackWaveformUri(track.id, waveformPath);
          _notifyIfAlive();
        }
      }
    } catch (_) {
      // Waveform extraction should not block playback or library browsing.
    } finally {
      await access.release();
    }
  }

  Future<ScopedTrackAccess?> _beginTrackAccess(Track track) async {
    final source =
        _trackSourcesByTrackId[track.id] ??
        TrackSourceRecord(
          trackId: track.id,
          platform: 'local',
          locator: track.filePath,
        );
    final access = await _appleMediaAccessChannel.beginAccess(source);
    if (access == null) {
      _updateTrackAvailability(track.id, TrackAvailability.unavailable);
      return null;
    }

    if (access.refreshedBookmarkBase64 case final refreshedBookmark?) {
      _trackSourcesByTrackId[track.id] = source.copyWith(
        bookmarkBase64: refreshedBookmark,
      );
    }

    if (!await File(access.path).exists()) {
      await access.release();
      _updateTrackAvailability(track.id, TrackAvailability.unavailable);
      return null;
    }

    _updateTrackAvailability(
      track.id,
      TrackAvailability.available,
      filePath: access.path,
    );
    return access;
  }

  Future<void> _refreshQueueFileAccesses(List<Track> tracks) async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS || Platform.isAndroid)) {
      return;
    }

    await _releaseQueueFileAccesses();
    for (final track in tracks) {
      final access = await _beginTrackAccess(track);
      if (access != null) {
        _activeTrackAccesses[track.id] = access;
      }
    }
  }

  Future<void> _releaseQueueFileAccesses() async {
    final accesses = _activeTrackAccesses.values.toList(growable: false);
    _activeTrackAccesses.clear();
    for (final access in accesses) {
      await access.release();
    }
  }

  void _replaceTrackWaveformUri(String trackId, String waveformPath) {
    var changed = false;
    _tracks = _tracks
        .map((track) {
          if (track.id != trackId || track.waveformUri == waveformPath) {
            return track;
          }
          changed = true;
          return track.copyWith(waveformUri: waveformPath);
        })
        .toList(growable: false);
    _queue = _queue
        .map(
          (track) => track.id == trackId
              ? track.copyWith(waveformUri: waveformPath)
              : track,
        )
        .toList(growable: false);
    if (_currentTrack?.id == trackId) {
      _currentTrack = _currentTrack?.copyWith(waveformUri: waveformPath);
      changed = true;
    }
    if (changed) {
      _persistSession();
    }
  }

  void _updateTrackAvailability(
    String trackId,
    TrackAvailability availability, {
    String? filePath,
  }) {
    var changed = false;
    final now = DateTime.now();
    _tracks = _tracks
        .map((track) {
          if (track.id != trackId) {
            return track;
          }

          final nextTrack = track.copyWith(
            availability: availability,
            filePath: filePath ?? track.filePath,
            lastValidatedAt: now,
          );
          changed = changed || nextTrack != track;
          return nextTrack;
        })
        .toList(growable: false);
    _queue = _queue
        .map(
          (track) => track.id == trackId
              ? track.copyWith(
                  availability: availability,
                  filePath: filePath ?? track.filePath,
                  lastValidatedAt: now,
                )
              : track,
        )
        .toList(growable: false);
    if (_currentTrack?.id == trackId) {
      _currentTrack = _currentTrack?.copyWith(
        availability: availability,
        filePath: filePath ?? _currentTrack!.filePath,
        lastValidatedAt: now,
      );
      changed = true;
    }
    if (changed) {
      _persistSession();
    }
  }

  Future<void> restoreSession() async {
    final repository = _repository;
    if (_hasRestoredSession || repository == null) {
      return;
    }

    _hasRestoredSession = true;

    try {
      final snapshot = await repository.load();
      _applyRepositorySnapshot(snapshot);

      final restoredUser =
          snapshot.userProfile ?? await _authService.restoreUser();
      if (restoredUser != null) {
        _userProfile = restoredUser;
      }
      _syncState = _buildDefaultSyncState();
      await _refreshOnlineState(notifyAfterCompletion: false);
      if (_userProfile != null) {
        await _restoreCloudSnapshotIfAvailable(
          applyRemoteWhenLibraryEmpty: true,
        );
      }
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

  void setSearchMode(SearchMode mode) {
    if (_searchMode == mode) {
      return;
    }

    _searchMode = mode;
    if (mode == SearchMode.standard) {
      _aiSearchSummary = null;
      _aiSearchResults = <Track>[];
    }
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
    if (_searchQuery.isEmpty && _aiSearchResults.isEmpty) {
      return;
    }

    _searchQuery = '';
    _aiSearchResults = <Track>[];
    _aiSearchSummary = null;
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
    _playbackEvents = <PlaybackEvent>[];
    _activePlaybackEventStartPositions.clear();
    _activePlaybackEventId = null;
    _recentTrackIds.clear();
    _statusMessage = 'Cleared saved playback history from ChiMusic.';
    notifyListeners();
    _persistSession();
    _queueSyncIfSignedIn();
  }

  void clearStatusMessage() {
    if (_statusMessage == null) {
      return;
    }

    _statusMessage = null;
    notifyListeners();
  }

  void setStatusMessage(String message) {
    if (_statusMessage == message) {
      return;
    }

    _statusMessage = message;
    notifyListeners();
  }

  void toggleThemeMode() {
    setThemeMode(
      _themeMode == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark,
    );
  }

  void setThemeMode(AppThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;
    notifyListeners();
    _persistSession();
  }

  Future<void> toggleShuffle() async {
    _isShuffleEnabled = !_isShuffleEnabled;
    await _rebuildQueueForPlaybackOrder();
  }

  Future<void> toggleRepeat() async {
    _isRepeatEnabled = !_isRepeatEnabled;

    final player = _player;
    if (_audioEnabled && player != null) {
      await player.setLoopMode(_isRepeatEnabled ? LoopMode.all : LoopMode.off);
    }

    notifyListeners();
    _persistSession();
  }

  void submitSearch([String? value]) {
    final candidate = (value ?? _searchQuery).trim();
    if (candidate.isEmpty) {
      return;
    }

    _rememberSearch(candidate);
    if (_searchMode == SearchMode.ai) {
      unawaited(runAiSearch(candidate));
      return;
    }

    notifyListeners();
    _persistSession();
  }

  Future<void> runAiSearch([String? value]) async {
    final candidate = (value ?? _searchQuery).trim();
    if (candidate.isEmpty) {
      return;
    }

    _searchQuery = candidate;
    _rememberSearch(candidate);

    if (!canUseAiSearch) {
      _hasUnlockedAiUpsell = true;
      _aiSearchResults = <Track>[];
      _aiSearchSummary =
          'Your free AI searches are used up. Upgrade to Pro for unlimited natural-language search.';
      notifyListeners();
      _persistSession();
      return;
    }

    _isRunningAiSearch = true;
    _aiSearchSummary = 'Reading your library structure and recent listening…';
    notifyListeners();

    final results = await _recommendationService.semanticSearch(
      query: candidate,
      tracks: _tracks,
      recentPlayedTracks: recentPlayedTracks,
      favoriteTracks: favoriteTracks,
    );

    if (!hasPro && _aiSearchTrialsRemaining > 0) {
      _aiSearchTrialsRemaining -= 1;
    }
    _hasUnlockedAiUpsell = true;
    _aiSearchResults = results;
    _aiSearchSummary = results.isEmpty
        ? 'AI could not find a close library match for "$candidate". Try an artist, mood, or use case.'
        : 'AI matched these tracks using genre, favorites, recency, and descriptive intent.';
    _isRunningAiSearch = false;
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
    if (_searchMode == SearchMode.ai) {
      unawaited(runAiSearch(normalized));
      return;
    }

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
    _queueSyncIfSignedIn();
  }

  void toggleLikedTrack(String trackId) {
    if (_likedTrackIds.contains(trackId)) {
      _likedTrackIds.remove(trackId);
    } else {
      _likedTrackIds.add(trackId);
    }

    notifyListeners();
    _persistSession();
    unawaited(_refreshRecommendationContent());
    _queueSyncIfSignedIn();
  }

  Future<void> signIn() async {
    if (_isSigningIn) {
      return;
    }

    _isSigningIn = true;
    notifyListeners();

    try {
      _userProfile = await _authService.signIn();
      _syncState = _buildDefaultSyncState();
      _statusMessage = 'Signed in. Sync and AI features are now available.';
      await _restoreCloudSnapshotIfAvailable(applyRemoteWhenLibraryEmpty: true);
      await syncLibraryNow(silent: true);
    } finally {
      _isSigningIn = false;
      notifyListeners();
      _persistSession();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _userProfile = null;
    _syncState = _buildDefaultSyncState();
    _statusMessage = 'Signed out. Local playback still works offline.';
    notifyListeners();
    _persistSession();
  }

  Future<void> upgradeToPro() async {
    if (_userProfile == null) {
      await signIn();
    }

    final user = _userProfile;
    if (user == null) {
      return;
    }

    _userProfile = await _subscriptionService.upgradeToPro(user);
    _statusMessage = 'ChiMusic Pro is active. AI search is now unlimited.';
    notifyListeners();
    _persistSession();
  }

  Future<void> syncLibraryNow({bool silent = false}) async {
    final user = _userProfile;
    if (user == null) {
      _syncState = _buildDefaultSyncState();
      if (!silent) {
        _statusMessage = 'Sign in to sync your library across devices.';
        notifyListeners();
      }
      _persistSession();
      return;
    }

    if (_syncState.isBusy) {
      return;
    }

    _syncState = SyncState(
      phase: SyncPhase.syncing,
      message: 'Syncing your library snapshot…',
      lastSyncedAt: _syncState.lastSyncedAt,
    );
    notifyListeners();

    final snapshot = MusicCloudSnapshot(
      userId: user.id,
      tracks: List<Track>.from(_tracks),
      playbackHistory: _playbackHistoryByTrackId.values.toList(growable: false),
      likedTrackIds: Set<String>.from(_likedTrackIds),
      savedCollectionIds: Set<String>.from(_savedCollectionIds),
      recentTrackIds: List<String>.from(_recentTrackIds),
      recentSearches: List<String>.from(_recentSearches),
      queueTrackIds: _queue.map((track) => track.id).toList(growable: false),
      currentTrackId: _currentTrack?.id,
      currentCollectionId: _currentCollection?.id,
      positionMs: _position.inMilliseconds,
    );

    try {
      _syncState = await _cloudSyncService.syncSnapshot(user, snapshot);
      _markLibrarySynced(_syncState.lastSyncedAt);
      if (!silent) {
        _statusMessage = _syncState.message;
      }
    } catch (_) {
      _syncState = SyncState(
        phase: SyncPhase.error,
        message: 'Cloud sync failed. Local playback and search still work.',
        lastSyncedAt: _syncState.lastSyncedAt,
      );
      if (!silent) {
        _statusMessage = _syncState.message;
      }
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

      final selections = await _pickImportSelections();
      await _importSelections(selections);
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
      final selections = await _appleMediaAccessChannel
          .attachPersistentBookmarks(
            audioPaths
                .map(
                  (audioPath) => LocalImportSelection(
                    path: audioPath,
                    platform: Platform.isAndroid ? 'android' : 'macos',
                  ),
                )
                .toList(growable: false),
          );
      await _importSelections(selections);
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
      if (_isPlaying) {
        _startPlaybackForTrack(_currentTrack!);
      } else {
        _closeActivePlaybackEvent(
          reason: PlaybackEndReason.paused,
          finalPosition: _position,
        );
      }
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

  Future<void> resumeTrack(Track track, {MusicCollection? collection}) async {
    final ownerCollection =
        collection ?? collectionForTrack(track) ?? allTracksCollection;
    final queueTracks = ownerCollection.tracks;
    final initialIndex = queueTracks.indexWhere((item) => item.id == track.id);

    await _loadQueue(
      queueTracks,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      collection: ownerCollection,
      autoplay: true,
      startPosition:
          playbackHistoryEntryForTrack(track.id)?.lastPosition ?? Duration.zero,
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

  Future<void> relinkTrack(Track track) async {
    final selections = await _pickImportSelections();
    if (selections.isEmpty) {
      return;
    }

    await _ensureCacheDirectoriesReady();
    final artworkCacheDirectory = _artworkCacheDirectory;
    if (artworkCacheDirectory == null) {
      _statusMessage =
          'ChiMusic could not prepare a cache for the re-linked file.';
      notifyListeners();
      return;
    }

    final payload = await buildImportedTrackFromSelection(
      selections.first,
      artworkCacheDirectory: artworkCacheDirectory,
      importedAt: track.importedAt,
    );
    if (payload == null) {
      return;
    }

    final relinkedTrack = payload.track.copyWith(
      id: track.id,
      importedAt: track.importedAt,
      availability: TrackAvailability.available,
    );
    final replacementById = <String, Track>{track.id: relinkedTrack};
    _replaceLibraryTracks(
      _tracks
          .map((item) => replacementById[item.id] ?? item)
          .toList(growable: false),
    );
    _trackSourcesByTrackId[track.id] = payload.source.copyWith(
      trackId: track.id,
    );
    _statusMessage = 'Re-linked ${relinkedTrack.title} to a new local file.';
    notifyListeners();
    _persistSession();
  }

  Future<void> removeTrackFromLibrary(String trackId) async {
    await _removeTracksFromLibrary(
      <String>{trackId},
      successMessage:
          'Removed 1 unavailable track from ChiMusic. Original files were not deleted.',
    );
  }

  Future<void> removeCollectionFromLibrary(String collectionId) async {
    final target = collectionById(collectionId);
    if (target == null) {
      return;
    }

    if (target.id == 'all_tracks' ||
        target.id == 'favorites' ||
        target.kind == MusicCollectionKind.smartPlaylist ||
        target.kind == MusicCollectionKind.playlist) {
      _savedCollectionIds.remove(collectionId);
      _statusMessage = 'Removed $collectionId from saved library shortcuts.';
      notifyListeners();
      _persistSession();
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
    _trackSourcesByTrackId.clear();
    _queue = <Track>[];
    _currentTrack = null;
    _currentCollection = null;
    _position = Duration.zero;
    _searchQuery = '';
    _likedTrackIds.clear();
    _savedCollectionIds.clear();
    _playbackHistoryByTrackId.clear();
    _playbackEvents = <PlaybackEvent>[];
    _activePlaybackEventStartPositions.clear();
    _recentTrackIds.clear();
    _recentSearches.clear();
    _aiSearchResults = <Track>[];
    _smartPlaylists = <SmartPlaylist>[];
    _recommendationCards = <RecommendationCard>[];
    _lyricsByTrackId.clear();
    _waveformsByTrackId.clear();
    _isPlaying = false;
    _isPreparingPlayback = false;
    _lastPersistedPositionBucket = null;
    _activePlaybackEventId = null;
    _statusMessage =
        'Cleared imported items from ChiMusic. Original audio files were not deleted.';
    _syncState = _buildDefaultSyncState();
    notifyListeners();
    _persistSession();
    _queueSyncIfSignedIn();
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
      _updateActivePlaybackEventProgress(nextPosition);
      notifyListeners();
      _persistSession();
      return;
    }

    final player = _player;

    _position = nextPosition;
    _syncCurrentTrackHistoryPosition(nextPosition);
    _updateActivePlaybackEventProgress(nextPosition);
    notifyListeners();
    await player.seek(nextPosition);
    _persistSession();
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if ((_volume - clamped).abs() < 0.001) {
      return;
    }

    _volume = clamped;
    notifyListeners();

    final player = _player;
    if (!_audioEnabled || player == null) {
      return;
    }

    await player.setVolume(clamped);
  }

  Future<void> skipNext() async {
    final currentTrack = _currentTrack;
    if (_queue.isEmpty || currentTrack == null) {
      return;
    }

    final currentIndex = _queue.indexWhere(
      (track) => track.id == currentTrack.id,
    );
    final nextIndex = currentIndex < 0
        ? 0
        : currentIndex + 1 < _queue.length
        ? currentIndex + 1
        : (_isRepeatEnabled ? 0 : currentIndex);

    if (!_isRepeatEnabled && nextIndex == currentIndex) {
      return;
    }

    if (!_audioEnabled || _player == null) {
      final nextTrack = _queue[nextIndex];
      if (_activePlaybackEventId != null) {
        _closeActivePlaybackEvent(
          reason: PlaybackEndReason.skipped,
          finalPosition: _position,
        );
      }
      _currentTrack = nextTrack;
      _position = Duration.zero;
      _isPlaying = true;
      _lastPersistedPositionBucket = 0;
      unawaited(loadLyricsForTrack(nextTrack));
      unawaited(_prepareWaveformForTrack(nextTrack));
      _startPlaybackForTrack(nextTrack);
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
        ? (_isRepeatEnabled ? _queue.length - 1 : 0)
        : currentIndex - 1;

    if (!_audioEnabled || _player == null) {
      final previousTrack = _queue[previousIndex];
      if (_activePlaybackEventId != null) {
        _closeActivePlaybackEvent(
          reason: PlaybackEndReason.skipped,
          finalPosition: _position,
        );
      }
      _currentTrack = previousTrack;
      _position = Duration.zero;
      _isPlaying = true;
      _lastPersistedPositionBucket = 0;
      unawaited(loadLyricsForTrack(previousTrack));
      unawaited(_prepareWaveformForTrack(previousTrack));
      _startPlaybackForTrack(previousTrack);
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
    final currentCollection = _currentCollection;
    if (currentCollection != null &&
        currentCollection.tracks.any((item) => item.id == track.id)) {
      return _restoreCollectionFromId(currentCollection.id) ??
          currentCollection;
    }

    for (final collection in playlistCollections) {
      if (collection.tracks.any((item) => item.id == track.id)) {
        return collection;
      }
    }

    for (final collection in albumCollections) {
      if (collection.tracks.any((item) => item.id == track.id)) {
        return collection;
      }
    }

    for (final collection in importedCollections) {
      if (collection.tracks.any((item) => item.id == track.id)) {
        return collection;
      }
    }

    return null;
  }

  MusicCollection? collectionById(String collectionId) {
    for (final collection in allBrowsableCollections) {
      if (collection.id == collectionId) {
        return collection;
      }
    }

    return null;
  }

  Future<void> loadLyricsForTrack(Track track) async {
    final existing = _lyricsByTrackId[track.id];
    if (existing != null &&
        (existing.status == LyricsStatus.loading ||
            existing.status == LyricsStatus.available ||
            existing.status == LyricsStatus.unavailable)) {
      return;
    }

    if (track.lyricsAvailability == LyricsAvailability.unavailable) {
      _lyricsByTrackId[track.id] = const LyricsState(
        status: LyricsStatus.unavailable,
        title: 'No synced lyrics yet',
        source: 'ChiMusic Metadata',
      );
      _notifyIfAlive();
      return;
    }

    _lyricsByTrackId[track.id] = const LyricsState(
      status: LyricsStatus.loading,
      title: 'Loading lyrics...',
      source: 'ChiMusic Metadata',
    );
    _notifyIfAlive();

    try {
      _lyricsByTrackId[track.id] = await _metadataEnrichmentService.fetchLyrics(
        track,
      );
    } catch (_) {
      _lyricsByTrackId[track.id] = const LyricsState(
        status: LyricsStatus.error,
        title: 'Lyrics unavailable',
        source: 'ChiMusic Metadata',
        errorMessage: 'Could not load synced lyrics for this track.',
      );
    }

    _notifyIfAlive();
  }

  int _scoreTrackMatch(Track track, String query) {
    var score = 0;
    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();
    final album = track.album.toLowerCase();
    final fileName = track.fileName.toLowerCase();
    final genre = (track.genre ?? '').toLowerCase();
    final year = '${track.year ?? ''}';

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

    if (genre.contains(query)) {
      score += 32;
    }

    if (year.contains(query)) {
      score += 24;
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
    final prompt = (collection.prompt ?? '').toLowerCase();
    final reason = (collection.reason ?? '').toLowerCase();

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

    if (prompt.contains(query)) {
      score += 24;
    }

    if (reason.contains(query)) {
      score += 20;
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
      reason: 'Built from your saved tracks.',
    );
  }

  void _rememberSearch(String value) {
    _recentSearches.removeWhere(
      (entry) => entry.toLowerCase() == value.toLowerCase(),
    );
    _recentSearches.insert(0, value);

    if (_recentSearches.length > 10) {
      _recentSearches.removeRange(10, _recentSearches.length);
    }
  }

  String get _normalizedQuery => _searchQuery.trim().toLowerCase();

  Future<void> _rebuildQueueForPlaybackOrder() async {
    final currentTrack = _currentTrack;
    if (currentTrack == null || _queue.isEmpty) {
      notifyListeners();
      _persistSession();
      return;
    }

    final nextQueue = _orderedQueueForCurrentContext(
      currentTrack: currentTrack,
    );
    _queue = nextQueue;
    final currentIndex = _queue.indexWhere(
      (track) => track.id == currentTrack.id,
    );
    if (currentIndex < 0) {
      notifyListeners();
      _persistSession();
      return;
    }

    if (!_audioEnabled || _player == null) {
      notifyListeners();
      _persistSession();
      return;
    }

    final player = _player;
    final position = _position;
    final autoplay = _isPlaying;
    _isPreparingPlayback = true;
    notifyListeners();

    try {
      await _refreshQueueFileAccesses(_queue);
      final sources = _queue
          .map(
            (track) => AudioSource.uri(
              Uri.file(track.filePath),
              tag: _buildMediaItem(track),
            ),
          )
          .toList(growable: false);

      await player.setAudioSources(
        sources,
        initialIndex: currentIndex,
        initialPosition: position,
      );
      await player.setLoopMode(_isRepeatEnabled ? LoopMode.all : LoopMode.off);

      if (autoplay) {
        await player.play();
      } else {
        await player.pause();
      }
    } on PlayerException {
      _statusMessage =
          'Unable to rebuild the playback queue for the new play mode.';
    } catch (_) {
      _statusMessage =
          'Playback queue update failed. Your current library is still intact.';
    } finally {
      _isPreparingPlayback = false;
      notifyListeners();
      _persistSession();
    }
  }

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
    _trackSourcesByTrackId.removeWhere(
      (trackId, _) => removedTrackIds.contains(trackId),
    );
    _playbackEvents = _playbackEvents
        .where((event) => !removedTrackIds.contains(event.trackId))
        .toList(growable: false);
    _lyricsByTrackId.removeWhere(
      (trackId, _) => removedTrackIds.contains(trackId),
    );
    _waveformsByTrackId.removeWhere(
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
      _activePlaybackEventId = null;
    } else if (_currentTrack != null) {
      final currentTrack = _currentTrack!;
      _currentCollection =
          collectionForTrack(currentTrack) ?? allTracksCollection;
    }

    _savedCollectionIds.removeWhere(
      (collectionId) => collectionById(collectionId) == null,
    );
    _statusMessage = successMessage;
    notifyListeners();
    await _refreshOnlineState(notifyAfterCompletion: false);
    _persistSession();
    _queueSyncIfSignedIn();
  }

  Future<void> _stopPlayback() async {
    if (!_audioEnabled || _player == null) {
      if (_activePlaybackEventId != null) {
        _closeActivePlaybackEvent(
          reason: PlaybackEndReason.stopped,
          finalPosition: _position,
        );
      }
      await _releaseQueueFileAccesses();
      return;
    }

    if (_activePlaybackEventId != null) {
      _closeActivePlaybackEvent(
        reason: PlaybackEndReason.stopped,
        finalPosition: _position,
      );
    }
    await _player.stop();
    await _releaseQueueFileAccesses();
  }

  Future<List<LocalImportSelection>> _pickImportSelections() async {
    if (_appleMediaAccessChannel.supportsNativePicker) {
      return _appleMediaAccessChannel.pickAudioFiles();
    }

    final pickedFiles = await openFiles(
      acceptedTypeGroups: <XTypeGroup>[localAudioTypeGroup],
    );
    final selections = pickedFiles
        .map((file) => file.path)
        .where((path) => path.isNotEmpty)
        .map(
          (filePath) => LocalImportSelection(
            path: filePath,
            platform: Platform.isAndroid ? 'android' : 'macos',
          ),
        )
        .toList(growable: false);
    return _appleMediaAccessChannel.attachPersistentBookmarks(selections);
  }

  Future<void> _importSelections(List<LocalImportSelection> selections) async {
    if (selections.isEmpty) {
      return;
    }

    final tracksByNormalizedPath = {
      for (final track in _tracks) path.normalize(track.filePath): track,
    };
    final supportedSelections = selections
        .where((selection) => isSupportedAudioPath(selection.path))
        .toList(growable: false);
    final duplicateCount = supportedSelections
        .where(
          (selection) => tracksByNormalizedPath.containsKey(
            path.normalize(selection.path),
          ),
        )
        .length;
    await _ensureCacheDirectoriesReady();
    final artworkCacheDirectory = _artworkCacheDirectory;
    if (artworkCacheDirectory == null) {
      _statusMessage = 'ChiMusic could not prepare its local artwork cache.';
      notifyListeners();
      return;
    }

    final payloads = <ImportedTrackPayload>[];
    final refreshedTracksById = <String, Track>{};
    final refreshedSourcesById = <String, TrackSourceRecord>{};
    for (final selection in supportedSelections) {
      final normalizedPath = path.normalize(selection.path);
      final payload = await buildImportedTrackFromSelection(
        selection,
        artworkCacheDirectory: artworkCacheDirectory,
      );
      if (payload == null) {
        continue;
      }

      final existingTrack = tracksByNormalizedPath[normalizedPath];
      if (existingTrack != null) {
        refreshedTracksById[existingTrack.id] =
            mergeImportedTrackWithExistingTrack(
              existing: existingTrack,
              imported: payload.track,
            );
        refreshedSourcesById[existingTrack.id] = payload.source.copyWith(
          trackId: existingTrack.id,
        );
        continue;
      }

      payloads.add(payload);
    }

    final newTracks = payloads
        .map((payload) => payload.track)
        .toList(growable: false);
    final refreshedCount = refreshedTracksById.length;

    if (newTracks.isEmpty && refreshedCount == 0) {
      _statusMessage = duplicateCount > 0
          ? 'Everything you picked is already in your ChiMusic library.'
          : 'No supported audio files were found in that selection.';
      notifyListeners();
      return;
    }

    if (refreshedTracksById.isNotEmpty) {
      _replaceLibraryTracks(
        _tracks
            .map((track) => refreshedTracksById[track.id] ?? track)
            .toList(growable: false),
      );
      _trackSourcesByTrackId.addAll(refreshedSourcesById);
    }
    if (newTracks.isNotEmpty) {
      _tracks = <Track>[...newTracks, ..._tracks];
    }
    for (final payload in payloads) {
      _trackSourcesByTrackId[payload.track.id] = payload.source;
    }
    _primeLyricsStates();
    final messageParts = <String>[];
    if (newTracks.isNotEmpty) {
      messageParts.add(
        'Imported ${newTracks.length} local audio file${newTracks.length == 1 ? '' : 's'}',
      );
    }
    if (refreshedCount > 0) {
      messageParts.add(
        'refreshed $refreshedCount existing item${refreshedCount == 1 ? '' : 's'} with the latest metadata and availability',
      );
    }
    final skippedCount = duplicateCount - refreshedCount;
    if (skippedCount > 0) {
      messageParts.add(
        'skipped $skippedCount item${skippedCount == 1 ? '' : 's'} already in your library',
      );
    }
    _statusMessage = '${messageParts.join(', ')}.';

    if (_currentTrack == null && hasMusic) {
      await _loadQueue(
        allTracksCollection.tracks,
        initialIndex: 0,
        collection: allTracksCollection,
        autoplay: false,
        clearStatusMessage: false,
      );
    }

    notifyListeners();
    await _refreshOnlineState(notifyAfterCompletion: false);
    await flushSession();
    _queueSyncIfSignedIn();
  }

  Future<void> _loadQueue(
    List<Track> tracks, {
    required int initialIndex,
    required MusicCollection collection,
    required bool autoplay,
    bool clearStatusMessage = true,
    Duration startPosition = Duration.zero,
  }) async {
    if (tracks.isEmpty) {
      return;
    }

    if (_activePlaybackEventId != null) {
      _closeActivePlaybackEvent(
        reason: PlaybackEndReason.replaced,
        finalPosition: _position,
      );
    }

    final clampedIndex = initialIndex.clamp(0, tracks.length - 1);
    _queue = List<Track>.from(tracks);
    _currentCollection = collection;
    final currentTrack = _queue[clampedIndex];
    _currentTrack = currentTrack;
    _queue = _orderedQueueForCurrentContext(
      baseQueue: _queue,
      currentTrack: currentTrack,
    );
    _position = _clampedPositionForTrack(currentTrack, startPosition);
    _lastPersistedPositionBucket = _position.inSeconds ~/ 5;
    if (clearStatusMessage) {
      _statusMessage = null;
    }
    _isPreparingPlayback = true;
    _isPlaying = autoplay && !_audioEnabled;
    unawaited(loadLyricsForTrack(currentTrack));
    unawaited(_prepareWaveformForTrack(currentTrack));
    notifyListeners();

    if (!_audioEnabled || _player == null) {
      _isPreparingPlayback = false;
      if (autoplay) {
        _startPlaybackForTrack(currentTrack);
      }
      notifyListeners();
      return;
    }

    try {
      await _refreshQueueFileAccesses(_queue);
      final sources = _queue
          .map(
            (track) => AudioSource.uri(
              Uri.file(track.filePath),
              tag: _buildMediaItem(track),
            ),
          )
          .toList(growable: false);

      final player = _player;

      await player.setAudioSources(
        sources,
        initialIndex: _queue.indexWhere((track) => track.id == currentTrack.id),
        initialPosition: _position,
      );
      await player.setLoopMode(_isRepeatEnabled ? LoopMode.all : LoopMode.off);
      await player.setShuffleModeEnabled(false);

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
        if (state.processingState == ProcessingState.completed) {
          if (_activePlaybackEventId != null) {
            _closeActivePlaybackEvent(
              reason: PlaybackEndReason.completed,
              finalPosition: _currentTrack?.duration ?? _position,
            );
          }
          _isPlaying = false;
          notifyListeners();
          _persistSession();
          return;
        }

        if (!state.playing && _isPlaying) {
          _closeActivePlaybackEvent(
            reason: PlaybackEndReason.paused,
            finalPosition: _position,
          );
        } else if (state.playing && !_isPlaying && _currentTrack != null) {
          _startPlaybackForTrack(_currentTrack!);
        }
        _isPlaying = state.playing;
        notifyListeners();
        _persistSession();
      }),
    );

    _subscriptions.add(
      player.positionStream.listen((position) {
        _position = position;
        _updateActivePlaybackEventProgress(position);
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

        if (_activePlaybackEventId != null) {
          _closeActivePlaybackEvent(
            reason: PlaybackEndReason.replaced,
            finalPosition: _position,
          );
        }
        _currentTrack = nextTrack;
        unawaited(loadLyricsForTrack(nextTrack));
        unawaited(_prepareWaveformForTrack(nextTrack));
        if (_isPlaying) {
          _startPlaybackForTrack(nextTrack);
        }
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

  MediaItem _buildMediaItem(Track track) {
    final artworkUri = track.artworkUri;
    return MediaItem(
      id: track.id,
      title: track.title,
      album: track.album,
      artist: track.artist,
      genre: track.genre,
      duration: track.duration,
      artUri: artworkUri != null && path.isAbsolute(artworkUri)
          ? Uri.file(artworkUri)
          : null,
      extras: <String, dynamic>{
        'fileExtension': track.fileExtension,
        'year': track.year,
      },
    );
  }

  void _startPlaybackForTrack(Track track) {
    final activeId = _activePlaybackEventId;
    if (activeId != null) {
      final activeIndex = _playbackEvents.indexWhere(
        (event) => event.id == activeId,
      );
      if (activeIndex >= 0 &&
          _playbackEvents[activeIndex].trackId == track.id) {
        return;
      }
    }

    final now = DateTime.now();
    _rememberRecentTrack(track.id);
    final existingEntry = _playbackHistoryByTrackId[track.id];
    _playbackHistoryByTrackId[track.id] = PlaybackHistoryEntry(
      trackId: track.id,
      lastPlayedAt: now,
      lastPosition: Duration.zero,
      playCount: (existingEntry?.playCount ?? 0) + 1,
      totalListened: existingEntry?.totalListened ?? Duration.zero,
    );

    final event = PlaybackEvent(
      id: '${track.id}::${now.microsecondsSinceEpoch}',
      trackId: track.id,
      collectionId: _currentCollection?.id,
      startedAt: now,
      maxPosition: _position,
    );
    _playbackEvents.insert(0, event);
    _activePlaybackEventId = event.id;
    _activePlaybackEventStartPositions[event.id] = _position;
    _persistSession();
    unawaited(_refreshRecommendationContent());
  }

  void _updateActivePlaybackEventProgress(Duration position) {
    final activeId = _activePlaybackEventId;
    if (activeId == null) {
      return;
    }

    final eventIndex = _playbackEvents.indexWhere(
      (event) => event.id == activeId,
    );
    if (eventIndex < 0) {
      _activePlaybackEventStartPositions.remove(activeId);
      _activePlaybackEventId = null;
      return;
    }

    final event = _playbackEvents[eventIndex];
    if (position <= event.maxPosition) {
      return;
    }

    _playbackEvents[eventIndex] = event.copyWith(maxPosition: position);
  }

  void _closeActivePlaybackEvent({
    required PlaybackEndReason reason,
    Duration? finalPosition,
  }) {
    final activeId = _activePlaybackEventId;
    if (activeId == null) {
      return;
    }

    final eventIndex = _playbackEvents.indexWhere(
      (event) => event.id == activeId,
    );
    if (eventIndex < 0) {
      _activePlaybackEventStartPositions.remove(activeId);
      _activePlaybackEventId = null;
      return;
    }

    final event = _playbackEvents[eventIndex];
    final rawStartPosition =
        _activePlaybackEventStartPositions.remove(activeId) ?? Duration.zero;
    Track? track;
    for (final candidate in _tracks) {
      if (candidate.id == event.trackId) {
        track = candidate;
        break;
      }
    }
    if (track == null && _currentTrack?.id == event.trackId) {
      track = _currentTrack;
    }
    final clampedPosition = track == null
        ? (finalPosition ?? _position)
        : _clampedPositionForTrack(track, finalPosition ?? _position);
    final startPosition = track == null
        ? rawStartPosition
        : _clampedPositionForTrack(track, rawStartPosition);
    final maxPosition = clampedPosition > event.maxPosition
        ? clampedPosition
        : event.maxPosition;
    final listenedThisEvent = maxPosition > startPosition
        ? maxPosition - startPosition
        : Duration.zero;

    _playbackEvents[eventIndex] = event.copyWith(
      endedAt: DateTime.now(),
      maxPosition: maxPosition,
      endReason: reason,
    );
    _activePlaybackEventId = null;

    final existingEntry = _playbackHistoryByTrackId[event.trackId];
    if (existingEntry != null) {
      _playbackHistoryByTrackId[event.trackId] = existingEntry.copyWith(
        lastPosition: _resumePositionForTrack(track, maxPosition, reason),
        totalListened: existingEntry.totalListened + listenedThisEvent,
      );
    }
    _persistSession();
  }

  Future<void> flushSession() async {
    _syncCurrentTrackHistoryPosition(_position);
    await _persistSession();
  }

  Future<void> _persistSession() {
    final repository = _repository;
    if (repository == null) {
      return Future<void>.value();
    }

    final snapshot = MusicRepositorySnapshot(
      tracks: List<Track>.from(_tracks),
      trackSources: _trackSourcesByTrackId.values.toList(growable: false),
      playbackStats: _playbackHistoryByTrackId.values.toList(growable: false),
      playbackEvents: List<PlaybackEvent>.from(_playbackEvents),
      playbackSession: PlaybackSessionState(
        queueTrackIds: _queue.map((track) => track.id).toList(growable: false),
        currentTrackId: _currentTrack?.id,
        currentCollectionId: _currentCollection?.id,
        position: _position,
        updatedAt: DateTime.now(),
      ),
      likedTrackIds: Set<String>.from(_likedTrackIds),
      savedCollectionIds: Set<String>.from(_savedCollectionIds),
      recentTrackIds: List<String>.from(_recentTrackIds),
      recentSearches: List<String>.from(_recentSearches),
      selectedTab: _selectedTab,
      libraryFilter: _libraryFilter,
      librarySort: _librarySort,
      searchQuery: _searchQuery,
      searchMode: _searchMode,
      userProfile: _userProfile,
      aiSearchTrialsRemaining: _aiSearchTrialsRemaining,
      hasUnlockedAiUpsell: _hasUnlockedAiUpsell,
      themeMode: _themeMode,
      isShuffleEnabled: _isShuffleEnabled,
      isRepeatEnabled: _isRepeatEnabled,
    );

    _persistOperation = _persistOperation.then((_) async {
      try {
        await repository.save(snapshot);
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

  Future<void> _restoreTrackAccessAndPlayback(
    MusicSessionSnapshot snapshot,
  ) async {
    final restoreFuture = _restorePlaybackSnapshot(snapshot);
    final didBackfillBookmarks = await _backfillMissingTrackSourceBookmarks();
    await restoreFuture;

    final shouldRetryRestore =
        didBackfillBookmarks &&
        _audioEnabled &&
        _player != null &&
        (_statusMessage ==
                'Unable to restore the last playback queue in this environment.' ||
            _statusMessage ==
                'Playback queue restore failed. Your library is still available.');
    if (shouldRetryRestore) {
      _statusMessage = null;
      await _restorePlaybackSnapshot(snapshot);
    }

    if (didBackfillBookmarks) {
      await _persistSession();
    }
  }

  Future<bool> _backfillMissingTrackSourceBookmarks() async {
    final sourcesNeedingBookmarks = _trackSourcesByTrackId.entries
        .where(
          (entry) =>
              entry.value.locator.isNotEmpty &&
              (entry.value.bookmarkBase64 == null ||
                  entry.value.bookmarkBase64!.isEmpty),
        )
        .toList(growable: false);
    if (sourcesNeedingBookmarks.isEmpty) {
      return false;
    }

    final bookmarksByPath = await _appleMediaAccessChannel
        .createBookmarksByPath(
          sourcesNeedingBookmarks.map((entry) => entry.value.locator),
        );
    if (bookmarksByPath.isEmpty) {
      return false;
    }

    var changed = false;
    for (final entry in sourcesNeedingBookmarks) {
      final bookmarkBase64 = bookmarksByPath[entry.value.locator];
      if (bookmarkBase64 == null || bookmarkBase64.isEmpty) {
        continue;
      }

      _trackSourcesByTrackId[entry.key] = entry.value.copyWith(
        bookmarkBase64: bookmarkBase64,
      );
      changed = true;
    }

    return changed;
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
    final initialPosition = _clampedPositionForTrack(
      currentTrack,
      Duration(milliseconds: snapshot.positionMs),
    );

    _queue = queue;
    _currentTrack = currentTrack;
    _currentCollection = _restoreCollectionFromId(snapshot.currentCollectionId);
    _queue = _orderedQueueForCurrentContext(
      baseQueue: _queue,
      currentTrack: currentTrack,
    );
    _position = initialPosition;
    _isPlaying = false;
    _isPreparingPlayback = _audioEnabled && _player != null;
    _lastPersistedPositionBucket = initialPosition.inSeconds ~/ 5;
    _syncCurrentTrackHistoryPosition(initialPosition);
    unawaited(loadLyricsForTrack(currentTrack));
    unawaited(_prepareWaveformForTrack(currentTrack));

    if (!_audioEnabled || _player == null) {
      _isPreparingPlayback = false;
      return;
    }

    try {
      await _refreshQueueFileAccesses(queue);
      final restoredQueue = List<Track>.from(_queue);
      final restoredCurrentTrack = _currentTrack;
      if (restoredQueue.isEmpty || restoredCurrentTrack == null) {
        _isPreparingPlayback = false;
        return;
      }

      final sources = restoredQueue
          .map((track) => AudioSource.uri(Uri.file(track.filePath), tag: track))
          .toList(growable: false);

      final player = _player;

      await player.setAudioSources(
        sources,
        initialIndex: max(
          0,
          restoredQueue.indexWhere(
            (track) => track.id == restoredCurrentTrack.id,
          ),
        ),
        initialPosition: _clampedPositionForTrack(
          restoredCurrentTrack,
          _position,
        ),
      );
      await player.setLoopMode(_isRepeatEnabled ? LoopMode.all : LoopMode.off);
      await player.setShuffleModeEnabled(false);
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

    return collectionById(collectionId);
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

  Duration _resumePositionForTrack(
    Track? track,
    Duration position,
    PlaybackEndReason reason,
  ) {
    if (track == null) {
      return position;
    }

    final clamped = _clampedPositionForTrack(track, position);
    final duration = track.duration;
    if (duration == null) {
      return clamped;
    }

    final nearlyComplete = duration - clamped <= const Duration(seconds: 3);
    if (reason == PlaybackEndReason.completed || nearlyComplete) {
      return Duration.zero;
    }

    return clamped;
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
      totalListened: existingEntry?.totalListened ?? Duration.zero,
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

  void _applyRepositorySnapshot(MusicRepositorySnapshot snapshot) {
    _trackSourcesByTrackId
      ..clear()
      ..addEntries(
        snapshot.trackSources.map((source) => MapEntry(source.trackId, source)),
      );
    _activePlaybackEventStartPositions.clear();
    final restoredAt = snapshot.playbackSession.updatedAt ?? DateTime.now();
    _playbackEvents = snapshot.playbackEvents
        .map(
          (event) => event.isOpen
              ? event.copyWith(
                  endedAt: restoredAt,
                  endReason: PlaybackEndReason.stopped,
                )
              : event,
        )
        .toList();
    _activePlaybackEventId = null;

    _applySessionSnapshot(
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

  void _applySessionSnapshot(MusicSessionSnapshot snapshot) {
    final tracks = snapshot.tracks
        .where((track) => track.filePath.isNotEmpty)
        .toList(growable: false);
    final trackIds = tracks.map((track) => track.id).toSet();

    _tracks = tracks;
    _trackSourcesByTrackId.removeWhere(
      (trackId, _) => !trackIds.contains(trackId),
    );
    for (final track in _tracks) {
      _trackSourcesByTrackId.putIfAbsent(
        track.id,
        () => TrackSourceRecord(
          trackId: track.id,
          platform: 'local',
          locator: track.filePath,
        ),
      );
    }
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
      ..addAll(snapshot.recentSearches.take(10));
    _selectedTab = snapshot.selectedTab;
    _libraryFilter = snapshot.libraryFilter;
    _librarySort = snapshot.librarySort;
    _searchQuery = snapshot.searchQuery;
    _searchMode = snapshot.searchMode;
    _userProfile = snapshot.userProfile;
    _aiSearchTrialsRemaining = snapshot.aiSearchTrialsRemaining;
    _hasUnlockedAiUpsell = snapshot.hasUnlockedAiUpsell;
    _themeMode = snapshot.themeMode;
    _isShuffleEnabled = snapshot.isShuffleEnabled;
    _isRepeatEnabled = snapshot.isRepeatEnabled;
    _savedCollectionIds.removeWhere(
      (collectionId) => collectionById(collectionId) == null,
    );
    _waveformsByTrackId.removeWhere(
      (trackId, _) => !trackIds.contains(trackId),
    );
    _primeLyricsStates();
    unawaited(_restoreTrackAccessAndPlayback(snapshot));
  }

  SyncState _buildDefaultSyncState() {
    final user = _userProfile;
    if (user == null) {
      return const SyncState();
    }

    return const SyncState(
      phase: SyncPhase.idle,
      message: 'Signed in. Sync is ready when you want it.',
    );
  }

  void _primeLyricsStates() {
    final next = <String, LyricsState>{};
    for (final track in _tracks) {
      next[track.id] =
          _lyricsByTrackId[track.id] ??
          LyricsState(
            status: track.lyricsAvailability == LyricsAvailability.available
                ? LyricsStatus.idle
                : LyricsStatus.unavailable,
            title: track.lyricsAvailability == LyricsAvailability.available
                ? 'Lyrics ready to load'
                : 'No synced lyrics yet',
            source: 'ChiMusic Metadata',
          );
    }
    _lyricsByTrackId
      ..clear()
      ..addAll(next);
  }

  Future<void> _refreshOnlineState({bool notifyAfterCompletion = true}) async {
    if (_tracks.isEmpty) {
      _smartPlaylists = <SmartPlaylist>[];
      _recommendationCards = <RecommendationCard>[];
      _aiSearchResults = <Track>[];
      _aiSearchSummary = null;
      _primeLyricsStates();
      if (notifyAfterCompletion) {
        _notifyIfAlive();
      }
      return;
    }

    _isEnhancingLibrary = true;
    if (notifyAfterCompletion) {
      _notifyIfAlive();
    }

    final enrichedTracks = await _metadataEnrichmentService.enrichTracks(
      _tracks,
    );
    _replaceLibraryTracks(enrichedTracks);
    _primeLyricsStates();
    await _refreshRecommendationContent();
    _isEnhancingLibrary = false;
    if (notifyAfterCompletion) {
      _notifyIfAlive();
    }
    _persistSession();
  }

  Future<void> _refreshRecommendationContent() async {
    if (_tracks.isEmpty) {
      _smartPlaylists = <SmartPlaylist>[];
      _recommendationCards = <RecommendationCard>[];
      return;
    }

    _smartPlaylists = await _recommendationService.buildSmartPlaylists(
      tracks: _tracks,
      recentPlayedTracks: recentPlayedTracks,
      favoriteTracks: favoriteTracks,
    );
    _recommendationCards = await _recommendationService
        .buildRecommendationCards(
          tracks: _tracks,
          recentPlayedTracks: recentPlayedTracks,
          favoriteTracks: favoriteTracks,
        );
    _notifyIfAlive();
  }

  void _replaceLibraryTracks(List<Track> tracks) {
    final tracksById = {for (final track in tracks) track.id: track};
    _tracks = tracks;
    _queue = _queue
        .map((track) => tracksById[track.id] ?? track)
        .where((track) => tracksById.containsKey(track.id))
        .toList(growable: false);
    if (_currentTrack case final currentTrack?) {
      _currentTrack = tracksById[currentTrack.id] ?? currentTrack;
    }
    if (_currentCollection case final currentCollection?) {
      _currentCollection =
          _restoreCollectionFromId(currentCollection.id) ?? currentCollection;
    }
  }

  Future<void> _restoreCloudSnapshotIfAvailable({
    required bool applyRemoteWhenLibraryEmpty,
  }) async {
    final user = _userProfile;
    if (user == null) {
      _syncState = _buildDefaultSyncState();
      return;
    }

    final snapshot = await _cloudSyncService.restoreSnapshot(user);
    if (snapshot == null) {
      _syncState = _buildDefaultSyncState();
      return;
    }

    _syncState = SyncState(
      phase: SyncPhase.synced,
      message: 'Cloud snapshot found for this account.',
      lastSyncedAt: snapshot.syncedAt,
    );

    if (!applyRemoteWhenLibraryEmpty || _tracks.isNotEmpty) {
      return;
    }

    final localSnapshot = MusicSessionSnapshot(
      tracks: snapshot.tracks,
      playbackHistory: snapshot.playbackHistory,
      likedTrackIds: snapshot.likedTrackIds,
      savedCollectionIds: snapshot.savedCollectionIds,
      recentTrackIds: snapshot.recentTrackIds,
      recentSearches: snapshot.recentSearches,
      queueTrackIds: snapshot.queueTrackIds,
      currentTrackId: snapshot.currentTrackId,
      currentCollectionId: snapshot.currentCollectionId,
      positionMs: snapshot.positionMs,
      userProfile: _userProfile,
      searchMode: _searchMode,
      libraryFilter: _libraryFilter,
      librarySort: _librarySort,
      selectedTab: _selectedTab,
      searchQuery: _searchQuery,
      aiSearchTrialsRemaining: _aiSearchTrialsRemaining,
      hasUnlockedAiUpsell: _hasUnlockedAiUpsell,
      themeMode: _themeMode,
      isShuffleEnabled: _isShuffleEnabled,
      isRepeatEnabled: _isRepeatEnabled,
    );
    _applySessionSnapshot(localSnapshot);
    await _refreshOnlineState(notifyAfterCompletion: false);
    _statusMessage = 'Restored your synced ChiMusic library snapshot.';
  }

  void _markLibrarySynced(DateTime? timestamp) {
    if (timestamp == null || _tracks.isEmpty) {
      return;
    }

    _tracks = _tracks
        .map((track) => track.copyWith(lastSyncedAt: timestamp))
        .toList(growable: false);
    _queue = _queue
        .map((track) => track.copyWith(lastSyncedAt: timestamp))
        .toList(growable: false);
    if (_currentTrack case final currentTrack?) {
      _currentTrack = currentTrack.copyWith(lastSyncedAt: timestamp);
    }
    if (_currentCollection case final currentCollection?) {
      _currentCollection =
          _restoreCollectionFromId(currentCollection.id) ?? currentCollection;
    }
  }

  void _queueSyncIfSignedIn() {
    if (!isSignedIn) {
      return;
    }
    unawaited(syncLibraryNow(silent: true));
  }

  void _notifyIfAlive() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_activePlaybackEventId != null) {
      _closeActivePlaybackEvent(
        reason: PlaybackEndReason.stopped,
        finalPosition: _position,
      );
    }
    unawaited(flushSession());
    unawaited(_releaseQueueFileAccesses());
    unawaited(_repository?.close() ?? Future<void>.value());
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player?.dispose();
    super.dispose();
  }
}
