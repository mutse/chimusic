import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

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

class MacosPlayerShell extends StatefulWidget {
  const MacosPlayerShell({super.key});

  @override
  State<MacosPlayerShell> createState() => _MacosPlayerShellState();
}

class _MacosPlayerShellState extends State<MacosPlayerShell> {
  late final TextEditingController _librarySearchController;
  var _page = _DesktopPage.home;
  bool _didBootstrap = false;
  Timer? _toastTimer;
  String? _observedStatusMessage;

  @override
  void initState() {
    super.initState();
    _librarySearchController = TextEditingController();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
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
                    onOpenNowPlaying: () =>
                        _setPage(_DesktopPage.nowPlaying, controller),
                  ),
                ],
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
                          text: 'SŌNO ',
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
  const _DesktopNowPlayingPage({required this.onOpenLibrary});

  final VoidCallback onOpenLibrary;

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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('正在播放', style: _DesktopTypography.display)),
              _Tag(label: collection?.title ?? 'Current Queue'),
            ],
          ),
          const SizedBox(height: 24),
          _SurfaceCard(
            padding: const EdgeInsets.all(28),
            background: Color.alphaBlend(
              track.palette.first.withValues(alpha: 0.14),
              _DesktopPalette.bg2,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 920;

                final art = ArtworkCover(
                  title: track.album,
                  palette: track.palette,
                  artworkUri: track.artworkUri,
                  size: stacked ? 240 : 280,
                  showTitle: true,
                  icon: Icons.music_note_rounded,
                );

                final meta = _NowPlayingMeta(
                  track: track,
                  collection: collection,
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
          const SizedBox(height: 28),
          _SurfaceCard(
            padding: const EdgeInsets.all(22),
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
                            formatDuration(controller.upNext[index].duration),
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
                          Divider(height: 1, color: _DesktopPalette.border),
                      ],
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
  const _DesktopPlayerBar({required this.onOpenNowPlaying});

  final VoidCallback onOpenNowPlaying;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = controller.currentTrack;
    final collection = track == null
        ? null
        : (controller.currentCollection ??
              controller.collectionForTrack(track));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: _DesktopPalette.bg1,
        border: Border(top: BorderSide(color: _DesktopPalette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: track == null ? null : onOpenNowPlaying,
              borderRadius: BorderRadius.circular(14),
              child: Row(
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
                    size: 54,
                    borderRadius: BorderRadius.circular(10),
                    icon: Icons.music_note_rounded,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                              : '${track.artist} • ${collection?.title ?? track.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _DesktopTypography.small.copyWith(
                            color: _DesktopPalette.textMuted,
                          ),
                        ),
                      ],
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
                      onTap: controller.toggleShuffle,
                    ),
                    const SizedBox(width: 10),
                    _TransportButton(
                      icon: Icons.skip_previous_rounded,
                      enabled: track != null,
                      onTap: controller.skipPrevious,
                    ),
                    const SizedBox(width: 10),
                    _TransportButton(
                      icon: controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      filled: true,
                      enabled: controller.hasMusic,
                      onTap: controller.togglePlayPause,
                    ),
                    const SizedBox(width: 10),
                    _TransportButton(
                      icon: Icons.skip_next_rounded,
                      enabled: track != null,
                      onTap: controller.skipNext,
                    ),
                    const SizedBox(width: 10),
                    _TransportToggleButton(
                      icon: Icons.repeat_rounded,
                      enabled: controller.hasMusic,
                      selected: controller.isRepeatEnabled,
                      onTap: controller.toggleRepeat,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                width: 210,
                child: Row(
                  children: [
                    Icon(
                      controller.volume <= 0.01
                          ? Icons.volume_off_rounded
                          : controller.volume < 0.5
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                      color: _DesktopPalette.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: _DesktopPalette.accent,
                          inactiveTrackColor: _DesktopPalette.bg4,
                          thumbColor: _DesktopPalette.textPrimary,
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: controller.volume,
                          onChanged: controller.setVolume,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
                Text(
                  hasTrack ? 'Now Playing' : 'Desktop Player',
                  style: _DesktopTypography.overline.copyWith(
                    color: _DesktopPalette.textMuted,
                  ),
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
        Row(
          children: [
            _TransportToggleButton(
              icon: Icons.shuffle_rounded,
              enabled: true,
              selected: controller.isShuffleEnabled,
              onTap: controller.toggleShuffle,
            ),
            const SizedBox(width: 12),
            _TransportButton(
              icon: Icons.skip_previous_rounded,
              enabled: true,
              onTap: controller.skipPrevious,
            ),
            const SizedBox(width: 12),
            _TransportButton(
              icon: controller.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              filled: true,
              enabled: true,
              onTap: controller.togglePlayPause,
            ),
            const SizedBox(width: 12),
            _TransportButton(
              icon: Icons.skip_next_rounded,
              enabled: true,
              onTap: controller.skipNext,
            ),
            const SizedBox(width: 12),
            _TransportToggleButton(
              icon: Icons.repeat_rounded,
              enabled: true,
              selected: controller.isRepeatEnabled,
              onTap: controller.toggleRepeat,
            ),
            const SizedBox(width: 16),
            _RoundIconButton(
              icon: controller.isTrackLiked(track.id)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              tooltip: controller.isTrackLiked(track.id) ? '取消喜欢' : '加入喜欢',
              color: controller.isTrackLiked(track.id)
                  ? _DesktopPalette.accent
                  : _DesktopPalette.textMuted,
              onTap: () => controller.toggleLikedTrack(track.id),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final entry = controller.playbackHistoryEntryForTrack(track.id);

    return InkWell(
      onTap: () => controller.resumeTrack(track),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
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

class _DesktopTrackRow extends StatelessWidget {
  const _DesktopTrackRow({
    required this.track,
    required this.indexLabel,
    required this.showAlbum,
    required this.trailing,
    required this.onTap,
  });

  final Track track;
  final String indexLabel;
  final bool showAlbum;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final playing = controller.currentTrack?.id == track.id;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: playing
              ? _DesktopPalette.accent.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Center(
                child: Icon(
                  playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                  color: playing
                      ? _DesktopPalette.accent
                      : _DesktopPalette.textFaint,
                  size: 16,
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
                    showAlbum ? track.artist : '$indexLabel. ${track.artist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _DesktopTypography.small.copyWith(
                      color: _DesktopPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (showAlbum)
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
            if (showAlbum)
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
            if (!showAlbum) const SizedBox(width: 12),
            SizedBox(width: 36, child: trailing),
          ],
        ),
      ),
    );
  }
}

class _RecentTrackCard extends StatelessWidget {
  const _RecentTrackCard({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);

    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: () => controller.playTrack(track),
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
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _DesktopPalette.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 18,
                          color: _DesktopPalette.bg0,
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
  const _InteractiveProgressBar({required this.progress, this.onSeek});

  final double progress;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fillWidth = constraints.maxWidth * clamped;
        return GestureDetector(
          onTapDown: onSeek == null
              ? null
              : (details) {
                  final fraction =
                      details.localPosition.dx /
                      constraints.maxWidth.clamp(1, double.infinity);
                  onSeek!(fraction.clamp(0.0, 1.0));
                },
          child: MouseRegion(
            cursor: onSeek == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: _DesktopPalette.bg4,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: fillWidth,
                  decoration: BoxDecoration(
                    color: _DesktopPalette.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
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
  });

  final IconData icon;
  final bool enabled;
  final Future<void> Function() onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onTap() : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: filled ? 42 : 34,
        height: filled ? 42 : 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? (enabled ? _DesktopPalette.textPrimary : _DesktopPalette.bg4)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: filled ? 22 : 18,
          color: filled
              ? _DesktopPalette.bg0
              : (enabled
                    ? _DesktopPalette.textMuted
                    : _DesktopPalette.textFaint),
        ),
      ),
    );
  }
}

class _TransportToggleButton extends StatelessWidget {
  const _TransportToggleButton({
    required this.icon,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final bool selected;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
    this.onTap,
    this.background,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? _DesktopPalette.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _DesktopPalette.borderStrong),
      ),
      child: child,
    );

    if (onTap == null) {
      return body;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: body,
    );
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
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _DesktopPalette.bg3,
              shape: BoxShape.circle,
              border: Border.all(color: _DesktopPalette.borderStrong),
            ),
            child: Icon(icon, color: _DesktopPalette.accent, size: 28),
          ),
          const SizedBox(height: 18),
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
