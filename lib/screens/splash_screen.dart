import 'package:flutter/material.dart';
import '../core/motion.dart';
import 'main_screen.dart';

/// MainScreen is built right away underneath this, with the splash drawn
/// as an overlay on top for a fixed duration -- not a separate route
/// pushed after a delay. That lets HomeScreen (inside MainScreen's
/// IndexedStack) start its own cache/network loading as soon as it's
/// built, instead of only starting once the splash finishes and navigates
/// away. The overlay's removal is purely time-based, not gated on that
/// load completing -- gating it on a home-data preload was tried before
/// and reverted because it could hang exactly like the native splash
/// previously did (see the "Fix app hanging on splash screen" / "Actually
/// wait for home screen preload during splash screen" / "Revert splash
/// screen home-data preload" commit history).
///
/// [showLogo] (computed in main.dart before runApp(), see
/// _needsFlutterSplashLogo()) controls whether this overlay actually shows
/// the logo image. Only Android 12+'s native splash is unable to show it
/// (masked into a small icon-shaped slot -- see pubspec.yaml's
/// flutter_native_splash config); every other platform's native splash
/// already rendered the full logo before Flutter even started, so showing
/// it again here would just repeat the same image back to back (observed
/// as a jarring "double splash screen" on e.g. Android 11).
class SplashScreen extends StatefulWidget {
  final bool showLogo;

  const SplashScreen({super.key, required this.showLogo});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late bool _showOverlay = widget.showLogo;
  bool _logoVisible = false;

  @override
  void initState() {
    super.initState();
    if (!widget.showLogo) return;
    // Flips one frame after the first (invisible) frame paints, so the
    // fade/scale-in is actually visible instead of the logo just
    // appearing already at full opacity/scale on the very first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _logoVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      setState(() => _showOverlay = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const MainScreen(),
        // Positioned.fill wraps AnimatedSwitcher itself (not the other way
        // around) -- AnimatedSwitcher's default transition wraps whatever
        // child it's given in a FadeTransition, so a Positioned passed as
        // that child ends up with FadeTransition as its parent instead of
        // this Stack, which Positioned can't work with.
        Positioned.fill(
          // AnimatedSwitcher (rather than the overlay just disappearing
          // the instant _showOverlay flips) fades MainScreen into view
          // smoothly instead of a hard cut.
          child: AnimatedSwitcher(
            duration: resolveMotion(context, Motion.overlayFade),
            child: _showOverlay
                ? Scaffold(
                    key: const ValueKey('splash-overlay'),
                    backgroundColor: Colors.white,
                    body: Center(
                      child: AnimatedOpacity(
                        opacity: _logoVisible ? 1 : 0,
                        duration: resolveMotion(context, Motion.splash),
                        curve: Curves.easeOut,
                        child: AnimatedScale(
                          scale: _logoVisible ? 1.0 : 0.9,
                          duration: resolveMotion(context, Motion.splash),
                          curve: Curves.easeOut,
                          child: const Image(
                            image: AssetImage('Assets/logo.png'),
                            width: 200,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('splash-gone')),
          ),
        ),
      ],
    );
  }
}
