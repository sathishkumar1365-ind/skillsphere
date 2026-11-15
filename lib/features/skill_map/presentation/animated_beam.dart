// Animated beams (after Magic UI's "Animated Beam"): a faint path between
// two nodes with a short beam of light travelling along it, again and
// again. Here every link of the skill map is one beam:
//
// * the path is a smooth S-curve (cubic Bézier) from the right edge of
//   one node to the left edge of the next (top to bottom on narrow
//   screens); beams into or out of the employee spread around the circle;
// * the light is the same curve cut to a short piece (PathMetric) and
//   stroked with a gradient that fades in from the tail, plus a soft glow
//   and a bright head;
// * colours carry the meaning used across the app: blue = level reached,
//   orange = gap, grey = held but not needed; "not acquired" is dashed;
// * on first view the paths draw themselves in, stage by stage (projects →
//   required → employee → current → gaps), then the pulses start, staggered.
//
// One painter draws every beam, in its own layer, from one clock – the
// nodes on top are not repainted while the light moves.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../home/presentation/home_theme.dart';
import '../data/skill_map.dart';
import '../data/skill_map_layout.dart';

/// Colours of a beam: its path, and the light's tail → head.
class BeamColors {
  const BeamColors({required this.base, required this.start, required this.stop});

  final Color base;
  final Color start;
  final Color stop;

  static const met = BeamColors(base: HomeColors.blue, start: Color(0xFF8FC2FF), stop: HomeColors.blue);
  static const gap = BeamColors(base: HomeColors.orange, start: Color(0xFFFFC98F), stop: HomeColors.orange);
  static const other = BeamColors(base: Color(0xFF9AA5B4), start: Color(0xFFD5DEEA), stop: Color(0xFF5E6E84));

  static BeamColors of(BeamTone tone) => switch (tone) {
        BeamTone.met => met,
        BeamTone.gap => gap,
        BeamTone.other => other,
      };
}

/// One link's geometry and timing.
class Beam {
  Beam({
    required this.id,
    required this.path,
    required this.tone,
    required this.stage,
    required this.dashed,
    required this.delay,
    required this.duration,
  }) : metric = _measure(path);

  /// The link id (from>to).
  final String id;
  final Path path;
  final BeamTone tone;
  final int stage;
  final bool dashed;

  /// Seconds before the first pulse.
  final double delay;

  /// Seconds one pulse takes from end to end.
  final double duration;

  final ui.PathMetric? metric;

  Path? _dashes;

  double get length => metric?.length ?? 0;

  /// The whole path as dashes (cached).
  Path get dashes {
    final cached = _dashes;
    if (cached != null) return cached;
    final m = metric;
    final built = m == null ? Path() : dashedPath(m, m.length);
    _dashes = built;
    return built;
  }

