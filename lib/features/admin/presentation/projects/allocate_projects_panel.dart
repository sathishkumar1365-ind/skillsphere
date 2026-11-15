// Project allocation for Team Leads (own department) and HRD (everyone).
//
// * showAllocateProjects – one employee, from their profile: tick the open
//   projects they work on. Each project shows how well they fit it (what it
//   needs from their role vs their levels) and the gaps it would add.
// * showBulkAllocate – several employees at once, from the team directory:
//   allocate them to (or release them from) one project, with a per-person
//   preview before confirming.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/employees.dart';
import '../../data/insights.dart';
import '../../data/job_roles.dart';
import '../../data/org_structure.dart';
import '../../data/projects.dart';
import '../widgets/admin_common.dart';
import 'projects_view.dart' show ProjectStatusPill;

// ======================================================== one employee

/// Opens "Allocate projects" for [employee]. Returns true when saved.
Future<bool> showAllocateProjects({
  required BuildContext context,
  required AppUser user,
  required EmployeeProfile employee,
}) async {
  final saved = await showSwingPanel<bool>(
    context: context,
    title: 'Allocate projects',
    subtitle: '${employee.name} · ${employee.id} · ${RoleRepository.instance.nameOf(employee.roleId)} · '
        '${EmployeeRepository.instance.departmentNameOf(employee)}',
    width: 880,
    builder: (panelContext) => _AllocateOne(
      user: user,
      employee: employee,
      onDone: (saved) => Navigator.of(panelContext).pop(saved),
    ),
  );
  return saved ?? false;
}

enum _ProjectFilter {
  all('All open projects'),
  department('Own department'),
  allocated('Allocated');

  const _ProjectFilter(this.label);
  final String label;
}

class _AllocateOne extends StatefulWidget {
  const _AllocateOne({required this.user, required this.employee, required this.onDone});

  final AppUser user;
  final EmployeeProfile employee;
  final ValueChanged<bool> onDone;

  @override
  State<_AllocateOne> createState() => _AllocateOneState();
}

