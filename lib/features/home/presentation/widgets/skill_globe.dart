import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/home_models.dart';
import '../home_theme.dart';

/// The hero's 3D skill globe: a spinning wireframe sphere with the
/// readiness score at its core, and skill chips orbiting around it in 3D.
/// Chips behind the globe are hidden by it and fade, chips in front grow
/// slightly — all from a single ticker, no 3D engine needed.
class SkillGlobe extends StatefulWidget {
  const SkillGlobe({
    super.key,
    required this.readinessPercent,
    required this.chips,
    this.size = 560,
  });

  final int readinessPercent;
  final List<GlobeChip> chips;

  /// Design size. The globe scales down to fit narrower screens.
  final double size;

  @override
  State<SkillGlobe> createState() => _SkillGlobeState();
}

class _SkillGlobeState extends State<SkillGlobe>
    with SingleTickerProviderStateMixin {
  static const double _startSeconds = 6; // a pleasant first pose
  static const double _spinPeriod = 40; // seconds per globe turn
  static const double _orbitPeriod = 32; // seconds per chip orbit
  static const double _floatPeriod = 7; // seconds per gentle bob
  static const double _globeRadius = 150;
  static const double _orbitRadius = 250;
  static const double _coreSize = 210;

  /// Vertical offset of each chip's orbit, so they don't share one ring.
  static const List<double> _chipHeights = [-34, 34, -67, 67, -17, -84, 45, -45];

  final ValueNotifier<double> _seconds = ValueNotifier<double>(_startSeconds);
  late final Ticker _ticker = createTicker((elapsed) {
    _seconds.value =
        _startSeconds + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  });

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
    final orbiting = widget.chips
        .map((c) => c.isGap ? '${c.label} (gap)' : c.label)
        .join(', ');
    return Semantics(
      image: true,
      label: 'Skill globe. Project readiness ${widget.readinessPercent} percent. '
          'Orbiting skills: $orbiting.',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _seconds,
                builder: (context, seconds, _) => _buildScene(seconds),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScene(double t) {
    final half = widget.size / 2;
    final floatY = math.sin(t * 2 * math.pi / _floatPeriod) * 8;
    final projector = _Projector(center: Offset(half, half + floatY));
    final spin = t / _spinPeriod * 2 * math.pi;

    // Wireframe rings, split into the half behind the core and the half in front.
    final backRings = Path();
    final frontRings = Path();
    _addRings(projector, spin, backRings, frontRings);

    // Orbiting chips.
    final behind = <_PlacedChip>[];
    final ahead = <_PlacedChip>[];
    final chips = widget.chips;
    for (var i = 0; i < chips.length; i++) {
      final angle = (t / _orbitPeriod + i / chips.length) * 2 * math.pi;
      final point = projector.project(
        _orbitRadius * math.sin(angle),
        _chipHeights[i % _chipHeights.length],
        _orbitRadius * math.cos(angle),
      );
      final facing = (1 + math.cos(angle)) / 2; // 1 = front, 0 = back
      final placed = _PlacedChip(chips[i], point, 0.45 + 0.55 * facing);
      (point.depth < 0 ? behind : ahead).add(placed);
    }
    behind.sort((a, b) => a.point.depth.compareTo(b.point.depth));
    ahead.sort((a, b) => a.point.depth.compareTo(b.point.depth));

    final center = projector.center;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RingPainter(backRings, const Color.fromRGBO(31, 95, 209, 0.2)),
          ),
        ),
        for (final chip in behind) _positionedChip(chip),
        Positioned(
          left: center.dx - _coreSize / 2,
          top: center.dy - _coreSize / 2,
          child: _GlobeCore(percent: widget.readinessPercent, size: _coreSize),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _RingPainter(frontRings, const Color.fromRGBO(31, 95, 209, 0.42)),
          ),
        ),
        for (final chip in ahead) _positionedChip(chip),
      ],
    );
  }

  Widget _positionedChip(_PlacedChip chip) {
    return Positioned(
      left: chip.point.offset.dx,
      top: chip.point.offset.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.scale(
          scale: chip.point.scale,
          child: Opacity(
            opacity: chip.opacity,
            child: _OrbitChip(chip: chip.chip),
          ),
        ),
      ),
    );
  }

  void _addRings(_Projector projector, double spin, Path back, Path front) {
    const steps = 72;
    const r = _globeRadius;
    final cosSpin = math.cos(spin);
    final sinSpin = math.sin(spin);

    void addRing(_Vec3 Function(double angle) pointAt) {
      _ProjectedPoint? previous;
      for (var i = 0; i <= steps; i++) {
        final v = pointAt(i / steps * 2 * math.pi);
        // Spin the globe around its vertical axis.
        final x = v.x * cosSpin + v.z * sinSpin;
        final z = -v.x * sinSpin + v.z * cosSpin;
        final p = projector.project(x, v.y, z);
        if (previous != null) {
          final target = (previous.depth + p.depth) < 0 ? back : front;
          target
            ..moveTo(previous.offset.dx, previous.offset.dy)
            ..lineTo(p.offset.dx, p.offset.dy);
        }
        previous = p;
      }
    }

    // Six meridians, 30° apart.
    for (var k = 0; k < 6; k++) {
      final b = k * math.pi / 6;
      final cosB = math.cos(b);
      final sinB = math.sin(b);
      addRing((a) => _Vec3(r * math.cos(a) * cosB, r * math.sin(a), -r * math.cos(a) * sinB));
    }
    // Equator and two lines of latitude.
    addRing((a) => _Vec3(r * math.cos(a), 0, r * math.sin(a)));
    const latRadius = 130.0;
    const latOffset = 75.0;
    addRing((a) => _Vec3(latRadius * math.cos(a), -latOffset, latRadius * math.sin(a)));
    addRing((a) => _Vec3(latRadius * math.cos(a), latOffset, latRadius * math.sin(a)));
  }
}

