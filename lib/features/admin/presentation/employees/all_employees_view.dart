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
import '../widgets/admin_common.dart';
import '../widgets/console_top_bar.dart';
import 'employee_profile_page.dart';

enum _StatusFilter {
  active('Active'),
  inactive('Inactive'),
  incomplete('Incomplete profiles'),
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
  newest('Recently onboarded');

  const _Sort(this.label);
  final String label;
}

/// One employee with their calculated gaps and readiness.
class _Row {
  _Row(this.profile, this.insight);

  final EmployeeProfile profile;
  final EmployeeInsight insight;
}

/// All Employees: search, filter (group, department, role, status) and
/// sort; select one to open their profile.
///
/// HRD sees everyone. A Team Lead sees only their own department
/// ([scopedToDepartment] = true; the server must enforce this too).
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
  String? _groupId;
  String? _departmentId;
  String? _roleId;
  _StatusFilter _status = _StatusFilter.active;
  _Sort _sort = _Sort.name;
  int _limit = _pageSize;

  bool get _scoped => widget.scopedToDepartment || !widget.user.role.canManageOrganization;

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
        _StatusFilter.all => true,
      };
      if (!statusOk) continue;
      if (_groupId != null && structure.departmentById(e.departmentId)?.groupId != _groupId) continue;
      if (_departmentId != null && e.departmentId != _departmentId) continue;
      if (_roleId != null && e.roleId != _roleId) continue;
      if (query.isNotEmpty) {
        final text = '${e.id} ${e.name} ${e.email} ${e.designation} ${employees.departmentNameOf(e)} '
                '${employees.groupNameOf(e)} ${RoleRepository.instance.nameOf(e.roleId)} ${e.location.label}'
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
        final rows = _rows();
        final shown = rows.take(_limit).toList();
        final width = MediaQuery.sizeOf(context).width;
        final kpiColumns = width >= 900 ? 4 : 2;
        final groups = [...structure.groups.value]..sort((a, b) => a.name.compareTo(b.name));
        final departments = (_groupId == null
                ? [...structure.departments.value]
                : structure.departmentsIn(_groupId!))
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
                KpiCard(value: active.length, label: 'Active employees', caption: '${scopeList.length - active.length} inactive'),
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
                  width: width < 560 ? width - 40 : 340,
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
                    ? _Table(rows: shown, onOpen: widget.onOpenEmployee, showDepartment: !_scoped)
                    : Column(
                        children: [
                          for (final r in shown)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _Card(row: r, onOpen: () => widget.onOpenEmployee(r.profile.id)),
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

class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.onOpen, required this.showDepartment});

  final List<_Row> rows;
  final ValueChanged<String> onOpen;
  final bool showDepartment;

  @override
  Widget build(BuildContext context) {
    TextStyle head() => HomeText.body(11.5, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.9);
    return OrgPanel(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Row(
              children: [
                Expanded(flex: 30, child: Text('EMPLOYEE', style: head())),
                Expanded(flex: 26, child: Text(showDepartment ? 'GROUP › DEPARTMENT' : 'REPORTS TO', style: head())),
                Expanded(flex: 18, child: Text('ROLE', style: head())),
                Expanded(flex: 16, child: Text('LOCATION', style: head())),
                Expanded(flex: 18, child: Text('READINESS', style: head())),
                Expanded(flex: 9, child: Text('GAPS', style: head(), textAlign: TextAlign.center)),
                Expanded(flex: 13, child: Text('STATUS', style: head())),
              ],
            ),
          ),
          const Divider(height: 1, color: HomeColors.cardBorder),
          for (var i = 0; i < rows.length; i++)
            _TableRow(row: rows[i], onOpen: onOpen, showDepartment: showDepartment, striped: i.isOdd),
        ],
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({required this.row, required this.onOpen, required this.showDepartment, required this.striped});

  final _Row row;
  final ValueChanged<String> onOpen;
  final bool showDepartment;
  final bool striped;

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
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        curve: HomeMotion.ease,
        transform: Matrix4.translationValues(_hover ? 4 : 0, 0, 0),
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFFEFF5FD) : (widget.striped ? const Color(0xFFF9FBFE) : Colors.white),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            onTap: () => widget.onOpen(e.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
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
                    flex: 26,
                    child: Text(
                      widget.showDepartment
                          ? '${employees.groupNameOf(e)} › ${employees.departmentNameOf(e)}'
                          : employees.managerLabel(e),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.body(13, color: HomeColors.body),
                    ),
                  ),
                  Expanded(
                    flex: 18,
                    child: e.roleId == null
                        ? Text('Not set', style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.orangeText))
                        : Text(RoleRepository.instance.nameOf(e.roleId),
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: HomeText.body(13, color: HomeColors.body)),
                  ),
                  Expanded(
                    flex: 16,
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
                  Expanded(
                    flex: 9,
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
  const _Card({required this.row, required this.onOpen});

  final _Row row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final e = row.profile;
    final info = row.insight;
    final employees = EmployeeRepository.instance;
    final readiness = info.readiness;
    return LiftCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PersonLine(
                  profile: e,
                  trailing: employees.isNew(e.id) ? const NewLabel() : _statusPill(e),
                ),
                const SizedBox(height: 12),
                Text('${employees.groupNameOf(e)} › ${employees.departmentNameOf(e)}',
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
    final side = MediaQuery.sizeOf(context).width < 600 ? 14.0 : 28.0;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFE),
      body: Stack(
        children: [
          const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: HomeColors.skyGradient))),
          Positioned.fill(child: DriftingClouds(scrollController: _scroll)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(side, 14, side, 10),
                  child: ConsoleTopBar(
                    title: user.role.canManageOrganization ? 'All employees' : '${user.department} team',
                    user: user,
                    onBack: () => Navigator.of(context).maybePop(),
                    onLogout: widget.onLogout,
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
                            constraints: const BoxConstraints(maxWidth: 1200),
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
        ],
      ),
    );
  }
}
