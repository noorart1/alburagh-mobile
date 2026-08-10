import 'package:flutter/material.dart';
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
/// MainScreen is built right away underneath this, with the splash drawn
/// as an overlay on top for a fixed duration -- not a separate route
/// pushed after a delay. That lets HomeScreen (inside MainScreen's
/// IndexedStack) start its own data loading as soon as it's built, instead
/// of only starting once the splash finishes and navigates away, so by the
/// time the overlay lifts there's a head start on that fetch. The overlay's
/// removal is still purely time-based, not gated on that fetch completing
/// -- an earlier attempt at gating it on a home-data preload was reverted
/// because it could hang exactly like the native splash previously did
/// (see the "Fix app hanging on splash screen" / "Actually wait for home
/// screen preload during splash screen" / "Revert splash screen home-data
/// preload" commits).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 5*1000), () {
      if (!mounted) return;
      setState(() => _showOverlay = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const MainScreen(),
        if (_showOverlay)
          const Positioned.fill(
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Image(
                  image: AssetImage('Assets/icon.png'),
                  width: 160,
                  height: 160,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
