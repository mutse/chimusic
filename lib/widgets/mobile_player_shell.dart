import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/history_export.dart';
import '../models/music_models.dart';
import '../state/chimusic_controller.dart';
import '../state/chimusic_scope.dart';
import 'sono_design.dart';

/// Bottom-nav destinations for the mobile shell. Local to this file — the
/// shared [MusicTab] enum only models home/search/library and is used by the
/// desktop shell, so history/settings live here (mirroring the desktop shell's
/// own private `_DesktopPage`).
enum _MobilePage { home, library, history, settings }

extension _MobilePageX on _MobilePage {
  String get label => switch (this) {
    _MobilePage.home => '首页',
    _MobilePage.library => '音乐库',
    _MobilePage.history => '记录',
    _MobilePage.settings => '设置',
  };

  IconData get icon => switch (this) {
    _MobilePage.home => Icons.home_rounded,
    _MobilePage.library => Icons.library_music_rounded,
    _MobilePage.history => Icons.history_rounded,
    _MobilePage.settings => Icons.settings_rounded,
  };
}

/// Local sort modes for the library page. The shared [LibrarySort] lacks an
/// artist option, so the four HTML chips are modelled here.
enum _MobileSort { added, name, artist, duration }

extension _MobileSortX on _MobileSort {
  String get label => switch (this) {
    _MobileSort.added => '最新',
    _MobileSort.name => '歌曲名',
    _MobileSort.artist => '歌手',
    _MobileSort.duration => '时长',
  };
}

const double _kNavHeight = 64;
const double _kMiniHeight = 64;

/// The Android/iOS player surface — a faithful Flutter port of
/// `docs/music-player-mobile.html` (SŌNO Mobile). Routed from [AppShell] for
/// any non-desktop width.
class MobilePlayerShell extends StatefulWidget {
  const MobilePlayerShell({super.key});

  @override
  State<MobilePlayerShell> createState() => _MobilePlayerShellState();
}

class _MobilePlayerShellState extends State<MobilePlayerShell> {
  late final TextEditingController _librarySearchController;
  _MobilePage _page = _MobilePage.home;
  String _libQuery = '';
  _MobileSort _sort = _MobileSort.added;
  bool _likedFilter = false;
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

  // Auto-clears the controller's status message after a few seconds, mirroring
  // the desktop shell's toast lifecycle.
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

  void _setPage(_MobilePage page) {
    if (_page == page) {
      return;
    }
    setState(() => _page = page);
  }

  Future<void> _exportHistory(
    MusicAppController controller,
    HistoryExportFormat format,
  ) async {
    if (!controller.hasPlaybackHistory) {
      controller.setStatusMessage('暂无播放记录可导出。');
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${format.suggestedFileName}');
      await file.writeAsString(buildHistoryExport(controller, format));
      if (!mounted) {
        return;
      }
      controller.setStatusMessage('已导出 ${format.label} 到 ${file.path}');
    } catch (_) {
      if (!mounted) {
        return;
      }
      controller.setStatusMessage('导出播放记录失败，请重试。');
    }
  }

