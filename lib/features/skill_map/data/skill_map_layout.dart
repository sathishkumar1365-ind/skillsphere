// Where every node of a skill map sits, worked out from the width alone
// (no measuring after layout, so the beams are drawn in the same frame as
// the nodes and nothing jumps).
//
// * Wide (the five columns fit with at least 40px between them for the
//   beams): Projects | Required | Employee | Current | Gaps, each column
//   centred vertically; every gap sits on the same line as its current
//   level, so those beams run straight.
// * Narrow: the same five as tiers from top to bottom, each tier a small
//   grid (2–3 per row), beams running downwards.
//
// Every node has a fixed height and a width from its column, so text is
// one line per row with an ellipsis (full text in tooltips/details).

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'skill_map.dart';

class SkillMapLayout {
  const SkillMapLayout._({
    required this.size,
    required this.axis,
    required this.rects,
    required this.columns,
    required this.headers,
    required this.hubLabel,
  });

  /// The canvas size (width = the width given).
  final Size size;

  /// Horizontal = columns; vertical = tiers.
  final Axis axis;

  /// Node id → box (placeholders included). The employee's box is the
  /// circle's square.
  final Map<String, Rect> rects;

  /// Node id → its column (for the staged entrance).
  final Map<String, SkillMapColumn> columns;

  /// Column (or tier) headings; none for the employee.
  final Map<SkillMapColumn, Rect> headers;

  /// Name + readiness under (wide) or beside (narrow) the employee circle.
  final Rect hubLabel;

  Rect get hub => rects[SkillMapIds.hub]!;

  static const double projectHeight = 66;
  static const double nodeHeight = 54;
  static const double rowGap = 12;
  static const double headerHeight = 28;
  static const double hubLabelHeight = 42;

  /// Smallest gap between two columns that still leaves room for curves.
  static const double minGutter = 40;

  static double heightOf(SkillMapColumn column) =>
      column == SkillMapColumn.projects ? projectHeight : nodeHeight;

  /// Node ids in [column], top to bottom; a placeholder when it is empty.
  static List<String> idsIn(SkillMap map, SkillMapColumn column) {
    final ids = switch (column) {
      SkillMapColumn.projects => [for (final p in map.projects) p.id],
      SkillMapColumn.needs => [for (final n in map.needs) n.id],
      SkillMapColumn.employee => [SkillMapIds.hub],
      SkillMapColumn.current => [for (final c in map.current) c.id],
      SkillMapColumn.gaps => [for (final g in map.gaps) g.id],
    };
    return ids.isEmpty ? [SkillMapIds.empty(column)] : ids;
  }

  /// Width needed for the wide layout's five columns (any width at or above
  /// this gets columns).
  static bool fitsColumns(double width) => _columnWidths(width) != null;

  static SkillMapLayout compute(SkillMap map, double width) {
    final w = math.max(0.0, width);
    return _horizontal(map, w) ?? _vertical(map, w);
  }

  /// [projects, needs, employee, current, gaps] widths and the gutter, or
  /// null when the gutter would be under [minGutter].
  static (List<double>, double)? _columnWidths(double w) {
    final project = (w * 0.175).clamp(140.0, 210.0);
    final need = (w * 0.16).clamp(128.0, 196.0);
    final gap = (w * 0.15).clamp(120.0, 180.0);
    const hub = 150.0;
    final widths = <double>[project, need, hub, need, gap];
    final gutter = (w - widths.reduce((a, b) => a + b)) / 4;
    if (gutter < minGutter) return null;
    return (widths, gutter);
  }

  // ------------------------------------------------------------- columns

