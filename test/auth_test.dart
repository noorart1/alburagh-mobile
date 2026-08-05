import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:alburagh_app/providers/auth_provider.dart';
import 'package:alburagh_app/providers/cart_provider.dart';
import 'package:alburagh_app/providers/wishlist_provider.dart';
import 'package:alburagh_app/screens/register_screen.dart';

void main() {
  group('Register Screen Tests', () {
    testWidgets('should display register form elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(create: (_) => WishlistProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(
                  context.read<CartProvider>(),
                  context.read<WishlistProvider>(),
                ),
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
              ChangeNotifierProvider(create: (_) => WishlistProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(
                  context.read<CartProvider>(),
                  context.read<WishlistProvider>(),
                ),
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
              ChangeNotifierProvider(create: (_) => WishlistProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(
                  context.read<CartProvider>(),
                  context.read<WishlistProvider>(),
                ),
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
              ChangeNotifierProvider(create: (_) => WishlistProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(
                  context.read<CartProvider>(),
                  context.read<WishlistProvider>(),
                ),
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
              ChangeNotifierProvider(create: (_) => WishlistProvider()),
              ChangeNotifierProvider(
                create: (context) => AuthProvider(
                  context.read<CartProvider>(),
                  context.read<WishlistProvider>(),
                ),
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
      final authProvider = AuthProvider(CartProvider(), WishlistProvider());

      expect(authProvider.isLoggedIn, false);
      expect(authProvider.user, null);
      expect(authProvider.isLoading, false);
      expect(authProvider.error, null);
    });

    test('clearError should reset error to null', () {
      final authProvider = AuthProvider(CartProvider(), WishlistProvider());

      authProvider.clearError();
      expect(authProvider.error, null);
    });
  });
}