/// Perspective camera looking slightly down on the globe.
class _Projector {
  _Projector({
    required this.center,
    double tiltXDegrees = -14,
    double tiltZDegrees = -4,
  })  : perspective = 1400, _cosX = math.cos(tiltXDegrees * math.pi / 180),
        _sinX = math.sin(tiltXDegrees * math.pi / 180),
        _cosZ = math.cos(tiltZDegrees * math.pi / 180),
        _sinZ = math.sin(tiltZDegrees * math.pi / 180);

  final Offset center;
  final double perspective;
  final double _cosX;
  final double _sinX;
  final double _cosZ;
  final double _sinZ;

  /// x right, y down, z toward the viewer.
  _ProjectedPoint project(double x, double y, double z) {
    final x1 = x * _cosZ - y * _sinZ;
    final y1 = x * _sinZ + y * _cosZ;
    final y2 = y1 * _cosX - z * _sinX;
    final z2 = y1 * _sinX + z * _cosX;
    final scale = perspective / (perspective - z2);
    return _ProjectedPoint(
      Offset(center.dx + x1 * scale, center.dy + y2 * scale),
      z2,
      scale,
    );
  }
}

class _Vec3 {
  const _Vec3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

class _ProjectedPoint {
  const _ProjectedPoint(this.offset, this.depth, this.scale);
  final Offset offset;

  /// Positive = in front of the globe's centre.
  final double depth;
  final double scale;
}

class _PlacedChip {
  const _PlacedChip(this.chip, this.point, this.opacity);
  final GlobeChip chip;
  final _ProjectedPoint point;
  final double opacity;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => true;
}

class _GlobeCore extends StatelessWidget {
  const _GlobeCore({required this.percent, required this.size});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.32, -0.44),
          radius: 0.95,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFDCEBFC),
            Color(0xFF9CC4F2),
            Color(0xFF5E95DD),
          ],
          stops: [0.0, 0.32, 0.68, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(31, 95, 209, 0.55),
            blurRadius: 70,
            spreadRadius: -30,
            offset: Offset(0, 40),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$percent%', style: HomeText.display(56, height: 1.0)),
          const SizedBox(height: 4),
          Text(
            'PROJECT READY',
            style: HomeText.body(13,
                weight: FontWeight.w700,
                color: HomeColors.ink,
                letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }
}

class _OrbitChip extends StatelessWidget {
  const _OrbitChip({required this.chip});

  final GlobeChip chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(999)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(15, 27, 45, 0.45),
            blurRadius: 24,
            spreadRadius: -12,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: chip.isGap ? HomeColors.orange : HomeColors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            chip.label,
            style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink),
          ),
        ],
      ),
    );
  }
}