class _AllocateOneState extends State<_AllocateOne> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _note = TextEditingController();
  late final Set<String> _original = {
    for (final p in ProjectRepository.instance.forEmployee(widget.employee.id)) p.id,
  };
  late Set<String> _selected = {..._original};
  _ProjectFilter _filter = _ProjectFilter.all;
  String _query = '';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    _note.dispose();
    super.dispose();
  }

  Set<String> get _added => _selected.difference(_original);

  Set<String> get _released => _original.difference(_selected);

  void _toggle(String projectId) {
    setState(() {
      final next = {..._selected};
      if (!next.remove(projectId)) next.add(projectId);
      _selected = next;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_added.isEmpty && _released.isEmpty) {
      widget.onDone(false);
      return;
    }
    if (_note.text.trim().length > ProjectRules.allocationNoteMax) {
      setState(() => _error = 'Keep the note under ${ProjectRules.allocationNoteMax} characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await apiPause(400);
      ProjectRepository.instance.setEmployeeProjects(
        by: widget.user,
        employeeId: widget.employee.id,
        projectIds: _selected,
        note: _note.text,
      );
      if (mounted) widget.onDone(true);
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final repo = ProjectRepository.instance;
    final allowed = repo.canAllocate(widget.user, employee);
    final query = _query.trim().toLowerCase();
    final departmentId = employee.departmentId;
    final projects = repo.openProjects.where((p) {
      final ok = switch (_filter) {
        _ProjectFilter.all => true,
        _ProjectFilter.department => p.departmentId == departmentId,
        _ProjectFilter.allocated => _selected.contains(p.id),
      };
      return ok && (query.isEmpty || p.searchText.contains(query));
    }).toList()
      // Allocated first, then own department, then by name.
      ..sort((a, b) {
        final bySelected = (_selected.contains(b.id) ? 1 : 0) - (_selected.contains(a.id) ? 1 : 0);
        if (bySelected != 0) return bySelected;
        final byDepartment = (b.departmentId == departmentId ? 1 : 0) - (a.departmentId == departmentId ? 1 : 0);
        if (byDepartment != 0) return byDepartment;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final addedGaps = _added.fold<int>(0, (sum, id) {
      final p = repo.byId(id);
      return p == null ? sum : sum + Insights.fit(employee, p).gapCount;
    });
    final narrow = MediaQuery.sizeOf(context).width < 640;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!allowed)
          InfoNote(
            tone: NoteTone.warning,
            text: employee.isActive
                ? 'You can only allocate projects to people in your own department (not yourself).'
                : '${employee.firstName} is inactive, so projects can\'t be allocated.',
          )
        else ...[
          if (employee.roleId == null) ...[
            const InfoNote(
              tone: NoteTone.warning,
              text: 'Role not set: projects that list needs per role can\'t be matched until HRD sets it. '
                  'Needs for everyone on a project are still shown.',
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: narrow ? double.infinity : 300,
                child: AdminSearchField(
                  controller: _search,
                  hint: 'Search code, name, customer…',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              ChoicePills<_ProjectFilter>(
                options: _ProjectFilter.values,
                selected: _filter,
                labelOf: (f) => switch (f) {
                  _ProjectFilter.department =>
                    '${EmployeeRepository.instance.departmentNameOf(employee)} projects',
                  _ProjectFilter.allocated => 'Allocated (${_selected.length})',
                  _ => f.label,
                },
                onSelected: (f) => setState(() => _filter = f),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (projects.isEmpty)
            EmptyState(
              title: _filter == _ProjectFilter.allocated ? 'No projects allocated' : 'No open projects match',
              message: 'Completed projects can\'t take new people.',
              icon: Icons.work_off_outlined,
            )
          else
            for (final p in projects)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ProjectChoiceTile(
                  project: p,
                  fit: Insights.fit(employee, p),
                  selected: _selected.contains(p.id),
                  wasSelected: _original.contains(p.id),
                  ownDepartment: p.departmentId == departmentId,
                  onTap: _saving ? null : () => _toggle(p.id),
                ),
              ),
          const SizedBox(height: 8),
          OrgPanel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(
                      label: '${_selected.length} ${_selected.length == 1 ? 'project' : 'projects'} after saving',
                      icon: Icons.work_outline_rounded,
                      background: HomeColors.blueTint,
                      foreground: HomeColors.blueDeep,
                    ),
                    if (_added.isNotEmpty)
                      StatusPill(
                        label: '+${_added.length} allocated',
                        icon: Icons.add_rounded,
                        background: OrgColors.goodTint,
                        foreground: OrgColors.good,
                      ),
                    if (_released.isNotEmpty)
                      StatusPill(
                        label: '−${_released.length} released',
                        icon: Icons.remove_rounded,
                        background: HomeColors.neutralTint,
                        foreground: HomeColors.body,
                      ),
                    if (addedGaps > 0)
                      StatusPill(
                        label: '$addedGaps new ${addedGaps == 1 ? 'gap' : 'gaps'} to close',
                        icon: Icons.north_east_rounded,
                        background: HomeColors.orangeTint,
                        foreground: HomeColors.orangeText,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const FieldLabel('Note', optional: true),
                TextField(
                  controller: _note,
                  maxLength: ProjectRules.allocationNoteMax,
                  minLines: 1,
                  maxLines: 3,
                  style: adminInputStyle,
                  decoration: adminDecoration(hint: 'e.g. Joins the sprint team from 1 Dec', counter: true),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  InfoNote(tone: NoteTone.error, text: _error!),
                ],
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    PillButton(
                      label: 'Cancel',
                      variant: PillVariant.outline,
                      height: 48,
                      fontSize: 14,
                      onPressed: _saving ? null : () => widget.onDone(false),
                    ),
                    PillButton(
                      label: _saving
                          ? 'Saving…'
                          : (_added.isEmpty && _released.isEmpty ? 'No changes' : 'Save allocation'),
                      height: 48,
                      fontSize: 14,
                      onPressed: _saving || (_added.isEmpty && _released.isEmpty) ? null : _save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ================================================================ tiles

/// A project the user can tick, with the employee's fit (ring), the team
/// fill and what the project needs from the employee's role.
class ProjectChoiceTile extends StatefulWidget {
  const ProjectChoiceTile({
    super.key,
    required this.project,
    required this.selected,
    required this.onTap,
    this.fit,
    this.wasSelected = false,
    this.ownDepartment = false,
    this.radio = false,
  });

  final ProjectRecord project;
  final ProjectFit? fit;
  final bool selected;

  /// Allocated before this panel opened (to show "Release" when unticked).
  final bool wasSelected;
  final bool ownDepartment;

  /// Single choice (bulk panel) instead of a tick box.
  final bool radio;
  final VoidCallback? onTap;

  @override
  State<ProjectChoiceTile> createState() => _ProjectChoiceTileState();
}

class _ProjectChoiceTileState extends State<ProjectChoiceTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final fit = widget.fit;
    final selected = widget.selected;
    final members = p.memberIds.where((id) => EmployeeRepository.instance.byId(id)?.isActive ?? false).length;
    final planned = p.plannedTeamSize;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final lift = selected ? 1.0 : (_hover ? 0.6 : 0.0);
    final tap = widget.onTap;
    final releasing = widget.wasSelected && !selected;
    final manager = EmployeeRepository.instance.byId(p.managerId);

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _TickBox(selected: selected, radio: widget.radio),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusPill(label: p.code, background: HomeColors.neutralTint, foreground: HomeColors.ink),
                  ProjectStatusPill(status: p.status),
                  if (widget.ownDepartment)
                    const StatusPill(
                      label: 'Own department',
                      icon: Icons.apartment_rounded,
                      background: HomeColors.blueTint,
                      foreground: HomeColors.blueDeep,
                    ),
                  if (releasing)
                    const StatusPill(
                      label: 'Will be released',
                      icon: Icons.remove_circle_outline_rounded,
                      background: HomeColors.orangeTint,
                      foreground: HomeColors.orangeText,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(p.name, style: HomeText.body(16.5, weight: FontWeight.w800, color: HomeColors.ink)),
              const SizedBox(height: 3),
              Text(
                [
                  OrgStructureRepository.instance.departmentName(p.departmentId),
                  if (p.customer.isNotEmpty) p.customer,
                  p.period,
                  if (manager != null) 'PM ${manager.name}',
                ].join(' · '),
                style: HomeText.body(12.5, color: HomeColors.muted, height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: MeterBar(
                      value: planned <= 0 ? (members > 0 ? 1.0 : 0.0) : math.min(1.0, members / planned),
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    planned <= 0 ? '$members in team' : '$members of $planned in team',
                    style: HomeText.body(12, weight: FontWeight.w700, color: HomeColors.ink),
                  ),
                ],
              ),
              if (fit != null) ...[
                const SizedBox(height: 10),
                if (fit.needs.isEmpty)
                  Text('Nothing specific needed from this role.', style: HomeText.body(12.5, color: HomeColors.muted))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final n in fit.needs.take(6)) NeedChip(need: n)],
                  ),
                if (fit.needs.length > 6) ...[
                  const SizedBox(height: 4),
                  Text('+${fit.needs.length - 6} more', style: HomeText.body(12, color: HomeColors.muted)),
                ],
              ],
            ],
          ),
        ),
        if (fit != null) ...[
          const SizedBox(width: 12),
          Column(
            children: [
              FitRing(percent: fit.percent, size: 58),
              const SizedBox(height: 4),
              Text('fit', style: HomeText.body(11, weight: FontWeight.w700, color: HomeColors.muted)),
            ],
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '${p.code} ${p.name}${fit == null ? '' : ', ${fit.percent} percent fit'}',
      child: MouseRegion(
        cursor: tap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: tap,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: lift),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
            curve: HomeMotion.ease,
            child: body,
            builder: (context, t, child) {
              // Identity at rest (no 3D matrix) – see the scroll-lag notes.
              final matrix = t == 0
                  ? Matrix4.identity()
                  : (Matrix4.identity()
                    ..setEntry(3, 2, 0.0011)
                    ..multiply(Matrix4.translationValues(0, -3 * t, 0))
                    ..multiply(Matrix4.rotationX(-0.05 * t)));
              return Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: AnimatedContainer(
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFF2F7FE) : Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    border: Border.all(
                      color: selected ? HomeColors.ink : (releasing ? HomeColors.orangeBand : HomeColors.cardBorder),
                      width: selected ? 1.6 : 1,
                    ),
                    boxShadow: t == 0
                        ? null
                        : [
                            BoxShadow(
                              color: Color.fromRGBO(15, 27, 45, 0.22 * t),
                              blurRadius: 26,
                              spreadRadius: -14,
                              offset: Offset(0, 14 * t),
                            ),
                          ],
                  ),
                  child: child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TickBox extends StatelessWidget {
  const _TickBox({required this.selected, required this.radio});

  final bool selected;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? HomeColors.ink : Colors.white,
        shape: radio ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radio ? null : const BorderRadius.all(Radius.circular(7)),
        border: Border.all(color: selected ? HomeColors.ink : HomeColors.chipBorder, width: 1.5),
      ),
      child: selected
          ? Icon(radio ? Icons.circle : Icons.check_rounded, size: radio ? 10 : 16, color: Colors.white)
          : null,
    );
  }
}

/// "Kubernetes L1" chip: green tick when met, orange "−2" when short.
class NeedChip extends StatelessWidget {
  const NeedChip({super.key, required this.need});

  final FitNeed need;

  @override
  Widget build(BuildContext context) {
    final met = need.met;
    final held = need.heldLevel;
    return Tooltip(
      message: held == null
          ? 'Not acquired yet · needs L${need.requiredLevel}'
          : 'Has L$held · needs L${need.requiredLevel}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: met ? OrgColors.goodTint : HomeColors.orangeTint,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(met ? Icons.check_rounded : Icons.north_east_rounded,
                size: 13, color: met ? OrgColors.good : HomeColors.orangeText),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                met ? '${need.competency.name} L${need.requiredLevel}' : '${need.competency.name} L${need.requiredLevel} · −${need.size}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HomeText.body(12, weight: FontWeight.w700, color: met ? OrgColors.good : HomeColors.orangeText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small fit ring (blue arc on a light track, % in the middle).
class FitRing extends StatelessWidget {
  const FitRing({super.key, required this.percent, this.size = 56});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0, 100);
    return Semantics(
      label: '$value percent fit',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _FitRingPainter(value / 100),
          child: Center(
            child: Text('$value%',
                style: HomeText.body(size * 0.25, weight: FontWeight.w800, color: HomeColors.ink)),
          ),
        ),
      ),
    );
  }
}

class _FitRingPainter extends CustomPainter {
  _FitRingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 1);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = HomeColors.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = HomeColors.blue
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_FitRingPainter oldDelegate) => oldDelegate.fraction != fraction;
}

// =========================================================== bulk action

/// Allocates (or, with [release], releases) several employees to one
/// project. Returns the result, or null when cancelled.
Future<AllocationResult?> showBulkAllocate({
  required BuildContext context,
  required AppUser user,
  required List<EmployeeProfile> employees,
  bool release = false,
}) {
  final count = employees.length;
  return showSwingPanel<AllocationResult>(
    context: context,
    title: release ? 'Release from a project' : 'Allocate to a project',
    subtitle: '$count ${count == 1 ? 'person' : 'people'} selected · '
        '${release ? 'take them off one project' : 'put them on one project'}, check the preview, confirm.',
    width: 940,
    builder: (panelContext) => _BulkAllocate(
      user: user,
      employees: employees,
      release: release,
      onDone: (result) => Navigator.of(panelContext).pop(result),
    ),
  );
}

enum _PersonOutcome {
  change,
  unchanged,
  notAllowed;
}

class _BulkAllocate extends StatefulWidget {
  const _BulkAllocate({
    required this.user,
    required this.employees,
    required this.release,
    required this.onDone,
  });

  final AppUser user;
  final List<EmployeeProfile> employees;
  final bool release;
  final ValueChanged<AllocationResult?> onDone;

  @override
  State<_BulkAllocate> createState() => _BulkAllocateState();
}

class _BulkAllocateState extends State<_BulkAllocate> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _query = '';
  String? _projectId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _release => widget.release;

  _PersonOutcome _outcome(EmployeeProfile e, ProjectRecord p) {
    final repo = ProjectRepository.instance;
    final allowed = _release ? repo.canRelease(widget.user, e) : repo.canAllocate(widget.user, e);
    if (!allowed) return _PersonOutcome.notAllowed;
    return p.memberIds.contains(e.id) == !_release ? _PersonOutcome.unchanged : _PersonOutcome.change;
  }

  Future<void> _confirm(ProjectRecord project) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ProjectRepository.instance;
      final ids = [for (final e in widget.employees) e.id];
      final result = _release
          ? await repo.release(by: widget.user, employeeIds: ids, projectId: project.id, note: _note.text)
          : await repo.allocate(by: widget.user, employeeIds: ids, projectId: project.id, note: _note.text);
      if (mounted) widget.onDone(result);
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProjectRepository.instance.projects,
      builder: (context, _) {
        final repo = ProjectRepository.instance;
        final query = _query.trim().toLowerCase();
        final peopleIds = {for (final e in widget.employees) e.id};
        final departments = {for (final e in widget.employees) e.departmentId};
        final projects = repo.openProjects.where((p) {
          if (query.isNotEmpty && !p.searchText.contains(query)) return false;
          // Releasing: only projects at least one selected person is on.
          return !_release || p.memberIds.any(peopleIds.contains);
        }).toList()
          ..sort((a, b) {
            final byDepartment =
                (departments.contains(b.departmentId) ? 1 : 0) - (departments.contains(a.departmentId) ? 1 : 0);
            return byDepartment != 0 ? byDepartment : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        final project = repo.byId(_projectId);
        final narrow = MediaQuery.sizeOf(context).width < 640;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepPanel(
              number: 1,
              title: 'Choose the project',
              subtitle: _release
                  ? 'Projects at least one of the selected people works on.'
                  : 'Open projects (planned, active, on hold). Own-department projects come first.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: narrow ? double.infinity : 320,
                      child: AdminSearchField(
                        controller: _search,
                        hint: 'Search code, name, customer…',
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (projects.isEmpty)
                    EmptyState(
                      title: _release ? 'Nobody selected is on a project' : 'No open projects match',
                      icon: Icons.work_off_outlined,
                    )
                  else
                    for (final p in projects)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ProjectChoiceTile(
                          project: p,
                          radio: true,
                          selected: p.id == _projectId,
                          ownDepartment: departments.contains(p.departmentId),
                          onTap: _saving
                              ? null
                              : () => setState(() {
                                    _projectId = p.id;
                                    _error = null;
                                  }),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (project == null)
              const InfoNote(text: 'Choose a project to see what changes for each person.')
            else
              TurnIn(
                replayKey: project.id,
                child: _preview(project),
              ),
          ],
        );
      },
    );
  }

  Widget _preview(ProjectRecord project) {
    final people = widget.employees;
    final outcomes = {for (final e in people) e.id: _outcome(e, project)};
    final changing = people.where((e) => outcomes[e.id] == _PersonOutcome.change).toList();
    final activeMembers =
        project.memberIds.where((id) => EmployeeRepository.instance.byId(id)?.isActive ?? false).length;
    final after = _release ? activeMembers - changing.length : activeMembers + changing.length;
    final planned = project.plannedTeamSize;
    final newGaps = _release
        ? 0
        : changing.fold<int>(0, (sum, e) => sum + Insights.fit(e, project).gapCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepPanel(
          number: 2,
          title: 'Check each person',
          subtitle: _release
              ? 'Who comes off ${project.code}. People not on it are left as they are.'
              : 'Fit = what ${project.code} needs from each person\'s role vs the levels they hold. '
                  'Gaps it adds show in their profile and in the reports.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in people)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PersonPreview(
                    employee: e,
                    project: project,
                    outcome: outcomes[e.id] ?? _PersonOutcome.notAllowed,
                    release: _release,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        StepPanel(
          number: 3,
          title: 'Confirm',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    label: '${changing.length} will be ${_release ? 'released' : 'allocated'}',
                    icon: _release ? Icons.remove_rounded : Icons.add_rounded,
                    background: _release ? HomeColors.neutralTint : OrgColors.goodTint,
                    foreground: _release ? HomeColors.body : OrgColors.good,
                  ),
                  StatusPill(
                    label: planned > 0 ? 'Team after: $after of $planned planned' : 'Team after: $after',
                    icon: Icons.groups_2_outlined,
                    background: HomeColors.blueTint,
                    foreground: HomeColors.blueDeep,
                  ),
                  if (newGaps > 0)
                    StatusPill(
                      label: '$newGaps new ${newGaps == 1 ? 'gap' : 'gaps'} to close',
                      icon: Icons.north_east_rounded,
                      background: HomeColors.orangeTint,
                      foreground: HomeColors.orangeText,
                    ),
                ],
              ),
              if (!_release && planned > 0 && after > planned) ...[
                const SizedBox(height: 12),
                InfoNote(
                  tone: NoteTone.warning,
                  text: '${project.code} plans $planned people; after this it has $after. '
                      'You can still go ahead (HRD sees it in the staffing report).',
                ),
              ],
              const SizedBox(height: 16),
              const FieldLabel('Note', optional: true),
              TextField(
                controller: _note,
                maxLength: ProjectRules.allocationNoteMax,
                minLines: 1,
                maxLines: 3,
                style: adminInputStyle,
                decoration: adminDecoration(
                  hint: _release ? 'e.g. Phase 1 delivered' : 'e.g. Sprint team for the Q1 release',
                  counter: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                InfoNote(tone: NoteTone.error, text: _error!),
              ],
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  PillButton(
                    label: 'Cancel',
                    variant: PillVariant.outline,
                    height: 48,
                    fontSize: 14,
                    onPressed: _saving ? null : () => widget.onDone(null),
                  ),
                  PillButton(
                    label: _saving
                        ? 'Saving…'
                        : changing.isEmpty
                            ? 'Nothing to change'
                            : '${_release ? 'Release' : 'Allocate'} ${changing.length} '
                                '${changing.length == 1 ? 'person' : 'people'} · ${project.code}',
                    height: 48,
                    fontSize: 14,
                    onPressed: _saving || changing.isEmpty ? null : () => _confirm(project),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonPreview extends StatelessWidget {
  const _PersonPreview({
    required this.employee,
    required this.project,
    required this.outcome,
    required this.release,
  });

  final EmployeeProfile employee;
  final ProjectRecord project;
  final _PersonOutcome outcome;
  final bool release;

  @override
  Widget build(BuildContext context) {
    final e = employee;
    final fit = Insights.fit(e, project);
    final count = ProjectRepository.instance.projectCountFor(e.id);
    final StatusPill pill = switch (outcome) {
      _PersonOutcome.change => release
          ? const StatusPill(
              label: 'Will be released',
              icon: Icons.remove_circle_outline_rounded,
              background: HomeColors.neutralTint,
              foreground: HomeColors.body,
            )
          : const StatusPill(
              label: 'Will be allocated',
              icon: Icons.add_circle_outline_rounded,
              background: OrgColors.goodTint,
              foreground: OrgColors.good,
            ),
      _PersonOutcome.unchanged => StatusPill(
          label: release ? 'Not on ${project.code}' : 'Already on ${project.code}',
          icon: Icons.remove_rounded,
          background: HomeColors.neutralTint,
          foreground: HomeColors.body,
        ),
      _PersonOutcome.notAllowed => StatusPill(
          label: e.isActive || release ? 'Not in your rights' : 'Inactive',
          icon: Icons.lock_outline_rounded,
          background: HomeColors.orangeTint,
          foreground: HomeColors.orangeText,
        ),
    };
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final person = PersonLine(
      profile: e,
      size: 34,
      detail: '${e.id} · ${RoleRepository.instance.nameOf(e.roleId)} · '
          '$count ${count == 1 ? 'project' : 'projects'} now',
    );
    final needs = release || fit.needs.isEmpty
        ? null
        : Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final n in fit.needs.take(4)) NeedChip(need: n)],
          );

    return Opacity(
      opacity: outcome == _PersonOutcome.change ? 1 : 0.62,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: HomeColors.cardBorder),
        ),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  person,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      pill,
                      if (!release) FitRing(percent: fit.percent, size: 40),
                    ],
                  ),
                  if (needs != null) ...[const SizedBox(height: 8), needs],
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 34, child: person),
                  const SizedBox(width: 12),
                  Expanded(flex: 40, child: needs ?? const SizedBox.shrink()),
                  const SizedBox(width: 12),
                  if (!release) ...[FitRing(percent: fit.percent, size: 44), const SizedBox(width: 12)],
                  SizedBox(width: 170, child: Align(alignment: Alignment.centerRight, child: pill)),
                ],
              ),
      ),
    );
  }
}
