import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/music_models.dart';
import '../state/chimusic_controller.dart';
import '../state/chimusic_scope.dart';

const oceanArtwork = 'assets/images/immersive_ocean.png';
const vinylArtwork = 'assets/images/immersive_vinyl.png';

/// Album artwork always takes precedence over the bundled fallback cover.
class PlayerArtwork extends StatelessWidget {
  const PlayerArtwork({
    super.key,
    required this.track,
    this.fit = BoxFit.cover,
  });

  final Track track;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Image.asset(oceanArtwork, fit: fit);
    final uri = track.artworkUri;
    if (uri == null || uri.isEmpty || uri.startsWith('mock:')) {
      return fallback();
    }
    if (uri.startsWith('assets/')) {
      return Image.asset(uri, fit: fit, errorBuilder: (_, _, _) => fallback());
    }
    if (!kIsWeb) {
      final path = uri.startsWith('file:') ? Uri.parse(uri).toFilePath() : uri;
      return Image.file(
        File(path),
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return fallback();
  }
}

class _PlayerColors {
  const _PlayerColors(this.light);
  final bool light;
  Color get background =>
      light ? const Color(0xFFF3EDE1) : const Color(0xFF030D12);
  Color get text => light ? const Color(0xFF342012) : const Color(0xFFF5F9F8);
  Color get muted => light ? const Color(0xFF806B59) : const Color(0xFFB6C6CD);
  Color get accent => light ? const Color(0xFFAB4828) : const Color(0xFFB4F4EA);
  Color get line => light ? const Color(0xFFDCD0C0) : const Color(0xFF3B5058);
  String? get displayFont => light ? 'NotoSerifSC' : null;
}

/// Shared Android/iOS full player with two deliberately different compositions.
/// The controller owns playback, history and durable theme selection.
class ImmersivePlayer extends StatelessWidget {
  const ImmersivePlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChiMusicScope.watch(context);
    final track = controller.currentTrack;
    final colors = _PlayerColors(controller.themeMode == AppThemeMode.light);
    if (track == null) {
      return Material(
        color: colors.background,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('还没有正在播放的歌曲', style: TextStyle(color: colors.text)),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('返回音乐库'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox.expand(
      child: Material(
        color: colors.background,
        child: Stack(
          children: [
            if (!colors.light)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: 0.20,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: PlayerArtwork(track: track),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Retain the full-size composition on phones; smaller displays
                  // and larger accessibility text can scroll without clipping.
                  final width = math.min(constraints.maxWidth, 480.0);
                  final artSize = math
                      .min(width - 48, constraints.maxHeight * 0.408)
                      .clamp(200.0, 380.0);
                  return Center(
                    child: SizedBox(
                      width: width,
                      child: SingleChildScrollView(
                        key: const Key('immersive-scroll'),
                        padding: EdgeInsets.fromLTRB(
                          24,
                          colors.light ? 14 : 28,
                          24,
                          22,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - (colors.light ? 36 : 50),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Header(colors: colors, controller: controller),
                              SizedBox(height: colors.light ? 6 : 10),
                              Center(
                                child: SizedBox.square(
                                  dimension: artSize,
                                  child: colors.light
                                      ? _Vinyl(track: track)
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: PlayerArtwork(track: track),
                                        ),
                                ),
                              ),
                              SizedBox(height: colors.light ? 24 : 26),
                              _TitleBlock(
                                track: track,
                                controller: controller,
                                colors: colors,
                              ),
                              if (!colors.light) ...[
                                const SizedBox(height: 10),
                                _LyricsPeek(
                                  track: track,
                                  controller: controller,
                                  colors: colors,
                                ),
                              ],
                              SizedBox(height: colors.light ? 10 : 8),
                              _Progress(
                                controller: controller,
                                track: track,
                                colors: colors,
                              ),
                              SizedBox(height: colors.light ? 0 : 6),
                              _Transport(
                                controller: controller,
                                colors: colors,
                              ),
                              SizedBox(height: colors.light ? 24 : 30),
                              _HistoryPeek(
                                controller: controller,
                                colors: colors,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors, required this.controller});
  final _PlayerColors colors;
  final MusicAppController controller;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (!colors.light)
        _Action(
          label: '收起播放器',
          icon: Icons.keyboard_arrow_down_rounded,
          color: colors.text,
          onPressed: () => Navigator.maybePop(context),
        ),
      Expanded(
        child: Column(
          crossAxisAlignment: colors.light
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Text(
              'ChiMusic',
              style: TextStyle(
                color: colors.text,
                fontFamily: colors.displayFont,
                fontSize: colors.light ? 24 : 21,
                fontWeight: colors.light ? FontWeight.w700 : FontWeight.w300,
                letterSpacing: colors.light ? -1 : 2.8,
              ),
            ),
            if (colors.light)
              Text(
                '此刻在听',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
          ],
        ),
      ),
      PopupMenuButton<String>(
        tooltip: '播放选项',
        color: colors.background,
        icon: Icon(Icons.more_horiz_rounded, color: colors.text),
        onSelected: (value) {
          switch (value) {
            case 'theme':
              controller.toggleThemeMode();
            case 'queue':
              _showPanel(context, controller, '播放队列');
            case 'lyrics':
              _showPanel(context, controller, '歌词');
            case 'volume':
              _showPanel(context, controller, '音量');
            case 'shuffle':
              controller.toggleShuffle();
            case 'repeat':
              controller.toggleRepeat();
            case 'close':
              Navigator.maybePop(context);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'theme',
            child: Text(
              colors.light ? '切换深色主题' : '切换浅色主题',
              style: TextStyle(color: colors.text),
            ),
          ),
          for (final entry in {
            'queue': '播放队列',
            'lyrics': '歌词',
            'volume': '音量',
            'shuffle': controller.isShuffleEnabled ? '关闭随机播放' : '随机播放',
            'repeat': controller.isRepeatEnabled ? '关闭循环播放' : '循环播放',
            'close': '收起播放器',
          }.entries)
            PopupMenuItem(
              value: entry.key,
              child: Text(entry.value, style: TextStyle(color: colors.text)),
            ),
        ],
      ),
    ],
  );
}

class _Vinyl extends StatelessWidget {
  const _Vinyl({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final hasCover =
          track.artworkUri != null &&
          track.artworkUri!.isNotEmpty &&
          !track.artworkUri!.startsWith('mock:');
      return Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(vinylArtwork, fit: BoxFit.contain),
          if (hasCover)
            ClipOval(
              child: SizedBox.square(
                dimension: constraints.maxWidth * 0.37,
                child: PlayerArtwork(track: track),
              ),
            ),
        ],
      );
    },
  );
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.track,
    required this.controller,
    required this.colors,
  });
  final Track track;
  final MusicAppController controller;
  final _PlayerColors colors;

  @override
  Widget build(BuildContext context) {
    final liked = controller.isTrackLiked(track.id);
    final favorite = _Action(
      label: liked ? '取消喜欢' : '喜欢歌曲',
      icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: liked ? colors.accent : colors.text,
      onPressed: () => controller.toggleLikedTrack(track.id),
    );
    return Row(
      children: [
        if (colors.light) favorite,
        Expanded(
          child: Column(
            crossAxisAlignment: colors.light
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: colors.light ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: colors.text,
                  fontFamily: colors.displayFont,
                  fontSize: colors.light ? 32 : 29,
                  height: 1.2,
                  fontWeight: colors.light ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: colors.light ? 15 : 17,
                  fontFamily: colors.displayFont,
                  letterSpacing: colors.light ? 2 : 0,
                ),
              ),
            ],
          ),
        ),
        if (!colors.light) favorite,
        if (colors.light)
          _Action(
            label: '播放队列',
            icon: Icons.queue_music_rounded,
            color: colors.text,
            onPressed: () => _showPanel(context, controller, '播放队列'),
          ),
      ],
    );
  }
}

class _LyricsPeek extends StatelessWidget {
  const _LyricsPeek({
    required this.track,
    required this.controller,
    required this.colors,
  });
  final Track track;
  final MusicAppController controller;
  final _PlayerColors colors;

