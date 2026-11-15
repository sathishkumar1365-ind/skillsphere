import 'package:flutter/material.dart';

import '../../../competency/data/competency_models.dart';
import '../../../competency/presentation/widgets/competency_common.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/insights.dart';
import '../widgets/admin_common.dart';

enum _GapFilter {
  all('All'),
  gaps('Gaps'),
  met('Met'),
  extra('Not required');

  const _GapFilter(this.label);
  final String label;
}

/// Required (by the employee's projects, for their role) vs acquired
/// competencies in ONE table: a competency several projects need is one
/// row with the highest required level and every project listed.
class CompetencyGapTable extends StatefulWidget {
  const CompetencyGapTable({
    super.key,
    required this.insight,
    this.onRequest,
    this.onOpenCompetency,
  });

  final EmployeeInsight insight;

  /// Team Leads: ask HR for a level-up on a row. Null hides the action.
  final ValueChanged<CompetencyRow>? onRequest;
  final ValueChanged<Competency>? onOpenCompetency;

  @override
  State<CompetencyGapTable> createState() => _CompetencyGapTableState();
}

class _CompetencyGapTableState extends State<CompetencyGapTable> {
  _GapFilter _filter = _GapFilter.all;

  @override
  Widget build(BuildContext context) {
    final info = widget.insight;
    final rows = info.rows.where((r) {
      return switch (_filter) {
        _GapFilter.all => true,
        _GapFilter.gaps => r.state.isGap,
        _GapFilter.met => r.state == RowState.met,
        _GapFilter.extra => r.state == RowState.extra,
      };
    }).toList();
    final extra = info.rows.where((r) => r.state == RowState.extra).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: '${info.requiredCount} required',
              icon: Icons.flag_outlined,
              background: HomeColors.blueTint,
              foreground: HomeColors.blueDeep,
            ),
            StatusPill(
              label: '${info.metCount} met',
              icon: Icons.check_circle_outline_rounded,
              background: OrgColors.goodTint,
              foreground: OrgColors.good,
            ),
            StatusPill(
              label: '${info.gapCount} ${info.gapCount == 1 ? 'gap' : 'gaps'}',
              icon: Icons.trending_up_rounded,
              background: HomeColors.orangeTint,
              foreground: HomeColors.orangeText,
            ),
            StatusPill(
              label: '$extra not required',
              icon: Icons.more_horiz_rounded,
              background: HomeColors.neutralTint,
              foreground: HomeColors.body,
            ),
            if (info.pendingCount > 0)
              StatusPill(
                label: '${info.pendingCount} waiting for HR',
                icon: Icons.hourglass_top_rounded,
                background: HomeColors.orangeTint,
                foreground: HomeColors.orangeText,
              ),
          ],
        ),
        const SizedBox(height: 14),
        ChoicePills<_GapFilter>(
          options: _GapFilter.values,
          selected: _filter,
          labelOf: (f) => switch (f) {
            _GapFilter.all => 'All · ${info.rows.length}',
            _GapFilter.gaps => 'Gaps · ${info.gapCount}',
            _GapFilter.met => 'Met · ${info.metCount}',
            _GapFilter.extra => 'Not required · $extra',
          },
          onSelected: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: 14),
        if (info.rows.isEmpty)
          const EmptyState(
            title: 'No competencies yet',
            message: 'No acquired skills and no project requirements.',
            icon: Icons.school_outlined,
          )
        else if (rows.isEmpty)
          Text('Nothing in this filter.', style: HomeText.body(13.5, color: HomeColors.muted))
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 860) {
                return Column(
                  children: [
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RowCard(row: r, onRequest: widget.onRequest, onOpen: widget.onOpenCompetency),
                      ),
                  ],
                );
              }
              TextStyle head() =>
                  HomeText.body(11.5, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.9);
              return OrgPanel(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                      child: Row(
                        children: [
                          Expanded(flex: 24, child: Text('COMPETENCY', style: head())),
                          Expanded(flex: 22, child: Text('REQUIRED BY', style: head())),
                          Expanded(flex: 12, child: Text('REQUIRED', style: head())),
                          Expanded(flex: 20, child: Text('ACQUIRED', style: head())),
                          Expanded(flex: 15, child: Text('GAP', style: head())),
                          Expanded(flex: 21, child: Text('', style: head())),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: HomeColors.cardBorder),
                    for (var i = 0; i < rows.length; i++)
                      _TableRow(
                        row: rows[i],
                        striped: i.isOdd,
                        onRequest: widget.onRequest,
                        onOpen: widget.onOpenCompetency,
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.row, required this.striped, required this.onRequest, required this.onOpen});

  final CompetencyRow row;
  final bool striped;
  final ValueChanged<CompetencyRow>? onRequest;
  final ValueChanged<Competency>? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: row.state.isGap
            ? const Color(0xFFFFFAF5)
            : (striped ? const Color(0xFFF9FBFE) : Colors.white),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        children: [
          Expanded(flex: 24, child: _NameCell(row: row, onOpen: onOpen)),
          Expanded(flex: 22, child: _SourcesCell(row: row)),
          Expanded(flex: 12, child: _RequiredCell(row: row)),
          Expanded(flex: 20, child: Padding(padding: const EdgeInsets.only(right: 16), child: _AcquiredCell(row: row))),
          Expanded(flex: 15, child: Align(alignment: Alignment.centerLeft, child: GapPill(row: row))),
          Expanded(flex: 21, child: Align(alignment: Alignment.centerRight, child: _ActionCell(row: row, onRequest: onRequest))),
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, required this.onRequest, required this.onOpen});

  final CompetencyRow row;
  final ValueChanged<CompetencyRow>? onRequest;
  final ValueChanged<Competency>? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: row.state.isGap ? HomeColors.orangeBand : HomeColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _NameCell(row: row, onOpen: onOpen)),
              GapPill(row: row),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REQUIRED', style: HomeText.body(10.5, weight: FontWeight.w800, color: HomeColors.muted)),
                    const SizedBox(height: 4),
                    _RequiredCell(row: row),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACQUIRED', style: HomeText.body(10.5, weight: FontWeight.w800, color: HomeColors.muted)),
                    const SizedBox(height: 4),
                    _AcquiredCell(row: row),
                  ],
                ),
              ),
            ],
          ),
          if (row.sources.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SourcesCell(row: row),
          ],
          if (row.pending != null || (onRequest != null && row.state.isGap)) ...[
            const SizedBox(height: 12),
            _ActionCell(row: row, onRequest: onRequest),
          ],
        ],
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.row, required this.onOpen});

  final CompetencyRow row;
  final ValueChanged<Competency>? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = row.competency;
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

