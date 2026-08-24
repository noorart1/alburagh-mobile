import 'package:flutter/material.dart';

/// Shared durations for the app's micro-interactions, so every new
/// animation reads as one consistent, subtle motion language instead of
/// each call site picking its own numbers.
class Motion {
  Motion._();

  static const Duration splash = Duration(milliseconds: 750);
  static const Duration overlayFade = Duration(milliseconds: 300);
  static const Duration sectionEntrance = Duration(milliseconds: 450);
  static const Duration pressScale = Duration(milliseconds: 120);
  static const Duration badgeBump = Duration(milliseconds: 180);
  static const Duration loadingCrossfade = Duration(milliseconds: 200);
}

/// Collapses [duration] to zero when the platform/user has requested
/// reduced motion, so every animation below respects that preference
/// without each call site re-checking [MediaQuery] itself.
Duration resolveMotion(BuildContext context, Duration duration) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
