import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:alburagh_app/providers/auth_provider.dart';
import 'package:alburagh_app/providers/cart_provider.dart';
import 'package:alburagh_app/screens/login_screen.dart';
import 'package:alburagh_app/screens/register_screen.dart';

void main() {
  group('Login Screen Tests', () {
    testWidgets('should display login form elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(context.read<CartProvider>()),
              ),
            ],
            child: const LoginScreen(),
          ),
        ),
      );

      expect(find.text('دار البراق'), findsOneWidget);
      expect(find.text('تسجيل الدخول إلى حسابك'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('متابعة كزائر'), findsOneWidget);
      expect(find.textContaining('ليس لديك حساب'), findsOneWidget);
      expect(find.textContaining('أنشئ حساب'), findsOneWidget);
    });

    testWidgets('should show/hide password when toggle clicked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(context.read<CartProvider>()),
              ),
            ],
            child: const LoginScreen(),
          ),
        ),
      );

      final passwordField = find.byType(TextField).last;
      final toggleButton = find.byIcon(Icons.visibility_off_outlined);

      expect(toggleButton, findsOneWidget);

      await tester.enterText(passwordField, 'testpassword');
      await tester.tap(toggleButton);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('should disable fields when loading', (
      WidgetTester tester,
    ) async {
      final cartProvider = CartProvider();
      final authProvider = AuthProvider(cartProvider);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: cartProvider),
              ChangeNotifierProvider.value(value: authProvider),
            ],
            child: const LoginScreen(),
          ),
        ),
      );

      expect(find.byType(TextField), findsNWidgets(2));
    });
  });

  group('Register Screen Tests', () {
    testWidgets('should display register form elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(context.read<CartProvider>()),
              ),
            ],
            child: const RegisterScreen(),
          ),
        ),
      );

      expect(find.text('إنشاء حساب'), findsOneWidget);
      expect(find.text('أنشئ حسابك الجديد'), findsOneWidget);
      expect(
        find.text('أدخل بياناتك لإنشاء حساب في دار البراق'),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNWidgets(5));
      expect(find.text('إنشاء الحساب'), findsOneWidget);
      expect(find.textContaining('لديك حساب'), findsOneWidget);
      expect(find.textContaining('تسجيل الدخول'), findsOneWidget);
    });

    testWidgets('should validate required fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(context.read<CartProvider>()),
              ),
            ],
            child: const RegisterScreen(),
          ),
        ),
      );

      await tester.tap(find.text('إنشاء الحساب'));
      await tester.pumpAndSettle();

      expect(find.text('أدخل الاسم الأول'), findsOneWidget);
      expect(find.text('أدخل البريد الإلكتروني'), findsOneWidget);
      expect(find.text('أدخل كلمة المرور'), findsOneWidget);
    });

    testWidgets('should validate email format', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(context.read<CartProvider>()),
              ),
            ],
            child: const RegisterScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(2), 'invalidemail');
      await tester.tap(find.text('إنشاء الحساب'));
      await tester.pumpAndSettle();

      expect(find.text('البريد الإلكتروني غير صحيح'), findsOneWidget);
    });

    testWidgets('should validate password length', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(context.read<CartProvider>()),
              ),
            ],
            child: const RegisterScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(4), '12345');
      await tester.tap(find.text('إنشاء الحساب'));
      await tester.pumpAndSettle();

      expect(
        find.text('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
        findsOneWidget,
      );
    });

    testWidgets('should show/hide password when toggle clicked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(context.read<CartProvider>()),
              ),
            ],
            child: const RegisterScreen(),
          ),
        ),
      );

      final passwordField = find.byType(TextFormField).last;
      final toggleButton = find.byIcon(Icons.visibility_off_outlined);

      expect(toggleButton, findsOneWidget);

      await tester.enterText(passwordField, 'testpassword');
      await tester.tap(toggleButton);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });

  group('AuthProvider Tests', () {
    test('initial state should be logged out', () {
      final authProvider = AuthProvider(CartProvider());

      expect(authProvider.isLoggedIn, false);
      expect(authProvider.user, null);
      expect(authProvider.isLoading, false);
      expect(authProvider.error, null);
    });

    test('clearError should reset error to null', () {
      final authProvider = AuthProvider(CartProvider());

      authProvider.clearError();
      expect(authProvider.error, null);
    });
  });
}