class _SourcesCell extends StatelessWidget {
  const _SourcesCell({required this.row});

  final CompetencyRow row;

  @override
  Widget build(BuildContext context) {
    if (row.sources.isEmpty) {
      return Text('No project needs it', style: HomeText.body(12.5, color: HomeColors.muted));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in row.sources)
          Tooltip(
            message: '${s.project.name} needs L${s.level} · ${CompetencyLevel.name(s.level)}'
                '${s.roleName == null ? ' from everyone' : ' from a ${s.roleName}'}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                border: Border.all(color: HomeColors.chipBorder),
              ),
              child: Text('${s.project.code} · L${s.level}',
                  style: HomeText.body(12, weight: FontWeight.w700, color: HomeColors.ink)),
            ),
          ),
      ],
    );
  }
}

class _RequiredCell extends StatelessWidget {
  const _RequiredCell({required this.row});

  final CompetencyRow row;

  @override
  Widget build(BuildContext context) {
    final required = row.requiredLevel;
    if (required == null) return Text('—', style: HomeText.body(14, color: HomeColors.muted));
    // Compact (fits narrow columns): "L3" block + the level name.
    return Tooltip(
      message: CompetencyLevel.short(required),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: required >= 3 ? HomeColors.ink : HomeColors.blueTint,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Text('L$required',
                style: HomeText.body(12.5,
                    weight: FontWeight.w800, color: required >= 3 ? Colors.white : HomeColors.blueDeep)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(CompetencyLevel.name(required),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HomeText.body(12, weight: FontWeight.w600, color: HomeColors.body)),
          ),
        ],
      ),
    );
  }
}

