import 'package:flutter_test/flutter_test.dart';

import 'package:cardaily/main.dart';

void main() {
  testWidgets('CarDailyApp launches to the splash intro screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CarDailyApp());
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
  });
}
