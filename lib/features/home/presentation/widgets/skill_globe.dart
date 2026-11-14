import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/home_models.dart';
import '../home_theme.dart';

/// The hero's 3D skill globe: a spinning wireframe sphere with a score at its
/// core, and skill chips orbiting around it in 3D. Chips behind the globe are
/// hidden by it and fade, chips in front grow slightly.
///
/// Performance notes (Flutter web):
/// * The chips and the core are built ONCE and cached as pictures
///   (RepaintBoundary). Each frame only moves them with a [Flow], so there is
///   no rebuild and no re-layout while the globe turns.
/// * The animation pauses automatically while the globe is scrolled out of
///   view, so it costs nothing when you read the rest of the page.
class SkillGlobe extends StatefulWidget {
  const SkillGlobe({
    super.key,
    required this.readinessPercent,
    required this.chips,
    this.caption = 'PROJECT READY',
    this.size = 560,
  });

  final int readinessPercent;
  final List<GlobeChip> chips;

  /// Small label under the percentage in the core.
  final String caption;

  /// Design size. The globe scales down to fit narrower screens.
  final double size;

  @override
  State<SkillGlobe> createState() => _SkillGlobeState();
}

class _SkillGlobeState extends State<SkillGlobe>
    with SingleTickerProviderStateMixin {
  static const double _startSeconds = 6; // a pleasant first pose

  late final _GlobeScene _scene = _GlobeScene(
    size: widget.size,
    chipCount: widget.chips.length,
  )..update(_startSeconds);

  late final Ticker _ticker = createTicker(_onTick);

  /// Time the globe has already turned before the last pause.
  Duration _carried = Duration.zero;
  Duration _lastElapsed = Duration.zero;

  ScrollPosition? _position;
  double _screenHeight = 0;
  bool _onScreen = true;
  bool _reduceMotion = false;
  bool _checkScheduled = false;

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;
    _scene.update(_startSeconds +
        (_carried + elapsed).inMicroseconds / Duration.microsecondsPerSecond);
  }

  /// Runs the ticker only while the globe is visible and motion is allowed.
  void _syncTicker() {
    final shouldRun = _onScreen && !_reduceMotion;
    if (shouldRun && !_ticker.isActive) {
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _carried += _lastElapsed;
      _lastElapsed = Duration.zero;
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _screenHeight = MediaQuery.sizeOf(context).height;

    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_scheduleVisibilityCheck);
      _position = position;
      _position?.addListener(_scheduleVisibilityCheck);
    }
    _syncTicker();
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(SkillGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chips.length != widget.chips.length) {
      _scene.chipCount = widget.chips.length;
      _scene.update(_startSeconds +
          (_carried + _lastElapsed).inMicroseconds /
              Duration.microsecondsPerSecond);
    }
  }

  void _scheduleVisibilityCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero).dy;
      final visible = top + box.size.height > 0 && top < _screenHeight;
      if (visible != _onScreen) {
        _onScreen = visible;
        _syncTicker();
      }
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleVisibilityCheck);
    _ticker.dispose();
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbiting = widget.chips
        .map((c) => c.isGap ? '${c.label} (gap)' : c.label)
        .join(', ');
    return Semantics(
      image: true,
      label: 'Skill globe. ${widget.readinessPercent} percent '
          '${widget.caption.toLowerCase()}. Orbiting skills: $orbiting.',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: RepaintBoundary(
              child: Flow(
                clipBehavior: Clip.none,
                delegate: _GlobeFlowDelegate(_scene),
                children: [
                  CustomPaint(painter: _RingPainter(_scene, front: false)),
                  RepaintBoundary(
                    child: _GlobeCore(
                      percent: widget.readinessPercent,
                      caption: widget.caption,
                      size: _GlobeScene.coreSize,
                    ),
                  ),
                  CustomPaint(painter: _RingPainter(_scene, front: true)),
                  for (final chip in widget.chips)
                    RepaintBoundary(child: _OrbitChip(chip: chip)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything that moves, recomputed once per frame and shared by the
/// ring painters and the chip layout.
class _GlobeScene extends ChangeNotifier {
  _GlobeScene({required this.size, required this.chipCount});

  final double size;
  int chipCount;

  static const double coreSize = 210;
  static const double _spinPeriod = 40; // seconds per globe turn
  static const double _orbitPeriod = 32; // seconds per chip orbit
  static const double _floatPeriod = 7; // seconds per gentle bob
  static const double _globeRadius = 150;
  static const double _orbitRadius = 250;

  /// Vertical offset of each chip's orbit, so they don't share one ring.
  static const List<double> _chipHeights = [-34, 34, -67, 67, -17, -84, 45, -45];

  Path backRings = Path();
  Path frontRings = Path();
  Offset coreCenter = Offset.zero;
  List<_ProjectedPoint> chipPoints = const [];
  List<double> chipOpacity = const [];

  /// Chip indexes behind / in front of the core, painted back to front.
  List<int> behind = const [];
  List<int> ahead = const [];

  void update(double t) {
    final half = size / 2;
    final floatY = math.sin(t * 2 * math.pi / _floatPeriod) * 8;
    final projector = _Projector(center: Offset(half, half + floatY));
    coreCenter = projector.center;

    final back = Path();
    final front = Path();
    _addRings(projector, t / _spinPeriod * 2 * math.pi, back, front);
    backRings = back;
    frontRings = front;

    final points = <_ProjectedPoint>[];
    final opacity = <double>[];
    final behindList = <int>[];
    final aheadList = <int>[];
    for (var i = 0; i < chipCount; i++) {
      final angle = (t / _orbitPeriod + i / chipCount) * 2 * math.pi;
      final point = projector.project(
        _orbitRadius * math.sin(angle),
        _chipHeights[i % _chipHeights.length],
        _orbitRadius * math.cos(angle),
      );
      final facing = (1 + math.cos(angle)) / 2; // 1 = front, 0 = back
      points.add(point);
      // Front half fully opaque (no extra layer); the back half fades.
      opacity.add(math.min(1.0, 0.45 + 0.76 * facing));
      (point.depth < 0 ? behindList : aheadList).add(i);
    }
    int byDepth(int a, int b) => points[a].depth.compareTo(points[b].depth);
    behindList.sort(byDepth);
    aheadList.sort(byDepth);

    chipPoints = points;
    chipOpacity = opacity;
    behind = behindList;
    ahead = aheadList;
    notifyListeners();
  }

  /// Builds the wireframe, split into the half behind the core and the half
  /// in front. Each continuous run is added as ONE polyline (a few calls per
  /// frame instead of hundreds).
  static void _addRings(_Projector projector, double spin, Path back, Path front) {
    const steps = 64;
    const r = _globeRadius;
    final cosSpin = math.cos(spin);
    final sinSpin = math.sin(spin);

    void addRing(_Vec3 Function(double angle) pointAt) {
      var run = <Offset>[];
      bool? runInFront;
      _ProjectedPoint? previous;

      void flush() {
        if (run.length > 1 && runInFront != null) {
          (runInFront! ? front : back).addPolygon(run, false);
        }
      }

      for (var i = 0; i <= steps; i++) {
        final v = pointAt(i / steps * 2 * math.pi);
        // Spin the globe around its vertical axis.
        final x = v.x * cosSpin + v.z * sinSpin;
        final z = -v.x * sinSpin + v.z * cosSpin;
        final p = projector.project(x, v.y, z);
        final prev = previous;
        if (prev != null) {
          final inFront = (prev.depth + p.depth) >= 0;
          if (inFront != runInFront) {
            flush();
            run = <Offset>[prev.offset];
            runInFront = inFront;
          }
          run.add(p.offset);
        }
        previous = p;
      }
      flush();
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

/// Places the cached core and chips each frame without rebuilding them.
class _GlobeFlowDelegate extends FlowDelegate {
  _GlobeFlowDelegate(this.scene) : super(repaint: scene);

  final _GlobeScene scene;

  static const int _backRings = 0;
  static const int _core = 1;
  static const int _frontRings = 2;
  static const int _firstChip = 3;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    if (i == _backRings || i == _frontRings) {
      return BoxConstraints.tight(constraints.biggest);
    }
    return constraints.loosen();
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    context.paintChild(_backRings);
    for (final chip in scene.behind) {
      _paintChip(context, chip);
    }
    final coreSize = context.getChildSize(_core) ?? Size.zero;
    context.paintChild(
      _core,
      transform: Matrix4.translationValues(
        scene.coreCenter.dx - coreSize.width / 2,
        scene.coreCenter.dy - coreSize.height / 2,
        0,
      ),
    );
    context.paintChild(_frontRings);
    for (final chip in scene.ahead) {
      _paintChip(context, chip);
    }
  }

  void _paintChip(FlowPaintingContext context, int chip) {
    final index = _firstChip + chip;
    if (index >= context.childCount || chip >= scene.chipPoints.length) return;
    final size = context.getChildSize(index) ?? Size.zero;
    final point = scene.chipPoints[chip];
    final s = point.scale;
    final transform = Matrix4.translationValues(
      point.offset.dx - size.width * s / 2,
      point.offset.dy - size.height * s / 2,
      0,
    )..multiply(Matrix4.diagonal3Values(s, s, 1));
    context.paintChild(index, transform: transform, opacity: scene.chipOpacity[chip]);
  }

  @override
  bool shouldRepaint(_GlobeFlowDelegate oldDelegate) =>
      !identical(oldDelegate.scene, scene);
}

/// Perspective camera looking slightly down on the globe.
class _Projector {
  _Projector({
    required this.center,
    double tiltXDegrees = -14,
    double tiltZDegrees = -4,
  })  : _cosX = math.cos(tiltXDegrees * math.pi / 180),
        _sinX = math.sin(tiltXDegrees * math.pi / 180),
        _cosZ = math.cos(tiltZDegrees * math.pi / 180),
        _sinZ = math.sin(tiltZDegrees * math.pi / 180);

  final Offset center;
  static const double perspective = 1400;
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

class _RingPainter extends CustomPainter {
  _RingPainter(this.scene, {required this.front}) : super(repaint: scene);

  final _GlobeScene scene;
  final bool front;

  static final Paint _backPaint = Paint()
    ..color = const Color.fromRGBO(31, 95, 209, 0.2)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _frontPaint = Paint()
    ..color = const Color.fromRGBO(31, 95, 209, 0.42)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      front ? scene.frontRings : scene.backRings,
      front ? _frontPaint : _backPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      !identical(oldDelegate.scene, scene) || oldDelegate.front != front;
}

class _GlobeCore extends StatelessWidget {
  const _GlobeCore({required this.percent, required this.caption, required this.size});

  final int percent;
  final String caption;
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
            color: Color.fromRGBO(31, 95, 209, 0.5),
            blurRadius: 56,
            spreadRadius: -26,
            offset: Offset(0, 36),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$percent%', style: HomeText.display(56, height: 1.0)),
          const SizedBox(height: 4),
          Text(
            caption,
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
            color: Color.fromRGBO(15, 27, 45, 0.30),
            blurRadius: 14,
            spreadRadius: -6,
            offset: Offset(0, 8),
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
