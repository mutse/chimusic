import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../models/music_models.dart';

const List<String> supportedAudioExtensions = <String>[
  'mp3',
  'm4a',
  'aac',
  'wav',
  'flac',
  'ogg',
  'opus',
];

const XTypeGroup localAudioTypeGroup = XTypeGroup(
  label: 'Audio',
  extensions: supportedAudioExtensions,
  uniformTypeIdentifiers: <String>['public.audio'],
);

bool isSupportedAudioPath(String filePath) {
  final extension = path
      .extension(filePath)
      .replaceFirst('.', '')
      .toLowerCase();
  return supportedAudioExtensions.contains(extension);
}

Track buildTrackFromPath(String filePath, {DateTime? importedAt}) {
  final normalizedPath = path.normalize(filePath);
  final folderPath = path.dirname(normalizedPath);
  final folderName = _displayFolderName(path.basename(folderPath));
  final fileName = path.basename(normalizedPath);
  final fileExtension = path
      .extension(normalizedPath)
      .replaceFirst('.', '')
      .toLowerCase();
  final stem = path.basenameWithoutExtension(normalizedPath);
  final parsed = _parseTrackName(stem, folderName);

  return Track(
    id: normalizedPath,
    filePath: normalizedPath,
    fileName: fileName,
    folderPath: folderPath,
    title: parsed.title,
    artist: parsed.artist,
    album: folderName.isEmpty ? 'Imported Audio' : folderName,
    palette: buildTrackPalette(normalizedPath),
    importedAt: importedAt ?? DateTime.now(),
    fileExtension: fileExtension,
  );
}

Future<List<String>> collectAudioFilesFromDirectory(
  String directoryPath,
) async {
  final result = <String>[];

  await for (final entity in Directory(
    directoryPath,
  ).list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }

    if (isSupportedAudioPath(entity.path)) {
      result.add(entity.path);
    }
  }

  result.sort();
  return result;
}

List<Color> buildTrackPalette(String seed) {
  final hash = seed.codeUnits.fold<int>(
    0,
    (value, codeUnit) => (value * 31 + codeUnit) & 0x7fffffff,
  );
  final hue = (hash % 360).toDouble();

  return <Color>[
    HSVColor.fromAHSV(1, hue, 0.60, 0.92).toColor(),
    HSVColor.fromAHSV(1, (hue + 42) % 360, 0.50, 0.66).toColor(),
    HSVColor.fromAHSV(1, (hue + 84) % 360, 0.72, 0.24).toColor(),
  ];
}

({String title, String artist}) _parseTrackName(
  String stem,
  String folderName,
) {
  final sanitizedStem = _sanitizeName(stem);
  final separator = sanitizedStem.contains(' - ') ? ' - ' : null;

  if (separator != null) {
    final parts = sanitizedStem.split(separator);
    if (parts.length >= 2) {
      final artist = parts.first.trim();
      final title = parts.skip(1).join(separator).trim();
      if (artist.isNotEmpty && title.isNotEmpty) {
        return (title: title, artist: artist);
      }
    }
  }

  return (
    title: sanitizedStem,
    artist: folderName.isEmpty ? 'Local Music' : folderName,
  );
}

String _displayFolderName(String rawFolderName) {
  if (rawFolderName.isEmpty ||
      rawFolderName == '.' ||
      rawFolderName == path.separator) {
    return '';
  }

  return _sanitizeName(rawFolderName);
}

String _sanitizeName(String value) {
  final collapsed = value
      .replaceAll(RegExp(r'[_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  return collapsed.trim().isEmpty ? 'Untitled' : collapsed.trim();
}
