// The nodes of the skill map: project cards, required / current
// competency chips, gap tiles, placeholders, column headings and the
// employee hub (readiness ring with a small orbit turning around it in 3D).
//
// Every node has a fixed size (from SkillMapLayout), one line per row of
// text with an ellipsis, a tooltip with the full text, and lifts toward
// the viewer in 3D on hover or keyboard focus (identity matrix at rest).

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../admin/presentation/projects/allocate_projects_panel.dart' show FitRing;
import '../../competency/data/competency_models.dart';
import '../../competency/presentation/widgets/competency_common.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../../training_plan/data/training_plans.dart';
import '../data/skill_map.dart';

// ================================================================= shell

/// Hover/focus/tap behaviour and the 3D lift shared by every node.
class MapNodeShell extends StatefulWidget {
  const MapNodeShell({
    super.key,
    required this.child,
    required this.semanticLabel,
    required this.onHover,
    required this.onTap,
    this.tooltip,
    this.selected = false,
    this.background = Colors.white,
    this.borderColor = HomeColors.cardBorder,
    this.dashed = false,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
  });

  final Widget child;
  final String semanticLabel;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  final String? tooltip;

  /// Pinned (tapped): ink outline.
  final bool selected;
  final Color background;
  final Color borderColor;

  /// Dashed outline = not acquired / nothing there.
  final bool dashed;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  State<MapNodeShell> createState() => _MapNodeShellState();
}

class _MapNodeShellState extends State<MapNodeShell> {
  bool _hovered = false;
  bool _focused = false;

  void _setHover(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHover(value || _focused);
  }

  void _setFocus(bool value) {
    if (_focused == value) return;
    setState(() => _focused = value);
    widget.onHover(value || _hovered);
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(widget.radius);
    final outline = widget.selected ? HomeColors.ink : widget.borderColor;

    Widget body = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: _setFocus,
        borderRadius: radius,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
    if (widget.dashed && !widget.selected) {
      body = DashedOutline(color: outline, radius: widget.radius, strokeWidth: 1.3, child: body);
    }

    Widget node = Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: active ? 1 : 0),
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
          curve: HomeMotion.ease,
          child: body,
          builder: (context, t, child) {
            // At rest: identity matrix and no shadow (nothing extra to paint).
            final matrix = t == 0
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..multiply(Matrix4.translationValues(0, -3 * t, 0))
                  ..multiply(Matrix4.rotationX(-0.14 * t)));
            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.background,
                  borderRadius: radius,
                  border: widget.dashed && !widget.selected
                      ? null
                      : Border.all(color: outline, width: widget.selected ? 1.6 : 1),
                  boxShadow: t == 0
                      ? null
                      : [
                          BoxShadow(
                            color: Color.fromRGBO(15, 27, 45, 0.28 * t),
                            blurRadius: 22,
                            spreadRadius: -10,
                            offset: Offset(0, 12 * t),
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
    final tip = widget.tooltip;
    if (tip != null && tip.isNotEmpty) {
      node = Tooltip(message: tip, waitDuration: const Duration(milliseconds: 700), child: node);
    }
    return node;
  }
}

/// Two lines (title + detail with an icon), each one line with an ellipsis.
class _TwoLines extends StatelessWidget {
  const _TwoLines({required this.title, required this.detail, required this.icon, required this.iconColor, this.detailColor});

  final String title;
  final String detail;
  final IconData icon;
  final Color iconColor;
  final Color? detailColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.ink, height: 1.25)),
        ),
        const SizedBox(height: 2),
        Flexible(
          child: Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(11.5,
                        weight: FontWeight.w600, color: detailColor ?? HomeColors.muted, height: 1.25)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================== projects

class ProjectNode extends StatelessWidget {
  const ProjectNode({
    super.key,
    required this.node,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  final MapProject node;
  final bool selected;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = node.project;
    final gaps = node.fit.gapCount;
    return MapNodeShell(
      selected: selected,
      onHover: onHover,
      onTap: onTap,
      radius: 18,
      tooltip: '${p.code} · ${p.name}\n${p.status.label} · ${p.period}',
      semanticLabel: 'Project ${p.code}, ${p.name}. Fit ${node.fit.percent} percent, '
          '${node.fit.needs.length} needs, $gaps ${gaps == 1 ? 'gap' : 'gaps'}.',
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(11)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3C7BE8), HomeColors.ink],
              ),
            ),
            child: const Icon(Icons.work_outline_rounded, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(p.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.body(13.5, weight: FontWeight.w800, color: HomeColors.ink, height: 1.25)),
                ),
                Flexible(
                  child: Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.body(11.5, color: HomeColors.muted, height: 1.3)),
                ),
                Flexible(
                  child: Text(
                    gaps == 0 ? 'All needs met' : '$gaps ${gaps == 1 ? 'gap' : 'gaps'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(11,
                        weight: FontWeight.w700, color: gaps == 0 ? OrgColors.good : HomeColors.orangeText, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FitRing(percent: node.fit.percent, size: 38),
        ],
      ),
    );
  }
}

