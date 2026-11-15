import 'package:flutter/material.dart';

import '../../../competency/data/competency_models.dart';
import '../../../competency/presentation/widgets/competency_common.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/scroll_reveal.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../../training_plan/data/training_plans.dart';
import '../../data/admin_base.dart';
import '../../data/insights.dart';
import '../widgets/admin_common.dart';

/// Gap size filter: −1, −2, −3 or more.
enum _SizeFilter {
  all('All'),
  one('−1'),
  two('−2'),
  three('−3 or more');

  const _SizeFilter(this.label);
  final String label;

  bool matches(GapEntry e) => switch (this) {
        _SizeFilter.all => true,
        _SizeFilter.one => e.size == 1,
        _SizeFilter.two => e.size == 2,
        _SizeFilter.three => e.size >= 3,
      };
}

/// The employee's skill gaps: ONE chart (current vs required level per
/// competency) and ONE table (one row per competency and project that
/// reports the gap: current level, the project's required level, the gap
/// −1/−2/−3, the training plan and the next action).
///
/// The gap is live: it changes as soon as a level is approved or a
/// project's requirement changes.
class EmployeeGapsPanel extends StatefulWidget {
  const EmployeeGapsPanel({
    super.key,
    required this.insight,
    this.onRequest,
    this.onPlan,
    this.onOpenPlans,
    this.onOpenCompetency,
  });

  final EmployeeInsight insight;

  /// Team Leads: ask HR for a level-up. Null hides the action.
  final ValueChanged<CompetencyRow>? onRequest;

  /// The employee themself: plan training for a gap. Null hides it.
  final ValueChanged<GapEntry>? onPlan;

  /// Scrolls to / opens the training plan section.
  final VoidCallback? onOpenPlans;
  final ValueChanged<Competency>? onOpenCompetency;

  @override
  State<EmployeeGapsPanel> createState() => _EmployeeGapsPanelState();
}

class _EmployeeGapsPanelState extends State<EmployeeGapsPanel> {
  _SizeFilter _filter = _SizeFilter.all;

  @override
  Widget build(BuildContext context) {
    final info = widget.insight;
    final all = info.gapEntries;
    final entries = all.where(_filter.matches).toList();
    int count(_SizeFilter f) => all.where(f.matches).length;
    final competencies = {for (final e in all) e.competency.id}.length;
    final projects = {for (final e in all) e.source.project.id}.length;

    if (all.isEmpty) {
      return EmptyState(
        title: info.requiredCount == 0 ? 'No project requirements yet' : 'No gaps – fully project-ready',
        message: info.requiredCount == 0
            ? '${info.profile.firstName} isn\'t on a project that needs anything from their role.'
            : 'Every competency ${info.profile.firstName}\'s projects need is at the required level.',
        icon: Icons.verified_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: '${all.length} ${all.length == 1 ? 'gap' : 'gaps'} reported',
              icon: Icons.trending_up_rounded,
              background: HomeColors.orangeTint,
              foreground: HomeColors.orangeText,
            ),
            StatusPill(
              label: '$competencies ${competencies == 1 ? 'competency' : 'competencies'}',
              icon: Icons.school_outlined,
              background: HomeColors.blueTint,
              foreground: HomeColors.blueDeep,
            ),
            StatusPill(
              label: 'from $projects ${projects == 1 ? 'project' : 'projects'}',
              icon: Icons.work_outline_rounded,
              background: HomeColors.neutralTint,
              foreground: HomeColors.ink,
            ),
          ],
        ),
        const SizedBox(height: 14),
        // One filter row above everything it scopes (chart and table).
        ChoicePills<_SizeFilter>(
          options: _SizeFilter.values,
          selected: _filter,
          labelOf: (f) => '${f.label} · ${count(f)}',
          onSelected: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          Text('No gaps of this size.', style: HomeText.body(13.5, color: HomeColors.muted))
        else ...[
          _GapChart(entries: entries, onOpenCompetency: widget.onOpenCompetency),
          const SizedBox(height: 18),
          _GapTable(
            employeeId: info.profile.id,
            entries: entries,
            onRequest: widget.onRequest,
            onPlan: widget.onPlan,
            onOpenPlans: widget.onOpenPlans,
            onOpenCompetency: widget.onOpenCompetency,
          ),
        ],
      ],
    );
  }
}

