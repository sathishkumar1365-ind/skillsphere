import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Smooth mouse-wheel scrolling for Flutter web.
///
/// Each wheel notch moves a target, and the page glides toward it every frame
/// (frame-rate independent easing). Unlike chaining `animateTo` calls, the
/// speed never resets when the wheel keeps turning, so fast scrolling stays
/// fluid instead of stuttering.
///
/// Trackpads, touch and scrollbar drags are left alone: the operating system
/// already smooths trackpad scrolling, and smoothing it twice feels laggy.
///
/// Put it INSIDE the scroll view, around its content, and give it the same
/// [controller].
class SmoothWheelScroll extends StatefulWidget {
  const SmoothWheelScroll({
    super.key,
    required this.controller,
    required this.child,
    this.speed = 1.0,
    this.smoothing = 12.0,
  });

  final ScrollController controller;
  final Widget child;

  /// Multiplier for each wheel step.
  final double speed;

  /// How quickly the page catches up with the wheel. Higher = snappier.
  /// 12 reaches 95% of the distance in about a quarter of a second.
  final double smoothing;

  @override
  State<SmoothWheelScroll> createState() => _SmoothWheelScrollState();
}

class _SmoothWheelScrollState extends State<SmoothWheelScroll>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);

  /// Where the wheel wants the page to be.
  double? _target;

  /// The offset this widget set last, to notice when something else
  /// (scrollbar drag, keyboard, a nav-link animation) moved the page.
  double _lastPixels = 0;
  Duration _lastTick = Duration.zero;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _handleSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.kind == PointerDeviceKind.trackpad) return;
    if (event.scrollDelta.dy == 0 || !widget.controller.hasClients) return;

    // Registering first means the scroll view's own wheel handling is skipped.
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (!mounted || !widget.controller.hasClients) return;
      final position = widget.controller.position;
      final delta = (resolved as PointerScrollEvent).scrollDelta.dy * widget.speed;

      if (MediaQuery.disableAnimationsOf(context)) {
        _stop();
        position.jumpTo((position.pixels + delta)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble());
        return;
      }

      final gliding = _ticker.isActive && _target != null;
      final from = gliding ? _target! : position.pixels;
      final to = (from + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (!gliding && to == position.pixels) return;
      _target = to;

      if (!gliding) {
        // Stop any other scroll animation (e.g. a nav-link jump) first.
        position.jumpTo(position.pixels);
        _lastPixels = position.pixels;
        _lastTick = Duration.zero;
        _ticker.start();
      }
    });
  }

  void _tick(Duration elapsed) {
    final target = _target;
    if (target == null || !widget.controller.hasClients) {
      _stop();
      return;
    }
    final position = widget.controller.position;

    // Someone else moved the page – give way to them.
    if ((position.pixels - _lastPixels).abs() > 1) {
      _stop();
      return;
    }

    final seconds = elapsed == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    final step = 1 - math.exp(-widget.smoothing * seconds.clamp(0.0, 0.1));

    final goal = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    var next = position.pixels + (goal - position.pixels) * step;
    if ((goal - next).abs() < 0.5) next = goal;

    position.jumpTo(next);
    _lastPixels = position.pixels;
    if (next == goal) _stop();
  }

  void _stop() {
    _target = null;
    if (_ticker.isActive) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _handleSignal,
      child: widget.child,
    );
  }
}
