import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/push_notifications.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_radius.dart';
import 'providers/cart_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/recently_viewed_provider.dart';
import 'screens/main_screen.dart';
import 'screens/cart_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotifications.init();
  final initialCurrency = await CurrencyProvider.loadInitial();
  runApp(MyApp(initialCurrency: initialCurrency));
}

class MyApp extends StatelessWidget {
  final String initialCurrency;

  const MyApp({super.key, required this.initialCurrency});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CurrencyProvider(initialCurrency: initialCurrency),
        ),
        ChangeNotifierProxyProvider<CurrencyProvider, CartProvider>(
          create: (_) => CartProvider(),
          update: (context, currencyProvider, cartProvider) {
            final cart = cartProvider ?? CartProvider();
            cart.setCurrency(currencyProvider.currency);
            return cart;
          },
        ),
        ChangeNotifierProxyProvider<CurrencyProvider, WishlistProvider>(
          create: (_) => WishlistProvider(),
          update: (context, currencyProvider, wishlistProvider) {
            final wishlist = wishlistProvider ?? WishlistProvider();
            wishlist.setCurrency(currencyProvider.currency);
            return wishlist;
          },
        ),
        ChangeNotifierProvider(create: (_) => RecentlyViewedProvider()),
        ChangeNotifierProxyProvider2<CartProvider, WishlistProvider, AuthProvider>(
          create: (context) => AuthProvider(
            Provider.of<CartProvider>(context, listen: false),
            Provider.of<WishlistProvider>(context, listen: false),
          ),
          update: (context, cartProvider, wishlistProvider, authProvider) =>
              authProvider ?? AuthProvider(cartProvider, wishlistProvider),
        ),
      ],
      child: MaterialApp(
        title: 'دار البراق',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
        theme: _buildTheme(),
        home: const MainScreen(),
        routes: {'/cart': (context) => const CartScreen()},
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  ThemeData _buildTheme() {
    final baseTextTheme = GoogleFonts.cairoTextTheme();
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      secondary: AppColors.accentOrange,
      surface: AppColors.white,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseTextTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        surfaceTintColor: Colors.transparent,
        color: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        backgroundColor: AppColors.white,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
