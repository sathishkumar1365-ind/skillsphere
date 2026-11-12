import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Four-colour "G" drawn in code (no image asset needed).
/// If you prefer the official file, swap this for
/// Image.asset('assets/images/google_g.png', width: 18).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final arcRect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);

    double rad(double deg) => deg * math.pi / 180;
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // 0° = 3 o'clock, angles grow clockwise.
    canvas.drawArc(arcRect, rad(0), rad(45), false, arc(_blue));
    canvas.drawArc(arcRect, rad(45), rad(90), false, arc(_green));
    canvas.drawArc(arcRect, rad(135), rad(80), false, arc(_yellow));
    canvas.drawArc(arcRect, rad(215), rad(103), false, arc(_red));

    // Blue crossbar.
    canvas.drawRect(
      Rect.fromLTRB(s * 0.5, s * 0.5 - stroke / 2, s, s * 0.5 + stroke / 2),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}