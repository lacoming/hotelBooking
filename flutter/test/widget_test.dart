import 'package:flutter_test/flutter_test.dart';

import 'package:mini_booking/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MiniBookingApp());
    expect(find.text('Hotels'), findsOneWidget);
  });
}
