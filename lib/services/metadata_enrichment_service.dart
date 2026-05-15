import '../models/music_models.dart';

abstract class MetadataEnrichmentService {
  Future<List<Track>> enrichTracks(List<Track> tracks);

  Future<LyricsState> fetchLyrics(Track track);
}

class MockMetadataEnrichmentService implements MetadataEnrichmentService {
  static const List<String> _genres = <String>[
    'Ambient',
    'Electronic',
    'Indie',
    'Soul',
    'Hip-Hop',
    'Jazz',
    'Lo-fi',
    'Alternative',
  ];

  @override
  Future<List<Track>> enrichTracks(List<Track> tracks) async {
    return tracks.map(_enrichTrack).toList(growable: false);
  }

  @override
  Future<LyricsState> fetchLyrics(Track track) async {
    if (track.lyricsAvailability == LyricsAvailability.unavailable) {
      return const LyricsState(
        status: LyricsStatus.unavailable,
        title: 'No synced lyrics yet',
        lines: <String>[],
        source: 'ChiMusic Metadata',
      );
    }

    final theme = (track.genre ?? 'Late Night').toLowerCase();
    return LyricsState(
      status: LyricsStatus.available,
      title: 'Synced lyric preview',
      source: 'ChiMusic Metadata',
      lines: <String>[
        'Lights low, $theme slow, the room begins to move.',
        'Every archive on this device still carries a point of view.',
        'Play it back and let the old signal find a brighter tone.',
        'Your library sounds alive again, even when you listen alone.',
      ],
    );
  }

  Track _enrichTrack(Track track) {
    final seed = track.id.hashCode.abs();
    final genre = _genres[seed % _genres.length];
    final year = 2004 + (seed % 19);
    final bitrate = 192 + ((seed % 5) * 32);
    final lyricsAvailability = seed % 5 == 0
        ? LyricsAvailability.unavailable
        : LyricsAvailability.available;

    return track.copyWith(
      artworkUri: 'mock://artwork/${track.id.hashCode.abs()}',
      lyricsAvailability: lyricsAvailability,
      genre: genre,
      year: year,
      bitrate: bitrate,
      fingerprint: 'fp_${seed.toRadixString(16)}',
      cloudMatchStatus: seed.isEven
          ? CloudMatchStatus.enriched
          : CloudMatchStatus.matched,
      credits: <String>[
        track.artist,
        '$genre Arrangement',
        'ChiMusic Session Notes',
      ],
    );
  }
}