  static ui.PathMetric? _measure(Path path) {
    final iterator = path.computeMetrics().iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

/// [metric] from 0 to [upTo] as dashes.
Path dashedPath(ui.PathMetric metric, double upTo, {double dash = 5, double gap = 4}) {
  final out = Path();
  var d = 0.0;
  while (d < upTo) {
    out.addPath(metric.extractPath(d, math.min(d + dash, upTo)), Offset.zero);
    d += dash + gap;
  }
  return out;
}

/// The beams for [map] laid out by [layout].
List<Beam> buildBeams(SkillMap map, SkillMapLayout layout) {
  final horizontal = layout.axis == Axis.horizontal;
  final rects = layout.rects;
  final links = [
    for (final l in map.links)
      if (rects.containsKey(l.from) && rects.containsKey(l.to)) l,
  ];

  // Several beams leaving (or entering) one node are spread along its edge
  // in the order of their other ends, so they don't cross at the node.
  double along(Rect r) => horizontal ? r.center.dy : r.center.dx;
  final outgoing = <String, List<MapLink>>{};
  final incoming = <String, List<MapLink>>{};
  for (final l in links) {
    (outgoing[l.from] ??= <MapLink>[]).add(l);
    (incoming[l.to] ??= <MapLink>[]).add(l);
  }
  final starts = <String, Offset>{};
  final ends = <String, Offset>{};
  for (final entry in outgoing.entries) {
    final list = entry.value..sort((a, b) => along(rects[a.to]!).compareTo(along(rects[b.to]!)));
    for (var i = 0; i < list.length; i++) {
      starts[list[i].id] = _anchor(rects[entry.key]!, i, list.length,
          out: true, hub: entry.key == SkillMapIds.hub, horizontal: horizontal);
    }
  }
  for (final entry in incoming.entries) {
    final list = entry.value..sort((a, b) => along(rects[a.from]!).compareTo(along(rects[b.from]!)));
    for (var i = 0; i < list.length; i++) {
      ends[list[i].id] = _anchor(rects[entry.key]!, i, list.length,
          out: false, hub: entry.key == SkillMapIds.hub, horizontal: horizontal);
    }
  }

  final perStage = <int, int>{};
  final beams = <Beam>[];
  for (final l in links) {
    final a = starts[l.id];
    final b = ends[l.id];
    if (a == null || b == null) continue;
    final index = perStage[l.stage] ?? 0;
    perStage[l.stage] = index + 1;
    beams.add(Beam(
      id: l.id,
      path: _curve(a, b, horizontal),
      tone: l.tone,
      stage: l.stage,
      dashed: l.dashed,
      // Stage by stage, and staggered within a stage, so the light seems
      // to flow from the projects to the gaps.
      delay: l.stage * 0.55 + (index % 6) * 0.3 + (index ~/ 6) * 0.13,
      duration: switch (l.tone) {
        BeamTone.gap => 2.6,
        BeamTone.met => 3.2,
        BeamTone.other => 3.6,
      },
    ));
  }
  return beams;
}

/// Where beam [i] of [n] leaves ([out]) or enters a node.
Offset _anchor(Rect r, int i, int n, {required bool out, required bool hub, required bool horizontal}) {
  if (hub) {
    // Around the circle: up to ±40° from the middle of its side.
    final radius = r.width / 2;
    final spread = math.min(0.7, 0.16 * (n - 1));
    final angle = n <= 1 ? 0.0 : -spread + 2 * spread * i / (n - 1);
    final c = r.center;
    if (horizontal) {
      return c + Offset((out ? 1 : -1) * radius * math.cos(angle), radius * math.sin(angle));
    }
    return c + Offset(radius * math.sin(angle), (out ? 1 : -1) * radius * math.cos(angle));
  }
  final span = horizontal ? r.height * 0.5 : r.width * 0.6;
  final step = n <= 1 ? 0.0 : math.min(horizontal ? 7.0 : 12.0, span / (n - 1));
  final offset = n <= 1 ? 0.0 : (i - (n - 1) / 2) * step;
  if (horizontal) return Offset(out ? r.right : r.left, r.center.dy + offset);
  return Offset(r.center.dx + offset, out ? r.bottom : r.top);
}

Path _curve(Offset a, Offset b, bool horizontal) {
  final path = Path()..moveTo(a.dx, a.dy);
  if (horizontal) {
    final dx = (b.dx - a.dx) * 0.5;
    path.cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);
  } else {
    final dy = (b.dy - a.dy) * 0.5;
    path.cubicTo(a.dx, a.dy + dy, b.dx, b.dy - dy, b.dx, b.dy);
  }
  return path;
}

/// Paints [beams]: the faint paths, then the moving light on each.
class BeamPainter extends CustomPainter {
  BeamPainter({
    required this.beams,
    required this.clock,
    required this.intro,
    required this.highlighted,
    required this.animate,
  }) : super(repaint: Listenable.merge(<Listenable>[clock, intro]));

  final List<Beam> beams;

  /// Seconds since the beams started (only moves while they are visible).
  final ValueListenable<double> clock;

  /// 0 → 1 while the paths draw themselves in.
  final Animation<double> intro;

  /// Link ids to bring forward (others are dimmed); null = all.
  final Set<String>? highlighted;

