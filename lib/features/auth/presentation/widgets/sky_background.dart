import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

/// Full-page light-blue sky with soft clouds.
/// Uses assets/images/sky_bg.jpg if present, otherwise paints clouds in code.
class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppAssets.hasSkyImage) {
      return CustomPaint(painter: CloudsPainter());
    }
    return Image.asset(
      AppAssets.skyBackground,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => CustomPaint(painter: CloudsPainter()),
    );
  }
}

class CloudsPainter extends CustomPainter {
  CloudsPainter({this.dense = false});

  /// More, smaller clouds (used inside the hero placeholder).
  final bool dense;

  // Puff layout for one cloud: dx, dy, radius (all relative to cloud size).
  static const _puffs = <List<double>>[
    [0.00, 0.00, 1.00],
    [-0.95, 0.25, 0.70],
    [0.95, 0.20, 0.78],
    [-0.40, -0.45, 0.68],
    [0.45, -0.52, 0.72],
    [1.75, 0.42, 0.50],
    [-1.65, 0.46, 0.46],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.skyTop, AppColors.skyMid, AppColors.skyBottom],
        ).createShader(rect),
    );

    final s = size.shortestSide;
    final w = size.width;
    final h = size.height;

    if (dense) {
      _cloud(canvas, Offset(w * 0.20, h * 0.12), s * 0.12);
      _cloud(canvas, Offset(w * 0.85, h * 0.20), s * 0.14);
      _cloud(canvas, Offset(w * 0.55, h * 0.50), s * 0.08);
    } else {
      _cloud(canvas, Offset(w * 0.80, h * 0.10), s * 0.17); // top-right
      _cloud(canvas, Offset(w * 0.10, h * 0.88), s * 0.20); // bottom-left
      _cloud(canvas, Offset(w * 0.90, h * 0.95), s * 0.15); // bottom-right
      _cloud(canvas, Offset(w * 0.03, h * 0.62), s * 0.09); // left edge
      _cloud(canvas, Offset(w * 0.45, h * 0.02), s * 0.07); // faint top
    }
  }

  void _cloud(Canvas canvas, Offset o, double r) {
    final glow = Paint()
      ..color = const Color(0x8CFFFFFF)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35);
    final core = Paint()
      ..color = const Color(0xE6FFFFFF)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12);

    for (final p in _puffs) {
      canvas.drawCircle(o + Offset(p[0] * r, p[1] * r), p[2] * r * 1.3, glow);
    }
    for (final p in _puffs) {
      canvas.drawCircle(o + Offset(p[0] * r, p[1] * r), p[2] * r, core);
    }
  }

  @override
  bool shouldRepaint(covariant CloudsPainter old) => old.dense != dense;
}