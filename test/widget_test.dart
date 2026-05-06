import 'package:chimusic/app/chimusic_app.dart';
import 'package:chimusic/state/chimusic_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots into the primary navigation shell', (tester) async {
    final controller = MusicAppController(enableAudio: false);

    await tester.pumpWidget(ChiMusicRoot(controller: controller));
    await tester.pump();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Library'), findsWidgets);
    expect(
      find.text('Turn local files into a full music app experience.'),
      findsOneWidget,
    );

    controller.dispose();
  });
}
