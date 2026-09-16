import 'package:flutter_test/flutter_test.dart';
import 'package:game/main.dart';

void main() {
  testWidgets('App loads lobby screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UrsinaMultiplayerApp());
    expect(find.text('Ursina TCP Deathmatch'), findsOneWidget);
    expect(find.text('Enter your username:'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });
}
