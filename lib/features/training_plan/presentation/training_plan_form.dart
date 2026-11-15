import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../admin/data/admin_base.dart';
import '../../admin/data/employees.dart';
import '../../admin/data/insights.dart';
import '../../admin/presentation/widgets/admin_common.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/data/competency_repository.dart';
import '../../competency/data/level_hours_policy.dart';
import '../../competency/presentation/widgets/competency_common.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../data/training_plans.dart';
import 'training_plan_common.dart';

/// Opens the plan form in a 3D swing panel: a new plan (optionally for a
/// [gap]) or [plan] to edit. Returns the saved plan.
Future<TrainingPlan?> showTrainingPlanForm({
  required BuildContext context,
  required AppUser user,
  required EmployeeProfile employee,
  TrainingPlan? plan,
  GapEntry? gap,
}) {
  return showSwingPanel<TrainingPlan>(
    context: context,
    title: plan == null ? 'Plan training' : 'Edit training plan',
    subtitle: plan == null
        ? 'How you will close the gap: the training, dates and hours.'
        : '${plan.title} · ${plan.id}',
    width: 820,
    builder: (panelContext) => TrainingPlanForm(
      user: user,
      employee: employee,
      plan: plan,
      gap: gap,
      onSaved: (p) => Navigator.of(panelContext).pop(p),
      onCancel: () => Navigator.of(panelContext).pop(),
    ),
  );
}

class TrainingPlanForm extends StatefulWidget {
  const TrainingPlanForm({
    super.key,
    required this.user,
    required this.employee,
    required this.onSaved,
    required this.onCancel,
    this.plan,
    this.gap,
  });

  final AppUser user;
  final EmployeeProfile employee;
  final TrainingPlan? plan;
  final GapEntry? gap;
  final ValueChanged<TrainingPlan> onSaved;
  final VoidCallback onCancel;

  @override
  State<TrainingPlanForm> createState() => _TrainingPlanFormState();
}

class _TrainingPlanFormState extends State<TrainingPlanForm> {
  final _title = TextEditingController();
  final _provider = TextEditingController();
  final _planned = TextEditingController();
  final _done = TextEditingController(text: '0');
  final _link = TextEditingController();
  final _notes = TextEditingController();