// ================================================================ chart

/// One bar per competency on the 0–5 scale: blue = current level, orange
/// band = the shortfall up to the ink tick at the highest level any of
/// the (filtered) projects needs, "−2" printed at the end.
class _GapChart extends StatelessWidget {
  const _GapChart({required this.entries, required this.onOpenCompetency});

  final List<GapEntry> entries;
  final ValueChanged<Competency>? onOpenCompetency;

  @override
  Widget build(BuildContext context) {
    // Per competency: current level, highest required, projects.
    final byCompetency = <String, ({GapEntry top, List<GapEntry> all})>{};
    for (final e in entries) {
      final current = byCompetency[e.competency.id];
      if (current == null) {
        byCompetency[e.competency.id] = (top: e, all: [e]);
      } else {
        current.all.add(e);
        if (e.requiredLevel > current.top.requiredLevel) {
          byCompetency[e.competency.id] = (top: e, all: current.all);
        }
      }
    }
    final rows = byCompetency.values.toList()
      ..sort((a, b) {
        final bySize = b.top.size.compareTo(a.top.size);
        return bySize != 0 ? bySize : a.top.competency.name.compareTo(b.top.competency.name);
      });

    return OrgPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final nameWidth = compact ? 0.0 : 190.0;
          const gapWidth = 64.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PanelTitle(
                'Current vs required level',
                subtitle: 'Per competency, against the highest level its projects need. '
                    'Hover a bar for the projects.',
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _LegendKey(kind: _LegendKind.current, label: 'Current level'),
                  _LegendKey(kind: _LegendKind.required, label: 'Required level'),
                  _LegendKey(kind: _LegendKind.gap, label: 'Gap'),
                ],
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) SizedBox(height: compact ? 14 : 12),
                _ChartRow(
                  top: rows[i].top,
                  all: rows[i].all,
                  compact: compact,
                  nameWidth: nameWidth,
                  gapWidth: gapWidth,
                  onOpen: onOpenCompetency,
                ),
              ],
              const SizedBox(height: 8),
              // Level axis under the bars.
              Row(
                children: [
                  SizedBox(width: compact ? 0 : nameWidth + 12),
                  const Expanded(child: _LevelAxis()),
                  const SizedBox(width: gapWidth + 12),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChartRow extends StatelessWidget {
  const _ChartRow({
    required this.top,
    required this.all,
    required this.compact,
    required this.nameWidth,
    required this.gapWidth,
    required this.onOpen,
  });

  final GapEntry top;
  final List<GapEntry> all;
  final bool compact;
  final double nameWidth;
  final double gapWidth;
  final ValueChanged<Competency>? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = top.competency;
    final current = top.currentLevel;
    final projects = [...all]..sort((a, b) => b.requiredLevel.compareTo(a.requiredLevel));
    final tooltip = '${c.name}: ${current == null ? 'not acquired' : 'L$current'} · '
        'needs ${projects.map((e) => '${e.source.project.code} L${e.requiredLevel}').join(', ')} · '
        'gap −${top.size}';
    final open = onOpen;
    final name = InkWell(
      onTap: open == null ? null : () => open(c),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Row(
        children: [
          CompetencyBadge.of(c, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink)),
          ),
        ],
      ),
    );
    final bar = Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        excludeSemantics: true,
        child: _GapBar(current: current, required: top.requiredLevel),
      ),
    );
    final gap = SizedBox(
      width: gapWidth,
      child: Align(alignment: Alignment.centerLeft, child: _GapValue(size: top.size)),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Expanded(child: name), gap]),
          const SizedBox(height: 6),
          bar,
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: nameWidth, child: name),
        const SizedBox(width: 12),
        Expanded(child: bar),
        const SizedBox(width: 12),
        gap,
      ],
    );
  }
}

/// Grows with the section's reveal.
class _GapBar extends StatelessWidget {
  const _GapBar({required this.current, required this.required});

  final int? current;
  final int required;

  @override
  Widget build(BuildContext context) {
    final reveal = ScrollReveal.of(context);
    return SizedBox(
      height: 24,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) => CustomPaint(
          painter: _GapBarPainter(
            // Level N fills N + 1 of 6 steps (like LevelSteps); not held = 0.
            have: current == null ? 0.0 : (current! + 1) / CompetencyLevel.count,
            need: (required + 1) / CompetencyLevel.count,
            progress: reveal.value,
          ),
        ),
      ),
    );
  }
}

