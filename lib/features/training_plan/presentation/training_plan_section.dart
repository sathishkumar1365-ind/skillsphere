import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/app_user.dart';
import '../../admin/data/admin_base.dart';
import '../../admin/data/employees.dart';
import '../../admin/data/insights.dart';
import '../../admin/data/projects.dart';
import '../../admin/presentation/widgets/admin_common.dart';
import '../../competency/data/competency_repository.dart';
import '../../competency/presentation/widgets/competency_common.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../home/presentation/widgets/lift_card.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../data/training_plans.dart';
import 'training_plan_common.dart';
import 'training_plan_form.dart';

/// "Training plan" section (Employee profile and the employee's Home):
/// how the employee plans to close their gaps – training type, course,
/// dates, hours and progress.
///
/// * The employee adds, edits, updates and removes their own plans.
/// * Team Leads (own department) and HRD see them read-only.
class TrainingPlanSection extends StatelessWidget {
  const TrainingPlanSection({super.key, required this.viewer, required this.employeeId});

  final AppUser viewer;
  final String employeeId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Insights.listenable,
      builder: (context, _) {
        final employee = EmployeeRepository.instance.byId(employeeId);
        if (employee == null) {
          return const EmptyState(title: 'Profile not found', icon: Icons.person_off_outlined);
        }
        return _Body(viewer: viewer, employee: employee);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.viewer, required this.employee});

  final AppUser viewer;
  final EmployeeProfile employee;

  bool get _own => viewer.id == employee.id;

  Future<void> _add(BuildContext context, {GapEntry? gap}) async {
    final saved = await showTrainingPlanForm(context: context, user: viewer, employee: employee, gap: gap);
    if (saved != null && context.mounted) {
      showAdminMessage(context, 'Added to your training plan: ${saved.title}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = TrainingPlanRepository.instance;
    final plans = repo.forEmployee(employee.id);
    final open = plans.where((p) => p.status.isOpen).toList();
    final inProgress = plans.where((p) => p.status == PlanStatus.inProgress).length;
    final hoursPlanned = open.fold<int>(0, (s, p) => s + p.plannedHours);
    final hoursDone = plans.fold<int>(0, (s, p) => s + p.completedHours);
    final insight = Insights.of(employee);
    final gapRows = insight.rows.where((r) => r.state.isGap).toList();
    // A gap with any plan (open, or completed and waiting for the level-up)
    // counts as planned.
    final unplanned = gapRows.where((r) => !plans.any((p) => p.competencyId == r.competency.id)).toList();
    final width = MediaQuery.sizeOf(context).width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: _own ? 'MY TRAINING PLAN' : 'TRAINING PLAN',
          subtitle: _own
              ? 'Plan how you\'ll close your gaps: the kind of training, the course, dates and hours. '
                  'Your Team Lead and HR see this plan.'
              : 'How ${employee.firstName} plans to close their gaps. Only ${employee.firstName} can change it.',
          trailing: _own ? PillButton(label: 'Add a plan', onPressed: () => _add(context)) : null,
        ),
        const SizedBox(height: 24),
        EqualHeightGrid(
          columns: width >= 900 ? 4 : 2,
          spacing: 14,
          runSpacing: 14,
          children: [
            KpiCard(value: open.length, label: 'Open plans', caption: '${plans.length - open.length} completed'),
            KpiCard(value: inProgress, label: 'In progress'),
            KpiCard(value: hoursPlanned, suffix: ' h', label: 'Hours planned', caption: 'Open plans'),
            KpiCard(value: hoursDone, suffix: ' h', label: 'Hours done', dark: true),
          ],
        ),
        const SizedBox(height: 18),
        if (gapRows.isNotEmpty)
          _UnplannedPanel(rows: unplanned, own: _own, onPlan: (row) => _add(context, gap: _gapFor(insight, row))),
        if (gapRows.isNotEmpty) const SizedBox(height: 18),
        if (plans.isEmpty)
          EmptyState(
            title: 'No training planned yet',
            message: _own
                ? 'Add a plan for each gap: an online course, a workshop, mentoring or on-the-job practice.'
                : '${employee.firstName} hasn\'t planned any training yet.',
            icon: Icons.school_outlined,
          )
        else
          _PlanGrid(plans: plans, viewer: viewer, employee: employee),
      ],
    );
  }

  /// The biggest gap entry of [row] (the project needing the most).
  static GapEntry? _gapFor(EmployeeInsight insight, CompetencyRow row) {
    for (final e in insight.gapEntries) {
      if (e.competency.id == row.competency.id) return e;
    }
    return null;
  }
}

