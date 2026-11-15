import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loads every Google Font weight SkillSphere uses, once, at start-up.
///
/// Why this exists (Flutter web): a Google Font is downloaded the first time
/// a text style asks for it, so the first frames are drawn with a fallback
/// font. Flutter redraws the text when the font arrives, but the separate
/// measurement it keeps for *intrinsic* sizes is not reset (RenderParagraph
/// keeps its own TextPainter for intrinsics and only resets it when the text
/// itself changes). Layouts that size rows from intrinsics – IntrinsicHeight,
/// EqualHeightGrid, IntrinsicWidth – then keep using the fallback font's
/// measurements. Inter is wider than the fallback, so those rows come out
/// too short and overflow (e.g. "RenderFlex overflowed by 41 pixels on the
/// bottom" on the dashboard's project cards).
///
/// Every weight is requested in `main()` (while the login page shows) and
/// signing in waits for [ready] before the first dashboard is built.
class AppFonts {
  AppFonts._();

  /// Inter weights used across the app (HomeText.body, login, theme).
  static const List<FontWeight> interWeights = [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ];

  static Future<void>? _loading;

  /// Starts downloading the fonts and returns at once. Safe to call again.
  static void preload() {
    _loading ??= _load();
  }

  static Future<void> _load() async {
    // Asking for a style registers the font file for loading.
    for (final weight in interWeights) {
      GoogleFonts.inter(fontWeight: weight);
    }
    GoogleFonts.anton();
    try {
      await GoogleFonts.pendingFonts();
    } catch (error) {
      // Offline or blocked: the app still works with the fallback font.
      debugPrint('SkillSphere: could not load fonts ($error)');
    }
  }

  /// Completes when the fonts are loaded – or after [timeout] on a slow
  /// network, so signing in is never held up for long. Never throws.
  static Future<void> ready({Duration timeout = const Duration(seconds: 6)}) {
    preload();
    final loading = _loading ?? Future<void>.value();
    return loading.timeout(timeout, onTimeout: () {});
  }
}
