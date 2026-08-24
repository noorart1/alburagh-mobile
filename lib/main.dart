import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/deep_link_service.dart';
import 'core/push_notifications.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_radius.dart';
import 'providers/cart_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/recently_viewed_provider.dart';
import 'screens/cart_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter's default ImageCache caps at 100MB / 1000 entries. Product
  // cards now decode each image close to its displayed size (~220 logical
  // px wide, see ProductCard's memCacheWidth), so ~2-3MB per decoded image
  // -- the default cap holds only ~30-40 of those in memory at once, which
  // a few screens' worth of scrolling through a long catalog blows past.
  // Once evicted, scrolling back to an earlier product re-decodes it from
  // disk cache instead of just repainting, which reads as the image
  // "flashing" back in. A larger cap keeps more of a long scroll session's
  // images resident.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // 200MB
  PaintingBinding.instance.imageCache.maximumSize = 300;
  // Firebase Web needs a FirebaseOptions config (via `flutterfire configure`)
  // that this project doesn't have yet -- push notifications are
  // Android/iOS-only for now.
  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // Deliberately NOT awaited: getToken()/subscribeToTopic() inside this
    // need network to reach Firebase and have no built-in timeout, so in
    // airplane mode (or right after a fresh install with no connection
    // yet) this could hang indefinitely -- which, awaited here, blocked
    // runApp() and left the app stuck on the native splash screen forever.
    // Push setup can finish whenever connectivity allows; nothing else in
    // the app depends on it being ready before first frame.
    unawaited(PushNotifications.init());
  }
  final initialCurrency = await CurrencyProvider.loadInitial();
  final showSplashLogo = await _needsFlutterSplashLogo();
  runApp(
    MyApp(initialCurrency: initialCurrency, showSplashLogo: showSplashLogo),
  );
  // Deliberately not awaited, same reasoning as PushNotifications.init()
  // above: this only needs to be ready by the time a checkout Custom Tab
  // could realistically return with a link, which is always well after
  // first frame.
  unawaited(DeepLinkService.init(MyApp.navigatorKey));
}

// Only Android 12+'s native SplashScreen API is unable to show the app's
// full logo -- its one image slot is always rendered small and masked
// inside an icon-shaped safe zone (see pubspec.yaml's flutter_native_splash
// config), so that's the only platform where SplashScreen's own
// Flutter-drawn overlay needs to show the logo itself. Every other
// platform's native splash (including older Android) already renders it in
// full, so repeating it there would just show the same image back to back.
// Resolved here, before runApp(), so it's ready before Flutter's first
// frame -- the native splash is still covering the screen during this
// await, so there's nothing to flicker.
Future<bool> _needsFlutterSplashLogo() async {
  if (kIsWeb || !Platform.isAndroid) return false;
  final info = await DeviceInfoPlugin().androidInfo;
  return info.version.sdkInt >= 31;
}

class MyApp extends StatelessWidget {
  final String initialCurrency;
  final bool showSplashLogo;

  const MyApp({
    super.key,
    required this.initialCurrency,
    required this.showSplashLogo,
  });

  // The app's root Navigator, kept accessible outside the widget tree the
  // same way MainScreen.requestedTabIndex already is -- DeepLinkService
  // needs it to push OrderDetailScreen regardless of which tab/screen is
  // currently showing when the checkout return link arrives.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
        ChangeNotifierProxyProvider2<
          CartProvider,
          WishlistProvider,
          AuthProvider
        >(
          create: (context) => AuthProvider(
            Provider.of<CartProvider>(context, listen: false),
            Provider.of<WishlistProvider>(context, listen: false),
          ),
          update: (context, cartProvider, wishlistProvider, authProvider) =>
              authProvider ?? AuthProvider(cartProvider, wishlistProvider),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
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
        home: SplashScreen(showLogo: showSplashLogo),
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
      // Applies to every existing `MaterialPageRoute` push across the app
      // (none of them override buildTransitions themselves) without
      // touching any of those call sites or the routing architecture
      // itself -- just a subtle fade + short upward slide on the incoming
      // page instead of each platform's default transition.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlideUpPageTransitionsBuilder(),
          TargetPlatform.iOS: _FadeSlideUpPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _FadeSlideUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlideUpPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