// ============================================================== required

class NeedNode extends StatelessWidget {
  const NeedNode({super.key, required this.node, required this.selected, required this.onHover, required this.onTap});

  final MapNeed node;
  final bool selected;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = node.competency;
    final count = node.sources.length;
    final met = node.met;
    final held = node.held;
    final projects = node.sources.map((s) => '${s.project.code} needs L${s.level}').join('\n');
    return MapNodeShell(
      selected: selected,
      onHover: onHover,
      onTap: onTap,
      tooltip: '${c.name} · ${c.category.label}\n$projects',
      semanticLabel: '${c.name} required at level ${node.level} by $count '
          '${count == 1 ? 'project' : 'projects'}. ${met ? 'Met' : 'Gap'}.',
      child: Row(
        children: [
          CompetencyBadge.of(c, size: 28),
          const SizedBox(width: 9),
          Expanded(
            child: _TwoLines(
              title: c.name,
              detail: 'Needs L${node.level}${count > 1 ? ' · $count projects' : ''}',
              icon: met ? Icons.check_circle_rounded : Icons.north_east_rounded,
              iconColor: met ? OrgColors.good : HomeColors.orange,
              detailColor: met ? HomeColors.muted : HomeColors.orangeText,
            ),
          ),
          if (!met)
            Tooltip(
              message: held == null ? 'Not acquired yet' : 'Holds L$held',
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.priority_high_rounded, size: 15, color: HomeColors.orange),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================== current

class CurrentNode extends StatelessWidget {
  const CurrentNode({super.key, required this.node, required this.selected, required this.onHover, required this.onTap});

  final MapCurrent node;
  final bool selected;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = node.competency;
    final level = node.level;
    final need = node.neededLevel;
    final pending = node.pending;
    final String detail;
    final IconData icon;
    final Color iconColor;
    Color? detailColor;
    if (level == null) {
      detail = need == null ? 'Not acquired' : 'Not acquired · needs L$need';
      icon = Icons.remove_circle_outline_rounded;
      iconColor = HomeColors.orange;
      detailColor = HomeColors.orangeText;
    } else if (need == null) {
      detail = 'L$level · not needed here';
      icon = Icons.radio_button_unchecked_rounded;
      iconColor = const Color(0xFF8593A6);
    } else if (level >= need) {
      detail = 'L$level · ${node.verified ? 'verified' : 'self-assessed'}';
      icon = Icons.check_circle_rounded;
      iconColor = OrgColors.good;
    } else {
      detail = 'L$level · needs L$need';
      icon = Icons.south_rounded;
      iconColor = HomeColors.orange;
      detailColor = HomeColors.orangeText;
    }
    return MapNodeShell(
      selected: selected,
      onHover: onHover,
      onTap: onTap,
      dashed: level == null,
      background: level == null ? const Color(0xFFFFFBF7) : Colors.white,
      borderColor: level == null ? HomeColors.peach : HomeColors.cardBorder,
      tooltip: '${c.name} · ${c.category.label}\n'
          '${level == null ? 'Not acquired' : '${CompetencyLevel.short(level)} · ${node.verified ? 'verified' : 'self-assessed'}'}'
          '${pending == null ? '' : '\nLevel-up to L${pending.toLevel} waiting for HR'}',
      semanticLabel: '${c.name}: $detail${pending == null ? '' : ', level-up waiting for HR'}.',
      child: Row(
        children: [
          CompetencyBadge.of(c, size: 28),
          const SizedBox(width: 9),
          Expanded(
            child: _TwoLines(title: c.name, detail: detail, icon: icon, iconColor: iconColor, detailColor: detailColor),
          ),
          if (pending != null)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.hourglass_top_rounded, size: 15, color: HomeColors.orange),
            ),
        ],
      ),
    );
  }
}

// ================================================================== gaps

class GapNode extends StatelessWidget {
  const GapNode({super.key, required this.node, required this.selected, required this.onHover, required this.onTap});

