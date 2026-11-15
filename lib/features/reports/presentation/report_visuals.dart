// How a report is drawn: key-number tiles, a pie chart, horizontal bars
// and a sortable table. Used by the dashboard widgets and the full report.
//
// Chart rules (dataviz guidance, validated palette):
// * Pie: at most five named slices + a grey "Other"; every slice's share is
//   printed in the legend (and on the slice when it fits); 2px white gaps.
// * Bars: one blue for magnitudes; ordered data (levels, gap ranges) uses
//   its own ramp; have vs need draws the shortfall in orange – orange means
//   "gap" everywhere in SkillSphere, always with a text value.
// * Values are printed; hover (or focus) shows the details.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/lift_card.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../data/report_models.dart';

class ReportColors {
  ReportColors._();

  /// Categorical order validated for CVD (adjacent + pie wrap-around),
  /// without orange, which SkillSphere keeps for gaps.
  static const List<Color> categorical = [
    Color(0xFF2A78D6),
    Color(0xFF1BAF7A),
    Color(0xFFEDA100),
    Color(0xFFE87BA4),
    Color(0xFF008300),
  ];

  static const Color other = Color(0xFF9AA5B4);

  /// Met (blue), then 1 / 2 / 3+ levels short: an ordinal orange ramp
  /// (validated: monotone, visible steps, light end clears the surface).
  static const List<Color> gaps = [
    Color(0xFF2A78D6),
    Color(0xFFF4A259),
    Color(0xFFE46F10),
    Color(0xFFA84F06),
  ];

  /// L0 → L5: one blue, evenly spaced in OKLab (validated ordinal ramp).
  static const List<Color> levels = [
    Color(0xFF86B6EF),
    Color(0xFF6D9BD3),
    Color(0xFF5480B8),
    Color(0xFF3C679E),
    Color(0xFF254E84),
    Color(0xFF0D366B),
  ];

  static const Color bar = HomeColors.blue;
  static const Color need = Color(0xFFE3ECF6);
  static const Color shortfall = HomeColors.orange;
}

IconData reportViewIcon(ReportView view) => switch (view) {
      ReportView.table => Icons.table_rows_outlined,
      ReportView.pie => Icons.pie_chart_outline_rounded,
      ReportView.bar => Icons.bar_chart_rounded,
      ReportView.kpi => Icons.numbers_rounded,
    };

IconData reportTypeIcon(ReportType type) => switch (type) {
      ReportType.competencyInventory => Icons.category_outlined,
      ReportType.levelDistribution => Icons.stacked_bar_chart_rounded,
      ReportType.employeeCompetencies => Icons.badge_outlined,
      ReportType.headcount => Icons.groups_2_outlined,
      ReportType.orgReadiness => Icons.track_changes_rounded,
      ReportType.teamReadiness => Icons.speed_rounded,
      ReportType.currentVsRequired => Icons.compare_arrows_rounded,
      ReportType.topGaps => Icons.trending_down_rounded,
      ReportType.projectStaffing => Icons.work_outline_rounded,
      ReportType.projectAllocation => Icons.assignment_ind_outlined,
      ReportType.trainingPlans => Icons.school_outlined,
      ReportType.levelUpRequests => Icons.verified_outlined,
      ReportType.additionalSkills => Icons.auto_awesome_outlined,
    };

/// A report in the chosen view. Falls back to bars when a pie can't show
/// the data (averages, have vs need) and says so.
class ReportVisual extends StatelessWidget {
  const ReportVisual({
    super.key,
    required this.result,
    required this.view,
    this.limit = 0,
    this.onOpenRow,
    this.query = '',
  });

  final ReportResult result;
  final ReportView view;

  /// Rows / bars / slices shown (0 = all).
  final int limit;
  final ValueChanged<ReportRow>? onOpenRow;

  /// Table search text.
  final String query;

