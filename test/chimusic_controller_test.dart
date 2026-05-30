import 'dart:async';

import 'package:chimusic/data/music_repository.dart';
import 'package:chimusic/data/music_session_store.dart';
import 'package:chimusic/models/music_models.dart';
import 'package:chimusic/state/chimusic_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

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

    test('playback history stores resume position and play counts', () async {
      final track = _track(
        folderPath: '/music/history',
        title: 'Replay',
        artist: 'North Coast',
        album: 'Sea Glass',
        duration: const Duration(minutes: 4),
        importedAt: DateTime(2026, 5, 6, 16),
      );
      final controller = MusicAppController(
        enableAudio: false,
        initialTracks: [track],
      );
      addTearDown(controller.dispose);

      await controller.playImportedTracks();
      await controller.seekToFraction(0.25);

      final entry = controller.playbackHistoryEntryForTrack(track.id);
      expect(controller.playbackHistoryTracks.single.id, track.id);
      expect(entry, isNotNull);
      expect(entry!.playCount, 1);
      expect(entry.lastPosition, const Duration(minutes: 1));
    });

    test(
      'resume playback adds only newly listened time to total history',
      () async {
        final track = _track(
          folderPath: '/music/history',
          title: 'Replay',
          artist: 'North Coast',
          album: 'Sea Glass',
          duration: const Duration(minutes: 4),
          importedAt: DateTime(2026, 5, 6, 16),
        );
        final controller = MusicAppController(
          enableAudio: false,
          initialTracks: [track],
        );
        addTearDown(controller.dispose);

        await controller.playImportedTracks();
        await controller.seekToFraction(0.5);
        await controller.togglePlayPause();

        await controller.resumeTrack(track);
        await controller.seekToFraction(0.75);
        await controller.togglePlayPause();

        final entry = controller.playbackHistoryEntryForTrack(track.id);
        expect(entry, isNotNull);
        expect(entry!.playCount, 2);
        expect(entry.lastPosition, const Duration(minutes: 3));
        expect(entry.totalListened, const Duration(minutes: 3));
      },
    );

    test('restoreSession rehydrates saved playback history details', () async {
      final track = _track(
        folderPath: '/music/history',
        title: 'Replay',
        artist: 'North Coast',
        album: 'Sea Glass',
        duration: const Duration(minutes: 4),
        importedAt: DateTime(2026, 5, 6, 16),
      );
      final entry = PlaybackHistoryEntry(
        trackId: track.id,
        lastPlayedAt: DateTime(2026, 5, 7, 10),
        lastPosition: const Duration(minutes: 2, seconds: 5),
        playCount: 3,
      );
      final store = _FakeSessionStore(
        snapshot: MusicSessionSnapshot(
          tracks: [track],
          playbackHistory: [entry],
          recentTrackIds: [track.id],
        ),
      );
      final controller = MusicAppController(
        enableAudio: false,
        sessionStore: store,
      );
      addTearDown(controller.dispose);

      await controller.restoreSession();

      final restoredEntry = controller.playbackHistoryEntryForTrack(track.id);
      expect(controller.playbackHistoryCount, 1);
      expect(controller.totalPlayCount, 3);
      expect(controller.recentPlayedTracks.single.id, track.id);
      expect(restoredEntry, isNotNull);
      expect(restoredEntry!.lastPosition, entry.lastPosition);
      expect(restoredEntry.playCount, entry.playCount);
    });

    test(
      'recent session groups, resume tracks, and most played tracks derive from persisted playback data',
      () {
        final resumeTrack = _track(
          folderPath: '/music/history',
          title: 'Resume Me',
          artist: 'North Coast',
          album: 'Sea Glass',
          duration: const Duration(minutes: 4),
          importedAt: DateTime(2026, 5, 6, 16),
        );
        final mostPlayedTrack = _track(
          folderPath: '/music/history',
          title: 'Looped',
          artist: 'North Coast',
          album: 'Sea Glass',
          duration: const Duration(minutes: 5),
          importedAt: DateTime(2026, 5, 6, 17),
        );
        final supportingTrack = _track(
          folderPath: '/music/history',
          title: 'Side Street',
          artist: 'North Coast',
          album: 'Sea Glass',
          duration: const Duration(minutes: 3, seconds: 20),
          importedAt: DateTime(2026, 5, 6, 18),
        );
        final controller = MusicAppController(
          enableAudio: false,
          initialTracks: [resumeTrack, mostPlayedTrack, supportingTrack],
          initialPlaybackHistory: [
            PlaybackHistoryEntry(
              trackId: resumeTrack.id,
              lastPlayedAt: DateTime(2026, 5, 8, 10),
              lastPosition: const Duration(minutes: 1, seconds: 32),
              playCount: 2,
              totalListened: const Duration(minutes: 4, seconds: 18),
            ),
            PlaybackHistoryEntry(
              trackId: mostPlayedTrack.id,
              lastPlayedAt: DateTime(2026, 5, 8, 8),
              playCount: 6,
              totalListened: const Duration(minutes: 18),
            ),
            PlaybackHistoryEntry(
              trackId: supportingTrack.id,
              lastPlayedAt: DateTime(2026, 5, 7, 21),
              playCount: 1,
              totalListened: const Duration(minutes: 2),
            ),
          ],
          initialPlaybackEvents: [
            PlaybackEvent(
              id: 'evt-1',
              trackId: resumeTrack.id,
              startedAt: DateTime(2026, 5, 8, 10),
              endedAt: DateTime(2026, 5, 8, 10, 2),
              maxPosition: const Duration(minutes: 1, seconds: 32),
              endReason: PlaybackEndReason.paused,
              collectionId: '/music/history',
            ),
            PlaybackEvent(
              id: 'evt-2',
              trackId: mostPlayedTrack.id,
              startedAt: DateTime(2026, 5, 8, 8),
              endedAt: DateTime(2026, 5, 8, 8, 5),
              maxPosition: const Duration(minutes: 5),
              endReason: PlaybackEndReason.completed,
              collectionId: '/music/history',
            ),
            PlaybackEvent(
              id: 'evt-3',
              trackId: supportingTrack.id,
              startedAt: DateTime(2026, 5, 7, 21),
              endedAt: DateTime(2026, 5, 7, 21, 2),
              maxPosition: const Duration(minutes: 2),
              endReason: PlaybackEndReason.stopped,
              collectionId: '/music/history',
            ),
          ],
        );
        addTearDown(controller.dispose);

        expect(controller.resumeTracks.map((track) => track.id), [
          resumeTrack.id,
        ]);
        expect(controller.continueListeningTracks.first.id, resumeTrack.id);
        expect(controller.mostPlayedTracks.first.id, mostPlayedTrack.id);
        expect(controller.playbackEventsForTrack(resumeTrack.id), hasLength(1));
        expect(controller.recentSessionGroups, hasLength(2));
        expect(controller.recentSessionGroups.first.events, hasLength(2));
      },
    );

    test(
      'restoreSession closes stale open events so playback can start a fresh event',
      () async {
        final track = _track(
          folderPath: '/music/history',
          title: 'Resume Me',
          artist: 'North Coast',
          album: 'Sea Glass',
          duration: const Duration(minutes: 4),
          importedAt: DateTime(2026, 5, 6, 16),
        );
        final repository = InMemoryMusicRepository(
          MusicRepositorySnapshot(
            tracks: [track],
            playbackStats: [
              PlaybackHistoryEntry(
                trackId: track.id,
                lastPlayedAt: DateTime(2026, 5, 8, 10),
                lastPosition: const Duration(minutes: 2),
                playCount: 1,
                totalListened: const Duration(minutes: 2),
              ),
            ],
            playbackEvents: [
              PlaybackEvent(
                id: 'open-event',
                trackId: track.id,
                startedAt: DateTime(2026, 5, 8, 10),
                maxPosition: const Duration(minutes: 2),
              ),
            ],
            playbackSession: PlaybackSessionState(
              queueTrackIds: [track.id],
              currentTrackId: track.id,
              currentCollectionId: 'all_tracks',
              position: const Duration(minutes: 2),
              updatedAt: DateTime(2026, 5, 8, 10, 2),
            ),
          ),
        );
        final controller = MusicAppController(
          enableAudio: false,
          repository: repository,
        );
        addTearDown(controller.dispose);

        await controller.restoreSession();

        expect(
          controller.playbackEvents.single.endReason,
          PlaybackEndReason.stopped,
        );

        await controller.togglePlayPause();

        expect(controller.isPlaying, isTrue);
        expect(controller.playbackEvents.first.isOpen, isTrue);
        expect(controller.playbackHistoryEntryForTrack(track.id)?.playCount, 2);
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
        expect(snapshot.playbackHistory.single.trackId, track.id);
        expect(
          snapshot.playbackHistory.single.lastPosition,
          const Duration(minutes: 2),
        );
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

    test('dispose triggers one final session flush', () async {
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

      controller.toggleLikedTrack(track.id);
      await store.firstSaveStarted.future;

      controller.dispose();
      await Future<void>.delayed(Duration.zero);

      store.release();
      await Future<void>.delayed(Duration.zero);

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

    test(
      'clearPlaybackHistory removes saved history but keeps the library',
      () {
        final track = _track(
          folderPath: '/music/history',
          title: 'Replay',
          artist: 'North Coast',
          album: 'Sea Glass',
          duration: const Duration(minutes: 4),
          importedAt: DateTime(2026, 5, 6, 16),
        );
        final controller = MusicAppController(
          enableAudio: false,
          initialTracks: [track],
          initialPlaybackHistory: [
            PlaybackHistoryEntry(
              trackId: track.id,
              lastPlayedAt: DateTime(2026, 5, 7, 10),
              lastPosition: const Duration(minutes: 1),
              playCount: 2,
            ),
          ],
          initialRecentTrackIds: [track.id],
        );
        addTearDown(controller.dispose);

        controller.clearPlaybackHistory();

        expect(controller.importedTrackCount, 1);
        expect(controller.playbackHistoryCount, 0);
        expect(controller.totalPlayCount, 0);
        expect(controller.recentPlayedTracks, isEmpty);
      },
    );

    test(
      'ai search uses free trials and surfaces intent-based matches',
      () async {
        final favoriteTrack = _track(
          folderPath: '/music/midnight',
          title: 'Night Drive',
          artist: 'Signal Bloom',
          album: 'After Hours',
          duration: const Duration(minutes: 4, seconds: 10),
          importedAt: DateTime(2026, 5, 6, 21),
        );
        final otherTrack = _track(
          folderPath: '/music/daylight',
          title: 'Morning Tape',
          artist: 'Signal Bloom',
          album: 'Daylight',
          duration: const Duration(minutes: 3, seconds: 18),
          importedAt: DateTime(2026, 5, 6, 9),
        );
        final controller = MusicAppController(
          enableAudio: false,
          initialTracks: [favoriteTrack, otherTrack],
          initialLikedTrackIds: {favoriteTrack.id},
        );
        addTearDown(controller.dispose);

        controller.setSearchMode(SearchMode.ai);
        controller.updateSearchQuery('favorite');
        await controller.runAiSearch();

        expect(controller.aiSearchResults.first.id, favoriteTrack.id);
        expect(controller.aiSearchTrialsRemaining, 1);
        expect(controller.shouldShowAiUpsell, isTrue);
      },
    );

    test('upgradeToPro unlocks unlimited AI access', () async {
      final controller = MusicAppController(enableAudio: false);
      addTearDown(controller.dispose);

      await controller.upgradeToPro();

      expect(controller.isSignedIn, isTrue);
      expect(controller.hasPro, isTrue);
      expect(controller.membershipTier, MembershipTier.pro);
      expect(controller.canUseAiSearch, isTrue);
    });

    test(
      'albums filter exposes album collections generated from local files',
      () {
        final firstAlbumTrack = _track(
          folderPath: '/music/coast',
          title: 'Blue Horizon',
          artist: 'North Coast',
          album: 'Sea Glass',
          duration: const Duration(minutes: 4),
          importedAt: DateTime(2026, 5, 6, 10),
        );
        final secondAlbumTrack = _track(
          folderPath: '/music/coast',
          title: 'Signals',
          artist: 'North Coast',
          album: 'Sea Glass',
          duration: const Duration(minutes: 3, seconds: 12),
          importedAt: DateTime(2026, 5, 6, 11),
        );
        final otherAlbumTrack = _track(
          folderPath: '/music/city',
          title: 'Late Metro',
          artist: 'Night Ferry',
          album: 'City Lines',
          duration: const Duration(minutes: 4, seconds: 2),
          importedAt: DateTime(2026, 5, 6, 12),
        );
        final controller = MusicAppController(
          enableAudio: false,
          initialTracks: [firstAlbumTrack, secondAlbumTrack, otherAlbumTrack],
        );
        addTearDown(controller.dispose);

        controller.openLibraryFilter(LibraryFilter.albums);

        expect(controller.filteredLibraryCollections.length, 2);
        expect(
          controller.filteredLibraryCollections.map(
            (collection) => collection.title,
          ),
          containsAll(<String>['Sea Glass', 'City Lines']),
        );
        expect(controller.albumCount, 2);
      },
    );

    test(
      'theme and playback mode preferences persist across restore',
      () async {
        final repository = InMemoryMusicRepository();
        final controller = MusicAppController(
          enableAudio: false,
          repository: repository,
        );
        addTearDown(controller.dispose);

        controller.setThemeMode(AppThemeMode.light);
        await controller.toggleShuffle();
        await controller.toggleRepeat();
        await controller.flushSession();

        final restored = MusicAppController(
          enableAudio: false,
          repository: repository,
        );
        addTearDown(restored.dispose);

        await restored.restoreSession();

        expect(restored.themeMode, AppThemeMode.light);
        expect(restored.isShuffleEnabled, isTrue);
        expect(restored.isRepeatEnabled, isTrue);
      },
    );

    test('skipNext wraps only when repeat is enabled', () async {
      final firstTrack = _track(
        folderPath: '/music/queue',
        title: 'First Light',
        artist: 'North Coast',
        album: 'Queue',
        duration: const Duration(minutes: 3),
        importedAt: DateTime(2026, 5, 5, 20),
      );
      final secondTrack = _track(
        folderPath: '/music/queue',
        title: 'Second Signal',
        artist: 'North Coast',
        album: 'Queue',
        duration: const Duration(minutes: 4),
        importedAt: DateTime(2026, 5, 5, 21),
      );
      final collection = MusicCollection(
        id: 'queue',
        title: 'Queue',
        subtitle: '2 tracks',
        description: 'Test queue',
        kind: MusicCollectionKind.playlist,
        palette: secondTrack.palette,
        tracks: [firstTrack, secondTrack],
      );
      final controller = MusicAppController(
        enableAudio: false,
        initialTracks: [firstTrack, secondTrack],
      );
      addTearDown(controller.dispose);

      await controller.playTrack(secondTrack, collection: collection);

      await controller.skipNext();
      expect(controller.currentTrack?.id, secondTrack.id);

      await controller.toggleRepeat();
      await controller.skipNext();
      expect(controller.currentTrack?.id, firstTrack.id);
    });
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
