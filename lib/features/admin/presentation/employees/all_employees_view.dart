import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../../core/sphere_page_route.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/drifting_clouds.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../home/presentation/widgets/smooth_wheel_scroll.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/employees.dart';
import '../../data/insights.dart';
import '../../data/job_roles.dart';
import '../../data/org_structure.dart';
import '../../data/projects.dart';
import '../../../reports/presentation/reports_view.dart';
import '../projects/allocate_projects_panel.dart';
import '../widgets/admin_common.dart';
import '../widgets/console_top_bar.dart';
import 'employee_profile_page.dart';

enum _StatusFilter {
  active('Active'),
  inactive('Inactive'),
  incomplete('Incomplete profiles'),
  unallocated('Not on a project'),
  all('All');

  const _StatusFilter(this.label);
  final String label;
}

enum _Sort {
  name('Name (A–Z)'),
  id('Employee ID'),
  readinessHigh('Readiness: high to low'),
  readinessLow('Readiness: low to high'),
  gaps('Most skill gaps'),
  projects('Most projects'),
  newest('Recently onboarded');

  const _Sort(this.label);
  final String label;
}

/// One employee with their calculated gaps and readiness.
class _Row {
  _Row(this.profile, this.insight);

  final EmployeeProfile profile;
  final EmployeeInsight insight;

  /// Open projects (not completed) the employee is allocated to.
  int get projectCount => insight.projects.length;
}

/// All Employees: search, filter (division, group, department, role,
/// status, not on a project) and sort; select one to open their profile.
///
/// HRD sees everyone. A Team Lead sees only their own department
/// ([scopedToDepartment] = true; the server must enforce this too).
///
/// Bulk project allocation: "Select people" turns on tick boxes; the bar
/// above the list then allocates the selected people to a project (or
/// releases them). HRD: anyone active; Team Lead: own department, not
/// themselves.
class AllEmployeesView extends StatefulWidget {
  const AllEmployeesView({
    super.key,
    required this.user,
    required this.onOpenEmployee,
    this.scopedToDepartment = false,
  });

  final AppUser user;
  final ValueChanged<String> onOpenEmployee;
  final bool scopedToDepartment;

  @override
  State<AllEmployeesView> createState() => _AllEmployeesViewState();
}

class _AllEmployeesViewState extends State<AllEmployeesView> {
  static const _pageSize = 30;

  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _divisionId;
  String? _groupId;
  String? _departmentId;
  String? _roleId;
  _StatusFilter _status = _StatusFilter.active;
  _Sort _sort = _Sort.name;
  int _limit = _pageSize;
  bool _selecting = false;
  Set<String> _selected = <String>{};
  bool _working = false;

  bool get _scoped => widget.scopedToDepartment || !widget.user.role.canManageOrganization;

  /// HRD and Team Leads can allocate projects.
  bool get _canAllocate => widget.user.role.canManageOrganization || widget.user.role.canEditTeamProfiles;

  bool _selectable(EmployeeProfile e) {
    final repo = ProjectRepository.instance;
    return repo.canAllocate(widget.user, e) || repo.canRelease(widget.user, e);
  }

  void _toggle(EmployeeProfile e) {
    if (!_selectable(e)) {
      showAdminMessage(
        context,
        e.id == widget.user.id
            ? 'Your own projects are allocated by HRD.'
            : 'You can only allocate people in your own department.',
      );
      return;
    }
    setState(() {
      final next = {..._selected};
      if (!next.remove(e.id)) next.add(e.id);
      _selected = next;
    });
  }

  void _toggleAll(List<_Row> shown) {
    final ids = [for (final r in shown) if (_selectable(r.profile)) r.profile.id];
    setState(() {
      final allIn = ids.isNotEmpty && ids.every(_selected.contains);
      final next = {..._selected};
      if (allIn) {
        next.removeAll(ids);
      } else {
        next.addAll(ids);
      }
      _selected = next;
    });
  }

