import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/main_screen.dart';
import 'screens/cart_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProxyProvider<CartProvider, AuthProvider>(
            create: (context) => AuthProvider(
              Provider.of<CartProvider>(context, listen: false),
            ),
            update: (context, cartProvider, authProvider) =>
                authProvider ?? AuthProvider(cartProvider),
          ),
        ],
        child: MaterialApp(
          title: 'دار البراق',
        locale: const Locale('ar'),
        supportedLocales: const [
          Locale('ar'),
          Locale('fa'),
          Locale('en'),
        ],
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
        theme: ThemeData(
          primarySwatch: Colors.green,
          fontFamily: 'Vazirmatn',
        ),
        home: const MainScreen(),
        routes: {
          '/cart': (context) => const CartScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
