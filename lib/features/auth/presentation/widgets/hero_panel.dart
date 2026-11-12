import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/app_colors.dart';
import 'sky_background.dart';

/// Left side of the card: rounded illustration with the
/// "EXPLORE. LEARN. GROW." slogan in the bottom-left corner.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, c) {
          // Slogan scales with the panel width (≈52px on desktop).
          final fontSize = (c.maxWidth * 0.115).clamp(28.0, 56.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              if (AppAssets.hasHeroImage)
                Image.asset(
                  AppAssets.loginHero,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const _HeroPlaceholder(),
                )
              else
                const _HeroPlaceholder(),
              // Soft dark fade at the bottom so the white slogan stays readable.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0, 0.2),
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x59000000)],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Text(
                  'EXPLORE.\nLEARN. GROW.',
                  style: GoogleFonts.anton(
                    fontSize: fontSize,
                    height: 1.08,
                    letterSpacing: 0.6,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Color(0x40000000), blurRadius: 12),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shown until you add assets/images/login_hero.png.
class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: CloudsPainter(dense: true)),
        // Grassy hill like the reference.
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.26,
            widthFactor: 1,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF6E8B3D), Color(0xFF3F5A22)],
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.elliptical(400, 50),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}