  static SkillMapLayout? _horizontal(SkillMap map, double w) {
    final measured = _columnWidths(w);
    if (measured == null) return null;
    final (widths, gutter) = measured;
    final columns = SkillMapColumn.values;

    final xs = <double>[];
    var x = 0.0;
    for (var i = 0; i < columns.length; i++) {
      xs.add(x);
      x += widths[i] + gutter;
    }

    double stackHeight(int count, double height) => count * height + math.max(0, count - 1) * rowGap;

    final hubDiameter = math.min(112.0, widths[2] - 20);
    final hubBlock = hubDiameter + 10 + hubLabelHeight;
    var body = hubBlock;
    final ids = <SkillMapColumn, List<String>>{};
    for (final c in columns) {
      ids[c] = idsIn(map, c);
      if (c == SkillMapColumn.employee) continue;
      body = math.max(body, stackHeight(ids[c]!.length, heightOf(c)));
    }

    const top = headerHeight + 12;
    final rects = <String, Rect>{};
    final owner = <String, SkillMapColumn>{};
    final headers = <SkillMapColumn, Rect>{};

    for (var i = 0; i < columns.length; i++) {
      final c = columns[i];
      final list = ids[c]!;
      if (c != SkillMapColumn.employee) headers[c] = Rect.fromLTWH(xs[i], 0, widths[i], headerHeight);
      if (c == SkillMapColumn.employee) {
        final cx = xs[i] + widths[i] / 2;
        final cy = top + (body - hubBlock) / 2 + hubDiameter / 2;
        rects[SkillMapIds.hub] = Rect.fromCircle(center: Offset(cx, cy), radius: hubDiameter / 2);
        owner[SkillMapIds.hub] = c;
        continue;
      }
      final height = heightOf(c);
      // Gaps line up with their current level (straight beams).
      if (c == SkillMapColumn.gaps && map.gaps.isNotEmpty) {
        for (final g in map.gaps) {
          final current = rects[SkillMapIds.current(g.competency.id)];
          if (current == null) continue;
          rects[g.id] = Rect.fromLTWH(xs[i], current.top, widths[i], height);
          owner[g.id] = c;
        }
        continue;
      }
      var y = top + (body - stackHeight(list.length, height)) / 2;
      for (final id in list) {
        rects[id] = Rect.fromLTWH(xs[i], y, widths[i], height);
        owner[id] = c;
        y += height + rowGap;
      }
    }

    final hub = rects[SkillMapIds.hub]!;
    return SkillMapLayout._(
      size: Size(w, top + body + 8),
      axis: Axis.horizontal,
      rects: rects,
      columns: owner,
      headers: headers,
      hubLabel: Rect.fromLTWH(xs[2], hub.bottom + 10, widths[2], hubLabelHeight),
    );
  }

  // --------------------------------------------------------------- tiers

  static SkillMapLayout _vertical(SkillMap map, double w) {
    const gap = 10.0;
    const tierGap = 46.0;
    const labelGap = 8.0;
    final rects = <String, Rect>{};
    final owner = <String, SkillMapColumn>{};
    final headers = <SkillMapColumn, Rect>{};
    var hubLabel = Rect.zero;
    var y = 0.0;

    int perRow(SkillMapColumn c) =>
        c == SkillMapColumn.projects ? (w >= 520 ? 2 : 1) : (w >= 640 ? 3 : 2);

    for (final c in SkillMapColumn.values) {
      if (c == SkillMapColumn.employee) {
        final diameter = w < 400 ? 84.0 : 100.0;
        final circle = Rect.fromCircle(center: Offset(w / 2, y + diameter / 2), radius: diameter / 2);
        rects[SkillMapIds.hub] = circle;
        owner[SkillMapIds.hub] = c;
        final labelLeft = circle.right + 12;
        hubLabel = Rect.fromLTWH(
          labelLeft,
          circle.center.dy - hubLabelHeight / 2,
          math.max(0.0, math.min(200.0, w - labelLeft)),
          hubLabelHeight,
        );
        y = circle.bottom + tierGap;
        continue;
      }
      headers[c] = Rect.fromLTWH(0, y, w, headerHeight);
      y += headerHeight + labelGap;
      final list = idsIn(map, c);
      final k = math.max(1, perRow(c));
      final nodeWidth = math.max(0.0, (w - gap * (k - 1)) / k);
      final height = heightOf(c);
      for (var start = 0; start < list.length; start += k) {
        final inRow = math.min(k, list.length - start);
        final rowWidth = inRow * nodeWidth + (inRow - 1) * gap;
        var x = (w - rowWidth) / 2;
        for (var j = 0; j < inRow; j++) {
          final id = list[start + j];
          rects[id] = Rect.fromLTWH(x, y, nodeWidth, height);
          owner[id] = c;
          x += nodeWidth + gap;
        }
        y += height + (start + k < list.length ? gap : 0.0);
      }
      y += c == SkillMapColumn.gaps ? 8.0 : tierGap;
    }

    return SkillMapLayout._(
      size: Size(w, y),
      axis: Axis.vertical,
      rects: rects,
      columns: owner,
      headers: headers,
      hubLabel: hubLabel,
    );
  }
}
