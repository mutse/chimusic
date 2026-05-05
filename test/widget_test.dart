import 'package:chimusic/app/chimusic_app.dart';
import 'package:chimusic/state/chimusic_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots into the primary navigation shell', (tester) async {
    final controller = MusicAppController(enableAudio: false);

    await tester.pumpWidget(ChiMusicRoot(controller: controller));
    await tester.pump();

    expect(find.text('Local music'), findsOneWidget);
    expect(find.text('Import local music to begin'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);

    controller.dispose();
  });
}