  @override
  Widget build(BuildContext context) {
    final lyrics = controller.lyricsStateForTrack(track);
    return InkWell(
      onTap: () => _showPanel(context, controller, '歌词'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lyrics.hasLyrics ? lyrics.lines.first : '静静聆听，让音乐陪着你',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.text, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 4),
            Text(
              lyrics.lines.length > 1 ? lyrics.lines[1] : '暂无歌词',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.muted, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.controller,
    required this.track,
    required this.colors,
  });
  final MusicAppController controller;
  final Track track;
  final _PlayerColors colors;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 26,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            padding: EdgeInsets.zero,
            trackHeight: 3,
            activeTrackColor: colors.accent,
            inactiveTrackColor: colors.line,
            thumbColor: colors.accent,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            key: const Key('player-progress'),
            label: formatDuration(controller.position, placeholder: '0:00'),
            value: controller.playbackProgress.clamp(0.0, 1.0),
            onChanged: track.duration == null
                ? null
                : controller.seekToFraction,
            onChangeEnd: (_) => controller.flushSession(),
          ),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formatDuration(controller.position, placeholder: '0:00'),
            style: TextStyle(color: colors.muted, fontSize: 13),
          ),
          Text(
            formatDuration(track.duration, placeholder: '--:--'),
            style: TextStyle(color: colors.muted, fontSize: 13),
          ),
        ],
      ),
    ],
  );
}

