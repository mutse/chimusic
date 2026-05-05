import 'package:flutter/material.dart';

import '../state/chimusic_controller.dart';
import '../state/chimusic_scope.dart';
import '../widgets/app_shell.dart';
import 'chimusic_theme.dart';

class ChiMusicRoot extends StatefulWidget {
  const ChiMusicRoot({super.key, this.controller});

  final MusicAppController? controller;

  @override
  State<ChiMusicRoot> createState() => _ChiMusicRootState();
}

class _ChiMusicRootState extends State<ChiMusicRoot> {
  late final MusicAppController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? MusicAppController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChiMusicScope(
      notifier: _controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ChiMusic',
        theme: buildChiMusicTheme(),
        home: const AppShell(),
      ),
    );
  }
}
