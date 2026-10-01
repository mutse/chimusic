// Design preview only. Production starts at lib/main.dart with real local audio.
import 'package:chimusic/app/chimusic_theme.dart';
import 'package:chimusic/models/music_models.dart';
import 'package:chimusic/services/metadata_enrichment_service.dart';
import 'package:chimusic/state/chimusic_controller.dart';
import 'package:chimusic/state/chimusic_scope.dart';
import 'package:chimusic/widgets/immersive_player.dart';
import 'package:chimusic/widgets/mobile_player_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

Track demoTrack(String id, String title, String artist, int seconds) => Track(
  id: id,
  filePath: '/preview/$id.mp3',
  fileName: '$id.mp3',
  folderPath: '/preview',
  title: title,
  artist: artist,
  album: 'ChiMusic Sessions',
  palette: const [Color(0xFFB4F4EA), Color(0xFF102C3A)],
  importedAt: DateTime(2026, 9, 22),
  duration: Duration(seconds: seconds),
  artworkUri: id == 'wind' ? 'assets/images/immersive_wind.png' : null,
  lyricsAvailability: LyricsAvailability.available,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final tracks = [
    demoTrack('tide', '潮汐之间', '林间来信', 276),
    demoTrack('sunset', '日落以后', '南方电台', 308),
    demoTrack('wind', '昨日的风', '南方电台', 242),
  ];
  final light = Uri.base.queryParameters['theme'] == 'light';
  final controller = MusicAppController(
    enableAudio: false,
    metadataEnrichmentService: _PreviewLyrics(),
    initialTracks: tracks,
    initialThemeMode: light ? AppThemeMode.light : AppThemeMode.dark,
    initialPlaybackHistory: [
      PlaybackHistoryEntry(
        trackId: 'wind',
        lastPlayedAt: DateTime(2026, 9, 21, 20, 16),
        lastPosition: const Duration(seconds: 136),
      ),
    ],
  );
  await controller.playTrack(tracks[light ? 1 : 0]);
  controller.seekToFraction(light ? 102 / 308 : 0.5);
  runApp(
    ChiMusicScope(
      notifier: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ChiMusic · 双主题交互预览',
          theme: buildChiMusicTheme(
            brightness: Brightness.light,
          ).copyWith(platform: TargetPlatform.android),
          darkTheme: buildChiMusicTheme().copyWith(
            platform: TargetPlatform.android,
          ),
          themeMode: controller.themeMode == AppThemeMode.light
              ? ThemeMode.light
              : ThemeMode.dark,
          builder: (context, child) => ColoredBox(
            color: const Color(0xFF20272D),
            child: Center(
              child: SizedBox(
                width: 390,
                height: 844,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: const Size(390, 844),
                    padding: EdgeInsets.zero,
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
          initialRoute: '/player',
          routes: {
            '/': (_) => const MobilePlayerShell(),
            '/player': (_) => const ImmersivePlayer(),
          },
        ),
      ),
    ),
  );
}

class _PreviewLyrics implements MetadataEnrichmentService {
  @override
  Future<List<Track>> enrichTracks(List<Track> tracks) async => tracks;
  @override
  Future<LyricsState> fetchLyrics(Track track) async => const LyricsState(
    status: LyricsStatus.available,
    lines: ['潮水退去 又一次靠近', '在无声的海底 听见你的回音'],
  );
}
