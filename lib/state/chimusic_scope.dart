import 'package:flutter/widgets.dart';

import 'chimusic_controller.dart';

class ChiMusicScope extends InheritedNotifier<MusicAppController> {
  const ChiMusicScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static MusicAppController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ChiMusicScope>();
    assert(
      scope != null,
      'ChiMusicScope.watch() called with no scope present.',
    );
    return scope!.notifier!;
  }

  static MusicAppController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<ChiMusicScope>();
    final scope = element?.widget as ChiMusicScope?;
    assert(scope != null, 'ChiMusicScope.read() called with no scope present.');
    return scope!.notifier!;
  }
}
