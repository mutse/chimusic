import 'dart:convert';

import '../models/music_models.dart';
import '../state/chimusic_controller.dart';

/// Output formats for exporting playback history.
///
/// Shared by the desktop and mobile shells so both surfaces produce identical
/// files.
enum HistoryExportFormat {
  csv('CSV', 'csv', 'chimusic-history.csv'),
  json('JSON', 'json', 'chimusic-history.json');

  const HistoryExportFormat(this.label, this.extension, this.suggestedFileName);

  final String label;
  final String extension;
  final String suggestedFileName;
}

/// Builds the export payload for [format] from the controller's history.
String buildHistoryExport(
  MusicAppController controller,
  HistoryExportFormat format,
) {
  return switch (format) {
    HistoryExportFormat.csv => buildHistoryCsv(controller),
    HistoryExportFormat.json => buildHistoryJson(controller),
  };
}

String buildHistoryCsv(MusicAppController controller) {
  final buffer = StringBuffer()
    ..writeln(
      'title,artist,album,play_count,last_played_at,resume_position,total_listened',
    );

  for (final track in controller.playbackHistoryTracks) {
    final entry = controller.playbackHistoryEntryForTrack(track.id);
    if (entry == null) {
      continue;
    }

    buffer.writeln(
      <String>[
        csvCell(track.title),
        csvCell(track.artist),
        csvCell(track.album),
        '${entry.playCount}',
        csvCell(entry.lastPlayedAt.toIso8601String()),
        csvCell(formatDuration(entry.lastPosition, placeholder: '00:00')),
        csvCell(formatDuration(entry.totalListened, placeholder: '00:00')),
      ].join(','),
    );
  }

  return buffer.toString();
}

String buildHistoryJson(MusicAppController controller) {
  final data = <String, Object?>{
    'generatedAt': DateTime.now().toIso8601String(),
    'tracks': controller.playbackHistoryTracks
        .map((track) {
          final entry = controller.playbackHistoryEntryForTrack(track.id);
          return <String, Object?>{
            'id': track.id,
            'title': track.title,
            'artist': track.artist,
            'album': track.album,
            'durationMs': track.duration?.inMilliseconds,
            'playCount': entry?.playCount ?? 0,
            'lastPlayedAt': entry?.lastPlayedAt.toIso8601String(),
            'resumePositionMs': entry?.lastPosition.inMilliseconds ?? 0,
            'totalListenedMs': entry?.totalListened.inMilliseconds ?? 0,
          };
        })
        .toList(growable: false),
    'events': controller.playbackEvents
        .map((event) {
          return <String, Object?>{
            'id': event.id,
            'trackId': event.trackId,
            'collectionId': event.collectionId,
            'startedAt': event.startedAt.toIso8601String(),
            'endedAt': event.endedAt?.toIso8601String(),
            'maxPositionMs': event.maxPosition.inMilliseconds,
            'endReason': event.endReason?.name,
          };
        })
        .toList(growable: false),
  };

  return const JsonEncoder.withIndent('  ').convert(data);
}

String csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
