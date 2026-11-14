import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../home_theme.dart';

/// A rounded card that lifts toward the viewer in 3D when hovered, or when a
/// button inside it has keyboard focus.
class LiftCard extends StatefulWidget {
  const LiftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 22,
    this.color = Colors.white,
    this.borderColor,
    this.liftBy = 8,
    this.tiltDegrees = 7,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color? borderColor;
  final double liftBy;
  final double tiltDegrees;

  @override
  State<LiftCard> createState() => _LiftCardState();
}

class _LiftCardState extends State<LiftCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final border = widget.borderColor;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: active ? 1 : 0),
          duration: reduceMotion ? Duration.zero : HomeMotion.hover,
          curve: HomeMotion.ease,
          child: Padding(padding: widget.padding, child: widget.child),
          builder: (context, t, child) {
            // At rest: no 3D matrix and no shadow, so a resting card costs
            // nothing extra while the page scrolls.
            final matrix = t == 0
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0011)
                  ..multiply(Matrix4.translationValues(0, -widget.liftBy * t, 0))
                  ..multiply(Matrix4.rotationX(
                      -widget.tiltDegrees * math.pi / 180 * t)));
            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: border == null ? null : Border.all(color: border),
                  boxShadow: t == 0
                      ? null
                      : [
                          BoxShadow(
                            color: Color.fromRGBO(15, 27, 45, 0.38 * t),
                            blurRadius: 44,
                            spreadRadius: -20,
                            offset: Offset(0, 28 * t),
                          ),
                        ],
                ),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
