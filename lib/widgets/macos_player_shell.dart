import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app/chimusic_branding.dart';
import '../models/music_models.dart';
import '../screens/app_details_sheet.dart';
import '../screens/collection_detail_page.dart';
import '../state/chimusic_controller.dart';
import '../state/chimusic_scope.dart';
import 'glass.dart';
import 'local_music_widgets.dart';

enum _DesktopPage { home, library, nowPlaying, history }

enum _HistoryExportFormat {
  csv('CSV', 'csv', 'chimusic-history.csv'),
  json('JSON', 'json', 'chimusic-history.json');

  const _HistoryExportFormat(
    this.label,
    this.extension,
    this.suggestedFileName,
  );

  final String label;
  final String extension;
  final String suggestedFileName;
}

List<Color> _desktopTrackPalette(Track? track) {
  final palette = track?.palette;
  if (palette == null || palette.isEmpty) {
    return <Color>[
      _DesktopPalette.accent,
      _DesktopPalette.accentSoft,
      _DesktopPalette.bg3,
    ];
  }
  return palette;
}

class _ArtworkFlight {
  const _ArtworkFlight({
    required this.track,
    required this.fromRect,
    required this.toRect,
  });

  final Track track;
  final Rect fromRect;
  final Rect toRect;

  _ArtworkFlight copyWith({Rect? toRect}) {
    return _ArtworkFlight(
      track: track,
      fromRect: fromRect,
      toRect: toRect ?? this.toRect,
    );
  }
}

class MacosPlayerShell extends StatefulWidget {
  const MacosPlayerShell({super.key});

  @override
  State<MacosPlayerShell> createState() => _MacosPlayerShellState();
}

