import 'package:flutter_test/flutter_test.dart';

import 'package:alburagh_app/main.dart';

void main() {
  testWidgets('app renders its primary navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(initialCurrency: 'USD'));

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('الأقسام'), findsOneWidget);
    expect(find.text('السلة'), findsOneWidget);
    expect(find.text('المفضلة'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);
  });
}