class _GapBarPainter extends CustomPainter {
  _GapBarPainter({required this.have, required this.need, required this.progress});

  final double have;
  final double need;
  final double progress;

  static const double _barHeight = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4) return;
    final top = (size.height - _barHeight) / 2;
    const radius = Radius.circular(4);

    // Track with faint step dividers (recessive grid).
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, top, size.width, _barHeight), radius),
      Paint()..color = HomeColors.gapTrack,
    );
    final divider = Paint()..color = Colors.white;
    for (var i = 1; i < CompetencyLevel.count; i++) {
      final x = size.width * i / CompetencyLevel.count;
      canvas.drawRect(Rect.fromLTWH(x - 1, top, 2, _barHeight), divider);
    }

    final haveX = have * size.width * progress;
    final needX = need * size.width;

    // Shortfall band between what is held and what is needed.
    final bandEnd = haveX + (needX - have * size.width) * progress;
    if (bandEnd > haveX + 0.5) {
      // 2px surface gap between the current bar and the band.
      final start = haveX > 0 ? haveX + 2 : 0.0;
      if (bandEnd > start) {
        final band = RRect.fromRectAndRadius(Rect.fromLTRB(start, top, bandEnd, top + _barHeight), radius);
        canvas.drawRRect(band, Paint()..color = HomeColors.orangeBand);
        canvas.drawRRect(
          band.deflate(0.75),
          Paint()
            ..color = HomeColors.orange
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    if (haveX > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, top, haveX, _barHeight), radius),
        Paint()..color = HomeColors.blue,
      );
    }

    // Required-level tick, fades in with the reveal.
    final x = needX.clamp(1.5, size.width - 1.5).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.5, 0, 3, size.height), const Radius.circular(2)),
      Paint()..color = HomeColors.ink.withValues(alpha: progress),
    );
  }

  @override
  bool shouldRepaint(_GapBarPainter oldDelegate) =>
      oldDelegate.have != have || oldDelegate.need != need || oldDelegate.progress != progress;
}

/// "L0 … L5" under the bars, each label centred on its step.
class _LevelAxis extends StatelessWidget {
  const _LevelAxis();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var l = CompetencyLevel.min; l <= CompetencyLevel.max; l++)
          Expanded(
            child: Text('L$l',
                textAlign: TextAlign.center,
                style: HomeText.body(11.5, weight: FontWeight.w700, color: HomeColors.muted)),
          ),
      ],
    );
  }
}

enum _LegendKind { current, required, gap }

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.kind, required this.label});

  final _LegendKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Widget swatch = switch (kind) {
      _LegendKind.current => Container(
          width: 18,
          height: 10,
          decoration: const BoxDecoration(
            color: HomeColors.blue,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
      _LegendKind.required => Container(
          width: 3,
          height: 16,
          decoration: const BoxDecoration(
            color: HomeColors.ink,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      _LegendKind.gap => Container(
          width: 18,
          height: 10,
          decoration: BoxDecoration(
            color: HomeColors.orangeBand,
            border: Border.all(color: HomeColors.orange, width: 1.5),
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
        ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 8),
        Text(label, style: HomeText.body(13)),
      ],
    );
  }
}

/// "−2" in an orange pill (with an icon, never colour alone).
class _GapValue extends StatelessWidget {
  const _GapValue({required this.size});

  final int size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$size ${size == 1 ? 'level' : 'levels'} below the required level',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: const BoxDecoration(
          color: HomeColors.orangeTint,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.south_rounded, size: 13, color: HomeColors.orangeText),
            const SizedBox(width: 2),
            Text('−$size', style: HomeText.body(13, weight: FontWeight.w800, color: HomeColors.orangeText)),
          ],
        ),
      ),
    );
  }
}

// ================================================================ table

class _GapTable extends StatelessWidget {
  const _GapTable({
    required this.employeeId,
    required this.entries,
    required this.onRequest,
    required this.onPlan,
    required this.onOpenPlans,
    required this.onOpenCompetency,
  });

