import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../home_theme.dart';

/// Rises its child into place (fade + lift + slight 3D tilt) the first time
/// it scrolls into view.
///
/// Widgets inside can read the progress with [ScrollReveal.of] to animate in
/// step with it (skill bars filling, rings sweeping, numbers counting up).
class ScrollReveal extends StatefulWidget {
  const ScrollReveal({
    super.key,
    required this.child,
    this.offset = 60,
    this.tiltDegrees = 14,
    this.trigger = 0.88,
    this.delay = Duration.zero,
  });

  final Widget child;

  /// How far below its final place the child starts, in pixels.
  final double offset;

  /// How far the child starts tipped back, in degrees.
  final double tiltDegrees;

  /// Starts when the child's top passes this fraction of the screen height.
  final double trigger;
  final Duration delay;

  /// Reveal progress (0 → 1) of the nearest [ScrollReveal] above [context].
  /// Returns a completed animation when there is none.
  static Animation<double> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RevealScope>();
    return scope?.animation ?? kAlwaysCompleteAnimation;
  }

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: HomeMotion.reveal);
  late final Animation<double> _progress =
      CurvedAnimation(parent: _controller, curve: HomeMotion.ease);

  ScrollPosition? _position;
  double _screenHeight = 0;
  bool _started = false;
  bool _checkScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _screenHeight = media.size.height;

    if (media.disableAnimations && !_started) {
      _started = true;
      _controller.value = 1;
    }

    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_scheduleCheck);
      _position = position;
      if (!_started) _position?.addListener(_scheduleCheck);
    }
    _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_started || _checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      _check();
    });
  }

  void _check() {
    if (_started || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;

    final top = box.localToGlobal(Offset.zero).dy;
    if (top >= _screenHeight * widget.trigger) return;

    _started = true;
    _position?.removeListener(_scheduleCheck);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleCheck);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RevealScope(
      animation: _progress,
      child: FadeTransition(
        opacity: _progress,
        child: AnimatedBuilder(
          animation: _progress,
          child: widget.child,
          builder: (context, child) {
            final remaining = 1 - _progress.value;
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0011)
              ..multiply(
                  Matrix4.translationValues(0, widget.offset * remaining, 0))
              ..multiply(Matrix4.rotationX(
                  -widget.tiltDegrees * math.pi / 180 * remaining));
            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _RevealScope extends InheritedWidget {
  const _RevealScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_RevealScope oldWidget) =>
      !identical(oldWidget.animation, animation);
}
