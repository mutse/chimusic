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