  final MapGap node;
  final bool selected;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = node.competency;
    final held = node.held;
    final plan = node.plan;
    final pending = node.pending;
    final reported = node.sources.map((s) => '${s.project.code}: −${s.size} (needs L${s.level})').join('\n');
    return MapNodeShell(
      selected: selected,
      onHover: onHover,
      onTap: onTap,
      background: const Color(0xFFFFF8F1),
      borderColor: HomeColors.orangeBand,
      tooltip: '${c.name}: ${held == null ? 'not acquired' : 'L$held'} → L${node.neededLevel}\n$reported'
          '${plan == null ? '\nNo training plan yet' : '\nPlan: ${plan.title} (${plan.status.label})'}'
          '${pending == null ? '' : '\nLevel-up to L${pending.toLevel} waiting for HR'}',
      semanticLabel: '${c.name} gap of ${node.size} ${node.size == 1 ? 'level' : 'levels'}. '
          '${plan == null ? 'No training plan.' : 'Training plan ${plan.status.label}.'}',
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(11)),
              border: Border.all(color: HomeColors.peach),
            ),
            child: Text('−${node.size}', style: HomeText.body(14.5, weight: FontWeight.w800, color: HomeColors.orangeText)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _TwoLines(
              title: c.name,
              detail: '${held == null ? '—' : 'L$held'} → L${node.neededLevel}',
              icon: Icons.trending_up_rounded,
              iconColor: HomeColors.orange,
              detailColor: HomeColors.orangeText,
            ),
          ),
          if (plan != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(planIcon(plan.status), size: 15, color: HomeColors.blueDeep),
            ),
          if (pending != null)
            const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.hourglass_top_rounded, size: 15, color: HomeColors.orange),
            ),
        ],
      ),
    );
  }
}

IconData planIcon(PlanStatus status) => switch (status) {
      PlanStatus.planned => Icons.event_outlined,
      PlanStatus.inProgress => Icons.play_circle_outline_rounded,
      PlanStatus.onHold => Icons.pause_circle_outline_rounded,
      PlanStatus.completed => Icons.task_alt_rounded,
    };

// ========================================================== placeholders

/// Shown in a column with nothing in it.
class PlaceholderNode extends StatelessWidget {
  const PlaceholderNode({super.key, required this.column, required this.hasNeeds});

  final SkillMapColumn column;

  /// The projects need something (so an empty gap column means "all met").
  final bool hasNeeds;