class _Transport extends StatelessWidget {
  const _Transport({required this.controller, required this.colors});
  final MusicAppController controller;
  final _PlayerColors colors;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: colors.light
        ? MainAxisAlignment.spaceBetween
        : MainAxisAlignment.spaceEvenly,
    children: [
      if (colors.light)
        _Action(
          label: controller.isShuffleEnabled ? '关闭随机播放' : '随机播放',
          icon: Icons.shuffle_rounded,
          size: 21,
          color: controller.isShuffleEnabled ? colors.accent : colors.muted,
          onPressed: controller.toggleShuffle,
        ),
      _Action(
        label: '上一首',
        icon: Icons.skip_previous_rounded,
        size: 42,
        color: colors.text,
        onPressed: controller.skipPrevious,
      ),
      Semantics(
        button: true,
        excludeSemantics: true,
        onTap: controller.togglePlayPause,
        label: controller.isPlaying ? '暂停' : '播放',
        child: SizedBox.square(
          dimension: colors.light ? 70 : 76,
          child: OutlinedButton(
            key: const Key('player-play-pause'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              backgroundColor: colors.light
                  ? colors.text
                  : colors.background.withValues(alpha: 0.55),
              side: BorderSide(
                color: colors.light ? colors.text : colors.accent,
                width: 1.5,
              ),
              foregroundColor: colors.light ? colors.background : colors.text,
            ),
            onPressed: controller.togglePlayPause,
            child: Icon(
              controller.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 38,
            ),
          ),
        ),
      ),
      _Action(
        label: '下一首',
        icon: Icons.skip_next_rounded,
        size: 42,
        color: colors.text,
        onPressed: controller.skipNext,
      ),
      if (colors.light)
        _Action(
          label: controller.isRepeatEnabled ? '关闭循环播放' : '循环播放',
          icon: Icons.repeat_rounded,
          size: 21,
          color: controller.isRepeatEnabled ? colors.accent : colors.muted,
          onPressed: controller.toggleRepeat,
        ),
    ],
  );
}

class _HistoryPeek extends StatelessWidget {
  const _HistoryPeek({required this.controller, required this.colors});
  final MusicAppController controller;
  final _PlayerColors colors;