  void _setSelecting(bool on) => setState(() {
        _selecting = on;
        if (!on) _selected = <String>{};
      });

  Future<void> _bulk({required bool release}) async {
    final employees = [
      for (final id in _selected)
        if (EmployeeRepository.instance.byId(id) case final EmployeeProfile e) e,
    ]..sort((a, b) => a.name.compareTo(b.name));
    if (employees.isEmpty || _working) return;
    setState(() => _working = true);
    try {
      final result = await showBulkAllocate(
        context: context,
        user: widget.user,
        employees: employees,
        release: release,
      );
      if (result == null || !mounted) return;
      final verb = release ? 'Released' : 'Allocated';
      final skipped = result.unchanged.length + result.notAllowed.length;
      showAdminMessage(
        context,
        '$verb ${result.count} ${result.count == 1 ? 'person' : 'people'} '
        '${release ? 'from' : 'to'} ${result.project.code}'
        '${skipped == 0 ? '.' : ' · $skipped left as they were.'}',
      );
      setState(() => _selected = <String>{});
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() => _limit = _pageSize;

  List<_Row> _rows() {
    final employees = EmployeeRepository.instance;
    final structure = OrgStructureRepository.instance;
    final query = _query.trim().toLowerCase();
    final list = <_Row>[];
    for (final e in employees.employees.value) {
      if (_scoped && employees.departmentNameOf(e) != widget.user.department) continue;
      final statusOk = switch (_status) {
        _StatusFilter.active => e.isActive,
        _StatusFilter.inactive => !e.isActive,
        _StatusFilter.incomplete => !e.isComplete,
        _StatusFilter.unallocated => e.isActive && ProjectRepository.instance.projectCountFor(e.id) == 0,
        _StatusFilter.all => true,
      };
      if (!statusOk) continue;
      if (_divisionId != null && structure.divisionOfDepartment(e.departmentId)?.id != _divisionId) continue;
      if (_groupId != null && structure.departmentById(e.departmentId)?.groupId != _groupId) continue;
      if (_departmentId != null && e.departmentId != _departmentId) continue;
      if (_roleId != null && e.roleId != _roleId) continue;
      if (query.isNotEmpty) {
        final text = '${e.id} ${e.name} ${e.email} ${e.designation} ${employees.departmentNameOf(e)} '
                '${employees.groupNameOf(e)} ${employees.divisionNameOf(e)} '
                '${RoleRepository.instance.nameOf(e.roleId)} ${e.location.label}'
            .toLowerCase();
        if (!text.contains(query)) continue;
      }
      list.add(_Row(e, Insights.of(e)));
    }
    switch (_sort) {
      case _Sort.name:
        list.sort((a, b) => a.profile.name.compareTo(b.profile.name));
      case _Sort.id:
        list.sort((a, b) => a.profile.id.compareTo(b.profile.id));
      case _Sort.readinessHigh:
        list.sort((a, b) => b.insight.displayReadiness.compareTo(a.insight.displayReadiness));
      case _Sort.readinessLow:
        list.sort((a, b) => a.insight.displayReadiness.compareTo(b.insight.displayReadiness));
      case _Sort.gaps:
        list.sort((a, b) => b.insight.gapCount.compareTo(a.insight.gapCount));
      case _Sort.projects:
        list.sort((a, b) {
          final byCount = b.projectCount.compareTo(a.projectCount);
          return byCount != 0 ? byCount : a.profile.name.compareTo(b.profile.name);
        });
      case _Sort.newest:
        list.sort((a, b) => b.profile.onboardedAt.compareTo(a.profile.onboardedAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Insights.listenable,
      builder: (context, _) {
        final employees = EmployeeRepository.instance;
        final structure = OrgStructureRepository.instance;
        final scopeList = employees.employees.value
            .where((e) => !_scoped || employees.departmentNameOf(e) == widget.user.department)
            .toList();
        final active = scopeList.where((e) => e.isActive).toList();
        final insights = [for (final e in active) Insights.of(e)];
        final withProjects = insights.where((i) => i.readiness != null).toList();
        final avgReadiness = withProjects.isEmpty
            ? 0
            : (withProjects.fold<int>(0, (s, i) => s + i.readiness!) / withProjects.length).round();
        final gaps = insights.fold<int>(0, (s, i) => s + i.gapCount);
        final incomplete = active.where((e) => !e.isComplete).length;
        final unallocated = insights.where((i) => i.projects.isEmpty).length;
        final rows = _rows();
        final shown = rows.take(_limit).toList();
        final width = MediaQuery.sizeOf(context).width;
        final kpiColumns = width >= 900 ? 4 : 2;
        final divisions = [...structure.divisions.value]..sort((a, b) => a.name.compareTo(b.name));
        final groups = (_divisionId == null ? [...structure.groups.value] : structure.groupsIn(_divisionId!))
          ..sort((a, b) => a.name.compareTo(b.name));
        final departments = (_groupId != null
                ? structure.departmentsIn(_groupId!)
                : (_divisionId != null ? structure.departmentsInDivision(_divisionId!) : [...structure.departments.value]))
          ..sort((a, b) => a.name.compareTo(b.name));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: _scoped ? '${widget.user.department.toUpperCase()} TEAM' : 'ALL EMPLOYEES',
              subtitle: _scoped
                  ? 'Everyone in your department. Open a profile to see project gaps, update it '
                      'or request a level-up for HR approval.'
                  : 'Every employee with their readiness and skill gaps. Open a profile for the '
                      'full view, projects and the combined competency table.',
            ),
            const SizedBox(height: 24),
            EqualHeightGrid(
              columns: kpiColumns,
              spacing: 14,
              runSpacing: 14,
              children: [
                KpiCard(
                  value: active.length,
                  label: 'Active employees',
                  caption: '${scopeList.length - active.length} inactive · $unallocated not on a project',
                ),
                KpiCard(value: avgReadiness, suffix: '%', label: 'Average readiness', caption: 'Of people on projects'),
                KpiCard(value: incomplete, label: 'Incomplete profiles', caption: 'Missing role, location…'),
                KpiCard(value: gaps, label: 'Open skill gaps', dark: true),
              ],
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  // Full row on narrow screens (never a negative width).
                  width: width < 560 ? double.infinity : 340,
                  child: AdminSearchField(
                    controller: _search,
                    hint: 'Search name, ID, email, role, city…',
                    onChanged: (v) => setState(() {
                      _query = v;
                      _reset();
                    }),
                  ),
                ),
                if (!_scoped) ...[
                  SizedBox(
                    width: 220,
                    child: AdminDropdown<String>(
                      value: _divisionId ?? '',
                      items: ['', for (final d in divisions) d.id],
                      labelOf: (id) => id.isEmpty ? 'All divisions' : (structure.divisionById(id)?.name ?? id),
                      onChanged: (id) => setState(() {
                        _divisionId = id.isEmpty ? null : id;
                        if (_divisionId != null && structure.divisionOfGroup(_groupId)?.id != _divisionId) {
                          _groupId = null;
                        }
                        if (_divisionId != null && structure.divisionOfDepartment(_departmentId)?.id != _divisionId) {
                          _departmentId = null;
                        }
                        _reset();
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: AdminDropdown<String>(
                      value: _groupId ?? '',
                      items: ['', for (final g in groups) g.id],
                      labelOf: (id) => id.isEmpty ? 'All groups' : (structure.groupById(id)?.name ?? id),
                      onChanged: (id) => setState(() {
                        _groupId = id.isEmpty ? null : id;
                        if (_groupId != null && structure.departmentById(_departmentId)?.groupId != _groupId) {
                          _departmentId = null;
                        }
                        _reset();
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: AdminDropdown<String>(
                      value: _departmentId ?? '',
                      items: ['', for (final d in departments) d.id],
                      labelOf: (id) => id.isEmpty ? 'All departments' : structure.departmentName(id),
                      onChanged: (id) => setState(() {
                        _departmentId = id.isEmpty ? null : id;
                        _reset();
                      }),
                    ),
                  ),
                ],
                SizedBox(
                  width: 210,
                  child: AdminDropdown<String>(
                    value: _roleId ?? '',
                    items: ['', for (final r in RoleRepository.instance.roles.value) r.id],
                    labelOf: (id) => id.isEmpty ? 'All roles' : RoleRepository.instance.nameOf(id),
                    onChanged: (id) => setState(() {
                      _roleId = id.isEmpty ? null : id;
                      _reset();
                    }),
                  ),
                ),
                _SortMenu(value: _sort, onChanged: (s) => setState(() => _sort = s)),
                if (_canAllocate)
                  _SelectToggle(selecting: _selecting, onChanged: _setSelecting),
              ],
            ),
            const SizedBox(height: 14),
            ChoicePills<_StatusFilter>(
              options: _StatusFilter.values,
              selected: _status,
              labelOf: (s) => s.label,
              onSelected: (s) => setState(() {
                _status = s;
                _reset();
              }),
            ),
            const SizedBox(height: 16),
            if (_selecting) ...[
              TurnIn(
                child: _SelectionBar(
                  count: _selected.length,
                  allShownSelected: shown.any((r) => _selectable(r.profile)) &&
                      shown.where((r) => _selectable(r.profile)).every((r) => _selected.contains(r.profile.id)),
                  busy: _working,
                  onToggleAll: () => _toggleAll(shown),
                  onAllocate: () => _bulk(release: false),
                  onRelease: () => _bulk(release: true),
                  onClear: () => setState(() => _selected = <String>{}),
                  onDone: () => _setSelecting(false),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Semantics(
              liveRegion: true,
              child: Text('Showing ${shown.length} of ${rows.length} employees',
                  style: HomeText.body(13.5, weight: FontWeight.w600, color: HomeColors.muted)),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const EmptyState(
                title: 'No employees match',
                message: 'Try another search or clear a filter.',
                icon: Icons.person_search_outlined,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth >= 880
                    ? _Table(
                        rows: shown,
                        onOpen: widget.onOpenEmployee,
                        showDepartment: !_scoped,
                        selection: _selecting
                            ? _Selection(
                                selected: _selected,
                                selectable: _selectable,
                                onToggle: _toggle,
                                onToggleAll: () => _toggleAll(shown),
                              )
                            : null,
                      )
                    : Column(
                        children: [
                          for (final r in shown)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _Card(
                                row: r,
                                onOpen: () => widget.onOpenEmployee(r.profile.id),
                                selection: _selecting
                                    ? _Selection(
                                        selected: _selected,
                                        selectable: _selectable,
                                        onToggle: _toggle,
                                        onToggleAll: () => _toggleAll(shown),
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
              ),
            if (rows.length > shown.length) ...[
              const SizedBox(height: 14),
              Center(
                child: PillButton(
                  label: 'Show more (${rows.length - shown.length} left)',
                  variant: PillVariant.outline,
                  height: 46,
                  fontSize: 14,
                  onPressed: () => setState(() => _limit += _pageSize),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final _Sort value;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Sort>(
      tooltip: 'Sort employees',
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 50),
      color: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      itemBuilder: (context) => [
        for (final option in _Sort.values)
          PopupMenuItem<_Sort>(
            value: option,
            child: Text(option.label,
                style: HomeText.body(14,
                    weight: option == value ? FontWeight.w800 : FontWeight.w500, color: HomeColors.ink)),
          ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(color: HomeColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18, color: HomeColors.ink),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Sort: ${value.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.body(14, weight: FontWeight.w600, color: HomeColors.ink)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 18, color: HomeColors.ink),
          ],
        ),
      ),
    );
  }
}

/// Tick-box state shared by the table and the cards while selecting.
class _Selection {
  const _Selection({
    required this.selected,
    required this.selectable,
    required this.onToggle,
    required this.onToggleAll,
  });

  final Set<String> selected;
  final bool Function(EmployeeProfile e) selectable;
  final ValueChanged<EmployeeProfile> onToggle;
  final VoidCallback onToggleAll;
}

class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.onOpen, required this.showDepartment, this.selection});

  final List<_Row> rows;
  final ValueChanged<String> onOpen;
  final bool showDepartment;
  final _Selection? selection;

  @override
  Widget build(BuildContext context) {
    TextStyle head() => HomeText.body(11.5, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.9);
    final select = selection;
    final selectableRows = select == null ? const <_Row>[] : rows.where((r) => select.selectable(r.profile)).toList();
    final allChecked =
        select != null && selectableRows.isNotEmpty && selectableRows.every((r) => select.selected.contains(r.profile.id));
    return OrgPanel(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Row(
              children: [
                if (select != null)
                  SizedBox(
                    width: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CheckCell(
                        checked: allChecked,
                        enabled: selectableRows.isNotEmpty,
                        tooltip: allChecked ? 'Clear the rows shown' : 'Select every row shown',
                        onTap: select.onToggleAll,
                      ),
                    ),
                  ),
                Expanded(flex: 30, child: Text('EMPLOYEE', style: head())),
                Expanded(flex: 24, child: Text(showDepartment ? 'GROUP › DEPARTMENT · DIVISION' : 'REPORTS TO', style: head())),
                Expanded(flex: 17, child: Text('ROLE', style: head())),
                Expanded(flex: 14, child: Text('LOCATION', style: head())),
                Expanded(flex: 18, child: Text('READINESS', style: head())),
                Expanded(flex: 10, child: Text('PROJECTS', style: head(), textAlign: TextAlign.center)),
                Expanded(flex: 8, child: Text('GAPS', style: head(), textAlign: TextAlign.center)),
                Expanded(flex: 13, child: Text('STATUS', style: head())),
              ],
            ),
          ),
          const Divider(height: 1, color: HomeColors.cardBorder),
          for (var i = 0; i < rows.length; i++)
            _TableRow(
              row: rows[i],
              onOpen: onOpen,
              showDepartment: showDepartment,
              striped: i.isOdd,
              selection: selection,
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.row,
    required this.onOpen,
    required this.showDepartment,
    required this.striped,
    this.selection,
  });

  final _Row row;
  final ValueChanged<String> onOpen;
  final bool showDepartment;
  final bool striped;
  final _Selection? selection;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.row.profile;
    final info = widget.row.insight;
    final employees = EmployeeRepository.instance;
    final readiness = info.readiness;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final select = widget.selection;
    final checked = select != null && select.selected.contains(e.id);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        curve: HomeMotion.ease,
        transform: Matrix4.translationValues(_hover ? 4 : 0, 0, 0),
        decoration: BoxDecoration(
          color: checked
              ? const Color(0xFFE6F0FD)
              : (_hover ? const Color(0xFFEFF5FD) : (widget.striped ? const Color(0xFFF9FBFE) : Colors.white)),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            onTap: select != null ? () => select.onToggle(e) : () => widget.onOpen(e.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  if (select != null)
                    SizedBox(
                      width: 40,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CheckCell(
                          checked: checked,
                          enabled: select.selectable(e),
                          tooltip: select.selectable(e) ? (checked ? 'Unselect' : 'Select') : 'Not in your rights',
                          onTap: () => select.onToggle(e),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 30,
                    child: PersonLine(
                      profile: e,
                      size: 34,
                      detail: '${e.id} · ${e.designation.isEmpty ? '—' : e.designation}',
                      trailing: employees.isNew(e.id) ? const NewLabel() : null,
                    ),
                  ),
                  Expanded(
                    flex: 24,
                    child: widget.showDepartment
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${employees.groupNameOf(e)} › ${employees.departmentNameOf(e)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: HomeText.body(13, color: HomeColors.body),
                              ),
                              Text(
                                employees.divisionNameOf(e),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HomeText.body(11.5, weight: FontWeight.w600, color: HomeColors.muted),
                              ),
                            ],
                          )
                        : Text(
                            employees.managerLabel(e),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(13, color: HomeColors.body),
                          ),
                  ),
                  Expanded(
                    flex: 17,
                    child: e.roleId == null
                        ? Text('Not set', style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.orangeText))
                        : Text(RoleRepository.instance.nameOf(e.roleId),
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: HomeText.body(13, color: HomeColors.body)),
                  ),
                  Expanded(
                    flex: 14,
                    child: Text(e.location.short,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: HomeText.body(13, color: HomeColors.body)),
                  ),
                  Expanded(
                    flex: 18,
                    child: readiness == null
                        ? Text(info.projects.isEmpty ? 'No project' : '—',
                            style: HomeText.body(13, color: HomeColors.muted))
                        : Padding(
                            padding: const EdgeInsets.only(right: 18),
                            child: Row(
                              children: [
                                Expanded(child: MeterBar(value: readiness / 100)),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 40,
                                  child: Text('$readiness%',
                                      style: HomeText.body(13, weight: FontWeight.w800, color: HomeColors.ink)),
                                ),
                              ],
                            ),
                          ),
                  ),
                  Expanded(flex: 10, child: Center(child: ProjectCountPill(projects: info.projects))),
                  Expanded(
                    flex: 8,
                    child: Center(
                      child: info.gapCount == 0
                          ? Text('0', style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.muted))
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: const BoxDecoration(
                                color: HomeColors.orangeTint,
                                borderRadius: BorderRadius.all(Radius.circular(999)),
                              ),
                              child: Text('${info.gapCount}',
                                  style: HomeText.body(13, weight: FontWeight.w800, color: HomeColors.orangeText)),
                            ),
                    ),
                  ),
                  Expanded(flex: 13, child: Align(alignment: Alignment.centerLeft, child: _statusPill(e))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _statusPill(EmployeeProfile e) {
  if (!e.isActive) {
    return const StatusPill(
      label: 'Inactive',
      icon: Icons.person_off_outlined,
      background: HomeColors.neutralTint,
      foreground: HomeColors.body,
    );
  }
  if (!e.isComplete) {
    return const StatusPill(
      label: 'Incomplete',
      icon: Icons.edit_note_rounded,
      background: HomeColors.orangeTint,
      foreground: HomeColors.orangeText,
    );
  }
  return const StatusPill(
    label: 'Active',
    icon: Icons.check_circle_outline_rounded,
    background: OrgColors.goodTint,
    foreground: OrgColors.good,
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.row, required this.onOpen, this.selection});

  final _Row row;
  final VoidCallback onOpen;
  final _Selection? selection;

  @override
  Widget build(BuildContext context) {
    final e = row.profile;
    final info = row.insight;
    final employees = EmployeeRepository.instance;
    final readiness = info.readiness;
    final select = selection;
    final checked = select != null && select.selected.contains(e.id);
    return LiftCard(
      padding: EdgeInsets.zero,
      color: checked ? const Color(0xFFE6F0FD) : Colors.white,
      borderColor: checked ? HomeColors.ink : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: select != null ? () => select.onToggle(e) : onOpen,
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (select != null) ...[
                      CheckCell(
                        checked: checked,
                        enabled: select.selectable(e),
                        tooltip: select.selectable(e) ? (checked ? 'Unselect' : 'Select') : 'Not in your rights',
                        onTap: () => select.onToggle(e),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: PersonLine(
                        profile: e,
                        trailing: employees.isNew(e.id) ? const NewLabel() : _statusPill(e),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(employees.placementOf(e),
                    style: HomeText.body(13, color: HomeColors.body)),
                Text('${RoleRepository.instance.nameOf(e.roleId)} · ${e.location.short}',
                    style: HomeText.body(12.5, color: HomeColors.muted)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: readiness == null
                          ? Text(info.projects.isEmpty ? 'No project yet' : 'Nothing required',
                              style: HomeText.body(12.5, color: HomeColors.muted))
                          : MeterBar(value: readiness / 100),
                    ),
                    const SizedBox(width: 10),
                    Text(readiness == null ? '' : '$readiness% ready',
                        style: HomeText.body(12.5, weight: FontWeight.w800, color: HomeColors.ink)),
                    const SizedBox(width: 10),
                    Text('${row.projectCount} ${row.projectCount == 1 ? 'project' : 'projects'}',
                        style: HomeText.body(12.5,
                            weight: FontWeight.w800,
                            color: row.projectCount > 0 ? HomeColors.blueDeep : HomeColors.muted)),
                    const SizedBox(width: 10),
                    Text('${info.gapCount} gaps',
                        style: HomeText.body(12.5,
                            weight: FontWeight.w800,
                            color: info.gapCount > 0 ? HomeColors.orangeText : HomeColors.muted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Select people" / "Done" pill that turns tick boxes on and off.
class _SelectToggle extends StatelessWidget {
  const _SelectToggle({required this.selecting, required this.onChanged});

  final bool selecting;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selecting ? 'Turn selection off' : 'Select people to allocate them to a project together',
      child: HoverRaise(
        child: Material(
          color: selecting ? HomeColors.ink : Colors.white,
          shape: StadiumBorder(side: BorderSide(color: selecting ? HomeColors.ink : HomeColors.chipBorder)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onChanged(!selecting),
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(selecting ? Icons.close_rounded : Icons.checklist_rounded,
                        size: 18, color: selecting ? Colors.white : HomeColors.ink),
                    const SizedBox(width: 8),
                    Text(selecting ? 'Done selecting' : 'Select people',
                        style: HomeText.body(14, weight: FontWeight.w700, color: selecting ? Colors.white : HomeColors.ink)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ink bar shown while selecting: count + bulk project actions.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.allShownSelected,
    required this.busy,
    required this.onToggleAll,
    required this.onAllocate,
    required this.onRelease,
    required this.onClear,
    required this.onDone,
  });

  final int count;
  final bool allShownSelected;
  final bool busy;
  final VoidCallback onToggleAll;
  final VoidCallback onAllocate;
  final VoidCallback onRelease;
  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final none = count == 0;
    Widget action(String label, IconData icon, VoidCallback? onTap, {bool primary = false}) => Material(
          color: primary ? Colors.white : const Color.fromRGBO(255, 255, 255, 0.10),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Opacity(
                opacity: onTap == null ? 0.45 : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 17, color: primary ? HomeColors.ink : Colors.white),
                    const SizedBox(width: 7),
                    Text(label,
                        style: HomeText.body(13.5, weight: FontWeight.w700, color: primary ? HomeColors.ink : Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: const BoxDecoration(
        color: HomeColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(15, 27, 45, 0.35), blurRadius: 24, spreadRadius: -12, offset: Offset(0, 12)),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              none ? 'Tick people to allocate them together' : '$count selected',
              style: HomeText.body(14.5, weight: FontWeight.w800, color: Colors.white),
            ),
          ),
          action(allShownSelected ? 'Clear shown' : 'Select all shown', Icons.done_all_rounded, busy ? null : onToggleAll),
          action('Allocate to project', Icons.playlist_add_rounded, none || busy ? null : onAllocate, primary: true),
          action('Release from project', Icons.playlist_remove_rounded, none || busy ? null : onRelease),
          if (!none) action('Clear', Icons.backspace_outlined, busy ? null : onClear),
          action('Done', Icons.close_rounded, busy ? null : onDone),
        ],
      ),
    );
  }
}

/// Square tick box used in the directory while selecting.
class CheckCell extends StatelessWidget {
  const CheckCell({
    super.key,
    required this.checked,
    required this.onTap,
    this.enabled = true,
    this.tooltip,
  });

  final bool checked;
  final bool enabled;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final box = Semantics(
      checked: checked,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: !enabled ? const Color(0xFFEEF1F5) : (checked ? HomeColors.ink : Colors.white),
              borderRadius: const BorderRadius.all(Radius.circular(7)),
              border: Border.all(
                color: !enabled ? HomeColors.cardBorder : (checked ? HomeColors.ink : HomeColors.chipBorder),
                width: 1.5,
              ),
            ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : (!enabled ? const Icon(Icons.lock_outline_rounded, size: 12, color: HomeColors.muted) : null),
          ),
        ),
      ),
    );
    final hint = tooltip;
    return hint == null ? box : Tooltip(message: hint, child: box);
  }
}

/// Number of open projects someone is allocated to; the codes show on hover.
class ProjectCountPill extends StatelessWidget {
  const ProjectCountPill({super.key, required this.projects});

  final List<ProjectRecord> projects;

  @override
  Widget build(BuildContext context) {
    final count = projects.length;
    if (count == 0) {
      return Tooltip(
        message: 'Not on a project',
        child: Text('0', style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.muted)),
      );
    }
    return Tooltip(
      message: [for (final p in projects) '${p.code} · ${p.name} (${p.status.label})'].join('\n'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: const BoxDecoration(
          color: HomeColors.blueTint,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.work_outline_rounded, size: 13, color: HomeColors.blueDeep),
            const SizedBox(width: 4),
            Text('$count', style: HomeText.body(13, weight: FontWeight.w800, color: HomeColors.blueDeep)),
          ],
        ),
      ),
    );
  }
}

/// The team directory as its own page (Team Leads: own department only).
class AllEmployeesPage extends StatefulWidget {
  const AllEmployeesPage({super.key, required this.user, this.onLogout});

  final AppUser user;
  final VoidCallback? onLogout;

  static Route<void> route({required AppUser user, VoidCallback? onLogout}) =>
      SpherePageRoute<void>(builder: (_) => AllEmployeesPage(user: user, onLogout: onLogout));

  @override
  State<AllEmployeesPage> createState() => _AllEmployeesPageState();
}

class _AllEmployeesPageState extends State<AllEmployeesPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(String id) {
    Navigator.of(context).push(EmployeeProfilePage.route(
      user: widget.user,
      employeeId: id,
      onLogout: widget.onLogout,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final allowed = user.role.canViewTeam;
    // Same frame as the dashboards (top bar and list share their edges).
    final side = ConsoleFrame.inset(MediaQuery.sizeOf(context).width);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFE),
      body: Stack(
        children: [
          const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: HomeColors.skyGradient))),
          Positioned.fill(child: DriftingClouds(scrollController: _scroll)),
          SafeArea(
            child: MinWidthBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(side, ConsoleFrame.topGap, side, 10),
                    child: ConsoleTopBar(
                      title: user.role.canManageOrganization ? 'All employees' : '${user.department} team',
                      user: user,
                      onBack: () => Navigator.of(context).maybePop(),
                      onLogout: widget.onLogout,
                      actions: [
                        if (allowed)
                          Tooltip(
                            message: 'Dashboards & reports',
                            child: HoverRaise(
                              child: Material(
                                color: Colors.white,
                                shape: const CircleBorder(side: BorderSide(color: HomeColors.divider)),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => Navigator.of(context)
                                      .push(TeamReportsPage.route(user: user, onLogout: widget.onLogout)),
                                  child: const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(Icons.insights_rounded, size: 20, color: HomeColors.ink),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(side, 16, side, 48),
                        child: SmoothWheelScroll(
                          controller: _scroll,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: ConsoleFrame.contentWidth),
                              child: allowed
                                  ? TurnIn(
                                      child: AllEmployeesView(
                                        user: user,
                                        onOpenEmployee: _open,
                                        scopedToDepartment: !user.role.canManageOrganization,
                                      ),
                                    )
                                  : const EmptyState(
                                      title: 'No access',
                                      message: 'Only Team Leads and the HRD team can see employee lists.',
                                      icon: Icons.lock_outline_rounded,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
