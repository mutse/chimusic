import '../models/music_models.dart';

abstract class RecommendationService {
  Future<List<SmartPlaylist>> buildSmartPlaylists({
    required List<Track> tracks,
    required List<Track> recentPlayedTracks,
    required List<Track> favoriteTracks,
  });

  Future<List<RecommendationCard>> buildRecommendationCards({
    required List<Track> tracks,
    required List<Track> recentPlayedTracks,
    required List<Track> favoriteTracks,
  });

  Future<List<Track>> semanticSearch({
    required String query,
    required List<Track> tracks,
    required List<Track> recentPlayedTracks,
    required List<Track> favoriteTracks,
  });
}

class MockRecommendationService implements RecommendationService {
  @override
  Future<List<RecommendationCard>> buildRecommendationCards({
    required List<Track> tracks,
    required List<Track> recentPlayedTracks,
    required List<Track> favoriteTracks,
  }) async {
    if (tracks.isEmpty) {
      return const <RecommendationCard>[];
    }

    final newest = List<Track>.from(tracks)
      ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    final rediscovery = favoriteTracks.isNotEmpty
        ? favoriteTracks.take(4).toList(growable: false)
        : newest.take(4).toList(growable: false);
    final momentum = recentPlayedTracks.isNotEmpty
        ? recentPlayedTracks.take(4).toList(growable: false)
        : newest.take(4).toList(growable: false);
    final genreLeader = newest.first.genre ?? 'Electronic';
    final genreSet = tracks
        .where((track) => track.genre == genreLeader)
        .take(4)
        .toList(growable: false);

    return <RecommendationCard>[
      RecommendationCard(
        id: 'continue_momentum',
        title: 'Keep the current run going',
        subtitle: 'Built from your latest plays',
        description:
            'Resume the tone and pacing from what you played most recently.',
        reason: 'Recent completions and repeat plays carry the highest weight.',
        palette: momentum.first.palette,
        tracks: momentum,
        callToActionLabel: 'Open Local Mix',
        callToActionQuery: 'more like ${momentum.first.artist}',
      ),
      RecommendationCard(
        id: 'rediscover_favorites',
        title: 'Rediscover saved favorites',
        subtitle: 'Good candidates for a second listen',
        description:
            'Your liked tracks are resurfaced when they have gone quiet for a while.',
        reason: 'Likes plus lower recency create rediscovery opportunities.',
        palette: rediscovery.first.palette,
        tracks: rediscovery,
        callToActionLabel: 'Explore',
        callToActionQuery: 'rediscover favorites',
      ),
      RecommendationCard(
        id: 'genre_lane',
        title: '$genreLeader lane',
        subtitle: 'Built from one strong local cluster',
        description:
            'A focused card for the sound that currently dominates your library.',
        reason: 'Genre clustering is based on enriched local metadata.',
        palette: genreSet.isEmpty
            ? newest.first.palette
            : genreSet.first.palette,
        tracks: genreSet.isEmpty
            ? newest.take(4).toList(growable: false)
            : genreSet,
        callToActionLabel: 'Search mood',
        callToActionQuery: '$genreLeader mood',
      ),
    ];
  }

