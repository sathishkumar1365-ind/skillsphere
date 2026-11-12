import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours for the Home page (design Option A · "Sky Sphere").
/// Matches the login page: light-blue sky, ink-black buttons, Anton headlines.
class HomeColors {
  HomeColors._();

  static const ink = Color(0xFF0F1B2D);
  static const body = Color(0xFF3A4B61);
  static const muted = Color(0xFF55667C);

  static const blue = Color(0xFF1F5FD1);
  static const blueDeep = Color(0xFF0F3F99);
  static const blueTint = Color(0xFFE8F1FD);
  static const track = Color(0xFFDCE6F2);

  static const orange = Color(0xFFE46F10);
  static const orangeTint = Color(0xFFFFF1E4);
  static const orangeText = Color(0xFF8A3D00);
  static const orangeBand = Color(0xFFFFE2C6);
  static const peach = Color(0xFFFFB067);

  static const cardBorder = Color(0xFFE3ECF6);
  static const chipBorder = Color(0xFFC9D7E8);
  static const divider = Color(0xFFD5E2F0);
  static const gapTrack = Color(0xFFEDF2F8);
  static const neutralTint = Color(0xFFEEF1F5);

  static const onInk = Color(0xFFE4ECF6);
  static const onInkMuted = Color(0xFFB9C7DA);

  static const skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFBFDDF7),
      Color(0xFFD6E9FA),
      Color(0xFFEEF6FD),
      Color(0xFFF7FBFE),
    ],
    stops: [0.0, 0.3, 0.62, 1.0],
  );
}

/// Text styles: Anton for display headlines, Inter for everything else.
class HomeText {
  HomeText._();

  static TextStyle display(
    double size, {
    Color color = HomeColors.ink,
    double height = 0.95,
  }) =>
      GoogleFonts.anton(
        fontSize: size,
        height: height,
        letterSpacing: size * 0.01,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = HomeColors.body,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
}

/// Shared motion values so every animation feels the same.
class HomeMotion {
  HomeMotion._();

  /// Fast start, long soft landing (CSS cubic-bezier(.2,.8,.2,1)).
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1);

  static const Duration hover = Duration(milliseconds: 450);
  static const Duration reveal = Duration(milliseconds: 900);
  static const Duration scrollTo = Duration(milliseconds: 750);
}