  /// False with reduced motion: paths only, no moving light.
  final bool animate;

  /// Seconds of rest between two pulses on one beam.
  static const double rest = 1.4;

  /// How far stage [stage] is drawn when the intro is at [intro].
  static double stageProgress(double intro, int stage) {
    final start = 0.16 + stage * 0.16;
    return ((intro - start) / 0.34).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final introValue = intro.value;
    final focus = highlighted;
    // Dimmed beams first, so the highlighted ones lie on top.
    for (final front in const [false, true]) {
      for (final b in beams) {
        final on = focus == null || focus.contains(b.id);
        if (on != front) continue;
        _paintBeam(canvas, b, on: on, focused: focus != null, t: t, introValue: introValue);
      }
    }
  }

  void _paintBeam(Canvas canvas, Beam b,
      {required bool on, required bool focused, required double t, required double introValue}) {
    final metric = b.metric;
    if (metric == null) return;
    final length = metric.length;
    if (length < 1) return;
    final drawn = stageProgress(introValue, b.stage);
    if (drawn <= 0) return;
    final colors = BeamColors.of(b.tone);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = on && focused ? 2.4 : 1.8
      ..color = colors.base.withValues(alpha: !on ? 0.08 : (focused ? 0.6 : 0.3));
    if (b.dashed) {
      canvas.drawPath(drawn >= 1 ? b.dashes : dashedPath(metric, length * drawn), base);
    } else {
      canvas.drawPath(drawn >= 1 ? b.path : metric.extractPath(0, length * drawn), base);
    }

    if (drawn < 1) {
      // Still drawing in: a bright tip at the growing end.
      final tip = metric.getTangentForOffset(length * drawn)?.position;
      if (tip != null && on) {
        canvas.drawCircle(tip, 6, Paint()..color = colors.stop.withValues(alpha: 0.18));
        canvas.drawCircle(tip, 2.6, Paint()..color = colors.stop);
      }
      return;
    }
    if (animate && on) _paintPulse(canvas, b, metric, length, t, colors, focused);
  }

  void _paintPulse(Canvas canvas, Beam b, ui.PathMetric metric, double length, double t, BeamColors colors,
      bool focused) {
    final local = t - b.delay;
    if (local < 0) return;
    final phase = local % (b.duration + rest);
    if (phase > b.duration) return;
    final progress = Curves.easeInOut.transform(phase / b.duration);
    final segment = (length * 0.35).clamp(36.0, 140.0);
    final head = progress * (length + segment);
    final from = math.max(0.0, head - segment);
    final to = math.min(length, head);
    if (to - from < 2) return;
    final a = metric.getTangentForOffset(from)?.position;
    final z = metric.getTangentForOffset(to)?.position;
    if (a == null || z == null || (z - a).distance < 1) return;

    final piece = metric.extractPath(from, to);
    final width = focused ? 3.0 : 2.4;
    // Soft glow under the light.
    canvas.drawPath(
      piece,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width * 3
        ..shader = ui.Gradient.linear(a, z, <Color>[
          colors.stop.withValues(alpha: 0),
          colors.stop.withValues(alpha: 0.2),
        ]),
    );
    // The light: transparent tail → light colour → strong head.
    canvas.drawPath(
      piece,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..shader = ui.Gradient.linear(
          a,
          z,
          <Color>[colors.start.withValues(alpha: 0), colors.start, colors.stop],
          const <double>[0, 0.45, 1],
        ),
    );
    if (head <= length) {
      canvas.drawCircle(z, width * 2.4, Paint()..color = colors.stop.withValues(alpha: 0.18));
      canvas.drawCircle(z, width * 0.95, Paint()..color = colors.stop);
    }
  }

  @override
  bool shouldRepaint(BeamPainter oldDelegate) =>
      !identical(oldDelegate.beams, beams) ||
      oldDelegate.highlighted != highlighted ||
      oldDelegate.animate != animate ||
      !identical(oldDelegate.clock, clock) ||
      !identical(oldDelegate.intro, intro);
}
