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
/// screen".
///
/// It waits for HomeScreen's data to preload (see [HomeDataCache]) so
/// HomeScreen never shows its own loading spinner right after this one --
/// but capped at [_maxPreloadWait], so a slow or dead connection still
/// can't hang here indefinitely the way the native splash once did (see
/// the "Fix app hanging on splash screen" commit): past that cap it gives
/// up and proceeds anyway, exactly as if the preload had never started,
/// leaving HomeScreen to fetch for itself as it always could.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minDisplayTime = Duration(milliseconds: 1200);
  static const _maxPreloadWait = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _proceedWhenReady();
  }

  Future<void> _proceedWhenReady() async {
    final currency = context.read<CurrencyProvider>().currency;

    await Future.wait([
      Future.delayed(_minDisplayTime),
      _preloadHomeScreen(currency),
    ]);

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => const MainScreen()));
  }

  Future<void> _preloadHomeScreen(String currency) async {
    try {
      await HomeDataCache.preload(ApiService(), currency).timeout(_maxPreloadWait);
    } catch (_) {
      // Timed out, offline, or the request failed -- HomeScreen falls back
      // to fetching for itself when it builds, same as before this
      // preload existed.
    }
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