  @override
  Widget build(BuildContext context) {
    final allMet = column == SkillMapColumn.gaps && hasNeeds;
    final (IconData icon, String text) = switch (column) {
      SkillMapColumn.projects => (Icons.work_off_outlined, 'Not on a project'),
      SkillMapColumn.needs => (Icons.playlist_remove_rounded, 'Nothing required'),
      SkillMapColumn.current => (Icons.school_outlined, 'No competencies yet'),
      SkillMapColumn.gaps => allMet ? (Icons.verified_rounded, 'No gaps') : (Icons.remove_rounded, 'No gaps to show'),
      SkillMapColumn.employee => (Icons.person_outline_rounded, ''),
    };
    final color = allMet ? OrgColors.good : HomeColors.muted;
    return Semantics(
      label: text,
      child: DashedOutline(
        color: allMet ? const Color(0xFF8CCBA8) : HomeColors.chipBorder,
        radius: 16,
        strokeWidth: 1.3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: allMet ? OrgColors.goodTint : const Color.fromRGBO(255, 255, 255, 0.7),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.body(12.5, weight: FontWeight.w700, color: color)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================== headings

class ColumnHeading extends StatelessWidget {
  const ColumnHeading({super.key, required this.column, required this.count, required this.wide});

  final SkillMapColumn column;
  final int count;

  /// Wide = column heading (short), else tier heading (long).
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final gaps = column == SkillMapColumn.gaps && count > 0;
    return Align(
      alignment: wide ? Alignment.bottomLeft : Alignment.centerLeft,
      child: Row(
        children: [
          Flexible(
            child: Text(
              (wide ? column.short : column.long).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.body(11, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 1.1),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: gaps ? HomeColors.orangeTint : HomeColors.neutralTint,
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Text('$count',
                style: HomeText.body(11, weight: FontWeight.w800, color: gaps ? HomeColors.orangeText : HomeColors.ink)),
          ),
        ],
      ),
    );
  }
}

// =================================================================== hub

/// The employee: initials on a raised disc, the readiness ring around it
/// and a small orbit turning in 3D (its back half passes behind the disc).
class HubNode extends StatelessWidget {
  const HubNode({
    super.key,
    required this.initials,
    required this.readiness,
    required this.clock,
    required this.selected,
    required this.semanticLabel,
    required this.onHover,
    required this.onTap,
  });

  final String initials;

  /// 0–100, null = no project needs anything.
  final int? readiness;
  final ValueListenable<double> clock;
  final bool selected;
  final String semanticLabel;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final disc = size * 0.72;
        return Semantics(
          button: true,
          selected: selected,
          label: semanticLabel,
          excludeSemantics: true,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => onHover(true),
            onExit: (_) => onHover(false),
            child: GestureDetector(
              onTap: onTap,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _HubPainter(clock: clock, readiness: readiness, front: false, selected: selected),
                  foregroundPainter: _HubPainter(clock: clock, readiness: readiness, front: true, selected: selected),
                  child: Center(
                    child: Container(
                      width: disc,
                      height: disc,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3C7BE8), HomeColors.ink],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(15, 27, 45, 0.35),
                            blurRadius: disc * 0.35,
                            spreadRadius: -disc * 0.12,
                            offset: Offset(0, disc * 0.16),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(disc * 0.16),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(initials, style: HomeText.display(disc * 0.36, color: Colors.white, height: 1)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HubPainter extends CustomPainter {
  _HubPainter({required this.clock, required this.readiness, required this.front, required this.selected})
      : super(repaint: clock);

  final ValueListenable<double> clock;
  final int? readiness;

  /// Front painter: the near half of the orbit and the moon when it is in
  /// front of the disc. Back painter: ring, far half, moon behind.
  final bool front;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final t = clock.value;

    if (!front) {
      // Readiness ring.
      final ring = Rect.fromCircle(center: c, radius: r - 4);
      canvas.drawCircle(
        c,
        r - 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = HomeColors.track,
      );
      final value = readiness;
      if (value != null && value > 0) {
        canvas.drawArc(
          ring,
          -math.pi / 2,
          math.pi * 2 * (value.clamp(0, 100) / 100),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..color = HomeColors.blue,
        );
      }
      if (selected) {
        canvas.drawCircle(
          c,
          r - 0.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = HomeColors.ink,
        );
      }
    }

    // Orbit: an ellipse (a circle seen at an angle) slowly turning, with a
    // small moon going round it. Near half (sin > 0) in front of the disc.
    final tilt = -0.45 + 0.12 * math.sin(t * 0.35);
    final a = r * 0.98;
    final b = r * 0.34;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = HomeColors.blue.withValues(alpha: front ? 0.45 : 0.22);
    final oval = Rect.fromCenter(center: Offset.zero, width: a * 2, height: b * 2);
    // Back half = upper arc (angles π..2π), front half = lower arc (0..π).
    canvas.drawArc(oval, front ? 0.0 : math.pi, math.pi, false, orbit);
    final angle = t * 1.1;
    final moonFront = math.sin(angle) > 0;
    if (moonFront == front) {
      final p = Offset(a * math.cos(angle), b * math.sin(angle));
      final depth = 0.75 + 0.25 * math.sin(angle);
      canvas.drawCircle(p, 6.5 * depth, Paint()..color = HomeColors.peach.withValues(alpha: 0.25));
      canvas.drawCircle(p, 3.4 * depth, Paint()..color = front ? HomeColors.orange : HomeColors.peach);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HubPainter oldDelegate) =>
      oldDelegate.readiness != readiness ||
      oldDelegate.front != front ||
      oldDelegate.selected != selected ||
      !identical(oldDelegate.clock, clock);
}

/// Name and readiness next to the hub.
class HubLabel extends StatelessWidget {
  const HubLabel({super.key, required this.name, required this.readiness, required this.gaps, required this.centred});

  final String name;
  final int? readiness;
  final int gaps;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final value = readiness;
    return Column(
      crossAxisAlignment: centred ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: centred ? TextAlign.center : TextAlign.start,
              style: HomeText.body(13.5, weight: FontWeight.w800, color: HomeColors.ink, height: 1.25)),
        ),
        Flexible(
          child: Text(
            value == null ? 'No project needs yet' : '$value% ready · $gaps ${gaps == 1 ? 'gap' : 'gaps'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centred ? TextAlign.center : TextAlign.start,
            style: HomeText.body(12, weight: FontWeight.w600, color: gaps > 0 ? HomeColors.orangeText : HomeColors.muted),
          ),
        ),
      ],
    );
  }
}
