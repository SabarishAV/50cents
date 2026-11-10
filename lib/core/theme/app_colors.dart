import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // private constructor: this class is never instantiated

  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF16181C);
  static const border = Color(0xFF23262B);

  /// Electric blue sampled from the app icon (hue ~200).
  static const neonBlue = Color(0xFF00B4FF);

  /// Lighter highlight used at the top of gradients and for glows.
  static const neonBlueBright = Color(0xFF7DE9FF);

  /// Deeper end of the blue gradient.
  static const neonBlueDeep = Color(0xFF0066E6);

  static const income = Color(0xFF00E676);
  static const expense = Color(0xFFFF4D4D);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF8A8F98);

  /// Soft outer glow used by neon buttons and the logo.
  static const neonGlow = Color(0x5500B4FF);
}
