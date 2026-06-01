import 'package:flutter/widgets.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/chimusic_app.dart';
import 'app/chimusic_branding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: chimusicNotificationChannelId,
    androidNotificationChannelName: chimusicNotificationChannelName,
    androidNotificationOngoing: true,
  );
  runApp(const ChiMusicRoot());
}
