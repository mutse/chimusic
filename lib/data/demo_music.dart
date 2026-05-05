import 'package:flutter/material.dart';

import '../models/music_models.dart';

class DemoCatalog {
  const DemoCatalog({
    required this.collections,
    required this.shelves,
    required this.categories,
    required this.recentlyPlayedIds,
    required this.featuredCollectionId,
  });

  final List<MusicCollection> collections;
  final List<HomeShelf> shelves;
  final List<SearchCategory> categories;
  final List<String> recentlyPlayedIds;
  final String featuredCollectionId;

  List<Track> get allTracks => [
    for (final collection in collections) ...collection.tracks,
  ];

  MusicCollection collectionById(String id) {
    return collections.firstWhere((collection) => collection.id == id);
  }
}

DemoCatalog buildDemoCatalog() {
  Track track({
    required String id,
    required String title,
    required String artist,
    required String album,
    required int minutes,
    required int seconds,
    required List<Color> palette,
    required String mood,
    String? lyric,
    bool explicit = false,
  }) {
    return Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: Duration(minutes: minutes, seconds: seconds),
      palette: palette,
      moodTag: mood,
      lyricLine: lyric,
      explicit: explicit,
    );
  }

  const tidalPalette = [
    Color(0xFF60D1D3),
    Color(0xFF0C5C78),
    Color(0xFF08263C),
  ];
  const afterglowPalette = [
    Color(0xFFFFA46C),
    Color(0xFFB9495D),
    Color(0xFF2C193E),
  ];
  const focusPalette = [
    Color(0xFFA5F2DB),
    Color(0xFF2A8E89),
    Color(0xFF0D2A35),
  ];
  const velvetPalette = [
    Color(0xFFFFB8B8),
    Color(0xFF8D5AA7),
    Color(0xFF191A39),
  ];
  const pulsePalette = [
    Color(0xFF8FE7FF),
    Color(0xFF2478C7),
    Color(0xFF091D43),
  ];
  const moonPalette = [Color(0xFFC5CFFF), Color(0xFF5B6DE3), Color(0xFF111936)];

  final tidalBloom = MusicCollection(
    id: 'tidal_bloom',
    title: 'Tidal Bloom',
    subtitle: 'Curated for late sunlight and open tabs',
    description:
        'Glass-toned pop, warm breaks, and melodic house with a polished afterglow.',
    kind: MusicCollectionKind.mix,
    palette: tidalPalette,
    badge: 'Featured',
    downloaded: true,
    tracks: [
      track(
        id: 'tidal_bloom_01',
        title: 'Soft Current',
        artist: 'Mira Vale',
        album: 'Tidal Bloom',
        minutes: 3,
        seconds: 24,
        palette: tidalPalette,
        mood: 'Liquid',
        lyric: 'Color spills slowly through the speakers.',
      ),
      track(
        id: 'tidal_bloom_02',
        title: 'Glass Horizon',
        artist: 'North Arcade',
        album: 'Tidal Bloom',
        minutes: 4,
        seconds: 2,
        palette: tidalPalette,
        mood: 'Glow',
        lyric: 'We stay bright enough to blur the skyline.',
      ),
      track(
        id: 'tidal_bloom_03',
        title: 'Sea Change',
        artist: 'Levin Coast',
        album: 'Tidal Bloom',
        minutes: 3,
        seconds: 38,
        palette: tidalPalette,
        mood: 'Drift',
      ),
      track(
        id: 'tidal_bloom_04',
        title: 'Blue Hour Echo',
        artist: 'Mira Vale',
        album: 'Tidal Bloom',
        minutes: 4,
        seconds: 11,
        palette: tidalPalette,
        mood: 'Evening',
      ),
    ],
  );

  final cityAfterglow = MusicCollection(
    id: 'city_afterglow',
    title: 'City Afterglow',
    subtitle: 'Neon soul with rooftop lift',
    description:
        'A cinematic run through amber synths, glossy basslines, and midnight vocals.',
    kind: MusicCollectionKind.playlist,
    palette: afterglowPalette,
    tracks: [
      track(
        id: 'city_afterglow_01',
        title: 'Amber Lanes',
        artist: 'June Arcade',
        album: 'City Afterglow',
        minutes: 3,
        seconds: 19,
        palette: afterglowPalette,
        mood: 'Drive',
      ),
      track(
        id: 'city_afterglow_02',
        title: 'Night Transit',
        artist: 'Theo Meridian',
        album: 'City Afterglow',
        minutes: 4,
        seconds: 6,
        palette: afterglowPalette,
        mood: 'Neon',
        lyric: 'Headlights bend like liquid in the rain.',
      ),
      track(
        id: 'city_afterglow_03',
        title: 'Slow Sparks',
        artist: 'June Arcade',
        album: 'City Afterglow',
        minutes: 2,
        seconds: 57,
        palette: afterglowPalette,
        mood: 'Warm',
      ),
      track(
        id: 'city_afterglow_04',
        title: 'Rooftop Static',
        artist: 'Theo Meridian',
        album: 'City Afterglow',
        minutes: 3,
        seconds: 43,
        palette: afterglowPalette,
        mood: 'Pulse',
      ),
    ],
  );

  final glassFocus = MusicCollection(
    id: 'glass_focus',
    title: 'Glass Focus',
    subtitle: 'Deep work without the drag',
    description:
        'Minimal rhythm, bright ambience, and steady movement for long creative sessions.',
    kind: MusicCollectionKind.playlist,
    palette: focusPalette,
    badge: 'Workday',
    downloaded: true,
    tracks: [
      track(
        id: 'glass_focus_01',
        title: 'Quiet Vectors',
        artist: 'Sora Metric',
        album: 'Glass Focus',
        minutes: 4,
        seconds: 17,
        palette: focusPalette,
        mood: 'Focus',
      ),
      track(
        id: 'glass_focus_02',
        title: 'Pulse Diagram',
        artist: 'Otis Parallel',
        album: 'Glass Focus',
        minutes: 3,
        seconds: 48,
        palette: focusPalette,
        mood: 'Flow',
      ),
      track(
        id: 'glass_focus_03',
        title: 'Mint Static',
        artist: 'Sora Metric',
        album: 'Glass Focus',
        minutes: 3,
        seconds: 34,
        palette: focusPalette,
        mood: 'Study',
      ),
      track(
        id: 'glass_focus_04',
        title: 'Open Canvas',
        artist: 'Otis Parallel',
        album: 'Glass Focus',
        minutes: 5,
        seconds: 1,
        palette: focusPalette,
        mood: 'Deep',
      ),
    ],
  );

  final velvetHaze = MusicCollection(
    id: 'velvet_haze',
    title: 'Velvet Haze',
    subtitle: 'An album for candlelit speakers',
    description:
        'Dream pop vocals, swollen chords, and a soft-focus rhythm section.',
    kind: MusicCollectionKind.album,
    palette: velvetPalette,
    tracks: [
      track(
        id: 'velvet_haze_01',
        title: 'Rose Signal',
        artist: 'Faye Lumen',
        album: 'Velvet Haze',
        minutes: 3,
        seconds: 47,
        palette: velvetPalette,
        mood: 'Dream',
      ),
      track(
        id: 'velvet_haze_02',
        title: 'Half-Light',
        artist: 'Faye Lumen',
        album: 'Velvet Haze',
        minutes: 4,
        seconds: 15,
        palette: velvetPalette,
        mood: 'Soft',
        lyric: 'Stay where the edges feel kinder.',
      ),
      track(
        id: 'velvet_haze_03',
        title: 'Silk Frequency',
        artist: 'Faye Lumen',
        album: 'Velvet Haze',
        minutes: 3,
        seconds: 30,
        palette: velvetPalette,
        mood: 'Velvet',
      ),
      track(
        id: 'velvet_haze_04',
        title: 'Petal Noise',
        artist: 'Faye Lumen',
        album: 'Velvet Haze',
        minutes: 4,
        seconds: 26,
        palette: velvetPalette,
        mood: 'Bloom',
        explicit: true,
      ),
    ],
  );

  final pulseRun = MusicCollection(
    id: 'pulse_run',
    title: 'Pulse Run',
    subtitle: 'Forward motion, zero dead air',
    description:
        'Bright electronic edges and club-trained drums tuned for movement.',
    kind: MusicCollectionKind.playlist,
    palette: pulsePalette,
    badge: 'Energy',
    tracks: [
      track(
        id: 'pulse_run_01',
        title: 'Arc Sprint',
        artist: 'Kite Theory',
        album: 'Pulse Run',
        minutes: 2,
        seconds: 56,
        palette: pulsePalette,
        mood: 'Sprint',
      ),
      track(
        id: 'pulse_run_02',
        title: 'Zero Delay',
        artist: 'Kite Theory',
        album: 'Pulse Run',
        minutes: 3,
        seconds: 8,
        palette: pulsePalette,
        mood: 'Push',
      ),
      track(
        id: 'pulse_run_03',
        title: 'Blue Circuit',
        artist: 'Nova Dash',
        album: 'Pulse Run',
        minutes: 3,
        seconds: 42,
        palette: pulsePalette,
        mood: 'Charge',
      ),
      track(
        id: 'pulse_run_04',
        title: 'Speed Memory',
        artist: 'Nova Dash',
        album: 'Pulse Run',
        minutes: 4,
        seconds: 4,
        palette: pulsePalette,
        mood: 'Lift',
      ),
    ],
  );

  final moonSignals = MusicCollection(
    id: 'moon_signals',
    title: 'Moon Signals',
    subtitle: 'Stillness with a pulse',
    description:
        'Wide synthesizers, intimate toplines, and nighttime clarity for slower rooms.',
    kind: MusicCollectionKind.album,
    palette: moonPalette,
    downloaded: true,
    tracks: [
      track(
        id: 'moon_signals_01',
        title: 'Orbiting Quiet',
        artist: 'Halo District',
        album: 'Moon Signals',
        minutes: 4,
        seconds: 9,
        palette: moonPalette,
        mood: 'Calm',
      ),
      track(
        id: 'moon_signals_02',
        title: 'Silver Frame',
        artist: 'Halo District',
        album: 'Moon Signals',
        minutes: 3,
        seconds: 51,
        palette: moonPalette,
        mood: 'Night',
      ),
      track(
        id: 'moon_signals_03',
        title: 'Satellite Bloom',
        artist: 'Halo District',
        album: 'Moon Signals',
        minutes: 4,
        seconds: 22,
        palette: moonPalette,
        mood: 'Float',
      ),
      track(
        id: 'moon_signals_04',
        title: 'Distant Harbour',
        artist: 'Halo District',
        album: 'Moon Signals',
        minutes: 3,
        seconds: 27,
        palette: moonPalette,
        mood: 'Quiet',
      ),
    ],
  );

  final collections = [
    tidalBloom,
    cityAfterglow,
    glassFocus,
    velvetHaze,
    pulseRun,
    moonSignals,
  ];

  return DemoCatalog(
    collections: collections,
    featuredCollectionId: tidalBloom.id,
    recentlyPlayedIds: [
      glassFocus.id,
      tidalBloom.id,
      moonSignals.id,
      cityAfterglow.id,
    ],
    shelves: const [
      HomeShelf(
        title: 'Made For You',
        subtitle: 'Personal mixes with polished momentum',
        collectionIds: ['tidal_bloom', 'glass_focus', 'city_afterglow'],
      ),
      HomeShelf(
        title: 'Fresh Radar',
        subtitle: 'New additions that match your recent sessions',
        collectionIds: ['pulse_run', 'moon_signals', 'velvet_haze'],
      ),
      HomeShelf(
        title: 'After Dark',
        subtitle: 'Softer edges and slower light',
        collectionIds: ['velvet_haze', 'moon_signals', 'tidal_bloom'],
      ),
    ],
    categories: const [
      SearchCategory(
        title: 'Energy',
        icon: Icons.bolt_rounded,
        palette: pulsePalette,
      ),
      SearchCategory(
        title: 'Focus',
        icon: Icons.auto_graph_rounded,
        palette: focusPalette,
      ),
      SearchCategory(
        title: 'Chill',
        icon: Icons.spa_rounded,
        palette: tidalPalette,
      ),
      SearchCategory(
        title: 'Late Night',
        icon: Icons.nights_stay_rounded,
        palette: moonPalette,
      ),
      SearchCategory(
        title: 'Indie Glow',
        icon: Icons.album_rounded,
        palette: velvetPalette,
      ),
      SearchCategory(
        title: 'City Pop',
        icon: Icons.location_city_rounded,
        palette: afterglowPalette,
      ),
    ],
  );
}