  Future<void> _confirmClearHistory(MusicAppController controller) async {
    if (!controller.hasPlaybackHistory) {
      controller.setStatusMessage('播放记录已经是空的。');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SonoPalette.bg2,
        title: Text('清空播放记录', style: SonoText.section),
        content: Text('此操作不可撤销，确认清空全部播放记录？', style: SonoText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消', style: TextStyle(color: SonoPalette.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('清空', style: TextStyle(color: SonoPalette.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      controller.clearPlaybackHistory();
    }
  }

  void _openNowPlayingSheet(MusicAppController controller) {
    if (!controller.hasCurrentTrack) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const _NowPlayingSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    SonoPalette.syncWith(
      controller.themeMode == AppThemeMode.light
          ? Brightness.light
          : Brightness.dark,
    );
    _syncStatusLifecycle(controller);

    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final navTotal = _kNavHeight + bottomSafe;
    final hasTrack = controller.hasCurrentTrack;
    final contentBottomPad = navTotal + (hasTrack ? _kMiniHeight + 12 : 0) + 16;

    return Scaffold(
      backgroundColor: SonoPalette.bg0,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_page),
                  child: _buildPage(controller, contentBottomPad),
                ),
              ),
            ),
          ),
          if (hasTrack)
            Positioned(
              left: 12,
              right: 12,
              bottom: navTotal + 8,
              child: _MiniPlayer(
                controller: controller,
                onOpen: () => _openNowPlayingSheet(controller),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomNav(
              page: _page,
              bottomSafe: bottomSafe,
              onSelect: _setPage,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: navTotal + (hasTrack ? _kMiniHeight + 12 : 0) + 16,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: controller.statusMessage == null
                    ? const SizedBox.shrink()
                    : _Toast(
                        key: ValueKey(controller.statusMessage),
                        message: controller.statusMessage!,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(MusicAppController controller, double bottomPad) {
    switch (_page) {
      case _MobilePage.home:
        return _HomePage(
          controller: controller,
          bottomPad: bottomPad,
          onOpenLibrary: () => _setPage(_MobilePage.library),
        );
      case _MobilePage.library:
        return _LibraryPage(
          controller: controller,
          bottomPad: bottomPad,
          searchController: _librarySearchController,
          query: _libQuery,
          sort: _sort,
          likedFilter: _likedFilter,
          onQueryChanged: (value) => setState(() => _libQuery = value),
          onSortChanged: (value) => setState(() => _sort = value),
          onLikedFilterChanged: (value) =>
              setState(() => _likedFilter = value),
        );
      case _MobilePage.history:
        return _HistoryPage(
          controller: controller,
          bottomPad: bottomPad,
          onExport: (format) => _exportHistory(controller, format),
          onClear: () => _confirmClearHistory(controller),
        );
      case _MobilePage.settings:
        return _SettingsPage(
          controller: controller,
          bottomPad: bottomPad,
          onExport: (format) => _exportHistory(controller, format),
          onClear: () => _confirmClearHistory(controller),
        );
    }
  }
}

// ════════════════════════════════════════════════════════════════
// SHARED ATOMS
// ════════════════════════════════════════════════════════════════

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.controller, this.tag});

  final String title;
  final MusicAppController controller;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: SonoText.pageTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: SonoPalette.accentTint,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                tag!,
                style: SonoText.mono.copyWith(color: SonoPalette.accent),
              ),
            ),
          ],
          const Spacer(),
          _CircleIconButton(
            icon: SonoPalette.isLight
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            onTap: controller.toggleThemeMode,
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.size = 36,
    this.iconSize = 18,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? SonoPalette.bg3,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: foreground ?? SonoPalette.textMuted,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.actionText, this.onAction});

  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Text(text, style: SonoText.section),
          const Spacer(),
          if (actionText != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText!,
                style: SonoText.mono.copyWith(color: SonoPalette.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 56),
      child: Column(
        children: [
          Icon(icon, size: 46, color: SonoPalette.textGhost),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: SonoText.body.copyWith(color: SonoPalette.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: SonoText.mono.copyWith(
              color: SonoPalette.textFaint,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// A track row used across home/library/history. [trailing] differs per page.
class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.playing,
    required this.onTap,
    this.trailing,
  });

  final Track track;
  final bool playing;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: playing ? SonoPalette.accentTint : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              SonoArtwork(
                track: track,
                size: 46,
                radius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SonoText.title.copyWith(
                        color: playing
                            ? SonoPalette.accent
                            : SonoPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SonoText.small.copyWith(
                        color: SonoPalette.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated equaliser bars shown on the currently-playing row.
class _PlayingBars extends StatefulWidget {
  const _PlayingBars();

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const phases = <double>[0.0, 0.25, 0.5, 0.25];
    return SizedBox(
      height: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < phases.length; i++) ...[
            if (i != 0) const SizedBox(width: 2),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = (_controller.value + phases[i]) % 1.0;
                final scale = 0.3 + (0.7 * (0.5 - (t - 0.5).abs()) * 2);
                return Container(
                  width: 2.5,
                  height: 14 * scale.clamp(0.2, 1.0),
                  decoration: BoxDecoration(
                    color: SonoPalette.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HOME PAGE
// ════════════════════════════════════════════════════════════════

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.controller,
    required this.bottomPad,
    required this.onOpenLibrary,
  });

  final MusicAppController controller;
  final double bottomPad;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final recent = controller.recentImportedTracks;
    final mostPlayed = controller.mostPlayedTracks.take(5).toList();
    final hour = DateTime.now().hour;
    final emoji = hour < 6
        ? '🌙'
        : hour < 12
        ? '🌅'
        : hour < 18
        ? '☀️'
        : '🌙';

    return ListView(
      padding: EdgeInsets.only(bottom: bottomPad),
      children: [
        _PageHeader(title: '首页', controller: controller),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Text(
            '今天想听什么？ $emoji',
            style: SonoText.small.copyWith(color: SonoPalette.textFaint),
          ),
        ),
        if (!controller.hasMusic)
          const _EmptyState(
            icon: Icons.library_music_outlined,
            title: '音乐库还是空的',
            body: '前往「音乐库」导入本地音乐文件\n支持 MP3、AAC、FLAC、WAV 等格式',
          )
        else ...[
          _SectionLabel(text: '最近添加', actionText: '全部 →', onAction: onOpenLibrary),
          SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final track = recent[index];
                return _HomeCard(
                  track: track,
                  onTap: () => controller.playTrack(
                    track,
                    collection: controller.collectionForTrack(track),
                  ),
                );
              },
            ),
          ),
          if (mostPlayed.isNotEmpty) ...[
            const _SectionLabel(text: '最常播放'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (final track in mostPlayed)
                    _TrackRow(
                      track: track,
                      playing:
                          controller.currentTrack?.id == track.id &&
                          controller.isPlaying,
                      onTap: () => controller.playTrack(
                        track,
                        collection: controller.collectionForTrack(track),
                      ),
                      trailing: _PlayCountTrailing(
                        track: track,
                        controller: controller,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _PlayCountTrailing extends StatelessWidget {
  const _PlayCountTrailing({required this.track, required this.controller});

  final Track track;
  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final playing =
        controller.currentTrack?.id == track.id && controller.isPlaying;
    if (playing) {
      return const _PlayingBars();
    }
    final plays = controller.playbackHistoryEntryForTrack(track.id)?.playCount;
    return Text(
      plays == null ? '' : '$plays 次',
      style: SonoText.mono.copyWith(color: SonoPalette.textGhost),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SonoPalette.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SonoPalette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SonoArtwork(
                  track: track,
                  size: 116,
                  radius: BorderRadius.circular(10),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: SonoPalette.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 16,
                      color: SonoPalette.cardPlayInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SonoText.title,
            ),
            const SizedBox(height: 2),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SonoText.mono.copyWith(color: SonoPalette.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// LIBRARY PAGE
// ════════════════════════════════════════════════════════════════

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({
    required this.controller,
    required this.bottomPad,
    required this.searchController,
    required this.query,
    required this.sort,
    required this.likedFilter,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onLikedFilterChanged,
  });

  final MusicAppController controller;
  final double bottomPad;
  final TextEditingController searchController;
  final String query;
  final _MobileSort sort;
  final bool likedFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_MobileSort> onSortChanged;
  final ValueChanged<bool> onLikedFilterChanged;

  List<Track> _resolve() {
    final q = query.trim().toLowerCase();
    final tracks = controller.importedTracks.where((track) {
      if (likedFilter && !controller.isTrackLiked(track.id)) {
        return false;
      }
      if (q.isEmpty) {
        return true;
      }
      return <String>[
        track.title,
        track.artist,
        track.album,
        track.fileName,
      ].join(' ').toLowerCase().contains(q);
    }).toList();

    switch (sort) {
      case _MobileSort.added:
        tracks.sort((a, b) => b.importedAt.compareTo(a.importedAt));
      case _MobileSort.name:
        tracks.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _MobileSort.artist:
        tracks.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
      case _MobileSort.duration:
        tracks.sort(
          (a, b) => (a.duration ?? Duration.zero)
              .compareTo(b.duration ?? Duration.zero),
        );
    }
    return tracks;
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _resolve();

    return ListView(
      padding: EdgeInsets.only(bottom: bottomPad),
      children: [
        _PageHeader(
          title: '音乐库',
          controller: controller,
          tag: '${tracks.length}',
        ),
        // Search field
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: SonoPalette.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SonoPalette.borderStrong),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: SonoPalette.textFaint),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onQueryChanged,
                  style: SonoText.body,
                  cursorColor: SonoPalette.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '搜索歌曲、歌手…',
                    hintStyle: SonoText.body.copyWith(
                      color: SonoPalette.textGhost,
                    ),
                  ),
                ),
              ),
              if (query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    searchController.clear();
                    onQueryChanged('');
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: SonoPalette.textFaint,
                  ),
                ),
            ],
          ),
        ),
        // Filter / sort chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _Chip(
                label: '喜欢',
                icon: likedFilter
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                active: likedFilter,
                onTap: () => onLikedFilterChanged(!likedFilter),
              ),
              const SizedBox(width: 8),
              for (final option in _MobileSort.values) ...[
                _Chip(
                  label: option.label,
                  active: sort == option,
                  onTap: () => onSortChanged(option),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        // Import zone
        _ImportZone(controller: controller),
        const SizedBox(height: 4),
        if (tracks.isEmpty)
          _EmptyState(
            icon: likedFilter
                ? Icons.favorite_border_rounded
                : Icons.search_off_rounded,
            title: likedFilter ? '还没有喜欢的歌曲' : '没有找到歌曲',
            body: likedFilter
                ? '在播放页点击 ♥ 收藏喜欢的歌曲'
                : '尝试不同的关键词，或导入更多音乐',
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (final track in tracks)
                  _TrackRow(
                    track: track,
                    playing:
                        controller.currentTrack?.id == track.id &&
                        controller.isPlaying,
                    onTap: () => controller.playTrack(
                      track,
                      collection: controller.collectionForTrack(track),
                    ),
                    trailing: _LibraryRowTrailing(
                      track: track,
                      controller: controller,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LibraryRowTrailing extends StatelessWidget {
  const _LibraryRowTrailing({required this.track, required this.controller});

  final Track track;
  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    final playing =
        controller.currentTrack?.id == track.id && controller.isPlaying;
    final liked = controller.isTrackLiked(track.id);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (liked)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              Icons.favorite_rounded,
              size: 12,
              color: SonoPalette.accent,
            ),
          ),
        Text(
          formatDuration(track.duration, placeholder: '--:--'),
          style: SonoText.mono.copyWith(color: SonoPalette.textGhost),
        ),
        const SizedBox(width: 4),
        if (playing)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: _PlayingBars(),
          )
        else
          _CircleIconButton(
            icon: Icons.delete_outline_rounded,
            size: 28,
            iconSize: 16,
            background: Colors.transparent,
            foreground: SonoPalette.textFaint,
            onTap: () => controller.removeTrackFromLibrary(track.id),
          ),
      ],
    );
  }
}

class _ImportZone extends StatelessWidget {
  const _ImportZone({required this.controller});

  final MusicAppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _DashedImportButton(
              icon: controller.isImporting
                  ? Icons.sync_rounded
                  : Icons.upload_rounded,
              title: controller.isImporting ? '正在导入…' : '导入本地音乐',
              subtitle: 'MP3 · AAC · FLAC · WAV · OGG',
              onTap: controller.isImporting
                  ? null
                  : controller.importLocalFiles,
            ),
          ),
          if (controller.supportsDirectoryImport) ...[
            const SizedBox(width: 10),
            _CircleIconButton(
              icon: Icons.folder_open_rounded,
              size: 52,
              iconSize: 22,
              background: SonoPalette.accentTint,
              foreground: SonoPalette.accent,
              onTap: controller.isImporting
                  ? () {}
                  : controller.importLocalFolder,
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedImportButton extends StatelessWidget {
  const _DashedImportButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SonoPalette.accent.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: SonoPalette.accent.withValues(alpha: 0.28),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: SonoPalette.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: SonoText.body.copyWith(
                        color: SonoPalette.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: SonoText.mono.copyWith(
                        color: SonoPalette.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? SonoPalette.accentTint : SonoPalette.bg3,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active
                ? SonoPalette.accent.withValues(alpha: 0.3)
                : SonoPalette.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: active ? SonoPalette.accent : SonoPalette.textMuted,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: SonoText.mono.copyWith(
                color: active ? SonoPalette.accent : SonoPalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HISTORY PAGE
// ════════════════════════════════════════════════════════════════

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({
    required this.controller,
    required this.bottomPad,
    required this.onExport,
    required this.onClear,
  });

  final MusicAppController controller;
  final double bottomPad;
  final ValueChanged<HistoryExportFormat> onExport;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final history = controller.recentPlayedTracks;
    final topTrack = controller.mostPlayedTracks.isEmpty
        ? null
        : controller.mostPlayedTracks.first;
    final artistCount = controller.playbackHistoryTracks
        .map((track) => track.artist)
        .toSet()
        .length;

    return ListView(
      padding: EdgeInsets.only(bottom: bottomPad),
      children: [
        _PageHeader(title: '播放记录', controller: controller),
        if (!controller.hasPlaybackHistory)
          const _EmptyState(
            icon: Icons.history_rounded,
            title: '还没有播放记录',
            body: '开始播放后自动记录',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    value: '${controller.playbackHistoryCount}',
                    label: '首歌曲',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    value: '${controller.totalPlayCount}',
                    label: '总播放',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(value: '$artistCount', label: '位歌手'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    value: topTrack == null ? '—' : topTrack.title,
                    label: '最爱单曲',
                    small: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _ExportButton(
                    icon: Icons.download_rounded,
                    label: 'CSV',
                    onTap: () => onExport(HistoryExportFormat.csv),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ExportButton(
                    icon: Icons.code_rounded,
                    label: 'JSON',
                    onTap: () => onExport(HistoryExportFormat.json),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ExportButton(
                    icon: Icons.delete_outline_rounded,
                    label: '清空',
                    danger: true,
                    onTap: onClear,
                  ),
                ),
              ],
            ),
          ),
          const _SectionLabel(text: '最近播放'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (final track in history)
                  _TrackRow(
                    track: track,
                    playing:
                        controller.currentTrack?.id == track.id &&
                        controller.isPlaying,
                    onTap: () => controller.playTrack(
                      track,
                      collection: controller.collectionForTrack(track),
                    ),
                    trailing: _PlayCountTrailing(
                      track: track,
                      controller: controller,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.small = false});

  final String value;
  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonoPalette.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SonoPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small
                ? SonoText.section.copyWith(
                    color: SonoPalette.accentSoft,
                    fontWeight: FontWeight.w300,
                  )
                : SonoText.stat,
          ),
          const SizedBox(height: 4),
          Text(label, style: SonoText.overline),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? SonoPalette.red : SonoPalette.textMuted;
    return Material(
      color: SonoPalette.bg2,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: danger
                  ? SonoPalette.red.withValues(alpha: 0.2)
                  : SonoPalette.borderStrong,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: SonoText.mono.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SETTINGS PAGE
// ════════════════════════════════════════════════════════════════

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.controller,
    required this.bottomPad,
    required this.onExport,
    required this.onClear,
  });

  final MusicAppController controller;
  final double bottomPad;
  final ValueChanged<HistoryExportFormat> onExport;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(bottom: bottomPad),
      children: [
        // Profile
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [SonoPalette.accent, SonoPalette.accentSoft],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'S',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w300,
                    color: SonoPalette.cardPlayInk,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('SŌNO Player', style: SonoText.section),
              const SizedBox(height: 4),
              Text(
                '${controller.importedTrackCount} 首歌曲 · ${controller.playbackHistoryCount} 条记录',
                style: SonoText.mono.copyWith(color: SonoPalette.textFaint),
              ),
            ],
          ),
        ),
        const _SettingsSection('外观'),
        _SettingsRow(
          icon: SonoPalette.isLight
              ? Icons.dark_mode_rounded
              : Icons.light_mode_rounded,
          iconAccent: true,
          label: SonoPalette.isLight ? '浅色主题' : '深色主题',
          subtitle: SonoPalette.isLight
              ? '米白 #F2EDE1 + 藕荷 #C07A92'
              : '曜黑 #0A0A0B + 暖金 #C9A96E',
          trailing: _ToggleSwitch(
            value: SonoPalette.isLight,
            onTap: controller.toggleThemeMode,
          ),
          onTap: controller.toggleThemeMode,
        ),
        const _SettingsSection('音乐'),
        _SettingsRow(
          icon: Icons.upload_rounded,
          iconAccent: true,
          label: '导入本地音乐',
          subtitle: 'MP3 · AAC · FLAC · WAV · OGG',
          onTap: controller.isImporting ? null : controller.importLocalFiles,
        ),
        const _SettingsSection('数据'),
        _SettingsRow(
          icon: Icons.download_rounded,
          iconColor: const Color(0xFF5CAD7A),
          label: '导出播放记录 CSV',
          subtitle: '包含所有播放历史数据',
          onTap: () => onExport(HistoryExportFormat.csv),
        ),
        _SettingsRow(
          icon: Icons.code_rounded,
          iconColor: const Color(0xFF6A9FD8),
          label: '导出播放记录 JSON',
          subtitle: '结构化数据格式',
          onTap: () => onExport(HistoryExportFormat.json),
        ),
        _SettingsRow(
          icon: Icons.delete_outline_rounded,
          iconColor: SonoPalette.red,
          label: '清空播放记录',
          labelColor: SonoPalette.red,
          subtitle: '此操作不可撤销',
          onTap: onClear,
        ),
        const _SettingsSection('关于'),
        _SettingsRow(
          icon: Icons.info_outline_rounded,
          iconColor: SonoPalette.accent,
          label: 'SŌNO Mobile',
          subtitle: 'v1.0 · 本地文件播放器',
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(title, style: SonoText.overline),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.iconAccent = false,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool iconAccent;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? SonoPalette.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconAccent
                      ? SonoPalette.accentTint
                      : resolvedIconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: resolvedIconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: SonoText.body.copyWith(
                        color: labelColor ?? SonoPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: SonoText.small.copyWith(
                        color: SonoPalette.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: SonoPalette.textGhost,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: value ? SonoPalette.accent : SonoPalette.bg4,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BOTTOM NAV
// ════════════════════════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.page,
    required this.bottomSafe,
    required this.onSelect,
  });

  final _MobilePage page;
  final double bottomSafe;
  final ValueChanged<_MobilePage> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kNavHeight + bottomSafe,
      padding: EdgeInsets.only(top: 8, bottom: bottomSafe),
      decoration: BoxDecoration(
        color: SonoPalette.bg1,
        border: Border(top: BorderSide(color: SonoPalette.border)),
      ),
      child: Row(
        children: [
          for (final destination in _MobilePage.values)
            Expanded(
              child: _NavTab(
                destination: destination,
                active: destination == page,
                onTap: () => onSelect(destination),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.destination,
    required this.active,
    required this.onTap,
  });

  final _MobilePage destination;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? SonoPalette.accent : SonoPalette.textFaint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? SonoPalette.accentTint : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(destination.icon, size: 22, color: color),
          ),
          const SizedBox(height: 4),
          Text(destination.label, style: SonoText.mono.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MINI PLAYER
// ════════════════════════════════════════════════════════════════

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.controller, required this.onOpen});

  final MusicAppController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final track = controller.currentTrack;
    if (track == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        height: _kMiniHeight,
        padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
        decoration: BoxDecoration(
          color: SonoPalette.miniBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: SonoPalette.borderStrong),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                SonoArtwork(
                  track: track,
                  size: 44,
                  radius: BorderRadius.circular(12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SonoText.title,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SonoText.small.copyWith(
                          color: SonoPalette.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                _CircleIconButton(
                  icon: Icons.skip_previous_rounded,
                  size: 36,
                  iconSize: 20,
                  background: Colors.transparent,
                  foreground: SonoPalette.textPrimary,
                  onTap: controller.skipPrevious,
                ),
                _CircleIconButton(
                  icon: controller.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 36,
                  iconSize: 18,
                  background: SonoPalette.accent,
                  foreground: SonoPalette.cardPlayInk,
                  onTap: controller.togglePlayPause,
                ),
                _CircleIconButton(
                  icon: Icons.skip_next_rounded,
                  size: 36,
                  iconSize: 20,
                  background: Colors.transparent,
                  foreground: SonoPalette.textPrimary,
                  onTap: controller.skipNext,
                ),
              ],
            ),
            const SizedBox(height: 4),
            _ProgressLine(progress: controller.playbackProgress),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: clamped,
        minHeight: 2,
        backgroundColor: SonoPalette.bg4,
        valueColor: AlwaysStoppedAnimation<Color>(SonoPalette.accent),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TOAST
// ════════════════════════════════════════════════════════════════

class _Toast extends StatelessWidget {
  const _Toast({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: SonoPalette.bg3,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: SonoPalette.borderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: SonoText.body.copyWith(fontSize: 13),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// NOW PLAYING SHEET
// ════════════════════════════════════════════════════════════════

class _NowPlayingSheet extends StatefulWidget {
  const _NowPlayingSheet();

  @override
  State<_NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<_NowPlayingSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = controller.currentTrack;

    if (track == null) {
      // Track was removed/cleared while open — dismiss on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
      return const SizedBox.shrink();
    }

    final liked = controller.isTrackLiked(track.id);
    final artSize = (MediaQuery.sizeOf(context).width * 0.72).clamp(160.0, 280.0);
    final upNext = controller.upNext;

    return FractionallySizedBox(
      heightFactor: 0.96,
      child: Container(
        decoration: BoxDecoration(
          color: SonoPalette.sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: SonoPalette.bg4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                children: [
                  Text('正在播放', style: SonoText.overline),
                  const Spacer(),
                  _CircleIconButton(
                    icon: Icons.close_rounded,
                    size: 32,
                    iconSize: 16,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
                children: [
                  // Artwork
                  Center(
                    child: AnimatedBuilder(
                      animation: _float,
                      builder: (context, child) {
                        final offset = controller.isPlaying
                            ? (_float.value - 0.5) * 12
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(0, offset),
                          child: child,
                        );
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 48,
                              offset: const Offset(0, 24),
                            ),
                          ],
                        ),
                        child: SonoArtwork(
                          track: track,
                          size: artSize.toDouble(),
                          radius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Title + like
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SonoText.npTitle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SonoText.body.copyWith(
                                color: SonoPalette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CircleIconButton(
                        icon: liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 40,
                        iconSize: 20,
                        foreground: liked
                            ? SonoPalette.accent
                            : SonoPalette.textMuted,
                        onTap: () => controller.toggleLikedTrack(track.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Seek bar
                  _SeekBar(
                    progress: controller.playbackProgress,
                    onSeek: controller.seekToFraction,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(controller.position, placeholder: '0:00'),
                        style: SonoText.mono.copyWith(
                          color: SonoPalette.textFaint,
                        ),
                      ),
                      Text(
                        formatDuration(track.duration, placeholder: '0:00'),
                        style: SonoText.mono.copyWith(
                          color: SonoPalette.textFaint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Transport
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TransportButton(
                        icon: Icons.shuffle_rounded,
                        active: controller.isShuffleEnabled,
                        size: 22,
                        onTap: controller.toggleShuffle,
                      ),
                      _TransportButton(
                        icon: Icons.skip_previous_rounded,
                        size: 28,
                        onTap: controller.skipPrevious,
                      ),
                      _PlayButton(
                        playing: controller.isPlaying,
                        onTap: controller.togglePlayPause,
                      ),
                      _TransportButton(
                        icon: Icons.skip_next_rounded,
                        size: 28,
                        onTap: controller.skipNext,
                      ),
                      _TransportButton(
                        icon: Icons.repeat_rounded,
                        active: controller.isRepeatEnabled,
                        size: 22,
                        onTap: controller.toggleRepeat,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Volume
                  Row(
                    children: [
                      Icon(
                        Icons.volume_down_rounded,
                        size: 18,
                        color: SonoPalette.textFaint,
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            activeTrackColor: SonoPalette.accent,
                            inactiveTrackColor: SonoPalette.bg4,
                            thumbColor: SonoPalette.textPrimary,
                            overlayColor: SonoPalette.accent.withValues(
                              alpha: 0.16,
                            ),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                          ),
                          child: Slider(
                            value: controller.volume.clamp(0.0, 1.0),
                            onChanged: controller.setVolume,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.volume_up_rounded,
                        size: 18,
                        color: SonoPalette.textFaint,
                      ),
                    ],
                  ),
                  if (upNext.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _UpNextPeek(
                      track: upNext.first,
                      onTap: () {
                        controller.playTrack(
                          upNext.first,
                          collection: controller.collectionForTrack(
                            upNext.first,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.progress, required this.onSeek});

  final double progress;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
        void seek(Offset local) =>
            onSeek((local.dx / width).clamp(0.0, 1.0));

        final fillWidth = width * clamped;
        final maxLeft = (width - 14).clamp(0.0, double.infinity);
        final thumbLeft = (fillWidth - 7).clamp(0.0, maxLeft).toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => seek(details.localPosition),
          onHorizontalDragUpdate: (details) => seek(details.localPosition),
          child: SizedBox(
            height: 18,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 7,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: SonoPalette.bg4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 7,
                  child: Container(
                    width: fillWidth,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [SonoPalette.accent, SonoPalette.accentSoft],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  left: thumbLeft,
                  top: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: SonoPalette.textPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.onTap,
    this.size = 24,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            size: size,
            color: active ? SonoPalette.accent : SonoPalette.textMuted,
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SonoPalette.accent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 30,
            color: SonoPalette.cardPlayInk,
          ),
        ),
      ),
    );
  }
}

class _UpNextPeek extends StatelessWidget {
  const _UpNextPeek({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SonoPalette.bg2,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SonoPalette.border),
          ),
          child: Row(
            children: [
              SonoArtwork(
                track: track,
                size: 36,
                radius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('接下来', style: SonoText.overline),
                    const SizedBox(height: 3),
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SonoText.small.copyWith(
                        color: SonoPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: SonoPalette.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