  final String employeeId;
  final List<GapEntry> entries;
  final ValueChanged<CompetencyRow>? onRequest;
  final ValueChanged<GapEntry>? onPlan;
  final VoidCallback? onOpenPlans;
  final ValueChanged<Competency>? onOpenCompetency;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GapCard(
                    employeeId: employeeId,
                    entry: e,
                    onRequest: onRequest,
                    onPlan: onPlan,
                    onOpenPlans: onOpenPlans,
                    onOpen: onOpenCompetency,
                  ),
                ),
            ],
          );
        }
        TextStyle head() => HomeText.body(11.5, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.9);
        return OrgPanel(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: Row(
                  children: [
                    Expanded(flex: 22, child: Text('COMPETENCY', style: head())),
                    Expanded(flex: 20, child: Text('REPORTED BY', style: head())),
                    Expanded(flex: 9, child: Text('CURRENT', style: head())),
                    Expanded(flex: 9, child: Text('REQUIRED', style: head())),
                    Expanded(flex: 9, child: Text('GAP', style: head())),
                    Expanded(flex: 17, child: Text('TRAINING PLAN', style: head())),
                    Expanded(flex: 16, child: Text('', style: head())),
                  ],
                ),
              ),
              const Divider(height: 1, color: HomeColors.cardBorder),
              for (var i = 0; i < entries.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: i.isOdd ? const Color(0xFFFFFAF5) : Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 22, child: _NameCell(entry: entries[i], onOpen: onOpenCompetency)),
                      Expanded(flex: 20, child: _ProjectCell(entry: entries[i])),
                      Expanded(flex: 9, child: _LevelNumber(level: entries[i].currentLevel)),
                      Expanded(flex: 9, child: _LevelNumber(level: entries[i].requiredLevel)),
                      Expanded(
                          flex: 9,
                          child: Align(alignment: Alignment.centerLeft, child: _GapValue(size: entries[i].size))),
                      Expanded(
                        flex: 17,
                        child: _PlanCell(
                          employeeId: employeeId,
                          entry: entries[i],
                          onPlan: onPlan,
                          onOpenPlans: onOpenPlans,
                        ),
                      ),
                      Expanded(
                        flex: 16,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _ActionCell(entry: entries[i], onRequest: onRequest),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GapCard extends StatelessWidget {
  const _GapCard({
    required this.employeeId,
    required this.entry,
    required this.onRequest,
    required this.onPlan,
    required this.onOpenPlans,
    required this.onOpen,
  });

  final String employeeId;
  final GapEntry entry;
  final ValueChanged<CompetencyRow>? onRequest;
  final ValueChanged<GapEntry>? onPlan;
  final VoidCallback? onOpenPlans;
  final ValueChanged<Competency>? onOpen;

  @override
  Widget build(BuildContext context) {
    TextStyle label() => HomeText.body(10.5, weight: FontWeight.w800, color: HomeColors.muted);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: HomeColors.orangeBand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _NameCell(entry: entry, onOpen: onOpen)),
              _GapValue(size: entry.size),
            ],
          ),
          const SizedBox(height: 10),
          _ProjectCell(entry: entry),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('CURRENT', style: label()), const SizedBox(height: 4), _LevelNumber(level: entry.currentLevel)],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('REQUIRED', style: label()), const SizedBox(height: 4), _LevelNumber(level: entry.requiredLevel)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PlanCell(employeeId: employeeId, entry: entry, onPlan: onPlan, onOpenPlans: onOpenPlans),
          if (entry.row.pending != null || onRequest != null) ...[
            const SizedBox(height: 10),
            _ActionCell(entry: entry, onRequest: onRequest),
          ],
        ],
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.entry, required this.onOpen});

  final GapEntry entry;
  final ValueChanged<Competency>? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = entry.competency;
    final open = onOpen;
    return InkWell(
      onTap: open == null ? null : () => open(c),
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            CompetencyBadge.of(c, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: CategoryPill(c.category, dense: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The project that reports the gap (code, name, role).
class _ProjectCell extends StatelessWidget {
  const _ProjectCell({required this.entry});

  final GapEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = entry.source;
    return Tooltip(
      message: '${s.project.name} needs L${s.level} · ${CompetencyLevel.name(s.level)}'
          '${s.roleName == null ? ' from everyone' : ' from a ${s.roleName}'}',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(color: HomeColors.chipBorder),
            ),
            child: Text(s.project.code, style: HomeText.body(12, weight: FontWeight.w800, color: HomeColors.ink)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(13, weight: FontWeight.w600, color: HomeColors.ink)),
                Text(s.roleName == null ? 'Everyone' : s.roleName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(11.5, color: HomeColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A level as a number in a coloured block ("—" when not acquired).
class _LevelNumber extends StatelessWidget {
  const _LevelNumber({required this.level});

  final int? level;

  @override
  Widget build(BuildContext context) {
    final l = level;
    if (l == null) {
      return Tooltip(
        message: 'Not acquired',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                border: Border.all(color: HomeColors.chipBorder),
              ),
              child: Text('—', style: HomeText.body(15, weight: FontWeight.w800, color: HomeColors.muted)),
            ),
          ],
        ),
      );
    }
    return Tooltip(
      message: CompetencyLevel.short(l),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: levelBlockColor(l),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Text('$l', style: HomeText.body(15, weight: FontWeight.w800, color: levelBlockText(l))),
          ),
        ],
      ),
    );
  }
}

