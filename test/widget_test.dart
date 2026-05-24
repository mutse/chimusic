import 'dart:convert';
import 'dart:async';

import 'package:chimusic/app/chimusic_app.dart';
import 'package:chimusic/data/music_session_store.dart';
import 'package:chimusic/models/music_models.dart';
import 'package:chimusic/screens/now_playing_sheet.dart';
import 'package:chimusic/state/chimusic_controller.dart';
import 'package:chimusic/state/chimusic_scope.dart';
import 'package:chimusic/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('boots into the primary navigation shell', (tester) async {
    final controller = MusicAppController(enableAudio: false);

    await tester.pumpWidget(ChiMusicRoot(controller: controller));
    await tester.pump();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Library'), findsWidgets);
    expect(
      find.text('Turn local files into a full music app experience.'),
      findsOneWidget,
    );

    controller.dispose();
  });

  testWidgets('home metrics do not overflow on compact wide layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(860, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = MusicAppController(enableAudio: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(ChiMusicRoot(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Resume Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flushes pending session data when the app is backgrounded', (
    tester,
  ) async {
    final track = Track(
      id: '/music/demo/North Coast - Blue Horizon.mp3',
      filePath: '/music/demo/North Coast - Blue Horizon.mp3',
      fileName: 'North Coast - Blue Horizon.mp3',
      folderPath: '/music/demo',
      title: 'Blue Horizon',
      artist: 'North Coast',
      album: 'Demo',
      palette: const [Color(0xFF1ED760), Color(0xFF0F5132), Color(0xFF111318)],
      importedAt: DateTime(2026, 5, 6, 15),
      duration: const Duration(minutes: 4),
      fileExtension: 'mp3',
    );
    final store = _BlockingSessionStore();
    final controller = MusicAppController(
      enableAudio: false,
      sessionStore: store,
      initialTracks: [track],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(ChiMusicRoot(controller: controller));
    await tester.pump();

    controller.toggleLikedTrack(track.id);
    await store.firstSaveStarted.future;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();

    store.release();
    await tester.pump();

    expect(store.saveCallCount, 2);
    expect(store.lastSaved?.likedTrackIds, {track.id});
  });

  testWidgets(
    'launch restores the persisted library and last playback automatically',
    (tester) async {
      final track = Track(
        id: '/music/archive/Daft Punk - Voyager.mp3',
        filePath: '/music/archive/Daft Punk - Voyager.mp3',
        fileName: 'Daft Punk - Voyager.mp3',
        folderPath: '/music/archive',
        title: 'Voyager',
        artist: 'Daft Punk',
        album: 'Archive',
        palette: const [
          Color(0xFF1ED760),
          Color(0xFF0F5132),
          Color(0xFF111318),
        ],
        importedAt: DateTime(2026, 5, 6, 15),
        duration: const Duration(minutes: 3, seconds: 44),
        fileExtension: 'mp3',
      );
      final snapshot = MusicSessionSnapshot(
        tracks: [track],
        likedTrackIds: {track.id},
        savedCollectionIds: {track.folderPath},
        recentTrackIds: [track.id],
        selectedTab: MusicTab.library,
        libraryFilter: LibraryFilter.favorites,
        librarySort: LibrarySort.recent,
        queueTrackIds: [track.id],
        currentTrackId: track.id,
        currentCollectionId: track.folderPath,
        positionMs: 61000,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'chimusic.session.v1': jsonEncode(snapshot.toJson()),
      });
      final controller = MusicAppController(
        enableAudio: false,
        sessionStore: SharedPreferencesMusicSessionStore(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(ChiMusicRoot(controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(AppShell), findsOneWidget);

      final context = tester.element(find.byType(AppShell));
      final restoredController = ChiMusicScope.read(context);

      expect(restoredController.importedTrackCount, 1);
      expect(restoredController.savedCollectionCount, 1);
      expect(restoredController.likedTracksCount, 1);
      expect(restoredController.selectedTab, MusicTab.library);
      expect(restoredController.libraryFilter, LibraryFilter.favorites);
      expect(restoredController.currentTrack?.title, 'Voyager');
      expect(restoredController.position, const Duration(seconds: 61));
      expect(find.text('Voyager'), findsWidgets);
    },
  );

  testWidgets(
    'library screen renders history, resume, and most played sections',
    (tester) async {
      final resumeTrack = Track(
        id: '/music/history/North Coast - Replay.mp3',
        filePath: '/music/history/North Coast - Replay.mp3',
        fileName: 'North Coast - Replay.mp3',
        folderPath: '/music/history',
        title: 'Replay',
        artist: 'North Coast',
        album: 'Sea Glass',
        palette: const [
          Color(0xFF1ED760),
          Color(0xFF0F5132),
          Color(0xFF111318),
        ],
        importedAt: DateTime(2026, 5, 6, 15),
        duration: const Duration(minutes: 4),
        fileExtension: 'mp3',
      );
      final mostPlayedTrack = Track(
        id: '/music/history/North Coast - Looped.mp3',
        filePath: '/music/history/North Coast - Looped.mp3',
        fileName: 'North Coast - Looped.mp3',
        folderPath: '/music/history',
        title: 'Looped',
        artist: 'North Coast',
        album: 'Sea Glass',
        palette: const [
          Color(0xFF4B7BFF),
          Color(0xFF0F3251),
          Color(0xFF111318),
        ],
        importedAt: DateTime(2026, 5, 6, 16),
        duration: const Duration(minutes: 5),
        fileExtension: 'mp3',
      );
      final controller = MusicAppController(
        enableAudio: false,
        initialTracks: [resumeTrack, mostPlayedTrack],
        initialSelectedTab: MusicTab.library,
        initialPlaybackHistory: [
          PlaybackHistoryEntry(
            trackId: resumeTrack.id,
            lastPlayedAt: DateTime(2026, 5, 8, 10),
            lastPosition: const Duration(minutes: 1, seconds: 32),
            playCount: 2,
            totalListened: const Duration(minutes: 4),
          ),
          PlaybackHistoryEntry(
            trackId: mostPlayedTrack.id,
            lastPlayedAt: DateTime(2026, 5, 8, 8),
            playCount: 6,
            totalListened: const Duration(minutes: 14),
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
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(ChiMusicRoot(controller: controller));
      await tester.pump();

      expect(find.text('History'), findsOneWidget);
      expect(find.text('Recent Sessions'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Most Played'), findsOneWidget);
      expect(find.text('Replay'), findsWidgets);
      expect(find.text('Looped'), findsWidgets);
    },
  );

  testWidgets('now playing sheet shows queue, lyrics, and history tabs', (
    tester,
  ) async {
    final track = Track(
      id: '/music/stage/North Coast - Blue Horizon.mp3',
      filePath: '/music/stage/North Coast - Blue Horizon.mp3',
      fileName: 'North Coast - Blue Horizon.mp3',
      folderPath: '/music/stage',
      title: 'Blue Horizon',
      artist: 'North Coast',
      album: 'Sea Glass',
      palette: const [Color(0xFF1ED760), Color(0xFF0F5132), Color(0xFF111318)],
      importedAt: DateTime(2026, 5, 6, 15),
      duration: const Duration(minutes: 4),
      fileExtension: 'mp3',
    );
    final controller = MusicAppController(
      enableAudio: false,
      initialTracks: [track],
      initialPlaybackHistory: [
        PlaybackHistoryEntry(
          trackId: track.id,
          lastPlayedAt: DateTime(2026, 5, 8, 10),
          lastPosition: const Duration(minutes: 2),
          playCount: 3,
          totalListened: const Duration(minutes: 6),
        ),
      ],
      initialPlaybackEvents: [
        PlaybackEvent(
          id: 'evt-stage',
          trackId: track.id,
          startedAt: DateTime(2026, 5, 8, 10),
          endedAt: DateTime(2026, 5, 8, 10, 2),
          maxPosition: const Duration(minutes: 2),
          endReason: PlaybackEndReason.paused,
          collectionId: 'all_tracks',
        ),
      ],
    );
    addTearDown(controller.dispose);

    await controller.playImportedTracks();
    await tester.pumpWidget(ChiMusicRoot(controller: controller));
    await tester.pump();

    final context = tester.element(find.byType(AppShell));
    Navigator.of(context).push(NowPlayingSheet.route());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Blue Horizon'), findsWidgets);
  });
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
