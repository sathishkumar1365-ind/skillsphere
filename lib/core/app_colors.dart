import 'package:flutter/material.dart';

/// Colours and asset paths for the login screen.
class AppColors {
  AppColors._();

  // Sky background
  static const skyTop = Color(0xFFA9CBEA);
  static const skyMid = Color(0xFFCFE2F3);
  static const skyBottom = Color(0xFFE8F1F9);

  // Card + form
  static const card = Colors.white;
  static const fieldFill = Color(0xFFF3F6FA);
  static const border = Color(0xFFE6E9EF);
  static const checkboxBorder = Color(0xFFC7CDD6);
  static const black = Color(0xFF0B0B0C);
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF6B7280);
  static const hint = Color(0xFFB0B7C3);
  static const error = Color(0xFFE5484D);
}

class AppAssets {
  AppAssets._();

  /// Set to true after you copy the image files into assets/images/.
  /// While false, nothing is requested, so no 404 messages in the console.
  static const hasHeroImage = false;
  static const hasSkyImage = false;

  /// Illustration on the left panel of the card (your mascot / artwork).
  static const loginHero = 'assets/images/login_hero.png';

  /// Optional full-page sky photo. If missing, clouds are painted in code.
  static const skyBackground = 'assets/images/sky_bg.jpg';
}