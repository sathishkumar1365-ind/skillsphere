import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Turns mouse-wheel steps into eased scroll animations, so the page glides
/// instead of jumping in fixed steps (Flutter web's default).
///
/// Put it INSIDE the scroll view, around its content, and give it the same
/// [controller]. Touch drags and scrollbar drags are not affected.
class SmoothWheelScroll extends StatefulWidget {
  const SmoothWheelScroll({
    super.key,
    required this.controller,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
    this.speed = 1.0,
  });

  final ScrollController controller;
  final Widget child;
  final Duration duration;
  final Curve curve;

  /// Multiplier for each wheel step.
  final double speed;

  @override
  State<SmoothWheelScroll> createState() => _SmoothWheelScrollState();
}

class _SmoothWheelScrollState extends State<SmoothWheelScroll> {
  double? _target;
  int _generation = 0;

  void _handleSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    if (!widget.controller.hasClients) return;

    // Registering first means the scroll view's own wheel handling is skipped.
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (!mounted || !widget.controller.hasClients) return;
      final scroll = resolved as PointerScrollEvent;
      final position = widget.controller.position;
      final from = _target ?? position.pixels;
      final to = (from + scroll.scrollDelta.dy * widget.speed)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (to == position.pixels) return;

      if (MediaQuery.of(context).disableAnimations) {
        _target = null;
        widget.controller.jumpTo(to);
        return;
      }

      _target = to;
      final generation = ++_generation;
      widget.controller
          .animateTo(to, duration: widget.duration, curve: widget.curve)
          .whenComplete(() {
        if (generation == _generation) _target = null;
      });
    });
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
