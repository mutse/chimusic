import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chimusic/data/local_audio_importer.dart';

void main() {
  test('buildTrackFromPath derives title, artist, album, and extension', () {
    final track = buildTrackFromPath(
      '/Users/demo/Music/City Lights/Daft Punk - Voyager.flac',
      importedAt: DateTime(2026, 5, 5),
    );

    expect(track.title, 'Voyager');
    expect(track.artist, 'Daft Punk');
    expect(track.album, 'City Lights');
    expect(track.fileExtension, 'flac');
    expect(track.fileName, 'Daft Punk - Voyager.flac');
  });

  test(
    'collectAudioFilesFromDirectory returns only supported audio files',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'chimusic_importer_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final albumDir = Directory('${tempDir.path}/Album');
      await albumDir.create(recursive: true);

      await File('${tempDir.path}/track-one.mp3').writeAsString('audio');
      await File('${albumDir.path}/track-two.m4a').writeAsString('audio');
      await File('${albumDir.path}/cover.jpg').writeAsString('image');

      final result = await collectAudioFilesFromDirectory(tempDir.path);

      expect(
        result,
        containsAll(<String>[
          '${tempDir.path}/track-one.mp3',
          '${albumDir.path}/track-two.m4a',
        ]),
      );
      expect(result.any((path) => path.endsWith('.jpg')), isFalse);
    },
  );

  test(
    'buildImportedTrackFromSelection prefers metadata and writes artwork cache',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'chimusic_metadata_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final file = File('${tempDir.path}/Fallback Artist - Demo Track.mp3');
      await file.writeAsString('audio');

      final payload = await buildImportedTrackFromSelection(
        LocalImportSelection(
          path: file.path,
          platform: 'ios',
          bookmarkBase64: 'bookmark-token',
        ),
        artworkCacheDirectory: '${tempDir.path}/artwork',
        metadataLoader: (audioFile, {bool getImage = false}) {
          final metadata = AudioMetadata(
            file: audioFile,
            title: 'Wave Runner',
            artist: 'Neon Harbor',
            album: 'Night Transit',
            duration: const Duration(minutes: 4, seconds: 12),
            trackNumber: 7,
            discNumber: 1,
            bitrate: 320,
          );
          metadata.year = DateTime(2024);
          metadata.genres = ['Synthwave'];
          metadata.pictures = <Picture>[
            Picture(
              Uint8List.fromList(<int>[1, 2, 3, 4]),
              'image/png',
              PictureType.coverFront,
            ),
          ];
          return metadata;
        },
      );

      expect(payload, isNotNull);
      expect(payload!.track.title, 'Wave Runner');
      expect(payload.track.artist, 'Neon Harbor');
      expect(payload.track.album, 'Night Transit');
      expect(payload.track.genre, 'Synthwave');
      expect(payload.track.year, 2024);
      expect(payload.track.trackNumber, 7);
      expect(payload.track.discNumber, 1);
      expect(payload.track.bitrate, 320);
      expect(payload.track.artworkUri, isNotNull);
      expect(File(payload.track.artworkUri!).existsSync(), isTrue);
      expect(payload.source.platform, 'ios');
      expect(payload.source.bookmarkBase64, 'bookmark-token');
    },
  );

  test(
    'buildImportedTrackFromSelection falls back when metadata fields are empty',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'chimusic_fallback_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final file = File('${tempDir.path}/Daft Punk - Voyager.flac');
      await file.writeAsString('audio');

      final payload = await buildImportedTrackFromSelection(
        LocalImportSelection(path: file.path),
        artworkCacheDirectory: '${tempDir.path}/artwork',
        metadataLoader: (audioFile, {bool getImage = false}) {
          return AudioMetadata(file: audioFile);
        },
      );

      expect(payload, isNotNull);
      expect(payload!.track.title, 'Voyager');
      expect(payload.track.artist, 'Daft Punk');
      expect(payload.track.album, startsWith('chimusic fallback'));
      expect(payload.track.artworkUri, isNull);
    },
  );

  test(
    'mergeImportedTrackWithExistingTrack upgrades fallback names and fills missing metadata',
    () {
      final existing =
          buildTrackFromPath(
            '/Users/demo/Music/Fallback Album/Fallback Artist - Demo Song.mp3',
            importedAt: DateTime(2026, 5, 5),
          ).copyWith(
            duration: null,
            clearDuration: true,
            genre: null,
            clearGenre: true,
            artworkUri: null,
            clearArtworkUri: true,
          );
      final imported = existing.copyWith(
        title: 'Midnight Current',
        artist: 'North Coast',
        album: 'Sea Glass',
        duration: const Duration(minutes: 4, seconds: 8),
        genre: 'Ambient',
        albumArtist: 'North Coast',
        artworkUri: '/tmp/artwork.png',
        bitrate: 320,
        trackNumber: 5,
        discNumber: 1,
      );

      final merged = mergeImportedTrackWithExistingTrack(
        existing: existing,
        imported: imported,
      );

      expect(merged.title, 'Midnight Current');
      expect(merged.artist, 'North Coast');
      expect(merged.album, 'Sea Glass');
      expect(merged.duration, const Duration(minutes: 4, seconds: 8));
      expect(merged.genre, 'Ambient');
      expect(merged.albumArtist, 'North Coast');
      expect(merged.artworkUri, '/tmp/artwork.png');
      expect(merged.bitrate, 320);
      expect(merged.trackNumber, 5);
      expect(merged.discNumber, 1);
    },
  );
}
