import 'package:flutter_test/flutter_test.dart';

import 'package:alburagh_app/main.dart';

void main() {
  testWidgets('app renders its primary navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(initialCurrency: 'USD'));
    // Lets the HomeScreen initState kicks off (categories, product
    // sections, cart) run to completion: the test environment's fake
    // HttpClient fails them immediately (see the "creates an HttpClient"
    // warning flutter test prints), but each still schedules a real Dio
    // connect-timeout Timer that needs the fake clock advanced past it to
    // be cancelled -- otherwise it's still "pending" when the test tears
    // down right after the first frame.
    await tester.pump(const Duration(seconds: 35));

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('السلة'), findsOneWidget);
    expect(find.text('المفضلة'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);
  });
}
