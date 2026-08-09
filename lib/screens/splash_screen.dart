import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/home_data_cache.dart';
import '../providers/currency_provider.dart';
import 'main_screen.dart';

/// Android 12+'s native SplashScreen API has no full-image mode -- its
/// only image slot always renders small and masked inside an icon-shaped
/// safe zone, an OS constraint (see pubspec.yaml's flutter_native_splash
/// config for why that's left plain-white there rather than showing a
/// masked icon). To actually show the full logo the way the app wants,
/// this Flutter-rendered screen takes over immediately after that brief
/// native flash and is what a user actually perceives as "the splash
/// screen". It's a fixed-duration transition, not gated on network or any
/// async init, so it can't hang the way the native splash previously did
/// (see the "Fix app hanging on splash screen" commit) -- it always
/// proceeds to MainScreen regardless of connectivity.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off HomeScreen's first data fetch now, while the fixed timer
    // below is already running anyway, so it's cached and ready by the
    // time MainScreen builds HomeScreen -- letting it skip straight past
    // its own loading spinner instead of showing one right after this
    // splash screen. Deliberately fire-and-forget: if this fails or is
    // slow, HomeScreen just falls back to fetching for itself when it
    // builds, same as before this preload existed. The timer below must
    // stay unconditional either way (see class doc).
    final currency = context.read<CurrencyProvider>().currency;
    unawaited(
      HomeDataCache.preload(
        ApiService(),
        currency,
      ).then((_) {}, onError: (_) {}),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image(
          image: AssetImage('Assets/icon.png'),
          width: 160,
          height: 160,
        ),
      ),
    );
  }
}
