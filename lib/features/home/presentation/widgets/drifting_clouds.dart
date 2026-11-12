import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Soft white clouds drifting slowly across the sky. When a [scrollController]
/// is given they also move up at a fraction of the scroll speed (parallax),
/// which gives the page depth.
class DriftingClouds extends StatefulWidget {
  const DriftingClouds({super.key, this.scrollController, this.parallax = 0.35});

  final ScrollController? scrollController;

  /// 0 = clouds stay put while scrolling, 1 = they scroll with the content.
  final double parallax;

  @override
  State<DriftingClouds> createState() => _DriftingCloudsState();
}

class _DriftingCloudsState extends State<DriftingClouds>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
      (elapsed) => _seconds.value = elapsed.inMilliseconds / 1000);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _ticker.isActive) {
      _ticker.stop();
    } else if (!reduceMotion && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _CloudPainter(
            seconds: _seconds,
            scroll: widget.scrollController,
            parallax: widget.parallax,
          ),
        ),
      ),
    );
  }
}

class _Puff {
  const _Puff(this.left, this.top, this.diameter);
  final double left;
  final double top;
  final double diameter;
}

class _Cloud {
  const _Cloud({
    required this.top,
    required this.width,
    required this.height,
    required this.baseHeight,
    required this.opacity,
    required this.period,
    required this.phase,
    required this.puffs,
  });

  final double top;
  final double width;
  final double height;
  final double baseHeight;
  final double opacity;

  /// Seconds to cross the screen once.
  final double period;

  /// Head start in seconds, so clouds don't all begin at the left edge.
  final double phase;
  final List<_Puff> puffs;
}

const _clouds = [
  _Cloud(top: 120, width: 260, height: 90, baseHeight: 54, opacity: 0.85, period: 120, phase: 20, puffs: [_Puff(50, 10, 90), _Puff(110, -14, 110)]),
  _Cloud(top: 430, width: 200, height: 70, baseHeight: 42, opacity: 0.7, period: 150, phase: 95, puffs: [_Puff(36, 6, 70), _Puff(86, -12, 86)]),
  _Cloud(top: 640, width: 320, height: 100, baseHeight: 60, opacity: 0.6, period: 180, phase: 40, puffs: [_Puff(60, 6, 110), _Puff(140, -22, 130)]),
];

class _CloudPainter extends CustomPainter {
  _CloudPainter({required this.seconds, required this.scroll, required this.parallax})
      : super(repaint: Listenable.merge([seconds, scroll]));

  final ValueNotifier<double> seconds;
  final ScrollController? scroll;
  final double parallax;

  @override
  void paint(Canvas canvas, Size size) {
    final t = seconds.value;
    final controller = scroll;
    final scrollOffset =
        (controller != null && controller.hasClients) ? controller.offset : 0.0;
    final white = Paint()..color = const Color(0xFFFFFFFF);

    for (final cloud in _clouds) {
      final progress = ((t + cloud.phase) / cloud.period) % 1.0;
      final x = -0.35 * size.width + progress * 1.5 * size.width;
      final y = cloud.top - scrollOffset * parallax;
      if (y + cloud.height + 40 < 0 || y - 60 > size.height) continue;

      // Paint each cloud opaque into a layer, then fade the whole layer, so
      // overlapping puffs don't show darker seams.
      final bounds =
          Rect.fromLTWH(x - 10, y - 60, cloud.width + 20, cloud.height + 100);
      canvas.saveLayer(
          bounds, Paint()..color = Color.fromRGBO(255, 255, 255, cloud.opacity));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y + cloud.height - cloud.baseHeight, cloud.width,
              cloud.baseHeight),
          Radius.circular(cloud.baseHeight / 2),
        ),
        white,
      );
      for (final puff in cloud.puffs) {
        canvas.drawCircle(
          Offset(x + puff.left + puff.diameter / 2,
              y + puff.top + puff.diameter / 2),
          puff.diameter / 2,
          white,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CloudPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.scroll != scroll ||
      oldDelegate.parallax != parallax;
}
