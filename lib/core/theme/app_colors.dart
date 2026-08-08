import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF623B97);
  static const Color primaryDark = Color(0xFF45276F);
  static const Color surfaceSoft = Color(0xFFF3EEFA);

  static const Color accentOrange = Color(0xFFF9770F);
  static const Color accentGreen = Color(0xFF8BA40A);
  static const Color accentYellow = Color(0xFFF5D62E);
  static const Color accentRed = Color(0xFFEF3838);
  static const Color accentCyan = Color(0xFF0E8EA8);

  static const Color background = Color(0xFFF9C900);
  static const Color textPrimary = Color(0xFF30283B);
  static const Color textMuted = Color(0xFF746D7D);
  static const Color border = Color(0xFFE9E3EE);
  static const Color white = Color(0xFFFFFFFF);

  static const Color success = accentGreen;
  static const Color warning = accentYellow;
  static const Color error = accentRed;

  // accentYellow used to be the 5th color here, but it's nearly identical
  // to the page's own yellow `background`, so that circle's border
  // effectively disappeared against it. primary gives real contrast
  // against the yellow background like the other four accents do.
  static const List<Color> categoryAccents = [
    accentOrange,
    accentGreen,
    accentCyan,
    accentRed,
    primary,
  ];
}
