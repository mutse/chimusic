import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/music_models.dart';
import 'local_audio_importer.dart';

class ScopedTrackAccess {
  const ScopedTrackAccess({required this.path, required this.release});

  final String path;
  final Future<void> Function() release;
}

class AppleMediaAccessChannel {
  static const MethodChannel _channel = MethodChannel(
    'chimusic.apple_media_access',
  );

  bool get supportsNativePicker => !kIsWeb && Platform.isIOS;

  Future<List<LocalImportSelection>> pickAudioFiles() async {
    if (!supportsNativePicker) {
      return const <LocalImportSelection>[];
    }

    final result = await _channel.invokeListMethod<Object?>('pickAudioFiles');
    if (result == null) {
      return const <LocalImportSelection>[];
    }

    return result
        .whereType<Map<Object?, Object?>>()
        .map(
          (entry) => LocalImportSelection(
            path: (entry['path'] as String?) ?? '',
            bookmarkBase64: entry['bookmarkBase64'] as String?,
            platform: 'ios',
          ),
        )
        .where((entry) => entry.path.isNotEmpty)
        .toList(growable: false);
  }

  Future<ScopedTrackAccess?> beginAccess(TrackSourceRecord source) async {
    if (kIsWeb || !Platform.isIOS) {
      return ScopedTrackAccess(path: source.locator, release: () async {});
    }

    final bookmarkBase64 = source.bookmarkBase64;
    if (bookmarkBase64 == null || bookmarkBase64.isEmpty) {
      return ScopedTrackAccess(path: source.locator, release: () async {});
    }

    final response = await _channel.invokeMapMethod<String, Object?>(
      'startAccessingBookmark',
      <String, Object?>{'bookmarkBase64': bookmarkBase64},
    );
    final resolvedPath = response?['path'] as String?;
    if (resolvedPath == null || resolvedPath.isEmpty) {
      return null;
    }

    return ScopedTrackAccess(
      path: resolvedPath,
      release: () async {
        await _channel.invokeMethod<void>(
          'stopAccessingBookmark',
          <String, Object?>{'bookmarkBase64': bookmarkBase64},
        );
      },
    );
  }
}