class _AcquiredCell extends StatelessWidget {
  const _AcquiredCell({required this.row});

  final CompetencyRow row;

  @override
  Widget build(BuildContext context) {
    final held = row.holder;
    if (held == null) {
      return Text('Not acquired', style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.orangeText));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LevelSteps(level: held.level),
        const SizedBox(height: 6),
        // A Wrap, not a Row: in narrow columns "Verified" moves to a second
        // line instead of overflowing.
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('L${held.level} · ${CompetencyLevel.name(held.level)}',
                style: HomeText.body(12.5, weight: FontWeight.w700, color: HomeColors.ink)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(held.verified ? Icons.verified_rounded : Icons.person_outline_rounded,
                    size: 14, color: held.verified ? OrgColors.good : HomeColors.muted),
                const SizedBox(width: 3),
                Text(held.verified ? 'Verified' : 'Self-assessed',
                    style: HomeText.body(11.5, color: HomeColors.muted)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Met / −2 levels / Not acquired / Not required.
class GapPill extends StatelessWidget {
  const GapPill({super.key, required this.row});

  final CompetencyRow row;

  @override
  Widget build(BuildContext context) {
    return switch (row.state) {
      RowState.met => const StatusPill(
          label: 'Met',
          icon: Icons.check_circle_outline_rounded,
          background: OrgColors.goodTint,
          foreground: OrgColors.good,
        ),
      RowState.below => StatusPill(
          label: '−${row.gapSize} ${row.gapSize == 1 ? 'level' : 'levels'}',
          icon: Icons.trending_up_rounded,
          background: HomeColors.orangeTint,
          foreground: HomeColors.orangeText,
        ),
      RowState.missing => const StatusPill(
          label: 'Not acquired',
          icon: Icons.add_circle_outline_rounded,
          background: HomeColors.orangeTint,
          foreground: HomeColors.orangeText,
        ),
      RowState.extra => const StatusPill(
          label: 'Not required',
          icon: Icons.remove_circle_outline_rounded,
          background: HomeColors.neutralTint,
          foreground: HomeColors.body,
        ),
    };
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({required this.row, required this.onRequest});

  final CompetencyRow row;
  final ValueChanged<CompetencyRow>? onRequest;

  @override
  Widget build(BuildContext context) {
    final pending = row.pending;
    if (pending != null) {
      return Tooltip(
        message: 'Raised by ${pending.raisedByName} · waiting for HR',
        child: StatusPill(
          label: 'HR: → L${pending.toLevel}',
          icon: Icons.hourglass_top_rounded,
          background: HomeColors.orangeTint,
          foreground: HomeColors.orangeText,
        ),
      );
    }
    final request = onRequest;
    final held = row.acquiredLevel;
    if (request == null || (held != null && held >= CompetencyLevel.max)) return const SizedBox.shrink();
    if (row.state.isGap) {
      return PillButton(
        label: 'Request level-up',
        height: 38,
        fontSize: 12,
        horizontalPadding: 12,
        onPressed: () => request(row),
      );
    }
    return TextButton(
      onPressed: () => request(row),
      style: TextButton.styleFrom(
        foregroundColor: HomeColors.blue,
        textStyle: HomeText.body(12.5, weight: FontWeight.w700),
      ),
      child: const Text('Level-up'),
    );
  }
}
