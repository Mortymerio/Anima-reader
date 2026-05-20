import 'package:flutter_test/flutter_test.dart';
import 'package:anima/main.dart';

void main() {
  testWidgets('AnimaApp renders setup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AnimaApp());

    // Verify the app title is displayed
    expect(find.text('Anima Library'), findsOneWidget);

    // Verify setup form fields are present
    expect(find.text('CONNECT LIBRARY'), findsOneWidget);
  });
}
