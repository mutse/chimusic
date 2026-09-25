import 'package:chimusic/app/chimusic_theme.dart';
import 'package:chimusic/data/music_session_store.dart';
import 'package:chimusic/models/music_models.dart';
import 'package:chimusic/state/chimusic_controller.dart';
import 'package:chimusic/state/chimusic_scope.dart';
import 'package:chimusic/widgets/immersive_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Track _track(String id, String title) => Track(
  id: id,
  filePath: '/music/$id.mp3',
  fileName: '$id.mp3',
  folderPath: '/music',
  title: title,
  artist: '林间来信',
  album: '深海回声',
  palette: const [Color(0xFFB4F4EA), Color(0xFF102C3A)],
  importedAt: DateTime(2026, 9, 22),
  duration: const Duration(seconds: 276),
);

Widget _app(MusicAppController controller, {double scale = 1}) => ChiMusicScope(
  notifier: controller,
  child: AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      theme: buildChiMusicTheme(
        brightness: controller.themeMode == AppThemeMode.light
            ? Brightness.light
            : Brightness.dark,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const ImmersivePlayer(),
    ),
  ),
);

void main() {
  testWidgets('theme switch, seek and history resume survive session restore', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _Store();
    final first = _track('tide', '潮汐之间');
    final previous = _track('wind', '昨日的风');
    final controller = MusicAppController(
      enableAudio: false,
      sessionStore: store,
      initialTracks: [first, previous],
      initialPlaybackHistory: [
        PlaybackHistoryEntry(
          trackId: previous.id,
          lastPlayedAt: DateTime(2026, 9, 21),
          lastPosition: const Duration(seconds: 136),
        ),
      ],
    );
    addTearDown(controller.dispose);
    await controller.playTrack(first);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    expect(find.text('播放记录'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('播放选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换浅色主题'));
    await tester.pumpAndSettle();
    expect(controller.themeMode, AppThemeMode.light);
    expect(find.text('聆听足迹'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('player-progress')));
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('player-progress'))),
    );
    await tester.pumpAndSettle();
    expect(controller.position.inSeconds, closeTo(138, 3));
    await tester.tap(find.byKey(const Key('player-play-pause')));
    await tester.pumpAndSettle();
    expect(controller.isPlaying, isFalse);

    await tester.ensureVisible(find.byKey(const Key('player-history')));
    await tester.tap(find.byKey(const Key('player-history')));
    await tester.pumpAndSettle();
    expect(find.text('保存在本机 · 点击歌曲接着听'), findsOneWidget);
    await tester.tap(find.byTooltip('继续播放 昨日的风').last);
    await tester.pumpAndSettle();
    expect(controller.currentTrack?.id, previous.id);
    expect(controller.position, const Duration(seconds: 136));
    expect(controller.isPlaying, isTrue);
    await controller.flushSession();

    final restored = MusicAppController(
      enableAudio: false,
      sessionStore: store,
    );
    addTearDown(restored.dispose);
    await restored.restoreSession();
    expect(restored.themeMode, AppThemeMode.light);
    expect(restored.currentTrack?.id, previous.id);
    expect(restored.position, const Duration(seconds: 136));
    expect(
      restored.playbackHistoryEntryForTrack(first.id)?.lastPosition.inSeconds,
      closeTo(138, 3),
    );
    expect(tester.takeException(), isNull);
  });

  for (final theme in AppThemeMode.values) {
    testWidgets('$theme fits a small phone with large text and long metadata', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final track = _track('long', '当潮水越过漫长的海岸线我们再次相遇');
      final controller = MusicAppController(
        enableAudio: false,
        initialTracks: [track],
        initialThemeMode: theme,
      );
      addTearDown(controller.dispose);
      await controller.playTrack(track);
      await tester.pumpWidget(_app(controller, scale: 1.6));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('player-history')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('player-history')));
      await tester.pumpAndSettle();
      expect(find.text('保存在本机 · 点击歌曲接着听'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Store implements MusicSessionStore {
  MusicSessionSnapshot snapshot = const MusicSessionSnapshot();
  @override
  Future<MusicSessionSnapshot> load() async => snapshot;
  @override
  Future<void> save(MusicSessionSnapshot value) async {
    snapshot = value;
  }
}
