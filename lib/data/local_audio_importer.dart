import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
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

typedef AudioMetadataLoader =
    AudioMetadata Function(File file, {bool getImage});

class LocalImportSelection {
  const LocalImportSelection({
    required this.path,
    this.locator,
    this.bookmarkBase64,
    this.platform,
  });

  final String path;
  final String? locator;
  final String? bookmarkBase64;
  final String? platform;
}

class ImportedTrackPayload {
  const ImportedTrackPayload({required this.track, required this.source});

  final Track track;
  final TrackSourceRecord source;
}

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
    availability: TrackAvailability.available,
    lastValidatedAt: importedAt ?? DateTime.now(),
  );
}

Future<ImportedTrackPayload?> buildImportedTrackFromSelection(
  LocalImportSelection selection, {
  required String artworkCacheDirectory,
  DateTime? importedAt,
  AudioMetadataLoader metadataLoader = readMetadata,
}) async {
  if (!isSupportedAudioPath(selection.path)) {
    return null;
  }

  final fallbackTrack = buildTrackFromPath(
    selection.path,
    importedAt: importedAt,
  );
  final importedTimestamp = importedAt ?? DateTime.now();
  final audioFile = File(selection.path);

  try {
    if (!await audioFile.exists()) {
      return ImportedTrackPayload(
        track: fallbackTrack.copyWith(
          availability: TrackAvailability.unavailable,
          lastValidatedAt: importedTimestamp,
        ),
        source: TrackSourceRecord(
          trackId: fallbackTrack.id,
          platform: selection.platform ?? _defaultPlatformLabel(),
          locator: selection.locator ?? selection.path,
          bookmarkBase64: selection.bookmarkBase64,
        ),
      );
    }

    final metadata = metadataLoader(audioFile, getImage: true);
    final artworkUri = await _writeArtworkIfPresent(
      trackId: fallbackTrack.id,
      pictures: metadata.pictures,
      artworkCacheDirectory: artworkCacheDirectory,
    );

    final track = fallbackTrack.copyWith(
      title: _nonEmptyOr(metadata.title, fallbackTrack.title),
      artist: _nonEmptyOr(metadata.artist, fallbackTrack.artist),
      album: _nonEmptyOr(metadata.album, fallbackTrack.album),
      albumArtist: _nonEmptyOr(
        metadata.performers.isEmpty ? null : metadata.performers.first,
        metadata.artist,
      ),
      duration: metadata.duration,
      fileExtension: fallbackTrack.fileExtension,
      artworkUri: artworkUri,
      clearArtworkUri: artworkUri == null,
      genre: metadata.genres.isEmpty ? null : metadata.genres.first,
      clearGenre: metadata.genres.isEmpty,
      year: metadata.year?.year,
      clearYear: metadata.year == null,
      bitrate: metadata.bitrate,
      clearBitrate: metadata.bitrate == null,
      trackNumber: metadata.trackNumber,
      clearTrackNumber: metadata.trackNumber == null,
      discNumber: metadata.discNumber,
      clearDiscNumber: metadata.discNumber == null,
      availability: TrackAvailability.available,
      lastValidatedAt: importedTimestamp,
    );

    return ImportedTrackPayload(
      track: track,
      source: TrackSourceRecord(
        trackId: track.id,
        platform: selection.platform ?? _defaultPlatformLabel(),
        locator: selection.locator ?? selection.path,
        bookmarkBase64: selection.bookmarkBase64,
      ),
    );
  } catch (_) {
    return ImportedTrackPayload(
      track: fallbackTrack.copyWith(
        availability: TrackAvailability.available,
        lastValidatedAt: importedTimestamp,
      ),
      source: TrackSourceRecord(
        trackId: fallbackTrack.id,
        platform: selection.platform ?? _defaultPlatformLabel(),
        locator: selection.locator ?? selection.path,
        bookmarkBase64: selection.bookmarkBase64,
      ),
    );
  }
}