  @override
  Widget build(BuildContext context) {
    final chart = result.chart;
    switch (view) {
      case ReportView.kpi:
        return ReportKpiGrid(kpis: result.kpis);
      case ReportView.table:
        return ReportTable(result: result, limit: limit, onOpenRow: onOpenRow, query: query);
      case ReportView.pie:
      case ReportView.bar:
        if (chart == null || chart.data.every((d) => d.value == 0 && (d.secondary ?? 0) == 0)) {
          return const _NothingToShow();
        }
        if (view == ReportView.pie && chart.pieAllowed && chart.palette != ChartPalette.paired) {
          return ReportPieChart(chart: chart);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (view == ReportView.pie) ...[
              _SmallNote(
                text: chart.palette == ChartPalette.paired
                    ? 'Have vs need is two numbers per row, so it is shown as bars.'
                    : 'These are averages, not parts of a whole, so they are shown as bars.',
              ),
              const SizedBox(height: 10),
            ],
            ReportBarChart(chart: chart, limit: limit),
          ],
        );
    }
  }
}

class _NothingToShow extends StatelessWidget {
  const _NothingToShow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 30, color: HomeColors.muted),
          const SizedBox(height: 8),
          Text('Nothing to show for these filters.',
              textAlign: TextAlign.center, style: HomeText.body(13.5, color: HomeColors.muted)),
        ],
      ),
    );
  }
}

class _SmallNote extends StatelessWidget {
  const _SmallNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 15, color: HomeColors.muted),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: HomeText.body(12, color: HomeColors.muted, height: 1.4))),
      ],
    );
  }
}

// ============================================================ key numbers

class ReportKpiGrid extends StatelessWidget {
  const ReportKpiGrid({super.key, required this.kpis});

  final List<ReportKpi> kpis;