/// The training plan for this competency, or a "Plan training" button for
/// the employee.
class _PlanCell extends StatelessWidget {
  const _PlanCell({required this.employeeId, required this.entry, required this.onPlan, required this.onOpenPlans});

  final String employeeId;
  final GapEntry entry;
  final ValueChanged<GapEntry>? onPlan;
  final VoidCallback? onOpenPlans;

  @override
  Widget build(BuildContext context) {
    final plan = TrainingPlanRepository.instance.mainPlanFor(employeeId, entry.competency.id);
    final plans = onOpenPlans;
    if (plan == null) {
      final add = onPlan;
      if (add == null) {
        return Text('No plan yet', style: HomeText.body(12.5, color: HomeColors.muted));
      }
      return TextButton.icon(
        onPressed: () => add(entry),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Plan training'),
        style: TextButton.styleFrom(
          foregroundColor: HomeColors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: HomeText.body(12.5, weight: FontWeight.w700),
        ),
      );
    }
    final (IconData icon, Color bg, Color fg) = switch (plan.status) {
      PlanStatus.planned => (Icons.event_outlined, HomeColors.blueTint, HomeColors.blueDeep),
      PlanStatus.inProgress => (Icons.play_circle_outline_rounded, HomeColors.blueTint, HomeColors.blueDeep),
      PlanStatus.onHold => (Icons.pause_circle_outline_rounded, HomeColors.neutralTint, HomeColors.body),
      PlanStatus.completed => (Icons.task_alt_rounded, OrgColors.goodTint, OrgColors.good),
    };
    final pill = StatusPill(label: plan.status.label, icon: icon, background: bg, foreground: fg);
    return InkWell(
      onTap: plans,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Tooltip(
        message: '${plan.title} · ${plan.type.label}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: pill),
            const SizedBox(height: 3),
            Text(
              plan.status == PlanStatus.completed
                  ? '${plan.plannedHours} h done'
                  : '${plan.completedHours}/${plan.plannedHours} h · by ${monthYear(plan.targetDate)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.body(11.5, color: plan.isOverdue() ? HomeColors.orangeText : HomeColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Team Lead action: request a level-up (or the pending request).
class _ActionCell extends StatelessWidget {
  const _ActionCell({required this.entry, required this.onRequest});

  final GapEntry entry;
  final ValueChanged<CompetencyRow>? onRequest;

  @override
  Widget build(BuildContext context) {
    final pending = entry.row.pending;
    if (pending != null) {
      return Tooltip(
        message: 'Raised by ${pending.raisedByName} with ${pending.hours} h · waiting for HR',
        child: StatusPill(
          label: 'HR: → L${pending.toLevel}',
          icon: Icons.hourglass_top_rounded,
          background: HomeColors.orangeTint,
          foreground: HomeColors.orangeText,
        ),
      );
    }
    final request = onRequest;
    if (request == null) return const SizedBox.shrink();
    return PillButton(
      label: 'Request level-up',
      height: 38,
      fontSize: 12,
      horizontalPadding: 12,
      onPressed: () => request(entry.row),
    );
  }
}
