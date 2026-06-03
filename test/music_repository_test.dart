import 'dart:io';

import 'package:chimusic/data/music_repository.dart';
import 'package:chimusic/models/music_models.dart';
import 'package:chimusic/state/chimusic_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MusicSnapshotFileStore saves and loads local music records', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'chimusic-file-store-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final track = _track(
      folderPath: '/music/archive',
      title: 'Voyager',
      artist: 'Daft Punk',
      album: 'Archive',
      duration: const Duration(minutes: 3, seconds: 44),
      importedAt: DateTime(2026, 5, 5, 9),
    );
    final snapshot = MusicRepositorySnapshot(
      tracks: [track],
      trackSources: [
        TrackSourceRecord(
          trackId: track.id,
          platform: 'macos',
          locator: track.filePath,
          bookmarkBase64: 'bookmark-1',
          relativePath: 'Archive/Voyager.mp3',
        ),
      ],
      playbackStats: [
        PlaybackHistoryEntry(
          trackId: track.id,
          lastPlayedAt: DateTime(2026, 5, 6, 10),
          lastPosition: const Duration(minutes: 2),
          playCount: 3,
          totalListened: const Duration(minutes: 8),
        ),
      ],
      playbackEvents: [
        PlaybackEvent(
          id: 'evt-1',
          trackId: track.id,
          collectionId: track.folderPath,
          startedAt: DateTime(2026, 5, 6, 10),
          endedAt: DateTime(2026, 5, 6, 10, 3),
          maxPosition: const Duration(minutes: 3),
          endReason: PlaybackEndReason.completed,
        ),
      ],
      playbackSession: PlaybackSessionState(
        queueTrackIds: [track.id],
        currentTrackId: track.id,
        currentCollectionId: track.folderPath,
        position: const Duration(minutes: 2),
        updatedAt: DateTime(2026, 5, 6, 10, 3),
      ),
      likedTrackIds: {track.id},
      savedCollectionIds: {track.folderPath},
      recentTrackIds: [track.id],
      recentSearches: const ['Archive'],
      selectedTab: MusicTab.library,
      libraryFilter: LibraryFilter.favorites,
      librarySort: LibrarySort.length,
      searchQuery: 'Voyager',
      searchMode: SearchMode.standard,
      userProfile: UserProfile(
        id: 'user-1',
        name: 'Chi Listener',
        email: 'chi@example.com',
        avatarSeed: 'chi-listener',
        membershipTier: MembershipTier.pro,
        signedInAt: DateTime(2026, 5, 1, 8),
      ),
      aiSearchTrialsRemaining: 1,
      hasUnlockedAiUpsell: true,
      themeMode: AppThemeMode.light,
      isShuffleEnabled: true,
      isRepeatEnabled: true,
    );
    final store = MusicSnapshotFileStore(
      directoryProvider: () async => tempDirectory,
      directoryName: 'state',
      fileName: 'music_records.json',
    );

    await store.save(snapshot);

    final file = await store.resolveFile();
    expect(await file.exists(), isTrue);

    final restored = await store.load();

    expect(restored, isNotNull);
    expect(restored!.tracks.single.id, track.id);
    expect(restored.trackSources.single.bookmarkBase64, 'bookmark-1');
    expect(restored.trackSources.single.relativePath, 'Archive/Voyager.mp3');
    expect(restored.playbackStats.single.playCount, 3);
    expect(restored.playbackEvents.single.id, 'evt-1');
    expect(restored.playbackSession.currentTrackId, track.id);
    expect(restored.likedTrackIds, {track.id});
    expect(restored.savedCollectionIds, {track.folderPath});
    expect(restored.recentSearches, ['Archive']);
    expect(restored.themeMode, AppThemeMode.light);
    expect(restored.isShuffleEnabled, isTrue);
    expect(restored.isRepeatEnabled, isTrue);
  });

  test(
    'MusicAppController restores saved imported tracks on the next startup',
    () async {
      final repository = InMemoryMusicRepository();
      final track = _track(
        folderPath: '/music/library',
        title: 'Signals',
        artist: 'North Coast',
        album: 'Sea Glass',
        duration: const Duration(minutes: 3, seconds: 12),
        importedAt: DateTime(2026, 5, 6, 11),
      );
      final controller = MusicAppController(
        enableAudio: false,
        repository: repository,
        initialTracks: [track],
        initialTrackSources: [
          TrackSourceRecord(
            trackId: track.id,
            platform: 'macos',
            locator: track.filePath,
            bookmarkBase64: 'bookmark-2',
          ),
        ],
        initialLikedTrackIds: {track.id},
        initialRecentTrackIds: [track.id],
      );
      addTearDown(controller.dispose);

      await controller.flushSession();

      expect(repository.snapshot.tracks.single.id, track.id);
      expect(repository.snapshot.trackSources.single.locator, track.filePath);

      final restored = MusicAppController(
        enableAudio: false,
        repository: repository,
      );
      addTearDown(restored.dispose);

      await restored.restoreSession();

      expect(restored.importedTrackCount, 1);
      expect(restored.importedTracks.single.id, track.id);
      expect(
        restored.trackSourceForTrack(track.id)?.bookmarkBase64,
        'bookmark-2',
      );
      expect(restored.likedTracksCount, 1);
      expect(restored.recentPlayedTracks.single.id, track.id);
    },
  );
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