/// Gaps that have no open plan yet.
class _UnplannedPanel extends StatelessWidget {
  const _UnplannedPanel({required this.rows, required this.own, required this.onPlan});

  final List<CompetencyRow> rows;
  final bool own;
  final ValueChanged<CompetencyRow> onPlan;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const InfoNote(tone: NoteTone.success, text: 'Every project gap has a training plan.');
    }
    return OrgPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitle(
            'Gaps without a plan',
            subtitle: own ? 'Pick one to plan the training for it.' : 'No training planned for these yet.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in rows)
                own
                    ? ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 16, color: HomeColors.orangeText),
                        label: Text('${r.competency.name} · −${r.gapSize} (needs L${r.requiredLevel})'),
                        labelStyle: HomeText.body(12.5, weight: FontWeight.w700, color: HomeColors.orangeText),
                        backgroundColor: HomeColors.orangeTint,
                        side: const BorderSide(color: HomeColors.orangeBand),
                        shape: const StadiumBorder(),
                        onPressed: () => onPlan(r),
                      )
                    : Chip(
                        avatar: const Icon(Icons.south_rounded, size: 16, color: HomeColors.orangeText),
                        label: Text('${r.competency.name} · −${r.gapSize} (needs L${r.requiredLevel})'),
                        labelStyle: HomeText.body(12.5, weight: FontWeight.w700, color: HomeColors.orangeText),
                        backgroundColor: HomeColors.orangeTint,
                        side: const BorderSide(color: HomeColors.orangeBand),
                        shape: const StadiumBorder(),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Two columns of plan cards on wide screens (no equal-height rows, so
/// cards of different lengths don't leave holes).
class _PlanGrid extends StatelessWidget {
  const _PlanGrid({required this.plans, required this.viewer, required this.employee});

  final List<TrainingPlan> plans;
  final AppUser viewer;
  final EmployeeProfile employee;

  @override
  Widget build(BuildContext context) {
    Widget card(int i) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: TurnIn(
            key: ValueKey<String>('plan-${plans[i].id}'),
            delay: Duration(milliseconds: (i < 6 ? i : 6) * 70),
            child: _PlanCard(plan: plans[i], viewer: viewer, employee: employee),
          ),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (var i = 0; i < plans.length; i++) card(i)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (var i = 0; i < plans.length; i += 2) card(i)],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (var i = 1; i < plans.length; i += 2) card(i)],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _Action { edit, start, hold, complete, remove }

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.viewer, required this.employee});

  final TrainingPlan plan;
  final AppUser viewer;
  final EmployeeProfile employee;

  Future<void> _act(BuildContext context, _Action action) async {
    final repo = TrainingPlanRepository.instance;
    try {
      switch (action) {
        case _Action.edit:
          final saved = await showTrainingPlanForm(context: context, user: viewer, employee: employee, plan: plan);
          if (saved != null && context.mounted) showAdminMessage(context, 'Plan saved.');
        case _Action.start:
          await repo.setStatus(by: viewer, planId: plan.id, status: PlanStatus.inProgress);
        case _Action.hold:
          await repo.setStatus(by: viewer, planId: plan.id, status: PlanStatus.onHold);
        case _Action.complete:
          await repo.setStatus(by: viewer, planId: plan.id, status: PlanStatus.completed);
          if (context.mounted) {
            showAdminMessage(context, 'Completed. Your Team Lead can now raise the level-up with your hours.');
          }
        case _Action.remove:
          final removed = plan;
          await repo.remove(by: viewer, planId: plan.id);
          if (context.mounted) {
            showAdminMessage(
              context,
              'Plan removed.',
              action: SnackBarAction(label: 'Undo', onPressed: () => repo.restore(by: viewer, plan: removed)),
            );
          }
      }
    } on TrainingPlanException catch (e) {
      if (context.mounted) showAdminMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final competency = CompetencyRepository.instance.byId(plan.competencyId);
    final held = CompetencyRepository.instance.holderOf(plan.competencyId, plan.employeeId)?.level;
    final reached = held != null && held >= plan.targetLevel;
    final overdue = plan.isOverdue();
    final canEdit = TrainingPlanRepository.instance.canEdit(viewer, plan.employeeId);
    final projects = [
      for (final id in plan.projectIds)
        if (ProjectRepository.instance.byId(id) case final ProjectRecord p) p,
    ];
    final link = plan.link;
    return LiftCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 10, 20),
      liftBy: 5,
      tiltDegrees: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeTile(type: plan.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.type.label.toUpperCase(),
                        style: HomeText.body(10.5, weight: FontWeight.w800, color: HomeColors.blue, letterSpacing: 1)),
                    const SizedBox(height: 3),
                    Text(plan.title, style: HomeText.body(16.5, weight: FontWeight.w800, color: HomeColors.ink, height: 1.3)),
                    if (plan.provider.isNotEmpty)
                      Text(plan.provider, style: HomeText.body(13, color: HomeColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PlanStatusPill(status: plan.status),
              if (canEdit)
                PopupMenuButton<_Action>(
                  tooltip: 'Plan actions',
                  color: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                  onSelected: (a) => _act(context, a),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: _Action.edit, child: Text('Edit / log hours…')),
                    if (plan.status == PlanStatus.planned || plan.status == PlanStatus.onHold)
                      const PopupMenuItem(value: _Action.start, child: Text('Start')),
                    if (plan.status == PlanStatus.planned || plan.status == PlanStatus.inProgress)
                      const PopupMenuItem(value: _Action.hold, child: Text('Put on hold')),
                    if (plan.status.isOpen) const PopupMenuItem(value: _Action.complete, child: Text('Mark completed')),
                    const PopupMenuItem(value: _Action.remove, child: Text('Remove')),
                  ],
                  icon: const Icon(Icons.more_vert_rounded),
                )
              else
                const SizedBox(width: 10),
            ],
          ),
          const SizedBox(height: 14),
          if (competency != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CompetencyBadge.of(competency, size: 26),
                      const SizedBox(width: 8),
                      Text(competency.name, style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink)),
                    ],
                  ),
                  StatusPill(
                    label: '${plan.currentLevel == null ? 'New' : 'L${plan.currentLevel}'} → L${plan.targetLevel}',
                    icon: Icons.trending_up_rounded,
                    background: HomeColors.blueTint,
                    foreground: HomeColors.blueDeep,
                  ),
                  if (reached)
                    const StatusPill(
                      label: 'Target level reached',
                      icon: Icons.verified_rounded,
                      background: OrgColors.goodTint,
                      foreground: OrgColors.good,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 16, color: HomeColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${dayMonthYear(plan.startDate)} → ${dayMonthYear(plan.targetDate)}',
                          style: HomeText.body(13, weight: FontWeight.w600, color: HomeColors.body)),
                    ),
                    if (overdue)
                      const StatusPill(
                        label: 'Overdue',
                        icon: Icons.warning_amber_rounded,
                        background: HomeColors.orangeTint,
                        foreground: HomeColors.orangeText,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Tooltip(
                  message: '${plan.completedHours} of ${plan.plannedHours} hours done',
                  child: Row(
                    children: [
                      Expanded(child: MeterBar(value: plan.progress)),
                      const SizedBox(width: 10),
                      Text('${plan.completedHours} / ${plan.plannedHours} h',
                          style: HomeText.body(13, weight: FontWeight.w800, color: HomeColors.ink)),
                    ],
                  ),
                ),
                if (projects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Closes gaps for', style: HomeText.body(12, color: HomeColors.muted)),
                      for (final p in projects)
                        Tooltip(
                          message: p.name,
                          child: StatusPill(label: p.code, background: HomeColors.neutralTint, foreground: HomeColors.ink),
                        ),
                    ],
                  ),
                ],
                if (plan.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(plan.notes, style: HomeText.body(13.5, height: 1.5)),
                ],
                if (link.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse(link), webOnlyWindowName: '_blank'),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open course page'),
                      style: TextButton.styleFrom(
                        foregroundColor: HomeColors.blue,
                        padding: EdgeInsets.zero,
                        textStyle: HomeText.body(13, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text('Updated ${relativeDays(plan.updatedAt)}',
                    style: HomeText.body(11.5, color: HomeColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Raised tile with the training type's icon.
class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.type});

  final TrainingType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C7BE8), HomeColors.ink],
        ),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(15, 27, 45, 0.32), blurRadius: 14, spreadRadius: -6, offset: Offset(0, 7)),
        ],
      ),
      child: Icon(trainingTypeIcon(type), color: Colors.white, size: 22),
    );
  }
}
