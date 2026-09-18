import 'package:flutter_test/flutter_test.dart';
import 'package:game/main.dart';

void main() {
  testWidgets('App loads lobby screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UrsinaMultiplayerApp());
    expect(find.text('DEATHMATCH 3D'), findsOneWidget);
    expect(find.text('Callsign / Username'), findsOneWidget);
    expect(find.text('JOIN BATTLE'), findsOneWidget);
  });
}
