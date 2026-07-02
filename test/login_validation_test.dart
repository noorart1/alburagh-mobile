import 'package:alburagh_app/screens/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts username login identifiers', () {
    expect(validateUsernameOrEmail('admin'), isNull);
    expect(validateUsernameOrEmail('admin123'), isNull);
  });

  test('rejects empty login identifiers', () {
    expect(validateUsernameOrEmail('   '), isNotNull);
    expect(validateUsernameOrEmail(''), isNotNull);
  });
}
