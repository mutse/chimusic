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
    return const LyricsState(
      status: LyricsStatus.unavailable,
      title: 'Lyrics unavailable',
      lines: <String>[],
      source: 'Local Metadata',
      errorMessage:
          'This local-first build does not ship a remote lyric catalog.',
    );
  }

  Track _enrichTrack(Track track) {
    final seed = track.id.hashCode.abs();
    final genre = _genres[seed % _genres.length];
    final year = 2004 + (seed % 19);
    final bitrate = 192 + ((seed % 5) * 32);

    return track.copyWith(
      artworkUri: 'mock://artwork/${track.id.hashCode.abs()}',
      lyricsAvailability: LyricsAvailability.unavailable,
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