  String? _competencyId;
  int? _target;
  TrainingType? _type;
  PlanStatus _status = PlanStatus.planned;
  DateTime? _start;
  DateTime? _end;
  Set<String> _projectIds = {};
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    if (plan != null) {
      _competencyId = plan.competencyId;
      _target = plan.targetLevel;
      _type = plan.type;
      _status = plan.status;
      _start = plan.startDate;
      _end = plan.targetDate;
      _projectIds = {...plan.projectIds};
      _title.text = plan.title;
      _provider.text = plan.provider;
      _planned.text = '${plan.plannedHours}';
      _done.text = '${plan.completedHours}';
      _link.text = plan.link;
      _notes.text = plan.notes;
      return;
    }
    final today = dateOnly(DateTime.now());
    _start = today;
    _end = DateTime(today.year, today.month + 2, today.day);
    final gap = widget.gap;
    if (gap != null) _choose(gap.competency.id, preferredTarget: gap.requiredLevel);
  }

  @override
  void dispose() {
    for (final c in [_title, _provider, _planned, _done, _link, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  EmployeeInsight get _insight => Insights.of(widget.employee);

  int? _currentOf(String competencyId) =>
      CompetencyRepository.instance.holderOf(competencyId, widget.employee.id)?.level;

  /// Picks a competency: target = what its projects need (or the next
  /// level), projects = those that report the gap.
  void _choose(String competencyId, {int? preferredTarget}) {
    _competencyId = competencyId;
    final row = _insight.rows.where((r) => r.competency.id == competencyId).firstOrNull;
    final current = _currentOf(competencyId);
    final need = preferredTarget ?? row?.requiredLevel;
    final next = (current ?? -1) + 1;
    _target = need != null && need > (current ?? -1) ? need : (next <= CompetencyLevel.max ? next : null);
    _projectIds = {
      for (final s in row?.sources ?? const <RequirementSource>[])
        if (current == null || s.level > current) s.project.id,
    };
  }

  TrainingPlanDraft get _draft => TrainingPlanDraft(
        competencyId: _competencyId,
        targetLevel: _target,
        type: _type,
        title: _title.text,
        provider: _provider.text,
        startDate: _start,
        targetDate: _end,
        plannedHours: int.tryParse(_planned.text.trim()),
        completedHours: int.tryParse(_done.text.trim().isEmpty ? '0' : _done.text.trim()) ?? -1,
        status: _status,
        link: _link.text,
        notes: _notes.text,
        projectIds: _projectIds.toList(),
      );

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final problem = TrainingPlanRepository.instance.problemWith(_draft, employeeId: widget.employee.id);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = TrainingPlanRepository.instance;
      final plan = widget.plan;
      final saved = plan == null
          ? await repo.add(by: widget.user, draft: _draft)
          : await repo.update(by: widget.user, planId: plan.id, draft: _draft);
      if (mounted) widget.onSaved(saved);
    } on TrainingPlanException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final competencies = CompetencyRepository.instance;
    final insight = _insight;
    final gapIds = [for (final r in insight.rows) if (r.state.isGap) r.competency.id];
    final others = [...competencies.competencies.value.where((c) => !gapIds.contains(c.id))]
      ..sort((a, b) => a.name.compareTo(b.name));
    final items = [...gapIds, for (final c in others) c.id];
    final id = _competencyId;
    final competency = id == null ? null : competencies.byId(id);
    final current = id == null ? null : _currentOf(id);
    final row = id == null ? null : insight.rows.where((r) => r.competency.id == id).firstOrNull;
    final type = _type;
    final target = _target;

    String labelOf(String cid) {
      final c = competencies.byId(cid);
      if (c == null) return cid;
      final r = insight.rows.where((x) => x.competency.id == cid).firstOrNull;
      if (r != null && r.state.isGap) return '${c.name} · gap −${r.gapSize} (needs L${r.requiredLevel})';
      final held = _currentOf(cid);
      return held == null ? c.name : '${c.name} · now L$held';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepPanel(
          number: 1,
          title: 'What to close',
          subtitle: 'Gaps reported by your projects come first; you can also plan for any library competency.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Competency',
                required: true,
                child: AdminDropdown<String>(
                  value: id,
                  items: items,
                  labelOf: labelOf,
                  hint: 'Choose a competency',
                  onChanged: (cid) => setState(() => _choose(cid)),
                ),
              ),
              if (competency != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CategoryPill(competency.category),
                    StatusPill(
                      label: current == null ? 'Not acquired yet' : 'Now ${CompetencyLevel.short(current)}',
                      background: HomeColors.neutralTint,
                      foreground: HomeColors.ink,
                    ),
                    if (row?.requiredLevel case final int need)
                      StatusPill(
                        label: 'Projects need L$need',
                        icon: Icons.flag_outlined,
                        background: HomeColors.blueTint,
                        foreground: HomeColors.blueDeep,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Target level',
                  required: true,
                  child: current != null && current >= CompetencyLevel.max
                      ? const InfoNote(text: 'Already at the highest level (L5 · Expert).')
                      : LevelPicker(
                          level: target,
                          minLevel: (current ?? -1) + 1,
                          onChanged: (l) => setState(() => _target = l),
                        ),
                ),
                if (target != null) ...[
                  const SizedBox(height: 8),
                  Text(competency.levelDescription(target),
                      style: HomeText.body(13, color: HomeColors.muted, height: 1.45)),
                  const SizedBox(height: 10),
                  InfoNote(
                    icon: Icons.schedule_rounded,
                    text: 'Hours policy for ${current == null ? 'New' : 'L$current'} → L$target '
                        '(${competency.category.label}): '
                        '${hoursLabel(LevelHoursPolicy.instance.hoursBetween(competency.category, current, target))}. '
                        'Your Team Lead enters the hours you acquired when raising the level-up.',
                  ),
                ],
                if (row != null && row.sources.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const FieldLabel('Closes the gap for', optional: true),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in row.sources)
                        OrgFilterPill(
                          label: '${_projectIds.contains(s.project.id) ? '✓ ' : ''}${s.project.code} · needs L${s.level}',
                          selected: _projectIds.contains(s.project.id),
                          onTap: () => setState(() {
                            final next = {..._projectIds};
                            if (!next.remove(s.project.id)) next.add(s.project.id);
                            _projectIds = next;
                          }),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        StepPanel(
          number: 2,
          title: 'How',
          subtitle: 'The kind of training and the course, programme or activity.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Training type', required: true),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in TrainingType.values)
                    TrainingTypeChip(type: t, selected: t == type, onTap: () => setState(() => _type = t)),
                ],
              ),
              const SizedBox(height: 18),
              FieldGrid(
                children: [
                  LabeledField(
                    label: 'Course / activity',
                    required: true,
                    child: TextField(
                      controller: _title,
                      style: adminInputStyle,
                      maxLength: TrainingPlanRules.titleMax,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: adminDecoration(hint: type?.example ?? 'What you will do'),
                    ),
                  ),
                  LabeledField(
                    label: 'Provider / mentor',
                    optional: true,
                    child: TextField(
                      controller: _provider,
                      style: adminInputStyle,
                      maxLength: TrainingPlanRules.providerMax,
                      decoration: adminDecoration(hint: 'e.g. Udemy, Vector Academy, DevOps team'),
                    ),
                  ),
                  LabeledField(
                    label: 'Link',
                    optional: true,
                    child: TextField(
                      controller: _link,
                      style: adminInputStyle,
                      keyboardType: TextInputType.url,
                      decoration: adminDecoration(hint: 'https://… course page or material'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StepPanel(
          number: 3,
          title: 'When and how much',
          subtitle: 'Dates, hours and where you are now. Update the hours as you go.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldGrid(
                children: [
                  LabeledField(
                    label: 'Start',
                    required: true,
                    child: DateField(value: _start, onChanged: (d) => setState(() => _start = d)),
                  ),
                  LabeledField(
                    label: 'Target date',
                    required: true,
                    child: DateField(
                      value: _end,
                      firstDate: _start,
                      onChanged: (d) => setState(() => _end = d),
                    ),
                  ),
                  LabeledField(
                    label: 'Planned hours',
                    required: true,
                    child: TextField(
                      controller: _planned,
                      style: adminInputStyle,
                      keyboardType: TextInputType.number,
                      decoration: adminDecoration(hint: 'e.g. 40').copyWith(suffixText: 'h'),
                    ),
                  ),
                  LabeledField(
                    label: 'Hours done',
                    optional: true,
                    child: TextField(
                      controller: _done,
                      style: adminInputStyle,
                      keyboardType: TextInputType.number,
                      decoration: adminDecoration(hint: '0').copyWith(suffixText: 'h'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const FieldLabel('Status'),
              ChoicePills<PlanStatus>(
                options: PlanStatus.values,
                selected: _status,
                labelOf: (s) => s.label,
                onSelected: (s) => setState(() => _status = s),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Notes',
                optional: true,
                child: TextField(
                  controller: _notes,
                  style: adminInputStyle,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: TrainingPlanRules.notesMax,
                  decoration: adminDecoration(
                    hint: 'e.g. Two evenings a week; the Airflow module matters most for ANP-27.',
                    counter: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          InfoNote(tone: NoteTone.error, text: _error!),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PillButton(
              label: _saving ? 'Saving…' : (_isEdit ? 'Save changes' : 'Add to my plan'),
              onPressed: _saving ? null : _save,
            ),
            PillButton(
              label: 'Cancel',
              variant: PillVariant.outline,
              onPressed: _saving ? null : widget.onCancel,
            ),
          ],
        ),
      ],
    );
  }
}
