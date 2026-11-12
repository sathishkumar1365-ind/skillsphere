import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Page transition used across SkillSphere: the new page fades in while
/// rising and tipping forward from a slight 3D tilt.
///
/// ```dart
/// Navigator.of(context).pushReplacement(
///   SpherePageRoute(builder: (_) => const HomePage()),
/// );
/// ```
class SpherePageRoute<T> extends PageRouteBuilder<T> {
  SpherePageRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 900),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: _buildTransition,
        );

  static const Curve _ease = Cubic(0.2, 0.8, 0.2, 1);

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) {
      return FadeTransition(opacity: animation, child: child);
    }
    final curved = CurvedAnimation(parent: animation, curve: _ease);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (context, child) {
          final remaining = 1 - curved.value;
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..multiply(Matrix4.translationValues(0, 50 * remaining, 0))
            ..multiply(Matrix4.rotationX(-8 * math.pi / 180 * remaining));
          return Transform(
            alignment: Alignment.topCenter,
            transform: matrix,
            child: child,
          );
        },
      ),
    );
  }
}