  @override
  Widget build(BuildContext context) {
    if (kpis.isEmpty) return const _NothingToShow();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = constraints.maxWidth;
        final columns = width >= 820 ? math.min(4, kpis.length) : (width >= 420 ? 2 : 1);
        final tileWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final k in kpis) SizedBox(width: tileWidth, child: _KpiTile(kpi: k)),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.kpi});

  final ReportKpi kpi;

  @override
  Widget build(BuildContext context) {
    final caption = kpi.caption;
    return LiftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      liftBy: 5,
      tiltDegrees: 5,
      radius: 18,
      color: const Color(0xFFF7FAFE),
      borderColor: HomeColors.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(kpi.value,
                      maxLines: 1,
                      style: HomeText.display(32, height: 1.05, color: kpi.alert ? HomeColors.orange : HomeColors.ink)),
                ),
              ),
              if (kpi.alert) ...[
                const SizedBox(width: 6),
                const Icon(Icons.warning_amber_rounded, size: 18, color: HomeColors.orangeText),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(kpi.label, style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink)),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(caption, style: HomeText.body(12, color: HomeColors.muted, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

// ==================================================================== pie

class _Slice {
  const _Slice(this.label, this.value, this.color, {this.note});

  final String label;
  final double value;
  final Color color;
  final String? note;
}

/// Up to five named slices + grey "Other" (categorical), or the ordered
/// ramp (levels, gap ranges). Zero values are left out.
List<_Slice> _slicesFor(ReportChart chart) {
  if (chart.palette == ChartPalette.gaps || chart.palette == ChartPalette.levels) {
    final ramp = chart.palette == ChartPalette.gaps ? ReportColors.gaps : ReportColors.levels;
    return [
      for (var i = 0; i < chart.data.length; i++)
        if (chart.data[i].value > 0)
          _Slice(chart.data[i].label, chart.data[i].value, ramp[math.min(i, ramp.length - 1)], note: chart.data[i].note),
    ];
  }
  final data = chart.data.where((d) => d.value > 0).toList();
  if (!chart.ordered) data.sort((a, b) => b.value.compareTo(a.value));
  const named = 5;
  final slices = <_Slice>[
    for (var i = 0; i < data.length && i < named; i++)
      _Slice(data[i].label, data[i].value, ReportColors.categorical[i], note: data[i].note),
  ];
  if (data.length > named) {
    final rest = data.skip(named).toList();
    slices.add(_Slice(
      'Other (${rest.length})',
      rest.fold<double>(0, (s, d) => s + d.value),
      ReportColors.other,
      note: rest.map((d) => d.label).join(', '),
    ));
  }
  return slices;
}

String _number(double v, String unit) {
  final text = v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  return '$text$unit';
}

class ReportPieChart extends StatefulWidget {
  const ReportPieChart({super.key, required this.chart});

  final ReportChart chart;

  @override
  State<ReportPieChart> createState() => _ReportPieChartState();
}

class _ReportPieChartState extends State<ReportPieChart> {
  int? _hovered;
  static const double _size = 210;

  void _hoverAt(Offset local, List<_Slice> slices, double total) {
    const center = Offset(_size / 2, _size / 2);
    final d = local - center;
    if (d.distance > _size / 2 || total <= 0) {
      if (_hovered != null) setState(() => _hovered = null);
      return;
    }
    // Angle clockwise from 12 o'clock, 0 → 2π.
    var angle = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    var start = 0.0;
    for (var i = 0; i < slices.length; i++) {
      final sweep = math.pi * 2 * slices[i].value / total;
      if (angle >= start && angle < start + sweep) {
        if (_hovered != i) setState(() => _hovered = i);
        return;
      }
      start += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final slices = _slicesFor(chart);
    final total = slices.fold<double>(0, (s, x) => s + x.value);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final pie = Semantics(
      label: '${chart.title}: ${[
        for (final s in slices) '${s.label} ${(s.value * 100 / total).round()} percent'
      ].join(', ')}',
      excludeSemantics: true,
      child: MouseRegion(
        onHover: (e) => _hoverAt(e.localPosition, slices, total),
        onExit: (_) => setState(() => _hovered = null),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
          curve: HomeMotion.ease,
          builder: (context, t, _) {
            // The disc lands flat: tipped back in 3D while it sweeps in,
            // identity at rest.
            final matrix = t >= 1
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..multiply(Matrix4.rotationX(0.85 * (1 - t))));
            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: CustomPaint(
                size: const Size.square(_size),
                painter: _PiePainter(
                  slices: slices,
                  total: total,
                  progress: t,
                  hovered: _hovered,
                ),
              ),
            );
          },
        ),
      ),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < slices.length; i++)
          MouseRegion(
            onEnter: (_) => setState(() => _hovered = i),
            onExit: (_) => setState(() => _hovered = null),
            child: Tooltip(
              message: slices[i].note == null || slices[i].note!.isEmpty
                  ? '${slices[i].label}: ${_number(slices[i].value, chart.unit)} ${chart.valueLabel.toLowerCase()}'
                  : '${slices[i].label}: ${slices[i].note}',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _hovered == i ? const Color(0xFFEFF5FD) : const Color.fromRGBO(255, 255, 255, 0),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: slices[i].color,
                        borderRadius: const BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(slices[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HomeText.body(13, weight: FontWeight.w600, color: HomeColors.ink)),
                    ),
                    const SizedBox(width: 8),
                    Text(_number(slices[i].value, chart.unit),
                        style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.body)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      child: Text('${(slices[i].value * 100 / total).round()}%',
                          textAlign: TextAlign.end,
                          style: HomeText.body(13, weight: FontWeight.w800, color: HomeColors.ink)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('Total ${_number(total, chart.unit)} ${chart.valueLabel.toLowerCase()}',
              style: HomeText.body(12, color: HomeColors.muted)),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 480) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              pie,
              const SizedBox(width: 22),
              Expanded(child: legend),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Center(child: pie), const SizedBox(height: 14), legend],
        );
      },
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.slices, required this.total, required this.progress, required this.hovered});

  final List<_Slice> slices;
  final double total;
  final double progress;
  final int? hovered;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;
    var start = -math.pi / 2;
    final gap = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < slices.length; i++) {
      final sweep = math.pi * 2 * slices[i].value / total * progress;
      final mid = start + sweep / 2;
      final lifted = hovered == i ? 7.0 : 0.0;
      final origin = center + Offset(math.cos(mid), math.sin(mid)) * lifted;
      final rect = Rect.fromCircle(center: origin, radius: radius);
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..arcTo(rect, start, sweep, false)
        ..close();
      if (hovered == i) {
        canvas.drawShadow(path, const Color.fromRGBO(15, 27, 45, 0.6), 6, false);
      }
      canvas.drawPath(path, Paint()..color = slices[i].color);
      if (slices.length > 1) canvas.drawPath(path, gap);

      final share = slices[i].value / total;
      if (progress >= 1 && share >= 0.08) {
        final labelPoint = origin + Offset(math.cos(mid), math.sin(mid)) * radius * 0.64;
        final dark = slices[i].color.computeLuminance() < 0.45;
        final painter = TextPainter(
          text: TextSpan(
            text: '${(share * 100).round()}%',
            style: HomeText.body(12.5, weight: FontWeight.w800, color: dark ? Colors.white : HomeColors.ink),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, labelPoint - Offset(painter.width / 2, painter.height / 2));
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.hovered != hovered ||
      oldDelegate.total != total ||
      oldDelegate.slices.length != slices.length;
}

// =================================================================== bars

class ReportBarChart extends StatelessWidget {
  const ReportBarChart({super.key, required this.chart, this.limit = 0});

  final ReportChart chart;

  /// Bars shown (0 = all).
  final int limit;

  Color _colorFor(int index) => switch (chart.palette) {
        ChartPalette.gaps => ReportColors.gaps[math.min(index, ReportColors.gaps.length - 1)],
        ChartPalette.levels => ReportColors.levels[math.min(index, ReportColors.levels.length - 1)],
        _ => ReportColors.bar,
      };

  @override
  Widget build(BuildContext context) {
    final paired = chart.palette == ChartPalette.paired;
    final indexed = [for (var i = 0; i < chart.data.length; i++) (index: i, datum: chart.data[i])];
    if (!chart.ordered) indexed.sort((a, b) => b.datum.value.compareTo(a.datum.value));
    final shown = limit > 0 && indexed.length > limit ? indexed.take(limit).toList() : indexed;
    var max = chart.unit == '%' ? 100.0 : 0.0;
    for (final e in shown) {
      max = math.max(max, math.max(e.datum.value, e.datum.secondary ?? 0.0));
    }
    if (max <= 0) max = 1;
    final hidden = indexed.length - shown.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = (constraints.maxWidth * 0.3).clamp(84.0, 220.0).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (paired) ...[
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _LegendKey(color: ReportColors.bar, label: chart.valueLabel),
                  const _LegendKey(color: ReportColors.shortfall, label: 'Short of the need'),
                  _LegendKey(color: ReportColors.need, label: chart.secondaryLabel ?? 'Needed', outline: true),
                ],
              ),
              const SizedBox(height: 12),
            ],
            for (var i = 0; i < shown.length; i++)
              _BarRow(
                datum: shown[i].datum,
                color: _colorFor(shown[i].index),
                max: max,
                unit: chart.unit,
                paired: paired,
                valueLabel: chart.valueLabel,
                secondaryLabel: chart.secondaryLabel,
                labelWidth: labelWidth,
                delay: i,
              ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('+$hidden more in the full report',
                    style: HomeText.body(12, weight: FontWeight.w600, color: HomeColors.muted)),
              ),
          ],
        );
      },
    );
  }
}

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.color, required this.label, this.outline = false});

  final Color color;
  final String label;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            border: outline ? Border.all(color: HomeColors.chipBorder) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: HomeText.body(12, weight: FontWeight.w600, color: HomeColors.body)),
      ],
    );
  }
}

