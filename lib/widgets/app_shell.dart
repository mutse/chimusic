import 'package:flutter/material.dart';

import 'glass.dart';
import 'macos_player_shell.dart';
import 'mobile_player_shell.dart';

/// Routes to the platform-appropriate player surface: a desktop shell for wide
/// windows (macOS/desktop), and the SŌNO mobile shell for phone-sized widths
/// (Android/iOS). See `docs/music-player-mobile.html` for the mobile design.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return isDesktopWidth(context)
        ? const MacosPlayerShell()
        : const MobilePlayerShell();
  }
}