  @override
  Widget build(BuildContext context) {
    final tracks = controller.playbackHistoryTracks
        .where((t) => t.id != controller.currentTrack?.id)
        .toList();
    if (!colors.light) {
      return InkWell(
        key: const Key('player-history'),
        onTap: () => _showPanel(context, controller, '播放记录'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(Icons.schedule_outlined, color: colors.text, size: 26),
              const SizedBox(width: 10),
              Text('播放记录', style: TextStyle(color: colors.text, fontSize: 15)),
              const Spacer(),
              Flexible(
                child: Text(
                  '自动保存进度',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.muted),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: colors.line, height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '聆听足迹',
                style: TextStyle(
                  fontFamily: colors.displayFont,
                  fontSize: 23,
                  color: colors.text,
                ),
              ),
            ),
            TextButton(
              key: const Key('player-history'),
              onPressed: () => _showPanel(context, controller, '播放记录'),
              style: TextButton.styleFrom(foregroundColor: colors.muted),
              child: const Text('查看全部 ›'),
            ),
          ],
        ),
        if (tracks.isNotEmpty)
          _HistoryRow(
            track: tracks.first,
            controller: controller,
            colors: colors,
            compact: true,
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              '听过的歌曲会留在这里',
              style: TextStyle(color: colors.muted, fontSize: 14),
            ),
          ),
        const SizedBox(height: 12),
        Divider(color: colors.line, height: 1),
        const SizedBox(height: 16),
        Text(
          '播放记录与进度自动保存在本机',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.track,
    required this.controller,
    required this.colors,
    this.compact = false,
  });
  final Track track;
  final MusicAppController controller;
  final _PlayerColors colors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final entry = controller.playbackHistoryEntryForTrack(track.id);
    final date = entry?.lastPlayedAt.toLocal();
    final time = date == null
        ? ''
        : '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} · ';
    return InkWell(
      onTap: () => controller.resumeTrack(track),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox.square(
                dimension: compact ? 58 : 48,
                child: PlayerArtwork(track: track),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: compact ? 18 : 16,
                      fontFamily: colors.displayFont,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${compact ? '' : time}上次听到 ${formatDuration(entry?.lastPosition, placeholder: '0:00')}',
                    maxLines: 2,
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            _Action(
              label: '继续播放 ${track.title}',
              icon: Icons.play_circle_fill_rounded,
              color: colors.accent,
              size: 36,
              onPressed: () => controller.resumeTrack(track),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.size = 26,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    color: color,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
    padding: const EdgeInsets.all(4),
    icon: Icon(icon, size: size),
  );
}

void _showPanel(
  BuildContext context,
  MusicAppController controller,
  String title,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final colors = _PlayerColors(
          controller.themeMode == AppThemeMode.light,
        );
        final track = controller.currentTrack;
        return FractionallySizedBox(
          heightFactor: 0.65,
          child: Material(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 24,
                              fontFamily: colors.displayFont,
                            ),
                          ),
                        ),
                        _Action(
                          label: '关闭$title',
                          icon: Icons.close_rounded,
                          color: colors.muted,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      children: [
                        if (title == '播放记录') ...[
                          Text(
                            '保存在本机 · 点击歌曲接着听',
                            style: TextStyle(color: colors.muted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          if (controller.playbackHistoryTracks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: Text(
                                '暂无播放记录',
                                style: TextStyle(color: colors.muted),
                              ),
                            ),
                          for (final item in controller.playbackHistoryTracks)
                            _HistoryRow(
                              track: item,
                              controller: controller,
                              colors: colors,
                            ),
                        ],
                        if (title == '播放队列') ...[
                          for (final item in controller.queue)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item.title,
                                style: TextStyle(
                                  color: item.id == track?.id
                                      ? colors.accent
                                      : colors.text,
                                ),
                              ),
                              subtitle: Text(
                                item.artist,
                                style: TextStyle(color: colors.muted),
                              ),
                              trailing: Icon(
                                Icons.play_arrow_rounded,
                                color: colors.accent,
                              ),
                              onTap: () => controller.playTrack(item),
                            ),
                        ],
                        if (title == '歌词' && track != null) ...[
                          if (!controller.lyricsStateForTrack(track).hasLyrics)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                '这首歌暂无歌词\n静静聆听，让音乐陪着你',
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 18,
                                  height: 2,
                                ),
                              ),
                            ),
                          for (final line
                              in controller.lyricsStateForTrack(track).lines)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                line,
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 22,
                                  height: 1.6,
                                ),
                              ),
                            ),
                        ],
                        if (title == '音量')
                          Slider(
                            label: '${(controller.volume * 100).round()}%',
                            value: controller.volume.clamp(0.0, 1.0),
                            activeColor: colors.accent,
                            onChanged: controller.setVolume,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