class _BarRow extends StatefulWidget {
  const _BarRow({
    required this.datum,
    required this.color,
    required this.max,
    required this.unit,
    required this.paired,
    required this.valueLabel,
    required this.secondaryLabel,
    required this.labelWidth,
    required this.delay,
  });

  final ChartDatum datum;
  final Color color;
  final double max;
  final String unit;
  final bool paired;
  final String valueLabel;
  final String? secondaryLabel;
  final double labelWidth;
  final int delay;

  @override
  State<_BarRow> createState() => _BarRowState();
}

class _BarRowState extends State<_BarRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.datum;
    final need = d.secondary ?? 0.0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final valueText = widget.paired
        ? '${_number(d.value, '')} of ${_number(need, '')}'
        : _number(d.value, widget.unit);
    final short = widget.paired ? need - d.value : 0.0;
    final tooltip = [
      d.label,
      widget.paired
          ? '${widget.valueLabel}: ${_number(d.value, '')} · ${widget.secondaryLabel ?? 'Needed'}: ${_number(need, '')}'
              '${short > 0 ? ' · short ${_number(short, '')}' : ''}'
          : '${widget.valueLabel}: ${_number(d.value, widget.unit)}',
      if (d.note != null && d.note!.isNotEmpty) d.note!,
    ].join('\n');

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFF1F6FC) : const Color.fromRGBO(255, 255, 255, 0),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: widget.labelWidth,
                child: Text(d.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(13, weight: FontWeight.w600, color: HomeColors.ink)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
                  duration: reduceMotion
                      ? Duration.zero
                      : Duration(milliseconds: 700 + math.min(widget.delay, 10) * 60),
                  curve: HomeMotion.ease,
                  builder: (context, t, _) => SizedBox(
                    height: 14,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: widget.paired ? Colors.white : HomeColors.gapTrack,
                              borderRadius: const BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                        ),
                        if (widget.paired)
                          _Fill(
                            fraction: need / widget.max * t,
                            color: short > 0 ? ReportColors.shortfall : ReportColors.need,
                            border: short > 0 ? null : HomeColors.chipBorder,
                          ),
                        _Fill(fraction: d.value / widget.max * t, color: widget.paired ? ReportColors.bar : widget.color),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: widget.paired ? 64 : 52,
                // Long values ("120 of 150") shrink instead of wrapping.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(valueText,
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      style: HomeText.body(12.5, weight: FontWeight.w800, color: HomeColors.ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fill extends StatelessWidget {
  const _Fill({required this.fraction, required this.color, this.border});

  final double fraction;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0).toDouble();
    if (f <= 0) return const SizedBox.shrink();
    return Positioned.fill(
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: f,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: border == null ? null : Border.all(color: border!),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================== table

/// Horizontal space inside every table row (left + right padding, the
/// alert edge included) and the width of the orange "gap" edge.
const double _rowInset = 24;
const double _edge = 3;

/// Rows of [result] with [query] in any column (all rows when empty).
List<ReportRow> matchingRows(ReportResult result, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [...result.rows];
  final columns = result.columns;
  return result.rows.where((r) {
    for (var i = 0; i < columns.length && i < r.cells.length; i++) {
      if (reportCellText(r.cells[i], columns[i].kind).toLowerCase().contains(q)) return true;
    }
    return false;
  }).toList();
}

/// Sortable table (click a header). Wide reports scroll sideways.
class ReportTable extends StatefulWidget {
  const ReportTable({
    super.key,
    required this.result,
    this.limit = 0,
    this.onOpenRow,
    this.query = '',
  });

  final ReportResult result;

  /// Rows shown (0 = all).
  final int limit;
  final ValueChanged<ReportRow>? onOpenRow;

  /// Only rows containing this text (any column), see [matchingRows].
  final String query;

  @override
  State<ReportTable> createState() => _ReportTableState();
}

class _ReportTableState extends State<ReportTable> {
  final ScrollController _horizontal = ScrollController();
  int? _sortColumn;
  bool _ascending = true;

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  void _sort(int column) {
    setState(() {
      if (_sortColumn == column) {
        _ascending = !_ascending;
      } else {
        _sortColumn = column;
        // Numbers start biggest first, text A–Z.
        _ascending = !widget.result.columns[column].isNumeric;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final columns = result.columns;
    if (result.rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _NothingToShow(),
          if (result.note != null) _SmallNote(text: result.note!),
        ],
      );
    }
    var rows = matchingRows(result, widget.query);
    final sortColumn = _sortColumn;
    if (sortColumn != null) {
      rows.sort((a, b) {
        final va = sortColumn < a.cells.length ? a.cells[sortColumn] : null;
        final vb = sortColumn < b.cells.length ? b.cells[sortColumn] : null;
        // Empty cells stay last both ways.
        if (va == null || vb == null) return compareReportCells(va, vb);
        final order = compareReportCells(va, vb);
        return _ascending ? order : -order;
      });
    }
    if (widget.limit > 0 && rows.length > widget.limit) rows = rows.take(widget.limit).toList();
    final open = widget.onOpenRow;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Every row (header and body) keeps _rowInset px for its padding –
        // the body rows' 3px gap edge is part of their left padding. Widths
        // are floored so rounding can never push a row past its box.
        final base = [for (final c in columns) math.max(84.0, c.flex * 10.5)];
        final natural = base.fold<double>(0, (s, w) => s + w);
        final available = constraints.maxWidth - _rowInset;
        final scale = available > natural ? available / natural : 1.0;
        final widths = [for (final w in base) (w * scale).floorToDouble()];
        final used = widths.fold<double>(0, (s, w) => s + w) + _rowInset;
        final tableWidth = math.max(used, constraints.maxWidth);

        final table = SizedBox(
          width: tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: _rowInset / 2, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F8FC),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < columns.length; i++)
                      SizedBox(
                        width: widths[i],
                        child: _HeaderCell(
                          column: columns[i],
                          sorted: _sortColumn == i,
                          ascending: _ascending,
                          onTap: () => _sort(i),
                        ),
                      ),
                  ],
                ),
              ),
              for (var r = 0; r < rows.length; r++)
                _TableRow(
                  row: rows[r],
                  columns: columns,
                  widths: widths,
                  striped: r.isOdd,
                  onTap: open != null && rows[r].employeeId != null ? () => open(rows[r]) : null,
                ),
            ],
          ),
        );

        if (tableWidth <= constraints.maxWidth + 0.5) return table;
        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: table,
          ),
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.column, required this.sorted, required this.ascending, required this.onTap});

  final ReportColumn column;
  final bool sorted;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sort by ${column.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          child: Row(
            children: [
              Flexible(
                child: Text(column.label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(11,
                        weight: FontWeight.w800,
                        color: sorted ? HomeColors.ink : HomeColors.muted,
                        letterSpacing: 0.7)),
              ),
              if (sorted)
                Icon(ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 13, color: HomeColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.row,
    required this.columns,
    required this.widths,
    required this.striped,
    required this.onTap,
  });

  final ReportRow row;
  final List<ReportColumn> columns;
  final List<double> widths;
  final bool striped;
  final VoidCallback? onTap;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final tap = widget.onTap;
    return MouseRegion(
      cursor: tap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: tap,
        child: Container(
          // 3px gap edge + 9px = the same 12px left inset as the header.
          padding: const EdgeInsets.fromLTRB(_rowInset / 2 - _edge, 2, _rowInset / 2, 2),
          decoration: BoxDecoration(
            color: _hover && tap != null
                ? const Color(0xFFEFF5FD)
                : (widget.striped ? const Color(0xFFF9FBFE) : Colors.white),
            border: Border(
              left: BorderSide(
                color: row.alert ? HomeColors.orange : const Color.fromRGBO(255, 255, 255, 0),
                width: _edge,
              ),
              bottom: const BorderSide(color: HomeColors.gapTrack),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < widget.columns.length; i++)
                SizedBox(
                  width: widget.widths[i],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                    child: _ReportCell(
                      value: i < row.cells.length ? row.cells[i] : null,
                      kind: widget.columns[i].kind,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCell extends StatelessWidget {
  const _ReportCell({required this.value, required this.kind});

  final Object? value;
  final CellKind kind;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final text = reportCellText(v, kind);
    switch (kind) {
      case CellKind.level:
        if (v is! int) return Text(text, style: HomeText.body(13, color: HomeColors.muted));
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const BoxDecoration(
              color: HomeColors.blueTint,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(text, style: HomeText.body(12, weight: FontWeight.w800, color: HomeColors.blueDeep)),
          ),
        );
      case CellKind.gap:
        if (v is! int) return Text(text, style: HomeText.body(13, color: HomeColors.muted));
        if (v == 0) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_rounded, size: 14, color: OrgColors.good),
              const SizedBox(width: 3),
              Text('Met', style: HomeText.body(12.5, weight: FontWeight.w700, color: OrgColors.good)),
            ],
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: const BoxDecoration(
              color: HomeColors.orangeTint,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(text, style: HomeText.body(12.5, weight: FontWeight.w800, color: HomeColors.orangeText)),
          ),
        );
      case CellKind.number:
      case CellKind.percent:
      case CellKind.decimal:
        return Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.ink));
      case CellKind.text:
      case CellKind.date:
        final cell = Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HomeText.body(13, color: HomeColors.body, height: 1.35));
        return text.length > 40 ? Tooltip(message: text, child: cell) : cell;
    }
  }
}
