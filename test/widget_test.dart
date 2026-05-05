import 'package:chimusic/app/chimusic_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots into the primary navigation shell', (tester) async {
    await tester.pumpWidget(const ChiMusicRoot());
    await tester.pump();

    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });
}
