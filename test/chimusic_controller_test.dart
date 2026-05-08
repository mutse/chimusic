import 'dart:async';

import 'package:chimusic/data/music_session_store.dart';
import 'package:chimusic/models/music_models.dart';
import 'package:chimusic/state/chimusic_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MusicAppController', () {
    test(
      'search ranking favors title prefix matches and stores recent searches',
      () {
        final voyagerTrack = _track(
          folderPath: '/music/discovery',
          title: 'Voyager',
          artist: 'Daft Punk',
          album: 'Discovery',
          duration: const Duration(minutes: 3, seconds: 47),
          importedAt: DateTime(2026, 5, 6, 9),
        );
        final artistMatchTrack = _track(
          folderPath: '/music/midnight',
          title: 'Midnight Echo',
          artist: 'Voyager Club',
          album: 'Midnight',
          duration: const Duration(minutes: 4, seconds: 5),
          importedAt: DateTime(2026, 5, 6, 10),
        );
        final controller = MusicAppController(
          enableAudio: false,
          initialTracks: [voyagerTrack, artistMatchTrack],
        );
        addTearDown(controller.dispose);

        controller.updateSearchQuery('voy');

        expect(controller.searchTrackResults.first.id, voyagerTrack.id);

        controller.submitSearch();

        expect(controller.recentSearches.first, 'voy');
        expect(controller.trendingSearches, contains('voy'));

        controller.applySearchSuggestion('Discovery');

        expect(controller.searchQuery, 'Discovery');
        expect(controller.recentSearches.first, 'Discovery');
      },
    );

    test(
      'library favorites filter and length sort expose saved content cleanly',
      () {
        final shortFavorite = _track(
          folderPath: '/music/morning',
          title: 'Sunrise',
          artist: 'The Early Set',
          album: 'Morning Glow',
          duration: const Duration(minutes: 2, seconds: 40),
          importedAt: DateTime(2026, 5, 6, 8),
        );
        final longFavorite = _track(
          folderPath: '/music/night',
          title: 'After Hours',
          artist: 'Night Shift',
          album: 'Late Drive',
          duration: const Duration(minutes: 5, seconds: 20),
          importedAt: DateTime(2026, 5, 6, 11),
        );
        final regularTrack = _track(
          folderPath: '/music/night',
          title: 'Low Lights',
          artist: 'Night Shift',
          album: 'Late Drive',
          duration: const Duration(minutes: 3, seconds: 30),
          importedAt: DateTime(2026, 5, 6, 12),
        );
        final controller = MusicAppController(
          enableAudio: false,
          initialTracks: [shortFavorite, longFavorite, regularTrack],
          initialLikedTrackIds: {shortFavorite.id, longFavorite.id},
          initialSavedCollectionIds: {'/music/night'},
        );
        addTearDown(controller.dispose);

        controller.openLibraryFilter(LibraryFilter.favorites);
        controller.setLibrarySort(LibrarySort.length);

        expect(controller.selectedTab, MusicTab.library);
        expect(controller.libraryFilter, LibraryFilter.favorites);
        expect(
          controller.filteredLibraryTracks.map((track) => track.id).toList(),
          [longFavorite.id, shortFavorite.id],
        );
        expect(controller.filteredLibraryCollections.single.id, '/music/night');
      },
    );

    test('playFavoriteTracks builds a liked songs queue', () async {
      final firstFavorite = _track(
        folderPath: '/music/favorites',
        title: 'Blue Horizon',
        artist: 'North Coast',
        album: 'Sea Glass',
        duration: const Duration(minutes: 4),
        importedAt: DateTime(2026, 5, 5, 20),
      );
      final secondFavorite = _track(
        folderPath: '/music/favorites',
        title: 'Signals',
        artist: 'North Coast',
        album: 'Sea Glass',
        duration: const Duration(minutes: 3, seconds: 12),
        importedAt: DateTime(2026, 5, 5, 21),
      );
      final controller = MusicAppController(
        enableAudio: false,
        initialTracks: [firstFavorite, secondFavorite],
        initialLikedTrackIds: {firstFavorite.id, secondFavorite.id},
      );
      addTearDown(controller.dispose);

      await controller.playFavoriteTracks();

      expect(controller.currentCollection?.title, 'Liked Songs');
      expect(controller.currentTrack?.id, firstFavorite.id);
      expect(controller.queue.map((track) => track.id).toList(), [
        firstFavorite.id,
        secondFavorite.id,
      ]);
      expect(controller.isPlaying, isTrue);
    });

    test('openSearch switches tabs and keeps the new query', () {
      final controller = MusicAppController(enableAudio: false);
      addTearDown(controller.dispose);

      controller.openSearch('Daft Punk');

      expect(controller.selectedTab, MusicTab.search);
      expect(controller.searchQuery, 'Daft Punk');
    });

    test('clearRecentSearches removes stored terms', () {
      final controller = MusicAppController(
        enableAudio: false,
        initialRecentSearches: const ['Voyager', 'Discovery'],
      );
      addTearDown(controller.dispose);

      controller.clearRecentSearches();

      expect(controller.recentSearches, isEmpty);
    });

    test(
      'playImportedTracks opens an all-tracks queue from the library',
      () async {
        final secondTrack = _track(
          folderPath: '/music/late',
          title: 'Signals',
          artist: 'North Coast',
          album: 'Late Set',
          duration: const Duration(minutes: 3, seconds: 12),
          importedAt: DateTime(2026, 5, 6, 11),
        );
        final firstTrack = _track(
          folderPath: '/music/late',
          title: 'All We Have',
          artist: 'North Coast',
          album: 'Late Set',
          duration: const Duration(minutes: 4, seconds: 4),
          importedAt: DateTime(2026, 5, 6, 10),
        );
        final controller = MusicAppController(
          enableAudio: false,
          initialTracks: [secondTrack, firstTrack],
        );
        addTearDown(controller.dispose);

        await controller.playImportedTracks();

        expect(controller.currentCollection?.id, 'all_tracks');
        expect(controller.currentTrack?.id, firstTrack.id);
        expect(controller.queue.map((track) => track.id).toList(), [
          firstTrack.id,
          secondTrack.id,
        ]);
        expect(controller.isPlaying, isTrue);
      },
    );

    test(
      'restoreSession rehydrates imported tracks, favorites, and view state',
      () async {
        final track = _track(
          folderPath: '/music/archive',
          title: 'Voyager',
          artist: 'Daft Punk',
          album: 'Archive',
          duration: const Duration(minutes: 3, seconds: 44),
          importedAt: DateTime(2026, 5, 5, 9),
        );
        final store = _FakeSessionStore(
          snapshot: MusicSessionSnapshot(
            tracks: [track],
            likedTrackIds: {track.id},
            savedCollectionIds: {track.folderPath},
            recentTrackIds: [track.id],
            recentSearches: const ['Archive'],
            selectedTab: MusicTab.library,
            libraryFilter: LibraryFilter.favorites,
            librarySort: LibrarySort.length,
            searchQuery: 'Archive',
          ),
        );
        final controller = MusicAppController(
          enableAudio: false,
          sessionStore: store,
        );
        addTearDown(controller.dispose);

        await controller.restoreSession();

        expect(controller.importedTrackCount, 1);
        expect(controller.likedTracksCount, 1);
        expect(controller.savedCollectionCount, 1);
        expect(controller.selectedTab, MusicTab.library);
        expect(controller.libraryFilter, LibraryFilter.favorites);
        expect(controller.librarySort, LibrarySort.length);
        expect(controller.searchQuery, 'Archive');
        expect(controller.recentSearches, ['Archive']);
      },
    );

    test(
      'restoreSession rehydrates the playback queue and saved progress',
      () async {
        final firstTrack = _track(
          folderPath: '/music/archive',
          title: 'Voyager',
          artist: 'Daft Punk',
          album: 'Archive',
          duration: const Duration(minutes: 3, seconds: 44),
          importedAt: DateTime(2026, 5, 5, 9),
        );
        final secondTrack = _track(
          folderPath: '/music/archive',
          title: 'Digital Love',
          artist: 'Daft Punk',
          album: 'Archive',
          duration: const Duration(minutes: 4, seconds: 58),
          importedAt: DateTime(2026, 5, 5, 10),
        );
        final store = _FakeSessionStore(
          snapshot: MusicSessionSnapshot(
            tracks: [firstTrack, secondTrack],
            queueTrackIds: [firstTrack.id, secondTrack.id],
            currentTrackId: secondTrack.id,
            currentCollectionId: firstTrack.folderPath,
            positionMs: 91000,
          ),
        );
        final controller = MusicAppController(
          enableAudio: false,
          sessionStore: store,
        );
        addTearDown(controller.dispose);

        await controller.restoreSession();

        expect(controller.queue.map((track) => track.id).toList(), [
          firstTrack.id,
          secondTrack.id,
        ]);
        expect(controller.currentTrack?.id, secondTrack.id);
        expect(controller.currentCollection?.id, firstTrack.folderPath);
        expect(controller.position, const Duration(seconds: 91));
        expect(controller.isPlaying, isFalse);
      },
    );

    test(
      'state changes persist through the configured session store',
      () async {
        final track = _track(
          folderPath: '/music/ocean',
          title: 'Blue Horizon',
          artist: 'North Coast',
          album: 'Sea Glass',
          duration: const Duration(minutes: 4, seconds: 8),
          importedAt: DateTime(2026, 5, 6, 15),
        );
        final store = _FakeSessionStore();
        final controller = MusicAppController(
          enableAudio: false,
          sessionStore: store,
          initialTracks: [track],
        );
        addTearDown(controller.dispose);

        controller.toggleLikedTrack(track.id);
        controller.toggleSavedCollection(track.folderPath);
        controller.openSearch('Sea Glass');

        await Future<void>.delayed(const Duration(milliseconds: 1));

        final snapshot = store.lastSaved;
        expect(snapshot, isNotNull);
        expect(snapshot!.tracks.single.id, track.id);
        expect(snapshot.likedTrackIds, {track.id});
        expect(snapshot.savedCollectionIds, {track.folderPath});
        expect(snapshot.selectedTab, MusicTab.search);
        expect(snapshot.searchQuery, 'Sea Glass');
      },
    );

    test(
      'playback queue and progress persist through the configured session store',
      () async {
        final track = _track(
          folderPath: '/music/ocean',
          title: 'Blue Horizon',
          artist: 'North Coast',
          album: 'Sea Glass',
          duration: const Duration(minutes: 4),
          importedAt: DateTime(2026, 5, 6, 15),
        );
        final store = _FakeSessionStore();
        final controller = MusicAppController(
          enableAudio: false,
          sessionStore: store,
          initialTracks: [track],
        );
        addTearDown(controller.dispose);

        await controller.playImportedTracks();
        await controller.seekToFraction(0.5);
        await Future<void>.delayed(const Duration(milliseconds: 1));

        final snapshot = store.lastSaved;
        expect(snapshot, isNotNull);
        expect(snapshot!.queueTrackIds, [track.id]);
        expect(snapshot.currentTrackId, track.id);
        expect(snapshot.currentCollectionId, 'all_tracks');
        expect(snapshot.positionMs, 120000);
      },
    );

    test('flushSession waits for pending persistence to finish', () async {
      final track = _track(
        folderPath: '/music/ocean',
        title: 'Blue Horizon',
        artist: 'North Coast',
        album: 'Sea Glass',
        duration: const Duration(minutes: 4),
        importedAt: DateTime(2026, 5, 6, 15),
      );
      final store = _BlockingSessionStore();
      final controller = MusicAppController(
        enableAudio: false,
        sessionStore: store,
        initialTracks: [track],
      );
      addTearDown(controller.dispose);

      controller.toggleLikedTrack(track.id);
      await store.firstSaveStarted.future;

      var completed = false;
      final flushFuture = controller.flushSession().then((_) {
        completed = true;
      });
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);

      store.release();
      await flushFuture;

      expect(store.saveCallCount, 2);
      expect(store.lastSaved?.likedTrackIds, {track.id});
    });

    test(
      'removeCollectionFromLibrary removes only that collection from the session',
      () async {
        final firstTrack = _track(
          folderPath: '/music/alpha',
          title: 'Alpha One',
          artist: 'Signal Bloom',
          album: 'Alpha',
          duration: const Duration(minutes: 4, seconds: 15),
          importedAt: DateTime(2026, 5, 6, 7),
        );
        final secondTrack = _track(
          folderPath: '/music/alpha',
          title: 'Alpha Two',
          artist: 'Signal Bloom',
          album: 'Alpha',
          duration: const Duration(minutes: 4, seconds: 40),
          importedAt: DateTime(2026, 5, 6, 8),
        );
        final keepTrack = _track(
          folderPath: '/music/beta',
          title: 'Beta One',
          artist: 'Night Ferry',
          album: 'Beta',
          duration: const Duration(minutes: 3, seconds: 20),
          importedAt: DateTime(2026, 5, 6, 9),
        );
        final controller = MusicAppController(
          enableAudio: false,
          initialTracks: [firstTrack, secondTrack, keepTrack],
          initialSavedCollectionIds: {'/music/alpha'},
        );
        addTearDown(controller.dispose);

        await controller.removeCollectionFromLibrary('/music/alpha');

        expect(controller.importedTracks.map((track) => track.id).toList(), [
          keepTrack.id,
        ]);
        expect(controller.savedCollections, isEmpty);
        expect(
          controller.statusMessage,
          contains('Original files were not deleted'),
        );
      },
    );

    test(
      'clearLibrarySession resets imported data without touching device files',
      () async {
        final track = _track(
          folderPath: '/music/favorites',
          title: 'Clear Me',
          artist: 'Soft Static',
          album: 'Archive',
          duration: const Duration(minutes: 3),
          importedAt: DateTime(2026, 5, 6, 13),
        );
        final controller = MusicAppController(
          enableAudio: false,
          initialTracks: [track],
          initialLikedTrackIds: {track.id},
          initialSavedCollectionIds: {track.folderPath},
          initialRecentSearches: const ['Archive'],
        );
        addTearDown(controller.dispose);

        await controller.clearLibrarySession();

        expect(controller.importedTracks, isEmpty);
        expect(controller.recentSearches, isEmpty);
        expect(controller.likedTracksCount, 0);
        expect(controller.collectionCount, 0);
        expect(
          controller.statusMessage,
          'Cleared imported items from ChiMusic. Original audio files were not deleted.',
        );
      },
    );
  });
}