  @override
  Future<List<SmartPlaylist>> buildSmartPlaylists({
    required List<Track> tracks,
    required List<Track> recentPlayedTracks,
    required List<Track> favoriteTracks,
  }) async {
    if (tracks.isEmpty) {
      return const <SmartPlaylist>[];
    }

    final newest = List<Track>.from(tracks)
      ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    final lateNight = tracks
        .where((track) {
          final genre = (track.genre ?? '').toLowerCase();
          return genre.contains('ambient') ||
              genre.contains('electronic') ||
              genre.contains('lo-fi');
        })
        .take(8)
        .toList(growable: false);
    final focus = tracks
        .where(
          (track) =>
              (track.duration ?? Duration.zero) >= const Duration(minutes: 3),
        )
        .take(8)
        .toList(growable: false);
    final recovery = favoriteTracks.isNotEmpty
        ? favoriteTracks.take(8).toList(growable: false)
        : recentPlayedTracks.take(8).toList(growable: false);

    final playlists = <SmartPlaylist>[
      SmartPlaylist(
        id: 'smart_recent_imports',
        title: 'Fresh Imports',
        subtitle: 'Newest files on this device',
        description: 'An instant playlist from the latest music you added.',
        prompt: 'Play the newest additions first.',
        palette: newest.first.palette,
        tracks: newest.take(8).toList(growable: false),
        reason: 'Ordered by import time.',
      ),
      SmartPlaylist(
        id: 'smart_late_night',
        title: 'Late Night Flow',
        subtitle: 'Quiet momentum for long sessions',
        description:
            'A mood playlist generated from calm or nocturnal metadata signals.',
        prompt: 'Find me a low-light queue from my local library.',
        palette:
            (lateNight.isNotEmpty ? lateNight.first : newest.first).palette,
        tracks: lateNight.isEmpty
            ? newest.take(8).toList(growable: false)
            : lateNight,
        reason: 'Blends genre, play history, and longer-form tracks.',
      ),
      SmartPlaylist(
        id: 'smart_focus',
        title: 'Focus Engine',
        subtitle: 'Steady pace, fewer skips',
        description:
            'Longer tracks with stable energy, ideal for background listening.',
        prompt: 'Build a focus playlist without obvious interruptions.',
        palette: (focus.isNotEmpty ? focus.first : newest.first).palette,
        tracks: focus.isEmpty ? newest.take(8).toList(growable: false) : focus,
        reason: 'Weighted toward track length and repeated playback.',
      ),
      SmartPlaylist(
        id: 'smart_recovery',
        title: 'Favorites Re-entry',
        subtitle: 'Back to the songs you already trust',
        description:
            'A clean starting point when you want immediate confidence.',
        prompt: 'Queue my most dependable favorites.',
        palette: (recovery.isNotEmpty ? recovery.first : newest.first).palette,
        tracks: recovery.isEmpty
            ? newest.take(8).toList(growable: false)
            : recovery,
        reason: 'Weighted toward liked tracks and recent positive signals.',
      ),
    ];

    return playlists
        .where((playlist) => playlist.tracks.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<Track>> semanticSearch({
    required String query,
    required List<Track> tracks,
    required List<Track> recentPlayedTracks,
    required List<Track> favoriteTracks,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <Track>[];
    }

    final recentIds = recentPlayedTracks.map((track) => track.id).toSet();
    final favoriteIds = favoriteTracks.map((track) => track.id).toSet();
    final moodKeywords = <String, List<String>>{
      'late night': <String>['ambient', 'electronic', 'lo-fi'],
      'focus': <String>['ambient', 'jazz', 'lo-fi'],
      'warm': <String>['soul', 'jazz', 'indie'],
      'lift': <String>['alternative', 'electronic', 'hip-hop'],
    };

    final scored =
        tracks
            .map((track) {
              var score = 0;
              final haystack = <String>[
                track.title,
                track.artist,
                track.album,
                track.genre ?? '',
                '${track.year ?? ''}',
              ].join(' ').toLowerCase();

              if (haystack.contains(normalized)) {
                score += 120;
              }

              for (final entry in moodKeywords.entries) {
                if (normalized.contains(entry.key)) {
                  for (final genre in entry.value) {
                    if ((track.genre ?? '').toLowerCase().contains(genre)) {
                      score += 40;
                    }
                  }
                }
              }

              if (normalized.contains('favorite') &&
                  favoriteIds.contains(track.id)) {
                score += 80;
              }
              if (normalized.contains('recent') &&
                  recentIds.contains(track.id)) {
                score += 70;
              }
              if (normalized.contains('new') || normalized.contains('fresh')) {
                score += track.importedAt.millisecondsSinceEpoch ~/ 100000000;
              }
              if (normalized.contains('long') &&
                  (track.duration ?? Duration.zero) >=
                      const Duration(minutes: 4)) {
                score += 25;
              }
              if (normalized.contains('short') &&
                  (track.duration ?? Duration.zero) <=
                      const Duration(minutes: 3)) {
                score += 25;
              }

              return (track: track, score: score);
            })
            .where((entry) => entry.score > 0)
            .toList(growable: false)
          ..sort((a, b) {
            final compare = b.score.compareTo(a.score);
            if (compare != 0) {
              return compare;
            }
            return b.track.importedAt.compareTo(a.track.importedAt);
          });

    return scored.take(12).map((entry) => entry.track).toList(growable: false);
  }
}