Track mergeImportedTrackWithExistingTrack({
  required Track existing,
  required Track imported,
}) {
  final fallback = buildTrackFromPath(
    existing.filePath,
    importedAt: existing.importedAt,
  );

  String chooseResolvedName({
    required String current,
    required String fallbackValue,
    required String importedValue,
  }) {
    if (current.trim().isEmpty) {
      return importedValue;
    }
    if (current == fallbackValue && importedValue != fallbackValue) {
      return importedValue;
    }
    return current;
  }

  return existing.copyWith(
    filePath: imported.filePath,
    fileName: imported.fileName,
    folderPath: imported.folderPath,
    title: chooseResolvedName(
      current: existing.title,
      fallbackValue: fallback.title,
      importedValue: imported.title,
    ),
    artist: chooseResolvedName(
      current: existing.artist,
      fallbackValue: fallback.artist,
      importedValue: imported.artist,
    ),
    album: chooseResolvedName(
      current: existing.album,
      fallbackValue: fallback.album,
      importedValue: imported.album,
    ),
    duration: existing.duration ?? imported.duration,
    fileExtension:
        (existing.fileExtension == null || existing.fileExtension!.isEmpty)
        ? imported.fileExtension
        : existing.fileExtension,
    artworkUri: existing.artworkUri ?? imported.artworkUri,
    albumArtist: _preferText(existing.albumArtist, imported.albumArtist),
    genre: _preferText(existing.genre, imported.genre),
    year: existing.year ?? imported.year,
    bitrate: existing.bitrate ?? imported.bitrate,
    trackNumber: existing.trackNumber ?? imported.trackNumber,
    discNumber: existing.discNumber ?? imported.discNumber,
    availability: imported.availability,
    lastValidatedAt: imported.lastValidatedAt ?? existing.lastValidatedAt,
    credits: existing.credits.isNotEmpty ? existing.credits : imported.credits,
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

Future<String?> _writeArtworkIfPresent({
  required String trackId,
  required List<Picture> pictures,
  required String artworkCacheDirectory,
}) async {
  if (pictures.isEmpty) {
    return null;
  }

  final picture = _selectBestPicture(pictures);
  if (picture == null || picture.bytes.isEmpty) {
    return null;
  }

  final extension = _extensionForMimetype(picture.mimetype);
  final directory = Directory(artworkCacheDirectory);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final artworkPath = path.join(
    artworkCacheDirectory,
    '${_stableSeed(trackId)}.$extension',
  );
  await File(
    artworkPath,
  ).writeAsBytes(Uint8List.fromList(picture.bytes), flush: true);
  return artworkPath;
}

Picture? _selectBestPicture(List<Picture> pictures) {
  for (final picture in pictures) {
    if (picture.pictureType == PictureType.coverFront) {
      return picture;
    }
  }

  return pictures.first;
}

String _extensionForMimetype(String mimetype) {
  final lowered = mimetype.toLowerCase();
  if (lowered.contains('png')) {
    return 'png';
  }
  if (lowered.contains('webp')) {
    return 'webp';
  }
  if (lowered.contains('gif')) {
    return 'gif';
  }
  return 'jpg';
}

String _defaultPlatformLabel() {
  if (Platform.isIOS) {
    return 'ios';
  }
  if (Platform.isMacOS) {
    return 'macos';
  }
  if (Platform.isAndroid) {
    return 'android';
  }
  return 'local';
}

String _stableSeed(String value) {
  final hash = value.codeUnits.fold<int>(
    0,
    (current, unit) => (current * 31 + unit) & 0x7fffffff,
  );
  return hash.toRadixString(16);
}

String? _nonEmptyOr(String? candidate, String? fallback) {
  final normalized = candidate?.trim();
  if (normalized == null || normalized.isEmpty) {
    return fallback;
  }
  return normalized;
}

String? _preferText(String? current, String? imported) {
  final normalizedCurrent = current?.trim();
  if (normalizedCurrent != null && normalizedCurrent.isNotEmpty) {
    return normalizedCurrent;
  }
  return _nonEmptyOr(imported, null);
}
