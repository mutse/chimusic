import 'dart:async';

import 'package:flutter/material.dart';

import '../data/music_session_store.dart';
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

class _ChiMusicRootState extends State<ChiMusicRoot>
    with WidgetsBindingObserver {
  late final MusicAppController _controller;
  late final bool _ownsController;
  late final Future<void>? _restoreFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        MusicAppController(sessionStore: SharedPreferencesMusicSessionStore());
    _restoreFuture = _controller.restoreSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_controller.flushSession());
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        home: _restoreFuture == null
            ? const AppShell()
            : FutureBuilder<void>(
                future: _restoreFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _StartupScreen();
                  }

                  return const AppShell();
                },
              ),
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(child: CircularProgressIndicator(strokeWidth: 2.6)),
    );
  }
}
