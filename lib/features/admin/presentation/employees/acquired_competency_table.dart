import 'package:flutter/material.dart';

import '../../../competency/data/competency_models.dart';
import '../../../competency/data/level_hours_policy.dart';
import '../../../competency/data/level_progress.dart';
import '../../../competency/presentation/widgets/competency_common.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/scroll_reveal.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/employees.dart';
import '../../data/insights.dart';
import '../widgets/admin_common.dart';

/// Everything the employee has acquired, with the level history behind it:
/// level, what projects need, last confirmed date, hours acquired since the
/// previous confirmation, total hours from the starting point and the hours
/// the next level needs (policy).
class AcquiredCompetencyTable extends StatelessWidget {
  const AcquiredCompetencyTable({
    super.key,
    required this.insight,
    this.onRequest,
    this.onOpenCompetency,
  });

  final EmployeeInsight insight;

  /// Team Leads: ask HR for a level-up. Null hides the action.
  final ValueChanged<CompetencyRow>? onRequest;
  final ValueChanged<Competency>? onOpenCompetency;

  @override
  Widget build(BuildContext context) {
    final rows = insight.rows.where((r) => r.holder != null).toList()
      ..sort((a, b) {
        final byLevel = (b.acquiredLevel ?? 0).compareTo(a.acquiredLevel ?? 0);
        return byLevel != 0 ? byLevel : a.competency.name.compareTo(b.competency.name);
      });
    final progress = LevelProgressRepository.instance;
    final employeeId = insight.profile.id;
    final infos = [for (final r in rows) _Info(r, progress.progressOf(employeeId, r.competency.id))];
    final verified = rows.where((r) => r.holder!.verified).length;
    final totalHours = infos.fold<int>(0, (s, i) => s + i.progress.totalHours);
    DateTime? latest;
    for (final i in infos) {
      final d = i.progress.lastConfirmedOn;
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }

    if (rows.isEmpty) {
      return const EmptyState(
        title: 'No acquired competencies yet',
        message: 'Levels are added at onboarding, by HRD, or when HR approves a level-up.',
        icon: Icons.school_outlined,
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
              label: '${rows.length} acquired',
              icon: Icons.school_outlined,
              background: HomeColors.blueTint,
              foreground: HomeColors.blueDeep,
            ),
            StatusPill(
              label: '$verified verified',
              icon: Icons.verified_rounded,
              background: OrgColors.goodTint,
              foreground: OrgColors.good,
            ),
            StatusPill(
              label: '${hoursLabel(totalHours)} in total',
              icon: Icons.schedule_rounded,
              background: HomeColors.neutralTint,
              foreground: HomeColors.ink,
            ),
            if (latest != null)
              StatusPill(
                label: 'Last confirmation ${dayMonthYear(latest)}',
                icon: Icons.event_available_outlined,
                background: HomeColors.neutralTint,
                foreground: HomeColors.ink,
              ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 980) {
              return Column(
                children: [
                  for (final info in infos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _Card(
                        info: info,
                        profile: insight.profile,
                        onRequest: onRequest,
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
                        Expanded(flex: 18, child: Text('LEVEL', style: head())),
                        Expanded(flex: 12, child: Text('PROJECTS NEED', style: head())),
                        Expanded(flex: 14, child: Text('LAST CONFIRMED', style: head())),
                        Expanded(flex: 15, child: Text('HOURS', style: head())),
                        Expanded(flex: 15, child: Text('NEXT LEVEL', style: head())),
                        Expanded(flex: 13, child: Text('', style: head())),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: HomeColors.cardBorder),
                  for (var i = 0; i < infos.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: i.isOdd ? const Color(0xFFF9FBFE) : Colors.white,
                        borderRadius: const BorderRadius.all(Radius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 22, child: _NameCell(row: infos[i].row, onOpen: onOpenCompetency)),
                          Expanded(
                            flex: 18,
                            child: Padding(padding: const EdgeInsets.only(right: 16), child: _LevelCell(row: infos[i].row)),
                          ),
                          Expanded(flex: 12, child: _NeedCell(row: infos[i].row)),
                          Expanded(flex: 14, child: _ConfirmedCell(progress: infos[i].progress)),
                          Expanded(flex: 15, child: _HoursCell(progress: infos[i].progress)),
                          Expanded(flex: 15, child: _NextCell(row: infos[i].row)),
                          Expanded(
                            flex: 13,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _Actions(
                                info: infos[i],
                                profile: insight.profile,
                                onRequest: onRequest,
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _Info {
  const _Info(this.row, this.progress);

  final CompetencyRow row;
  final LevelProgress progress;
}

class _Card extends StatelessWidget {
  const _Card({required this.info, required this.profile, required this.onRequest, required this.onOpen});

  final _Info info;
  final EmployeeProfile profile;
  final ValueChanged<CompetencyRow>? onRequest;
  final ValueChanged<Competency>? onOpen;

  @override
  Widget build(BuildContext context) {
    TextStyle label() => HomeText.body(10.5, weight: FontWeight.w800, color: HomeColors.muted);
    Widget block(String title, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [Text(title, style: label()), const SizedBox(height: 4), child],
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _NameCell(row: info.row, onOpen: onOpen)),
              _Actions(info: info, profile: profile, onRequest: onRequest),
            ],
          ),
          const SizedBox(height: 12),
          _LevelCell(row: info.row),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              block('PROJECTS NEED', _NeedCell(row: info.row)),
              block('LAST CONFIRMED', _ConfirmedCell(progress: info.progress)),
              block('HOURS', _HoursCell(progress: info.progress)),
              block('NEXT LEVEL', _NextCell(row: info.row)),
            ],
          ),
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

class _LevelCell extends StatelessWidget {
  const _LevelCell({required this.row});

  final CompetencyRow row;

  @override
  Widget build(BuildContext context) {
    final held = row.holder!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LevelSteps(level: held.level),
        const SizedBox(height: 6),
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
                Text(held.verified ? 'Verified' : 'Self-assessed', style: HomeText.body(11.5, color: HomeColors.muted)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// "L4 · −1" / "L3 · Met" / "—".
class _NeedCell extends StatelessWidget {
  const _NeedCell({required this.row});

  final CompetencyRow row;

  @override
  Widget build(BuildContext context) {
    final required = row.requiredLevel;
    if (required == null) return Text('Not required', style: HomeText.body(12.5, color: HomeColors.muted));
    final met = row.state == RowState.met;
    return Tooltip(
      message: row.sources.map((s) => '${s.project.code} L${s.level}').join(' · '),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('L$required', style: HomeText.body(13.5, weight: FontWeight.w800, color: HomeColors.ink)),
          const SizedBox(width: 6),
          Flexible(
            child: StatusPill(
              label: met ? 'Met' : '−${row.gapSize}',
              icon: met ? Icons.check_rounded : Icons.south_rounded,
              background: met ? OrgColors.goodTint : HomeColors.orangeTint,
              foreground: met ? OrgColors.good : HomeColors.orangeText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmedCell extends StatelessWidget {
  const _ConfirmedCell({required this.progress});

  final LevelProgress progress;

  @override
  Widget build(BuildContext context) {
    final last = progress.lastConfirmation;
    if (last == null) {
      return Text('Not confirmed yet', style: HomeText.body(12.5, weight: FontWeight.w600, color: HomeColors.orangeText));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(dayMonthYear(last.confirmedOn), style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.ink)),
        Text('${last.stepLabel} · ${relativeDays(last.confirmedOn)}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: HomeText.body(11.5, color: HomeColors.muted)),
      ],
    );
  }
}

/// Hours since the previous confirmation (of the last one) + total.
class _HoursCell extends StatelessWidget {
  const _HoursCell({required this.progress});

  final LevelProgress progress;

  @override
  Widget build(BuildContext context) {
    final last = progress.lastConfirmation;
    final since = last == null || last.source == LevelChangeSource.starting ? null : last.hours;
    return Tooltip(
      message: 'Hours acquired between the previous confirmed level and the last one, and the total '
          'since the starting point (${progress.start == null ? '—' : dayMonthYear(progress.start!.confirmedOn)}).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(since == null ? '—' : '${hoursLabel(since)} for ${last!.stepLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.ink)),
          Text('Total ${hoursLabel(progress.totalHours)}', style: HomeText.body(11.5, color: HomeColors.muted)),
        ],
      ),
    );
  }
}

/// Hours the policy asks for the next level, or the pending request.
class _NextCell extends StatelessWidget {
  const _NextCell({required this.row});

  final CompetencyRow row;

  @override
  Widget build(BuildContext context) {
    final pending = row.pending;
    if (pending != null) {
      return Tooltip(
        message: 'Raised by ${pending.raisedByName} · waiting for HR',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusPill(
              label: 'HR: → L${pending.toLevel}',
              icon: Icons.hourglass_top_rounded,
              background: HomeColors.orangeTint,
              foreground: HomeColors.orangeText,
            ),
            const SizedBox(height: 3),
            Text('${hoursLabel(pending.hours)} of ${hoursLabel(pending.requiredHours)}',
                style: HomeText.body(11.5, color: pending.belowPolicy ? HomeColors.orangeText : HomeColors.muted)),
          ],
        ),
      );
    }
    final level = row.acquiredLevel ?? 0;
    final hours = LevelHoursPolicy.instance.hoursToNext(row.competency.category, level);
    if (hours == null) return Text('Top level', style: HomeText.body(12.5, weight: FontWeight.w700, color: OrgColors.good));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('L${level + 1} needs ${hoursLabel(hours)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.ink)),
        Text('${row.competency.category.label} policy', style: HomeText.body(11.5, color: HomeColors.muted)),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.info, required this.profile, required this.onRequest});

  final _Info info;
  final EmployeeProfile profile;
  final ValueChanged<CompetencyRow>? onRequest;

  @override
  Widget build(BuildContext context) {
    final request = onRequest;
    final row = info.row;
    final canRaise = row.pending == null && (row.acquiredLevel ?? 0) < CompetencyLevel.max;
    // A Wrap (not a Row): in the narrowest table column "Level-up" moves
    // under the history icon instead of overflowing.
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: 'Level history',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.timeline_rounded, size: 20, color: HomeColors.ink),
          onPressed: () => showLevelHistory(context: context, profile: profile, competency: row.competency),
        ),
        if (request != null && canRaise)
          TextButton(
            onPressed: () => request(row),
            style: TextButton.styleFrom(
              foregroundColor: HomeColors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: HomeText.body(12.5, weight: FontWeight.w700),
            ),
            child: const Text('Level-up'),
          ),
      ],
    );
  }
}

// ======================================================== level history

/// The level history of one competency: every confirmation with its hours
/// next to the policy for that step, newest first.
Future<void> showLevelHistory({
  required BuildContext context,
  required EmployeeProfile profile,
  required Competency competency,
}) {
  return showSwingPanel<void>(
    context: context,
    title: '${competency.name} – level history',
    subtitle: '${profile.name} · ${profile.id}',
    width: 720,
    builder: (_) => _HistoryView(profile: profile, competency: competency),
  );
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.profile, required this.competency});

  final EmployeeProfile profile;
  final Competency competency;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Insights.listenable,
      builder: (context, _) {
        final progress = LevelProgressRepository.instance.progressOf(profile.id, competency.id);
        final holder = Insights.of(profile).rows.where((r) => r.competency.id == competency.id).firstOrNull?.holder;
        final policy = LevelHoursPolicy.instance;
        final next = holder == null ? null : policy.hoursToNext(competency.category, holder.level);
        final history = progress.history.reversed.toList();
        final maxHours = history.fold<int>(1, (m, r) {
          final need = r.fromLevel == null || r.source != LevelChangeSource.approval
              ? r.hours
              : policy.hoursBetween(competency.category, r.fromLevel, r.toLevel);
          final top = r.hours > need ? r.hours : need;
          return top > m ? top : m;
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CompetencyBadge.of(competency, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(competency.name, style: HomeText.body(18, weight: FontWeight.w800, color: HomeColors.ink)),
                      const SizedBox(height: 4),
                      CategoryPill(competency.category, dense: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FieldGrid(
              maxColumns: 4,
              minFieldWidth: 140,
              children: [
                DetailItem(
                  label: 'Current level',
                  value: holder == null ? 'Not held' : CompetencyLevel.short(holder.level),
                  icon: Icons.stacked_bar_chart_rounded,
                ),
                DetailItem(
                  label: 'Last confirmed',
                  value: progress.lastConfirmedOn == null ? 'Not yet' : dayMonthYear(progress.lastConfirmedOn!),
                  icon: Icons.event_available_outlined,
                ),
                DetailItem(label: 'Total hours', value: hoursLabel(progress.totalHours), icon: Icons.schedule_rounded),
                DetailItem(
                  label: 'Next level needs',
                  value: next == null ? (holder == null ? '—' : 'Top level') : hoursLabel(next),
                  icon: Icons.flag_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _HistoryLegend(policy: false, label: 'Hours acquired'),
                _HistoryLegend(policy: true, label: 'Policy for the step'),
              ],
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              Text('No history recorded yet.', style: HomeText.body(13.5, color: HomeColors.muted))
            else
              for (var i = 0; i < history.length; i++)
                _HistoryEntry(
                  record: history[i],
                  policyHours: history[i].source == LevelChangeSource.approval
                      ? policy.hoursBetween(competency.category, history[i].fromLevel, history[i].toLevel)
                      : null,
                  maxHours: maxHours,
                  last: i == history.length - 1,
                ),
          ],
        );
      },
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({
    required this.record,
    required this.policyHours,
    required this.maxHours,
    required this.last,
  });

  final LevelConfirmation record;

  /// Policy for this jump (approvals only).
  final int? policyHours;
  final int maxHours;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final policy = policyHours;
    final below = policy != null && r.hours < policy;
    final dotColor = switch (r.source) {
      LevelChangeSource.approval => HomeColors.blue,
      LevelChangeSource.selfAssessed => HomeColors.chipBorder,
      _ => HomeColors.ink,
    };
    // A Stack (not IntrinsicHeight + Row): the rail is positioned against the
    // entry's own height, so no intrinsic text measuring is needed.
    return Stack(
      children: [
        if (!last)
          Positioned(
            left: 5,
            top: 20,
            bottom: 0,
            child: Container(width: 2, color: HomeColors.cardBorder),
          ),
        Positioned(
          left: 0,
          top: 4,
          child: Container(width: 12, height: 12, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(r.stepLabel, style: HomeText.body(14.5, weight: FontWeight.w800, color: HomeColors.ink)),
                  StatusPill(
                    label: r.source.label,
                    background: r.confirms ? HomeColors.blueTint : HomeColors.neutralTint,
                    foreground: r.confirms ? HomeColors.blueDeep : HomeColors.body,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${dayMonthYear(r.confirmedOn)} · ${r.confirms ? 'confirmed by ${r.confirmedBy}' : 'not confirmed'}'
                '${r.requestId == null ? '' : ' · ${r.requestId}'}',
                style: HomeText.body(12.5, color: HomeColors.muted),
              ),
              if (r.source == LevelChangeSource.approval || r.hours > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: '${hoursLabel(r.hours)} acquired'
                            '${policy == null ? '' : ' · policy ${hoursLabel(policy)}'}',
                        child: _HoursBar(hours: r.hours, policy: policy, max: maxHours),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 150,
                      child: Text(
                        policy == null ? hoursLabel(r.hours) : '${hoursLabel(r.hours)} of ${hoursLabel(policy)}',
                        style: HomeText.body(12.5,
                            weight: FontWeight.w700, color: below ? HomeColors.orangeText : HomeColors.ink),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Blue bar = hours acquired, ink tick = policy for the step.
class _HoursBar extends StatelessWidget {
  const _HoursBar({required this.hours, required this.policy, required this.max});

  final int hours;
  final int? policy;
  final int max;

  @override
  Widget build(BuildContext context) {
    final reveal = ScrollReveal.of(context);
    return SizedBox(
      height: 18,
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) => CustomPaint(
          painter: _HoursPainter(
            hours: hours / max,
            policy: policy == null ? null : policy! / max,
            progress: reveal.value,
          ),
        ),
      ),
    );
  }
}

class _HoursPainter extends CustomPainter {
  _HoursPainter({required this.hours, required this.policy, required this.progress});

  final double hours;
  final double? policy;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4) return;
    const barHeight = 10.0;
    final top = (size.height - barHeight) / 2;
    const radius = Radius.circular(4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, top, size.width, barHeight), radius),
      Paint()..color = HomeColors.gapTrack,
    );
    final w = (hours * size.width * progress).clamp(0.0, size.width).toDouble();
    if (w > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, top, w, barHeight), radius),
        Paint()..color = HomeColors.blue,
      );
    }
    final p = policy;
    if (p != null) {
      final x = (p * size.width).clamp(1.5, size.width - 1.5).toDouble();
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.5, 0, 3, size.height), const Radius.circular(2)),
        Paint()..color = HomeColors.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_HoursPainter oldDelegate) =>
      oldDelegate.hours != hours || oldDelegate.policy != policy || oldDelegate.progress != progress;
}

class _HistoryLegend extends StatelessWidget {
  const _HistoryLegend({required this.policy, required this.label});

  final bool policy;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        policy
            ? Container(
                width: 3,
                height: 16,
                decoration: const BoxDecoration(
                  color: HomeColors.ink,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              )
            : Container(
                width: 18,
                height: 10,
                decoration: const BoxDecoration(
                  color: HomeColors.blue,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
        const SizedBox(width: 8),
        Text(label, style: HomeText.body(13)),
      ],
    );
  }
}