Track _track({
  required String folderPath,
  required String title,
  required String artist,
  required String album,
  required Duration duration,
  required DateTime importedAt,
}) {
  final filePath = '$folderPath/$artist - $title.mp3';

  return Track(
    id: filePath,
    filePath: filePath,
    fileName: '$artist - $title.mp3',
    folderPath: folderPath,
    title: title,
    artist: artist,
    album: album,
    palette: const [Color(0xFF1ED760), Color(0xFF0F5132), Color(0xFF111318)],
    importedAt: importedAt,
    duration: duration,
    fileExtension: 'mp3',
  );
}

class _FakeSessionStore implements MusicSessionStore {
  _FakeSessionStore({this.snapshot = const MusicSessionSnapshot()});

  final MusicSessionSnapshot snapshot;
  MusicSessionSnapshot? lastSaved;

  @override
  Future<MusicSessionSnapshot> load() async => snapshot;

  @override
  Future<void> save(MusicSessionSnapshot snapshot) async {
    lastSaved = snapshot;
  }
}

class _BlockingSessionStore implements MusicSessionStore {
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<void> _release = Completer<void>();
  MusicSessionSnapshot? lastSaved;
  int saveCallCount = 0;

  @override
  Future<MusicSessionSnapshot> load() async => const MusicSessionSnapshot();

  @override
  Future<void> save(MusicSessionSnapshot snapshot) async {
    saveCallCount += 1;
    lastSaved = snapshot;
    if (!firstSaveStarted.isCompleted) {
      firstSaveStarted.complete();
    }
    await _release.future;
  }

  void release() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }
}