class _MacosPlayerShellState extends State<MacosPlayerShell>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _librarySearchController;
  late final AnimationController _artworkFlightController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  final GlobalKey _shellStackKey = GlobalKey();
  final GlobalKey _playerArtworkKey = GlobalKey();
  final GlobalKey _nowPlayingArtworkKey = GlobalKey();
  var _page = _DesktopPage.home;
  bool _didBootstrap = false;
  bool _hidePlayerArtwork = false;
  bool _hideNowPlayingArtwork = false;
  Timer? _toastTimer;
  String? _observedStatusMessage;
  _ArtworkFlight? _artworkFlight;

  @override
  void initState() {
    super.initState();
    _librarySearchController = TextEditingController();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _artworkFlightController.dispose();
    _librarySearchController.dispose();
    super.dispose();
  }

  void _bootstrapFromController(MusicAppController controller) {
    if (_didBootstrap) {
      return;
    }

    _page = switch (controller.selectedTab) {
      MusicTab.library || MusicTab.search => _DesktopPage.library,
      _ => _DesktopPage.home,
    };
    _librarySearchController.text = controller.searchQuery;
    _didBootstrap = true;
  }

  void _setPage(_DesktopPage page, MusicAppController controller) {
    if (_page == page) {
      return;
    }

    setState(() {
      _page = page;
    });

    switch (page) {
      case _DesktopPage.home:
        controller.selectTab(MusicTab.home);
      case _DesktopPage.library:
        controller.selectTab(MusicTab.library);
      case _DesktopPage.nowPlaying:
      case _DesktopPage.history:
        break;
    }
  }

  Rect? _rectForKey(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final shellBox =
        _shellStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || shellBox == null || !box.hasSize || !shellBox.hasSize) {
      return null;
    }

    final topLeft = box.localToGlobal(Offset.zero, ancestor: shellBox);
    return topLeft & box.size;
  }

  Future<void> _awaitFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }

  Future<void> _openNowPlayingWithArtworkFlight(
    MusicAppController controller,
  ) async {
    final track = controller.currentTrack;
    if (track == null) {
      _setPage(_DesktopPage.nowPlaying, controller);
      return;
    }
    if (_page == _DesktopPage.nowPlaying) {
      return;
    }

    final fromRect = _rectForKey(_playerArtworkKey);
    if (fromRect == null) {
      _setPage(_DesktopPage.nowPlaying, controller);
      return;
    }

    _artworkFlightController.stop();
    _artworkFlightController.value = 0;

    setState(() {
      _page = _DesktopPage.nowPlaying;
      _hidePlayerArtwork = true;
      _hideNowPlayingArtwork = true;
      _artworkFlight = _ArtworkFlight(
        track: track,
        fromRect: fromRect,
        toRect: fromRect,
      );
    });

    await _awaitFrame();
    await _awaitFrame();
    if (!mounted) {
      return;
    }
    if (controller.currentTrack?.id != track.id) {
      setState(() {
        _artworkFlight = null;
        _hidePlayerArtwork = false;
        _hideNowPlayingArtwork = false;
      });
      return;
    }

    final toRect = _rectForKey(_nowPlayingArtworkKey);
    if (toRect == null) {
      setState(() {
        _artworkFlight = null;
        _hidePlayerArtwork = false;
        _hideNowPlayingArtwork = false;
      });
      return;
    }

    setState(() {
      _artworkFlight = _artworkFlight?.copyWith(toRect: toRect);
    });

    await _artworkFlightController.forward(from: 0);
    if (!mounted) {
      return;
    }

    setState(() {
      _artworkFlight = null;
      _hidePlayerArtwork = false;
      _hideNowPlayingArtwork = false;
    });
  }

  List<Track> _resolveLibraryTracks(MusicAppController controller) {
    final query = controller.searchQuery.trim().toLowerCase();
    final tracks = controller.importedTracks
        .where((track) {
          if (query.isEmpty) {
            return true;
          }

          final haystack = <String>[
            track.title,
            track.artist,
            track.album,
            track.fileName,
            track.genre ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);

    final sorted = List<Track>.from(tracks);
    switch (controller.librarySort) {
      case LibrarySort.recent:
        sorted.sort((a, b) => b.importedAt.compareTo(a.importedAt));
        break;
      case LibrarySort.title:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case LibrarySort.length:
        sorted.sort(
          (a, b) => (b.duration ?? Duration.zero).compareTo(
            a.duration ?? Duration.zero,
          ),
        );
        break;
    }

    return sorted;
  }

  Future<void> _exportHistory(
    MusicAppController controller,
    _HistoryExportFormat format,
  ) async {
    final location = await getSaveLocation(
      suggestedName: format.suggestedFileName,
      confirmButtonText: '导出',
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(label: format.label, extensions: <String>[format.extension]),
      ],
    );
    if (location == null) {
      return;
    }

    final payload = switch (format) {
      _HistoryExportFormat.csv => _buildHistoryCsv(controller),
      _HistoryExportFormat.json => _buildHistoryJson(controller),
    };

    try {
      await File(location.path).writeAsString(payload);
      if (!mounted) {
        return;
      }

      controller.setStatusMessage('已导出播放记录到 ${location.path}');
    } catch (_) {
      if (!mounted) {
        return;
      }
      controller.setStatusMessage('导出播放记录失败，请重试。');
    }
  }

  String _buildHistoryCsv(MusicAppController controller) {
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
          _csvCell(track.title),
          _csvCell(track.artist),
          _csvCell(track.album),
          '${entry.playCount}',
          _csvCell(entry.lastPlayedAt.toIso8601String()),
          _csvCell(formatDuration(entry.lastPosition, placeholder: '00:00')),
          _csvCell(formatDuration(entry.totalListened, placeholder: '00:00')),
        ].join(','),
      );
    }

    return buffer.toString();
  }

  String _buildHistoryJson(MusicAppController controller) {
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

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  void _syncStatusLifecycle(MusicAppController controller) {
    final message = controller.statusMessage;
    if (_observedStatusMessage == message) {
      return;
    }

    _observedStatusMessage = message;
    _toastTimer?.cancel();
    if (message == null || message.trim().isEmpty) {
      return;
    }

    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      if (controller.statusMessage == message) {
        controller.clearStatusMessage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    _bootstrapFromController(controller);
    _syncStatusLifecycle(controller);
    _DesktopPalette.syncWith(
      controller.themeMode == AppThemeMode.light
          ? Brightness.light
          : Brightness.dark,
    );

    return Scaffold(
      backgroundColor: _DesktopPalette.bg0,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _DesktopPalette.bg0,
              _DesktopPalette.backdropMid,
              _DesktopPalette.backdropEnd,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            key: _shellStackKey,
            children: [
              Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 260,
                          child: _DesktopSidebar(
                            page: _page,
                            onSelectPage: (page) => _setPage(page, controller),
                          ),
                        ),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: _DesktopPalette.border),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.02),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey(_page),
                                child: switch (_page) {
                                  _DesktopPage.home => _DesktopHomePage(
                                    onOpenLibrary: () => _setPage(
                                      _DesktopPage.library,
                                      controller,
                                    ),
                                    onOpenNowPlaying: () => _setPage(
                                      _DesktopPage.nowPlaying,
                                      controller,
                                    ),
                                  ),
                                  _DesktopPage.library => _DesktopLibraryPage(
                                    controller: controller,
                                    searchController: _librarySearchController,
                                    tracks: _resolveLibraryTracks(controller),
                                    onSearchChanged: (value) {
                                      controller.updateSearchQuery(value);
                                    },
                                    onClearSearch: () {
                                      _librarySearchController.clear();
                                      controller.clearSearch();
                                    },
                                  ),
                                  _DesktopPage.nowPlaying =>
                                    _DesktopNowPlayingPage(
                                      artworkKey: _nowPlayingArtworkKey,
                                      hideArtwork: _hideNowPlayingArtwork,
                                      onOpenLibrary: () => _setPage(
                                        _DesktopPage.library,
                                        controller,
                                      ),
                                    ),
                                  _DesktopPage.history => _DesktopHistoryPage(
                                    onExport: (format) =>
                                        _exportHistory(controller, format),
                                    onOpenLibrary: () => _setPage(
                                      _DesktopPage.library,
                                      controller,
                                    ),
                                  ),
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _DesktopPlayerBar(
                    artworkKey: _playerArtworkKey,
                    hideArtwork: _hidePlayerArtwork,
                    onOpenNowPlaying: () =>
                        _openNowPlayingWithArtworkFlight(controller),
                  ),
                ],
              ),
              if (_artworkFlight case final flight?)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _artworkFlightController,
                      builder: (context, child) {
                        return _ArtworkFlightOverlay(
                          flight: flight,
                          progress: Curves.easeInOutCubic.transform(
                            _artworkFlightController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 116,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.16),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: controller.statusMessage == null
                        ? const SizedBox.shrink()
                        : _DesktopToast(
                            key: ValueKey(controller.statusMessage),
                            message: controller.statusMessage!,
                            onClose: controller.clearStatusMessage,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.page, required this.onSelectPage});

  final _DesktopPage page;
  final ValueChanged<_DesktopPage> onSelectPage;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final collections = controller.pinnedCollections;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      color: _DesktopPalette.bg1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3.2,
                      ),
                      children: [
                        TextSpan(
                          text: '$chimusicAppName ',
                          style: TextStyle(color: _DesktopPalette.accent),
                        ),
                        TextSpan(
                          text: 'player',
                          style: TextStyle(
                            color: _DesktopPalette.textMuted,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _RoundIconButton(
                  icon: controller.themeMode == AppThemeMode.light
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  tooltip: controller.themeMode == AppThemeMode.light
                      ? '切换到深色'
                      : '切换到浅色',
                  onTap: () {
                    controller.toggleThemeMode();
                    controller.setStatusMessage(
                      controller.themeMode == AppThemeMode.light
                          ? '已切换到浅色外观。'
                          : '已切换到深色外观。',
                    );
                  },
                ),
                const SizedBox(width: 8),
                _RoundIconButton(
                  icon: Icons.info_outline_rounded,
                  tooltip: 'App details',
                  onTap: () => AppDetailsSheet.show(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _DesktopPalette.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Column(
              children: [
                _SidebarNavButton(
                  label: '首页',
                  icon: Icons.home_outlined,
                  selected: page == _DesktopPage.home,
                  onTap: () => onSelectPage(_DesktopPage.home),
                ),
                _SidebarNavButton(
                  label: '音乐库',
                  icon: Icons.library_music_outlined,
                  selected: page == _DesktopPage.library,
                  onTap: () => onSelectPage(_DesktopPage.library),
                ),
                _SidebarNavButton(
                  label: '正在播放',
                  icon: Icons.play_circle_outline_rounded,
                  selected: page == _DesktopPage.nowPlaying,
                  onTap: () => onSelectPage(_DesktopPage.nowPlaying),
                ),
                _SidebarNavButton(
                  label: '播放记录',
                  icon: Icons.history_rounded,
                  selected: page == _DesktopPage.history,
                  onTap: () => onSelectPage(_DesktopPage.history),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
            child: Text(
              '播放列表',
              style: _DesktopTypography.overline.copyWith(
                color: _DesktopPalette.textFaint,
              ),
            ),
          ),
          Expanded(
            child: collections.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Text(
                      '收藏夹、最近收听和导入目录会出现在这里。',
                      style: _DesktopTypography.body.copyWith(
                        color: _DesktopPalette.textMuted,
                        height: 1.5,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: collections.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final collection = collections[index];
                      final active =
                          controller.currentCollection?.id == collection.id;
                      return _SidebarCollectionButton(
                        collection: collection,
                        active: active,
                      );
                    },
                  ),
          ),
          Divider(height: 1, color: _DesktopPalette.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '导入本地音乐',
                  style: _DesktopTypography.body.copyWith(
                    color: _DesktopPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ImportMusicActions(controller: controller, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopHomePage extends StatelessWidget {
  const _DesktopHomePage({
    required this.onOpenLibrary,
    required this.onOpenNowPlaying,
  });

  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenNowPlaying;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final heroTrack =
        controller.currentTrack ??
        (controller.continueListeningTracks.isEmpty
            ? null
            : controller.continueListeningTracks.first);
    final recentTracks = controller.recentImportedTracks.take(6).toList();
    final topTracks = controller.playbackHistoryTracks.take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroPanel(
            controller: controller,
            track: heroTrack,
            onOpenLibrary: onOpenLibrary,
            onOpenNowPlaying: onOpenNowPlaying,
          ),
          const SizedBox(height: 34),
          _PageSectionTitle(
            title: '最近添加',
            trailing: TextButton(
              onPressed: onOpenLibrary,
              child: const Text('查看全部'),
            ),
          ),
          const SizedBox(height: 16),
          if (recentTracks.isEmpty)
            _EmptyStateCard(
              icon: Icons.library_music_outlined,
              title: '你的音乐库还是空的',
              body: '从左侧导入文件或文件夹后，这里会自动展示最近加入的歌曲。',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentTracks.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                childAspectRatio: 0.78,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final track = recentTracks[index];
                return _RecentTrackCard(track: track);
              },
            ),
          if (topTracks.isNotEmpty) ...[
            const SizedBox(height: 34),
            const _PageSectionTitle(title: '最常播放'),
            const SizedBox(height: 16),
            _SurfaceCard(
              child: Column(
                children: [
                  for (var index = 0; index < topTracks.length; index++) ...[
                    _DesktopTrackRow(
                      track: topTracks[index],
                      indexLabel: '${index + 1}',
                      showAlbum: true,
                      trailing: Text(
                        '${controller.playbackHistoryEntryForTrack(topTracks[index].id)?.playCount ?? 0} 次',
                        style: _DesktopTypography.mono.copyWith(
                          color: _DesktopPalette.textMuted,
                        ),
                      ),
                      onTap: () => controller.resumeTrack(topTracks[index]),
                    ),
                    if (index != topTracks.length - 1)
                      Divider(height: 1, color: _DesktopPalette.border),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopLibraryPage extends StatelessWidget {
  const _DesktopLibraryPage({
    required this.controller,
    required this.searchController,
    required this.tracks,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final MusicAppController controller;
  final TextEditingController searchController;
  final List<Track> tracks;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final queryActive = controller.searchQuery.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 34, 40, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Text('音乐库', style: _DesktopTypography.display),
                    _Tag(label: '${tracks.length}'),
                  ],
                ),
              ),
              _RoundIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'App details',
                onTap: () => AppDetailsSheet.show(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SurfaceCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: _SearchField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    onClear: onClearSearch,
                  ),
                ),
                const SizedBox(width: 12),
                _SortDropdown(
                  value: controller.librarySort,
                  onChanged: controller.setLibrarySort,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _DesktopPalette.border)),
            ),
            child: Row(
              children: [
                SizedBox(width: 32),
                SizedBox(width: 56),
                Expanded(child: Text('歌曲', style: _DesktopTypography.overline)),
                SizedBox(
                  width: 160,
                  child: Text(
                    '专辑',
                    style: _DesktopTypography.overline,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '时长',
                    style: _DesktopTypography.overline,
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: 36),
              ],
            ),
          ),
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: _EmptyStateCard(
                      icon: queryActive
                          ? Icons.search_off_rounded
                          : Icons.audio_file_outlined,
                      title: queryActive ? '没有匹配结果' : '还没有音乐',
                      body: queryActive
                          ? '试试按歌曲名、歌手、专辑或文件名搜索。'
                          : '从左侧导入音频文件后，这里会显示完整曲库。',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    itemCount: tracks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return _DesktopTrackRow(
                        track: track,
                        indexLabel: '${index + 1}',
                        showAlbum: true,
                        revealTrailingOnHover: true,
                        trailing: IconButton(
                          tooltip: controller.isTrackLiked(track.id)
                              ? '取消喜欢'
                              : '加入喜欢',
                          onPressed: () =>
                              controller.toggleLikedTrack(track.id),
                          icon: Icon(
                            controller.isTrackLiked(track.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: controller.isTrackLiked(track.id)
                                ? _DesktopPalette.accent
                                : _DesktopPalette.textMuted,
                            size: 18,
                          ),
                        ),
                        onTap: () => controller.playTrack(track),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNowPlayingPage extends StatelessWidget {
  const _DesktopNowPlayingPage({
    required this.onOpenLibrary,
    required this.artworkKey,
    required this.hideArtwork,
  });

  final VoidCallback onOpenLibrary;
  final GlobalKey artworkKey;
  final bool hideArtwork;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = controller.currentTrack;
    final collection = track == null
        ? null
        : (controller.currentCollection ??
              controller.collectionForTrack(track));

    if (track == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: _EmptyStateCard(
            icon: Icons.play_circle_outline_rounded,
            title: '还没有正在播放的歌曲',
            body: '从首页或音乐库选择一首歌后，这里会显示完整播放信息和接下来的队列。',
            actionLabel: '打开音乐库',
            onAction: onOpenLibrary,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 720),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ...previousChildren,
                ...?switch (currentChild) {
                  null => null,
                  final child => <Widget>[child],
                },
              ],
            );
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _NowPlayingAtmosphere(
            key: ValueKey('np-atmo-${track.id}'),
            track: track,
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('正在播放', style: _DesktopTypography.display),
                  ),
                  _Tag(label: collection?.title ?? 'Current Queue'),
                ],
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 560),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      ...?switch (currentChild) {
                        null => null,
                        final child => <Widget>[child],
                      },
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.988,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _NowPlayingReveal(
                  key: ValueKey('np-hero-${track.id}'),
                  delay: const Duration(milliseconds: 40),
                  child: _NowPlayingHeroSurface(
                    track: track,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 920;

                        final art = _NowPlayingReveal(
                          key: ValueKey('np-art-${track.id}'),
                          beginOffset: stacked
                              ? const Offset(0, 0.05)
                              : const Offset(-0.04, 0),
                          child: Opacity(
                            opacity: hideArtwork ? 0 : 1,
                            child: KeyedSubtree(
                              key: artworkKey,
                              child: _NowPlayingArtworkSpotlight(
                                track: track,
                                size: stacked ? 240 : 280,
                                isPlaying: controller.isPlaying,
                              ),
                            ),
                          ),
                        );

                        final meta = _NowPlayingReveal(
                          key: ValueKey('np-meta-${track.id}'),
                          delay: const Duration(milliseconds: 90),
                          beginOffset: stacked
                              ? const Offset(0, 0.05)
                              : const Offset(0.04, 0),
                          child: _NowPlayingMeta(
                            track: track,
                            collection: collection,
                          ),
                        );

                        if (stacked) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(child: art),
                              const SizedBox(height: 24),
                              meta,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            art,
                            const SizedBox(width: 28),
                            Expanded(child: meta),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 480),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.028),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _NowPlayingReveal(
                  key: ValueKey('np-next-${track.id}'),
                  delay: const Duration(milliseconds: 170),
                  beginOffset: const Offset(0, 0.04),
                  child: _NowPlayingQueueSurface(
                    track: track,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('接下来播放', style: _DesktopTypography.section),
                        const SizedBox(height: 14),
                        if (controller.upNext.isEmpty)
                          Text(
                            '当前队列在这首歌后没有更多内容了。',
                            style: _DesktopTypography.body.copyWith(
                              color: _DesktopPalette.textMuted,
                            ),
                          )
                        else
                          Column(
                            children: [
                              for (
                                var index = 0;
                                index < controller.upNext.length;
                                index++
                              ) ...[
                                _DesktopTrackRow(
                                  track: controller.upNext[index],
                                  indexLabel: '${index + 1}',
                                  showAlbum: false,
                                  trailing: Text(
                                    formatDuration(
                                      controller.upNext[index].duration,
                                    ),
                                    style: _DesktopTypography.mono.copyWith(
                                      color: _DesktopPalette.textMuted,
                                    ),
                                  ),
                                  onTap: () => controller.playTrack(
                                    controller.upNext[index],
                                    collection: controller.currentCollection,
                                  ),
                                ),
                                if (index != controller.upNext.length - 1)
                                  Divider(
                                    height: 1,
                                    color: _DesktopPalette.border,
                                  ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopHistoryPage extends StatelessWidget {
  const _DesktopHistoryPage({
    required this.onOpenLibrary,
    required this.onExport,
  });

  final VoidCallback onOpenLibrary;
  final Future<void> Function(_HistoryExportFormat format) onExport;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final historyTracks = controller.playbackHistoryTracks;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('播放记录', style: _DesktopTypography.display)),
              TextButton.icon(
                onPressed: historyTracks.isEmpty
                    ? null
                    : () => onExport(_HistoryExportFormat.csv),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('导出 CSV'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: historyTracks.isEmpty
                    ? null
                    : () => onExport(_HistoryExportFormat.json),
                icon: const Icon(Icons.data_object_rounded, size: 18),
                label: const Text('导出 JSON'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: historyTracks.isEmpty
                    ? null
                    : controller.clearPlaybackHistory,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('清空记录'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 1440 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.7,
            children: [
              _StatCard(value: '${controller.totalPlayCount}', label: '总播放次数'),
              _StatCard(
                value: '${controller.playbackHistoryCount}',
                label: '有记录的歌曲',
              ),
              _StatCard(
                value: '${controller.resumeTracks.length}',
                label: '可继续收听',
              ),
              _StatCard(
                value: '${controller.playbackEvents.length}',
                label: '播放会话',
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (historyTracks.isEmpty)
            _EmptyStateCard(
              icon: Icons.history_rounded,
              title: '还没有播放记录',
              body: '开始播放音乐后，这里会自动记录最近播放与恢复位置。',
              actionLabel: '打开音乐库',
              onAction: onOpenLibrary,
            )
          else
            _SurfaceCard(
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < historyTracks.length;
                    index++
                  ) ...[
                    _HistoryRow(track: historyTracks[index]),
                    if (index != historyTracks.length - 1)
                      Divider(height: 1, color: _DesktopPalette.border),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopPlayerBar extends StatelessWidget {
  const _DesktopPlayerBar({
    required this.onOpenNowPlaying,
    required this.artworkKey,
    required this.hideArtwork,
  });

  final VoidCallback onOpenNowPlaying;
  final GlobalKey artworkKey;
  final bool hideArtwork;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = controller.currentTrack;
    final collection = track == null
        ? null
        : (controller.currentCollection ??
              controller.collectionForTrack(track));
    final palette = _desktopTrackPalette(track);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      height: 108,
      decoration: BoxDecoration(
        color: _DesktopPalette.bg1,
        border: Border(top: BorderSide(color: _DesktopPalette.border)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _DesktopPlayerBarBackdrop(
              track: track,
              isPlaying: controller.isPlaying,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: InkWell(
                    onTap: track == null ? null : onOpenNowPlaying,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        _MiniNowPlayingArtwork(
                          key: artworkKey,
                          track: track,
                          isPlaying: controller.isPlaying,
                          hidden: hideArtwork,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.06),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Column(
                              key: ValueKey(
                                'player-meta-${track?.id ?? 'empty'}-${controller.isPlaying}-${collection?.id ?? 'none'}',
                              ),
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (track != null &&
                                        controller.isPlaying) ...[
                                      _WaveBars(
                                        height: 10,
                                        color: palette.first,
                                        minFactor: 0.26,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      track == null
                                          ? '准备就绪'
                                          : (controller.isPlaying
                                                ? '正在播放'
                                                : '已暂停'),
                                      style: _DesktopTypography.mono.copyWith(
                                        color: palette.first,
                                      ),
                                    ),
                                    if (track != null &&
                                        collection != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: _DesktopPalette.textFaint,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          collection.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: _DesktopTypography.small
                                              .copyWith(
                                                color:
                                                    _DesktopPalette.textMuted,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  track?.title ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _DesktopTypography.body.copyWith(
                                    color: _DesktopPalette.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  track == null
                                      ? '选择一首歌曲开始聆听'
                                      : '${track.artist} • ${track.album}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _DesktopTypography.small.copyWith(
                                    color: _DesktopPalette.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TransportToggleButton(
                            icon: Icons.shuffle_rounded,
                            enabled: controller.hasMusic,
                            selected: controller.isShuffleEnabled,
                            tooltip: controller.isShuffleEnabled
                                ? '关闭随机播放'
                                : '开启随机播放',
                            onTap: controller.toggleShuffle,
                          ),
                          const SizedBox(width: 10),
                          _TransportButton(
                            icon: Icons.skip_previous_rounded,
                            enabled: track != null,
                            tooltip: '上一首 / 重新开始',
                            onTap: controller.skipPrevious,
                          ),
                          const SizedBox(width: 10),
                          _TransportButton(
                            icon: controller.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            filled: true,
                            enabled: controller.hasMusic,
                            tooltip: controller.isPlaying ? '暂停' : '播放',
                            onTap: controller.togglePlayPause,
                          ),
                          const SizedBox(width: 10),
                          _TransportButton(
                            icon: Icons.skip_next_rounded,
                            enabled: controller.canSkipNext,
                            tooltip: controller.canSkipNext
                                ? '下一首'
                                : '队列中没有下一首',
                            onTap: controller.skipNext,
                          ),
                          const SizedBox(width: 10),
                          _TransportToggleButton(
                            icon: Icons.repeat_rounded,
                            enabled: controller.hasMusic,
                            selected: controller.isRepeatEnabled,
                            tooltip: controller.isRepeatEnabled
                                ? '关闭循环播放'
                                : '开启循环播放',
                            onTap: controller.toggleRepeat,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 42,
                            child: Text(
                              formatDuration(
                                controller.position,
                                placeholder: '00:00',
                              ),
                              style: _DesktopTypography.mono.copyWith(
                                color: _DesktopPalette.textFaint,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _InteractiveProgressBar(
                              progress: controller.playbackProgress,
                              palette: palette,
                              isPlaying: controller.isPlaying,
                              onSeek: track == null
                                  ? null
                                  : (value) {
                                      controller.seekToFraction(value);
                                    },
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              formatDuration(track?.duration),
                              textAlign: TextAlign.right,
                              style: _DesktopTypography.mono.copyWith(
                                color: _DesktopPalette.textFaint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 244,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              if (collection != null)
                                _PlayerModePill(
                                  icon: Icons.queue_music_rounded,
                                  label: collection.title,
                                  color: palette.first,
                                ),
                              if (controller.isShuffleEnabled)
                                _PlayerModePill(
                                  icon: Icons.shuffle_rounded,
                                  label: 'Shuffle',
                                  color: palette.first,
                                ),
                              if (controller.isRepeatEnabled)
                                _PlayerModePill(
                                  icon: Icons.repeat_rounded,
                                  label: 'Repeat',
                                  color: palette.first,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  controller.volume <= 0.01
                                      ? Icons.volume_off_rounded
                                      : controller.volume < 0.5
                                      ? Icons.volume_down_rounded
                                      : Icons.volume_up_rounded,
                                  key: ValueKey<int>(
                                    controller.volume <= 0.01
                                        ? 0
                                        : (controller.volume < 0.5 ? 1 : 2),
                                  ),
                                  color: _DesktopPalette.textMuted,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    activeTrackColor: palette.first,
                                    inactiveTrackColor: _DesktopPalette.bg4,
                                    thumbColor: _DesktopPalette.textPrimary,
                                    overlayShape:
                                        SliderComponentShape.noOverlay,
                                  ),
                                  child: Slider(
                                    value: controller.volume,
                                    onChanged: controller.setVolume,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _TransportButton(
                                icon: Icons.open_in_full_rounded,
                                enabled: track != null,
                                tooltip: track == null
                                    ? '选择歌曲后可展开播放页'
                                    : '展开播放页',
                                onTap: () async {
                                  onOpenNowPlaying();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPlayerBarBackdrop extends StatefulWidget {
  const _DesktopPlayerBarBackdrop({
    required this.track,
    required this.isPlaying,
  });

  final Track? track;
  final bool isPlaying;

  @override
  State<_DesktopPlayerBarBackdrop> createState() =>
      _DesktopPlayerBarBackdropState();
}

class _DesktopPlayerBarBackdropState extends State<_DesktopPlayerBarBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    if (track == null) {
      return const SizedBox.shrink();
    }

    final palette = _desktopTrackPalette(track);
    final primary = palette.first;
    final secondary = palette.length > 1
        ? palette[1]
        : _DesktopPalette.accentSoft;
    final tertiary = palette.length > 2 ? palette[2] : _DesktopPalette.bg3;
    final intensity = widget.isPlaying ? 1.0 : 0.52;

    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final theta = _controller.value * math.pi * 2;
            final driftX = math.sin(theta);
            final driftY = math.cos(theta);

            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        primary.withValues(alpha: 0.06 * intensity),
                        _DesktopPalette.bg1.withValues(alpha: 0.0),
                        secondary.withValues(alpha: 0.05 * intensity),
                      ],
                    ),
                  ),
                ),
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 54, sigmaY: 54),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _AtmosphereOrb(
                        alignment: const Alignment(-0.92, -0.24),
                        size: const Size(240, 240),
                        offset: Offset(18 * driftX, 8 * driftY),
                        colors: [
                          primary.withValues(alpha: 0.18 * intensity),
                          secondary.withValues(alpha: 0.1 * intensity),
                          Colors.transparent,
                        ],
                      ),
                      _AtmosphereOrb(
                        alignment: const Alignment(0.2, 0.72),
                        size: const Size(320, 320),
                        offset: Offset(-24 * driftY, 10 * driftX),
                        colors: [
                          secondary.withValues(alpha: 0.12 * intensity),
                          tertiary.withValues(alpha: 0.08 * intensity),
                          Colors.transparent,
                        ],
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.36 + (0.06 * (driftX + 1) / 2),
                    child: Container(
                      height: 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary.withValues(alpha: 0.0),
                            primary.withValues(alpha: 0.7 * intensity),
                            secondary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniNowPlayingArtwork extends StatefulWidget {
  const _MiniNowPlayingArtwork({
    super.key,
    required this.track,
    required this.isPlaying,
    this.hidden = false,
  });

  final Track? track;
  final bool isPlaying;
  final bool hidden;

  @override
  State<_MiniNowPlayingArtwork> createState() => _MiniNowPlayingArtworkState();
}

class _MiniNowPlayingArtworkState extends State<_MiniNowPlayingArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.18;
    }
  }

  @override
  void didUpdateWidget(covariant _MiniNowPlayingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying == widget.isPlaying &&
        oldWidget.track?.id == widget.track?.id) {
      return;
    }

    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..animateTo(
          0.18,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final palette = _desktopTrackPalette(track);
    final primary = palette.first;
    final secondary = palette.length > 1
        ? palette[1]
        : _DesktopPalette.accentSoft;

    return SizedBox(
      width: 62,
      height: 62,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (widget.hidden) {
            return const SizedBox.expand();
          }

          final phase = widget.isPlaying ? _controller.value : 0.18;
          final glow = 0.24 + (0.2 * phase);
          final scale = track == null ? 1.0 : 0.98 + (0.04 * phase);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (track != null)
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: glow),
                          blurRadius: 26,
                          spreadRadius: 1.5,
                        ),
                        BoxShadow(
                          color: secondary.withValues(alpha: glow * 0.64),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: track == null
                        ? _DesktopPalette.borderStrong
                        : primary.withValues(
                            alpha: widget.isPlaying ? 0.54 : 0.28,
                          ),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: ArtworkCover(
                  title: track?.album ?? 'ChiMusic',
                  palette: palette,
                  artworkUri: track?.artworkUri,
                  size: 54,
                  borderRadius: BorderRadius.circular(11),
                  icon: Icons.music_note_rounded,
                ),
              ),
              if (track != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _DesktopPalette.bg0.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: primary.withValues(alpha: 0.3)),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },
                      child: widget.isPlaying
                          ? _WaveBars(
                              key: const ValueKey('playing'),
                              height: 10,
                              color: primary,
                              minFactor: 0.3,
                            )
                          : Icon(
                              Icons.play_arrow_rounded,
                              key: const ValueKey('paused'),
                              size: 12,
                              color: primary,
                            ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ArtworkFlightOverlay extends StatelessWidget {
  const _ArtworkFlightOverlay({required this.flight, required this.progress});

  final _ArtworkFlight flight;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = _desktopTrackPalette(flight.track);
    final primary = palette.first;
    final secondary = palette.length > 1
        ? palette[1]
        : _DesktopPalette.accentSoft;
    final rect = Rect.lerp(flight.fromRect, flight.toRect, progress)!;
    final corner = ui.lerpDouble(14, rect.width * 0.1, progress) ?? 14;
    final shimmer = Curves.easeOutCubic.transform(progress);
    final glow = 0.18 + (0.14 * math.sin(progress * math.pi));

    return Stack(
      children: [
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: Transform.scale(
              scale: 0.98 + (0.02 * shimmer),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    left: -24,
                    top: -24,
                    right: -24,
                    bottom: -24,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            primary.withValues(alpha: glow),
                            secondary.withValues(alpha: glow * 0.72),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.48, 1],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(ui.lerpDouble(2, 3, progress) ?? 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(corner),
                      border: Border.all(
                        color: primary.withValues(
                          alpha: 0.4 + (0.18 * progress),
                        ),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(
                            alpha: 0.18 + (0.14 * shimmer),
                          ),
                          blurRadius: 28 + (36 * shimmer),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ArtworkCover(
                      title: flight.track.album,
                      palette: palette,
                      artworkUri: flight.track.artworkUri,
                      size: rect.width - ((ui.lerpDouble(4, 6, progress) ?? 4)),
                      borderRadius: BorderRadius.circular(corner * 0.82),
                      showTitle: rect.width > 120,
                      icon: Icons.music_note_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerModePill extends StatelessWidget {
  const _PlayerModePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _DesktopTypography.mono.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingAtmosphere extends StatefulWidget {
  const _NowPlayingAtmosphere({super.key, required this.track});

  final Track track;

  @override
  State<_NowPlayingAtmosphere> createState() => _NowPlayingAtmosphereState();
}

class _NowPlayingAtmosphereState extends State<_NowPlayingAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final palette = widget.track.palette.isEmpty
        ? <Color>[
            _DesktopPalette.accent,
            _DesktopPalette.accentSoft,
            _DesktopPalette.bg3,
          ]
        : widget.track.palette;
    final primary = palette.first;
    final secondary = palette.length > 1
        ? palette[1]
        : _DesktopPalette.accentSoft;
    final tertiary = palette.length > 2 ? palette[2] : _DesktopPalette.bg3;

    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final theta = _controller.value * math.pi * 2;
            final driftX = math.sin(theta);
            final driftY = math.cos(theta);

            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _DesktopPalette.bg0.withValues(alpha: 0),
                        _DesktopPalette.bg0.withValues(
                          alpha: isLight ? 0.08 : 0.16,
                        ),
                        _DesktopPalette.bg0.withValues(
                          alpha: isLight ? 0.44 : 0.74,
                        ),
                      ],
                      stops: const [0, 0.42, 1],
                    ),
                  ),
                ),
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 88, sigmaY: 88),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _AtmosphereOrb(
                        alignment: const Alignment(-0.12, -0.9),
                        size: const Size(560, 560),
                        offset: Offset(36 * driftX, 20 * driftY),
                        colors: [
                          primary.withValues(alpha: isLight ? 0.28 : 0.22),
                          secondary.withValues(alpha: isLight ? 0.18 : 0.14),
                          Colors.transparent,
                        ],
                      ),
                      _AtmosphereOrb(
                        alignment: const Alignment(0.88, -0.18),
                        size: const Size(360, 360),
                        offset: Offset(-28 * driftY, 22 * driftX),
                        colors: [
                          secondary.withValues(alpha: isLight ? 0.2 : 0.16),
                          tertiary.withValues(alpha: isLight ? 0.14 : 0.1),
                          Colors.transparent,
                        ],
                      ),
                      _AtmosphereOrb(
                        alignment: const Alignment(-0.84, 0.16),
                        size: const Size(300, 300),
                        offset: Offset(22 * driftX, -18 * driftY),
                        colors: [
                          tertiary.withValues(alpha: isLight ? 0.18 : 0.14),
                          primary.withValues(alpha: isLight ? 0.12 : 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.52),
                      radius: 1.08,
                      colors: [
                        primary.withValues(alpha: isLight ? 0.12 : 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AtmosphereOrb extends StatelessWidget {
  const _AtmosphereOrb({
    required this.alignment,
    required this.size,
    required this.offset,
    required this.colors,
  });

  final Alignment alignment;
  final Size size;
  final Offset offset;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors, stops: const [0, 0.52, 1]),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingHeroSurface extends StatelessWidget {
  const _NowPlayingHeroSurface({required this.track, required this.child});

  final Track track;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final palette = track.palette.isEmpty
        ? <Color>[_DesktopPalette.accent, _DesktopPalette.accentSoft]
        : track.palette;
    final primary = palette.first;
    final secondary = palette.length > 1
        ? palette[1]
        : _DesktopPalette.accentSoft;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                primary.withValues(alpha: isLight ? 0.18 : 0.12),
                _DesktopPalette.bg2,
              ).withValues(alpha: isLight ? 0.92 : 0.9),
              Color.alphaBlend(
                secondary.withValues(alpha: isLight ? 0.12 : 0.08),
                _DesktopPalette.bg1,
              ).withValues(alpha: isLight ? 0.86 : 0.84),
            ],
          ),
          border: Border.all(
            color: primary.withValues(alpha: isLight ? 0.22 : 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: isLight ? 0.12 : 0.18),
              blurRadius: 42,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -90,
              top: -70,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: isLight ? 0.26 : 0.18),
                        blurRadius: 120,
                        spreadRadius: 26,
                      ),
                    ],
                  ),
                  child: const SizedBox(width: 180, height: 180),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(28), child: child),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingQueueSurface extends StatelessWidget {
  const _NowPlayingQueueSurface({required this.track, required this.child});

  final Track track;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final palette = track.palette.isEmpty
        ? <Color>[_DesktopPalette.accent, _DesktopPalette.accentSoft]
        : track.palette;
    final primary = palette.first;
    final secondary = palette.length > 1
        ? palette[1]
        : _DesktopPalette.accentSoft;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  primary.withValues(alpha: isLight ? 0.08 : 0.06),
                  _DesktopPalette.bg2.withValues(alpha: 0.88),
                ),
                Color.alphaBlend(
                  secondary.withValues(alpha: isLight ? 0.06 : 0.04),
                  _DesktopPalette.bg1.withValues(alpha: 0.8),
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: primary.withValues(alpha: isLight ? 0.16 : 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: isLight ? 0.06 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        primary.withValues(alpha: isLight ? 0.26 : 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _NowPlayingArtworkSpotlight extends StatefulWidget {
  const _NowPlayingArtworkSpotlight({
    required this.track,
    required this.size,
    required this.isPlaying,
  });

  final Track track;
  final double size;
  final bool isPlaying;

  @override
  State<_NowPlayingArtworkSpotlight> createState() =>
      _NowPlayingArtworkSpotlightState();
}

class _NowPlayingArtworkSpotlightState
    extends State<_NowPlayingArtworkSpotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation(immediate: true);
  }

  @override
  void didUpdateWidget(covariant _NowPlayingArtworkSpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying ||
        oldWidget.track.id != widget.track.id) {
      _syncAnimation();
    }
  }

  void _syncAnimation({bool immediate = false}) {
    if (widget.isPlaying) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }

    _controller.stop();
    if (immediate) {
      _controller.value = 0.18;
      return;
    }
    _controller.animateTo(
      0.18,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final palette = widget.track.palette.isEmpty
        ? <Color>[
            _DesktopPalette.accent,
            _DesktopPalette.accentSoft,
            _DesktopPalette.bg3,
          ]
        : widget.track.palette;
    final primary = palette.first;
    final secondary = palette.length > 1
        ? palette[1]
        : _DesktopPalette.accentSoft;
    final tertiary = palette.length > 2 ? palette[2] : _DesktopPalette.bg3;
    final radius = BorderRadius.circular(widget.size * 0.1);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ArtworkCover(
              title: widget.track.album,
              palette: palette,
              artworkUri: widget.track.artworkUri,
              size: widget.size,
              borderRadius: radius,
              showTitle: true,
              icon: Icons.music_note_rounded,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isLight ? 0.24 : 0.14,
                      ),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: isLight ? 0.1 : 0.08),
                        Colors.transparent,
                        tertiary.withValues(alpha: isLight ? 0.06 : 0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        builder: (context, child) {
          final phase = widget.isPlaying ? _controller.value : 0.18;
          final pulse = (math.sin(phase * math.pi * 2) + 1) / 2;
          final floatY = widget.isPlaying ? math.sin(phase * math.pi) * 6 : 0.0;
          final glowScale = 0.92 + (pulse * 0.18);
          final ringScale = 0.9 + (pulse * 0.1);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                left: -38,
                top: -38,
                right: -38,
                bottom: -38,
                child: Transform.scale(
                  scale: glowScale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primary.withValues(alpha: isLight ? 0.22 : 0.16),
                          secondary.withValues(alpha: isLight ? 0.14 : 0.1),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                left: -18,
                top: -18,
                right: -18,
                bottom: -18,
                child: Transform.scale(
                  scale: ringScale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primary.withValues(alpha: isLight ? 0.2 : 0.14),
                        width: 1.2,
                      ),
                      gradient: RadialGradient(
                        colors: [
                          primary.withValues(alpha: isLight ? 0.08 : 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(offset: Offset(0, -floatY), child: child),
            ],
          );
        },
      ),
    );
  }
}

class _NowPlayingReveal extends StatefulWidget {
  const _NowPlayingReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.035),
  });

  final Widget child;
  final Duration delay;
  final Offset beginOffset;

  @override
  State<_NowPlayingReveal> createState() => _NowPlayingRevealState();
}

class _NowPlayingRevealState extends State<_NowPlayingReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (!mounted) {
        return;
      }
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.beginOffset,
          end: Offset.zero,
        ).animate(animation),
        child: widget.child,
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.controller,
    required this.track,
    required this.onOpenLibrary,
    required this.onOpenNowPlaying,
  });

  final MusicAppController controller;
  final Track? track;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenNowPlaying;

  @override
  Widget build(BuildContext context) {
    final hasTrack = track != null;
    final title = hasTrack
        ? track!.title
        : controller.hasMusic
        ? '从你的曲库挑一首歌'
        : '导入本地音乐开始构建桌面播放器';
    final subtitle = hasTrack
        ? track!.artist
        : controller.hasMusic
        ? '已经准备好 ${controller.importedTrackCount} 首歌，点击播放继续聆听。'
        : '参考稿里的首页、曲库、播放页和历史页已经接入到 macOS 桌面布局。';

    return _SurfaceCard(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ArtworkCover(
            title: track?.album ?? 'ChiMusic',
            palette:
                track?.palette ??
                <Color>[
                  _DesktopPalette.accent,
                  _DesktopPalette.accentSoft,
                  _DesktopPalette.bg3,
                ],
            artworkUri: track?.artworkUri,
            size: 180,
            borderRadius: BorderRadius.circular(16),
            showTitle: true,
            icon: Icons.library_music_rounded,
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hasTrack ? 'Now Playing' : 'Desktop Player',
                      style: _DesktopTypography.overline.copyWith(
                        color: _DesktopPalette.textMuted,
                      ),
                    ),
                    if (hasTrack && controller.isPlaying) ...[
                      const SizedBox(width: 10),
                      _WaveBars(
                        height: 12,
                        color: _DesktopPalette.accent,
                        minFactor: 0.28,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(title, style: _DesktopTypography.display),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: _DesktopTypography.body.copyWith(
                    color: _DesktopPalette.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ActionButton(
                      label: hasTrack
                          ? (controller.isPlaying ? '暂停' : '播放')
                          : (controller.hasMusic ? '开始播放' : '导入音乐'),
                      icon: hasTrack
                          ? (controller.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded)
                          : controller.hasMusic
                          ? Icons.play_arrow_rounded
                          : Icons.file_upload_outlined,
                      accent: true,
                      onTap: () {
                        if (hasTrack) {
                          controller.togglePlayPause();
                          onOpenNowPlaying();
                          return;
                        }
                        if (controller.hasMusic) {
                          controller.playImportedTracks();
                          onOpenNowPlaying();
                          return;
                        }
                        controller.supportsDirectoryImport
                            ? controller.importLocalFolder()
                            : controller.importLocalFiles();
                      },
                    ),
                    _ActionButton(
                      label: '浏览曲库',
                      icon: Icons.library_music_outlined,
                      onTap: onOpenLibrary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingMeta extends StatelessWidget {
  const _NowPlayingMeta({required this.track, required this.collection});

  final Track track;
  final MusicCollection? collection;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final entry = controller.playbackHistoryEntryForTrack(track.id);
    final isLiked = controller.isTrackLiked(track.id);

    Future<void> handleShuffleToggle() async {
      await controller.toggleShuffle();
      controller.setStatusMessage(
        controller.isShuffleEnabled ? '已开启随机播放。' : '已关闭随机播放。',
      );
    }

    Future<void> handleRepeatToggle() async {
      await controller.toggleRepeat();
      controller.setStatusMessage(
        controller.isRepeatEnabled ? '已开启循环播放。' : '已关闭循环播放。',
      );
    }

    void handleLikedToggle() {
      controller.toggleLikedTrack(track.id);
      controller.setStatusMessage(
        isLiked ? '已取消喜欢《${track.title}》。' : '已加入喜欢《${track.title}》。',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(track.title, style: _DesktopTypography.display),
        const SizedBox(height: 10),
        Text(
          '${track.artist} • ${track.album}',
          style: _DesktopTypography.body.copyWith(
            color: _DesktopPalette.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (collection != null) _Tag(label: collection!.title),
            _Tag(label: formatDuration(track.duration)),
            if (entry != null) _Tag(label: '${entry.playCount} 次播放'),
            if (track.year case final year?) _Tag(label: '$year'),
          ],
        ),
        const SizedBox(height: 24),
        WaveformProgressBar(
          progress: controller.playbackProgress,
          palette: track.palette,
          waveform: controller.waveformForTrack(track),
          height: 54,
          onSeek: (value) {
            controller.seekToFraction(value);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              formatDuration(controller.position, placeholder: '00:00'),
              style: _DesktopTypography.mono.copyWith(
                color: _DesktopPalette.textMuted,
              ),
            ),
            const Spacer(),
            Text(
              formatDuration(track.duration),
              style: _DesktopTypography.mono.copyWith(
                color: _DesktopPalette.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _TransportToggleButton(
              icon: Icons.shuffle_rounded,
              enabled: true,
              selected: controller.isShuffleEnabled,
              tooltip: controller.isShuffleEnabled ? '关闭随机播放' : '开启随机播放',
              onTap: handleShuffleToggle,
            ),
            _TransportButton(
              icon: Icons.skip_previous_rounded,
              enabled: true,
              tooltip: '上一首 / 重新开始',
              onTap: controller.skipPrevious,
            ),
            _TransportButton(
              icon: controller.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              filled: true,
              enabled: true,
              tooltip: controller.isPlaying ? '暂停' : '播放',
              onTap: controller.togglePlayPause,
            ),
            _TransportButton(
              icon: Icons.skip_next_rounded,
              enabled: controller.canSkipNext,
              tooltip: controller.canSkipNext ? '下一首' : '队列中没有下一首',
              onTap: controller.skipNext,
            ),
            _TransportToggleButton(
              icon: Icons.repeat_rounded,
              enabled: true,
              selected: controller.isRepeatEnabled,
              tooltip: controller.isRepeatEnabled ? '关闭循环播放' : '开启循环播放',
              onTap: handleRepeatToggle,
            ),
            _RoundIconButton(
              icon: isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              tooltip: isLiked ? '取消喜欢' : '加入喜欢',
              color: isLiked
                  ? _DesktopPalette.accent
                  : _DesktopPalette.textMuted,
              onTap: handleLikedToggle,
            ),
            if (collection case final currentCollection?)
              _RoundIconButton(
                icon: Icons.queue_music_rounded,
                tooltip: '打开当前列表',
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(CollectionDetailPage.route(currentCollection));
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _HistoryRow extends StatefulWidget {
  const _HistoryRow({required this.track});

  final Track track;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = widget.track;
    final entry = controller.playbackHistoryEntryForTrack(track.id);
    final active = _hovered || controller.currentTrack?.id == track.id;

    return InkWell(
      onTap: () => controller.resumeTrack(track),
      onHover: (hovered) {
        if (_hovered == hovered) {
          return;
        }
        setState(() {
          _hovered = hovered;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active ? _DesktopPalette.bg2 : Colors.transparent,
          border: Border.all(
            color: active ? _DesktopPalette.borderStrong : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ArtworkCover(
              title: track.album,
              palette: track.palette,
              artworkUri: track.artworkUri,
              size: 46,
              borderRadius: BorderRadius.circular(8),
              icon: Icons.music_note_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _DesktopTypography.body.copyWith(
                      color: _DesktopPalette.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _DesktopTypography.small.copyWith(
                      color: _DesktopPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                '${entry?.playCount ?? 0} 次',
                textAlign: TextAlign.center,
                style: _DesktopTypography.mono.copyWith(
                  color: _DesktopPalette.textMuted,
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                entry == null
                    ? '—'
                    : formatRelativePlayTime(entry.lastPlayedAt),
                textAlign: TextAlign.right,
                style: _DesktopTypography.mono.copyWith(
                  color: _DesktopPalette.textFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopTrackRow extends StatefulWidget {
  const _DesktopTrackRow({
    required this.track,
    required this.indexLabel,
    required this.showAlbum,
    required this.trailing,
    required this.onTap,
    this.revealTrailingOnHover = false,
  });

  final Track track;
  final String indexLabel;
  final bool showAlbum;
  final Widget trailing;
  final VoidCallback onTap;
  final bool revealTrailingOnHover;

  @override
  State<_DesktopTrackRow> createState() => _DesktopTrackRowState();
}

class _DesktopTrackRowState extends State<_DesktopTrackRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = widget.track;
    final playing = controller.currentTrack?.id == track.id;
    final active = playing || _hovered;

    return InkWell(
      onTap: widget.onTap,
      onHover: (hovered) {
        if (_hovered == hovered) {
          return;
        }
        setState(() {
          _hovered = hovered;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: playing
              ? _DesktopPalette.accent.withValues(alpha: 0.08)
              : (active ? _DesktopPalette.bg2 : Colors.transparent),
          border: Border.all(
            color: active ? _DesktopPalette.borderStrong : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  },
                  child: playing && controller.isPlaying
                      ? _WaveBars(
                          key: const ValueKey('bars'),
                          height: 14,
                          color: _DesktopPalette.accent,
                          minFactor: 0.28,
                        )
                      : active
                      ? Icon(
                          Icons.play_arrow_rounded,
                          key: const ValueKey('play'),
                          color: playing
                              ? _DesktopPalette.accent
                              : _DesktopPalette.textMuted,
                          size: 16,
                        )
                      : Text(
                          widget.indexLabel,
                          key: const ValueKey('index'),
                          style: _DesktopTypography.mono.copyWith(
                            color: _DesktopPalette.textFaint,
                          ),
                        ),
                ),
              ),
            ),
            ArtworkCover(
              title: track.album,
              palette: track.palette,
              artworkUri: track.artworkUri,
              size: 44,
              borderRadius: BorderRadius.circular(8),
              icon: Icons.music_note_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _DesktopTypography.body.copyWith(
                      color: playing
                          ? _DesktopPalette.accent
                          : _DesktopPalette.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.showAlbum
                        ? track.artist
                        : '${widget.indexLabel}. ${track.artist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _DesktopTypography.small.copyWith(
                      color: _DesktopPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showAlbum)
              SizedBox(
                width: 160,
                child: Text(
                  track.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _DesktopTypography.small.copyWith(
                    color: _DesktopPalette.textFaint,
                  ),
                ),
              ),
            if (widget.showAlbum)
              SizedBox(
                width: 80,
                child: Text(
                  formatDuration(track.duration),
                  textAlign: TextAlign.right,
                  style: _DesktopTypography.mono.copyWith(
                    color: _DesktopPalette.textMuted,
                  ),
                ),
              ),
            if (!widget.showAlbum) const SizedBox(width: 12),
            SizedBox(
              width: 36,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: !widget.revealTrailingOnHover || active ? 1 : 0,
                child: IgnorePointer(
                  ignoring: widget.revealTrailingOnHover && !active,
                  child: widget.trailing,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTrackCard extends StatefulWidget {
  const _RecentTrackCard({required this.track});

  final Track track;

  @override
  State<_RecentTrackCard> createState() => _RecentTrackCardState();
}

class _RecentTrackCardState extends State<_RecentTrackCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = widget.track;
    final active = _hovered || controller.currentTrack?.id == track.id;

    return MouseRegion(
      onEnter: (_) {
        if (_hovered) {
          return;
        }
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        if (!_hovered) {
          return;
        }
        setState(() {
          _hovered = false;
        });
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: active ? 1.015 : 1,
        child: InkWell(
          onTap: () => controller.playTrack(track),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: active ? _DesktopPalette.bg3 : _DesktopPalette.bg2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _DesktopPalette.borderStrong),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: track.palette.first.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight;

                      return Stack(
                        children: [
                          Center(
                            child: ArtworkCover(
                              title: track.album,
                              palette: track.palette,
                              artworkUri: track.artworkUri,
                              size: size,
                              borderRadius: BorderRadius.circular(12),
                              icon: Icons.music_note_rounded,
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: active ? 1 : 0,
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 180),
                                scale: active ? 1 : 0.86,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: _DesktopPalette.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child:
                                        controller.currentTrack?.id ==
                                                track.id &&
                                            controller.isPlaying
                                        ? _WaveBars(
                                            height: 12,
                                            color: _DesktopPalette.bg0,
                                            minFactor: 0.28,
                                          )
                                        : Icon(
                                            Icons.play_arrow_rounded,
                                            size: 18,
                                            color: _DesktopPalette.bg0,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _DesktopTypography.body.copyWith(
                    color: _DesktopPalette.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _DesktopTypography.small.copyWith(
                    color: _DesktopPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveBars extends StatefulWidget {
  const _WaveBars({
    super.key,
    required this.height,
    required this.color,
    this.minFactor = 0.24,
  });

  final double height;
  final Color color;
  final double minFactor;

  @override
  State<_WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<_WaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 920),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List<Widget>.generate(5, (index) {
              final phase = (_controller.value * 2 * math.pi) + (index * 0.72);
              final normalized = (math.sin(phase) + 1) / 2;
              final factor =
                  widget.minFactor + ((1 - widget.minFactor) * normalized);

              return Padding(
                padding: EdgeInsets.only(right: index == 4 ? 0 : 2),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 2,
                    height: widget.height * factor,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _SidebarCollectionButton extends StatelessWidget {
  const _SidebarCollectionButton({
    required this.collection,
    required this.active,
  });

  final MusicCollection collection;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.of(context).push(CollectionDetailPage.route(collection));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active
              ? _DesktopPalette.accent.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? _DesktopPalette.accent
                    : _DesktopPalette.textFaint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                collection.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _DesktopTypography.body.copyWith(
                  color: active
                      ? _DesktopPalette.accent
                      : _DesktopPalette.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavButton extends StatelessWidget {
  const _SidebarNavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? _DesktopPalette.accent.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? _DesktopPalette.accent
                    : _DesktopPalette.textMuted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: _DesktopTypography.body.copyWith(
                  color: selected
                      ? _DesktopPalette.accent
                      : _DesktopPalette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _DesktopPalette.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _DesktopPalette.borderStrong),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search_rounded,
            color: _DesktopPalette.textFaint,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: _DesktopPalette.textPrimary),
              decoration: InputDecoration(
                hintText: '搜索歌曲、歌手、专辑…',
                hintStyle: TextStyle(color: _DesktopPalette.textFaint),
                border: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: onClear,
              icon: Icon(
                Icons.close_rounded,
                color: _DesktopPalette.textMuted,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final LibrarySort value;
  final ValueChanged<LibrarySort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _DesktopPalette.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _DesktopPalette.borderStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LibrarySort>(
          value: value,
          dropdownColor: _DesktopPalette.bg2,
          borderRadius: BorderRadius.circular(12),
          style: _DesktopTypography.mono.copyWith(
            color: _DesktopPalette.textPrimary,
          ),
          iconEnabledColor: _DesktopPalette.textMuted,
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
          items: const [
            DropdownMenuItem(value: LibrarySort.recent, child: Text('最近添加')),
            DropdownMenuItem(value: LibrarySort.title, child: Text('歌曲名')),
            DropdownMenuItem(value: LibrarySort.length, child: Text('时长')),
          ],
        ),
      ),
    );
  }
}

class _InteractiveProgressBar extends StatelessWidget {
  const _InteractiveProgressBar({
    required this.progress,
    this.palette = const <Color>[],
    this.isPlaying = false,
    this.onSeek,
  });

  final double progress;
  final List<Color> palette;
  final bool isPlaying;
  final ValueChanged<double>? onSeek;

  void _seekTo(double dx, double width) {
    if (onSeek == null) {
      return;
    }
    final safeWidth = width <= 0 ? 1.0 : width;
    onSeek!((dx / safeWidth).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    final resolvedPalette = palette.isEmpty
        ? <Color>[_DesktopPalette.accent, _DesktopPalette.accentSoft]
        : palette;
    final primary = resolvedPalette.first;
    final secondary = resolvedPalette.length > 1
        ? resolvedPalette[1]
        : _DesktopPalette.accentSoft;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillWidth = width * clamped;
        final thumbSize = isPlaying ? 11.0 : 9.0;
        final thumbLeft = (fillWidth - (thumbSize / 2))
            .clamp(0.0, math.max(0.0, width - thumbSize))
            .toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onSeek == null
              ? null
              : (details) {
                  _seekTo(details.localPosition.dx, width);
                },
          onHorizontalDragStart: onSeek == null
              ? null
              : (details) {
                  _seekTo(details.localPosition.dx, width);
                },
          onHorizontalDragUpdate: onSeek == null
              ? null
              : (details) {
                  _seekTo(details.localPosition.dx, width);
                },
          child: MouseRegion(
            cursor: onSeek == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: SizedBox(
              height: 18,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: _DesktopPalette.bg4,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Container(
                    width: fillWidth,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primary.withValues(alpha: 0.96),
                          secondary.withValues(alpha: 0.82),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        if (isPlaying)
                          BoxShadow(
                            color: primary.withValues(alpha: 0.24),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                  ),
                  if (fillWidth > 0)
                    Positioned(
                      left: thumbLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOutCubic,
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _DesktopPalette.textPrimary,
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(
                                alpha: isPlaying ? 0.3 : 0.16,
                              ),
                              blurRadius: isPlaying ? 16 : 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final background = accent ? _DesktopPalette.accent : _DesktopPalette.bg3;
    final foreground = accent
        ? _DesktopPalette.bg0
        : _DesktopPalette.textPrimary;

    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.filled = false,
    this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final Future<void> Function() onTap;
  final bool filled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: enabled ? () => onTap() : null,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        width: filled ? 42 : 34,
        height: filled ? 42 : 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled && enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _DesktopPalette.textPrimary,
                    _DesktopPalette.textPrimary.withValues(alpha: 0.88),
                  ],
                )
              : null,
          color: filled
              ? (enabled ? null : _DesktopPalette.bg4)
              : Colors.transparent,
          boxShadow: [
            if (filled && enabled)
              BoxShadow(
                color: _DesktopPalette.accent.withValues(alpha: 0.18),
                blurRadius: 16,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: filled ? 22 : 18,
              color: filled
                  ? _DesktopPalette.bg0
                  : (enabled
                        ? _DesktopPalette.textMuted
                        : _DesktopPalette.textFaint),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip!, child: button);
  }
}

class _TransportToggleButton extends StatelessWidget {
  const _TransportToggleButton({
    required this.icon,
    required this.enabled,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final bool selected;
  final Future<void> Function() onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: enabled ? () => onTap() : null,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? _DesktopPalette.accent.withValues(alpha: 0.16)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected
              ? _DesktopPalette.accent
              : (enabled
                    ? _DesktopPalette.textMuted
                    : _DesktopPalette.textFaint),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip!, child: button);
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _DesktopPalette.bg3,
            border: Border.all(color: _DesktopPalette.borderStrong),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 16,
                color: color ?? _DesktopPalette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: _DesktopPalette.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _DesktopPalette.borderStrong),
      ),
      child: child,
    );

    return body;
  }
}

class _DesktopToast extends StatelessWidget {
  const _DesktopToast({
    super.key,
    required this.message,
    required this.onClose,
  });

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _DesktopPalette.bg3.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _DesktopPalette.borderStrong),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: _DesktopPalette.accent,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: _DesktopTypography.body.copyWith(
                  color: _DesktopPalette.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: _DesktopPalette.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _DesktopPalette.accent.withValues(alpha: 0.18),
                        _DesktopPalette.accent.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _DesktopPalette.bg3,
                    shape: BoxShape.circle,
                    border: Border.all(color: _DesktopPalette.borderStrong),
                  ),
                  child: Icon(icon, color: _DesktopPalette.accent, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _DecorativeBars(),
          const SizedBox(height: 16),
          Text(title, style: _DesktopTypography.section),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: _DesktopTypography.body.copyWith(
              color: _DesktopPalette.textMuted,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            _ActionButton(
              label: actionLabel!,
              icon: Icons.arrow_forward_rounded,
              accent: true,
              onTap: onAction!,
            ),
          ],
        ],
      ),
    );
  }
}

class _DecorativeBars extends StatelessWidget {
  const _DecorativeBars();

  @override
  Widget build(BuildContext context) {
    const heights = <double>[7, 12, 18, 12, 7];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < heights.length; index++)
          Container(
            width: 3,
            height: heights[index],
            margin: EdgeInsets.only(right: index == heights.length - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: _DesktopPalette.accent.withValues(
                alpha: 0.4 + (index * 0.08),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _PageSectionTitle extends StatelessWidget {
  const _PageSectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Expanded(child: Text(title, style: _DesktopTypography.section)),
    ];
    if (trailing case final trailingWidget?) {
      children.add(trailingWidget);
    }

    return Row(children: children);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: _DesktopTypography.stat),
          const SizedBox(height: 8),
          Text(
            label,
            style: _DesktopTypography.overline.copyWith(
              color: _DesktopPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _DesktopPalette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: _DesktopTypography.mono.copyWith(color: _DesktopPalette.accent),
      ),
    );
  }
}

class _DesktopPalette {
  static Color bg0 = const Color(0xFF0A0A0B);
  static Color bg1 = const Color(0xFF111113);
  static Color bg2 = const Color(0xFF181819);
  static Color bg3 = const Color(0xFF222224);
  static Color bg4 = const Color(0xFF2C2C2F);
  static Color accent = const Color(0xFFC9A96E);
  static Color accentSoft = const Color(0xFFE8C98A);
  static Color textPrimary = const Color(0xFFF0EDE8);
  static Color textMuted = const Color(0xFFB8B4AC);
  static Color textFaint = const Color(0xFF787470);
  static Color border = const Color(0x14FFFFFF);
  static Color borderStrong = const Color(0x1FFFFFFF);
  static Color backdropMid = const Color(0xFF0D0D0F);
  static Color backdropEnd = const Color(0xFF14110C);

  static void syncWith(Brightness brightness) {
    if (brightness == Brightness.light) {
      bg0 = const Color(0xFFF2EDE1);
      bg1 = const Color(0xFFEDE7DA);
      bg2 = const Color(0xFFE6DFCF);
      bg3 = const Color(0xFFDDD5C4);
      bg4 = const Color(0xFFCEC5B3);
      accent = const Color(0xFFC07A92);
      accentSoft = const Color(0xFFD3A9B4);
      textPrimary = const Color(0xFF2C2018);
      textMuted = const Color(0xFF6B5240);
      textFaint = const Color(0xFF9A8470);
      border = const Color(0x142C2018);
      borderStrong = const Color(0x1F2C2018);
      backdropMid = const Color(0xFFEDE7DA);
      backdropEnd = const Color(0xFFE8DCCF);
      return;
    }

    bg0 = const Color(0xFF0A0A0B);
    bg1 = const Color(0xFF111113);
    bg2 = const Color(0xFF181819);
    bg3 = const Color(0xFF222224);
    bg4 = const Color(0xFF2C2C2F);
    accent = const Color(0xFFC9A96E);
    accentSoft = const Color(0xFFE8C98A);
    textPrimary = const Color(0xFFF0EDE8);
    textMuted = const Color(0xFFB8B4AC);
    textFaint = const Color(0xFF787470);
    border = const Color(0x14FFFFFF);
    borderStrong = const Color(0x1FFFFFFF);
    backdropMid = const Color(0xFF0D0D0F);
    backdropEnd = const Color(0xFF14110C);
  }
}

class _DesktopTypography {
  static TextStyle get display => TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w300,
    height: 1.08,
    color: _DesktopPalette.textPrimary,
  );

  static TextStyle get section => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: _DesktopPalette.textPrimary,
  );

  static TextStyle get stat => TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w300,
    color: _DesktopPalette.accentSoft,
  );

  static TextStyle get body => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: _DesktopPalette.textPrimary,
  );

  static TextStyle get small => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: _DesktopPalette.textMuted,
  );

  static TextStyle get mono => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: _DesktopPalette.textMuted,
    letterSpacing: 0.4,
  );

  static TextStyle get overline => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: _DesktopPalette.textFaint,
    letterSpacing: 1.4,
  );
}
