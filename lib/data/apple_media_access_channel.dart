import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/music_models.dart';
import 'local_audio_importer.dart';

class ScopedTrackAccess {
  const ScopedTrackAccess({
    required this.path,
    required this.release,
    this.refreshedBookmarkBase64,
  });

  final String path;
  final Future<void> Function() release;
  final String? refreshedBookmarkBase64;
}

class AppleMediaAccessChannel {
  static const MethodChannel _channel = MethodChannel(
    'chimusic.apple_media_access',
  );

  bool get supportsNativePicker =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  bool get supportsSecurityScopedBookmarks =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS || Platform.isAndroid);

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
            locator: entry['locator'] as String?,
            bookmarkBase64: entry['bookmarkBase64'] as String?,
            platform:
                (entry['platform'] as String?) ??
                (Platform.isAndroid ? 'android' : 'ios'),
          ),
        )
        .where((entry) => entry.path.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, String>> createBookmarksByPath(
    Iterable<String> paths,
  ) async {
    if (!supportsSecurityScopedBookmarks) {
      return const <String, String>{};
    }

    final uniquePaths = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniquePaths.isEmpty) {
      return const <String, String>{};
    }

    try {
      final result = await _channel.invokeListMethod<Object?>(
        'createBookmarks',
        <String, Object?>{'paths': uniquePaths},
      );
      if (result == null || result.isEmpty) {
        return const <String, String>{};
      }

      final bookmarksByPath = <String, String>{};
      for (final entry in result.whereType<Map<Object?, Object?>>()) {
        final path = entry['path'] as String?;
        final bookmarkBase64 = entry['bookmarkBase64'] as String?;
        if (path == null ||
            path.isEmpty ||
            bookmarkBase64 == null ||
            bookmarkBase64.isEmpty) {
          continue;
        }
        bookmarksByPath[path] = bookmarkBase64;
      }
      return bookmarksByPath;
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<List<LocalImportSelection>> attachPersistentBookmarks(
    List<LocalImportSelection> selections,
  ) async {
    if (selections.isEmpty) {
      return selections;
    }

    final missingBookmarkPaths = selections
        .where(
          (selection) =>
              (selection.locator ?? selection.path).isNotEmpty &&
              (selection.bookmarkBase64 == null ||
                  selection.bookmarkBase64!.isEmpty),
        )
        .map((selection) => selection.locator ?? selection.path);
    final bookmarksByPath = await createBookmarksByPath(missingBookmarkPaths);
    if (bookmarksByPath.isEmpty) {
      return selections;
    }

    return selections
        .map((selection) {
          final existingBookmark = selection.bookmarkBase64;
          if (existingBookmark != null && existingBookmark.isNotEmpty) {
            return selection;
          }

          final bookmarkBase64 =
              bookmarksByPath[selection.locator ?? selection.path];
          if (bookmarkBase64 == null || bookmarkBase64.isEmpty) {
            return selection;
          }

          return LocalImportSelection(
            path: selection.path,
            locator: selection.locator,
            bookmarkBase64: bookmarkBase64,
            platform: selection.platform,
          );
        })
        .toList(growable: false);
  }

  Future<ScopedTrackAccess?> beginAccess(TrackSourceRecord source) async {
    if (!supportsSecurityScopedBookmarks) {
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
      refreshedBookmarkBase64: response?['bookmarkBase64'] as String?,
      release: () async {
        await _channel.invokeMethod<void>(
          'stopAccessingBookmark',
          <String, Object?>{'bookmarkBase64': bookmarkBase64},
        );
      },
    );
  }
}
