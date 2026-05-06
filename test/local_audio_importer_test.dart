import 'dart:io';

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
}
