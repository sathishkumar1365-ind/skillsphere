import 'package:flutter/material.dart';

import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../data/org_models.dart';
import 'org_common.dart';

enum _SortBy {
  alphabetical('Name (A–Z)'),
  readinessHigh('Readiness: high to low'),
  readinessLow('Readiness: low to high'),
  gaps('Most skill gaps');

  const _SortBy(this.label);
  final String label;
}

/// Searchable, filterable list of employees and their competency summary.
/// A table on wide screens, cards on narrow ones.
///
/// * Super Admin: all employees, with the department filter.
/// * Team Lead: pass only their department's employees and set
///   [showDepartment] to false (the department column becomes "Projects").
class EmployeeDirectory extends StatefulWidget {
  const EmployeeDirectory({
    super.key,
    required this.employees,
    required this.onOpenEmployee,
    this.departments = const [],
    this.showDepartment = true,
  });

  final List<EmployeeRecord> employees;
  final ValueChanged<EmployeeRecord> onOpenEmployee;

  /// Department filter options. Empty = no department filter.
  final List<String> departments;
  final bool showDepartment;

  @override
  State<EmployeeDirectory> createState() => _EmployeeDirectoryState();
}

class _EmployeeDirectoryState extends State<EmployeeDirectory> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _department; // null = all
  _SortBy _sort = _SortBy.alphabetical;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<EmployeeRecord> get _visible {
    final query = _query.trim().toLowerCase();
    final list = widget.employees.where((e) {
      if (_department != null && e.department != _department) return false;
      return query.isEmpty || e.searchText.contains(query);
    }).toList();
    switch (_sort) {
      case _SortBy.alphabetical:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _SortBy.readinessHigh:
        list.sort((a, b) => b.readiness.compareTo(a.readiness));
      case _SortBy.readinessLow:
        list.sort((a, b) => a.readiness.compareTo(b.readiness));
      case _SortBy.gaps:
        list.sort((a, b) => b.gapCount.compareTo(a.gapCount));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final table = width >= 900;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: width < 520 ? width : 360,
                  child: _SearchField(
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
                _SortMenu(value: _sort, onChanged: (v) => setState(() => _sort = v)),
              ],
            ),
            if (widget.departments.isNotEmpty) ...[
              const SizedBox(height: 14),
              Semantics(
                container: true,
                label: 'Filter by department',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OrgFilterPill(
                      label: 'All departments',
                      selected: _department == null,
                      onTap: () => setState(() => _department = null),
                    ),
                    for (final name in widget.departments)
                      OrgFilterPill(
                        label: name,
                        selected: _department == name,
                        onTap: () => setState(() => _department = name),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Semantics(
              liveRegion: true,
              child: Text(
                'Showing ${visible.length} of ${widget.employees.length} employees',
                style: HomeText.body(13.5, weight: FontWeight.w600, color: HomeColors.muted),
              ),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              OrgPanel(
                child: Text('No employees match your search or filter.',
                    style: HomeText.body(15)),
              )
            else if (table)
              _EmployeeTable(
                employees: visible,
                showDepartment: widget.showDepartment,
                onOpen: widget.onOpenEmployee,
              )
            else
              _EmployeeCards(
                employees: visible,
                columns: width >= 600 ? 2 : 1,
                onOpen: widget.onOpenEmployee,
              ),
          ],
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(999)),
      borderSide: BorderSide(color: HomeColors.chipBorder),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: HomeText.body(15, color: HomeColors.ink),
      decoration: InputDecoration(
        hintText: 'Search name, ID, skill, project…',
        hintStyle: HomeText.body(15, color: HomeColors.muted),
        prefixIcon: const Icon(Icons.search_rounded, color: HomeColors.muted),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                ),
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: HomeColors.ink, width: 1.5),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final _SortBy value;
  final ValueChanged<_SortBy> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortBy>(
      tooltip: 'Sort employees',
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 50),
      color: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      itemBuilder: (context) => [
        for (final option in _SortBy.values)
          PopupMenuItem<_SortBy>(
            value: option,
            child: Text(
              option.label,
              style: HomeText.body(14,
                  weight: option == value ? FontWeight.w800 : FontWeight.w500,
                  color: HomeColors.ink),
            ),
          ),
      ],
      child: Container(
        height: 46,
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
            Text('Sort: ${value.label}',
                style: HomeText.body(14, weight: FontWeight.w600, color: HomeColors.ink)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 18, color: HomeColors.ink),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- table

class _EmployeeTable extends StatelessWidget {
  const _EmployeeTable({
    required this.employees,
    required this.showDepartment,
    required this.onOpen,
  });

  final List<EmployeeRecord> employees;
  final bool showDepartment;
  final ValueChanged<EmployeeRecord> onOpen;

  static const _flex = [30, 17, 15, 18, 7, 7, 13];

  @override
  Widget build(BuildContext context) {
    final headers = [
      'Employee',
      showDepartment ? 'Department' : 'Projects',
      'Reports to',
      'Readiness',
      'Skills',
      'Gaps',
      'Status',
    ];
    final headerStyle = HomeText.body(12,
        weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.8);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFFF4F8FC),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  for (var i = 0; i < headers.length; i++)
                    Expanded(
                      flex: _flex[i],
                      child: Text(
                        headers[i].toUpperCase(),
                        textAlign: i == 4 || i == 5 ? TextAlign.center : TextAlign.start,
                        style: headerStyle,
                      ),
                    ),
                ],
              ),
            ),
            for (var i = 0; i < employees.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: HomeColors.gapTrack),
              _EmployeeRow(
                employee: employees[i],
                showDepartment: showDepartment,
                onTap: () => onOpen(employees[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.employee, required this.showDepartment, required this.onTap});

  final EmployeeRecord employee;
  final bool showDepartment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = employee;
    final cell = HomeText.body(14, color: HomeColors.body);
    final projectCount = e.projects.length;
    final second = showDepartment
        ? e.department
        : (projectCount == 0
            ? 'Not on a project'
            : '$projectCount · ${e.projects.join(', ')}');
    const flex = _EmployeeTable._flex;

    return InkWell(
      onTap: onTap,
      hoverColor: const Color(0xFFF2F7FD),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: flex[0],
              child: Row(
                children: [
                  InitialsAvatar(initials: e.initials),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(15,
                                weight: FontWeight.w700, color: HomeColors.ink)),
                        const SizedBox(height: 2),
                        Text('${e.id} · ${e.designation}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(12.5, color: HomeColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: flex[1],
              child: Tooltip(
                message: projectCount == 0 ? 'Not on a project' : e.projects.join('\n'),
                child: Text(second,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: !showDepartment && projectCount == 0
                        ? HomeText.body(14, color: HomeColors.muted)
                        : cell),
              ),
            ),
            Expanded(
              flex: flex[2],
              child: Text(e.reportsTo,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: cell),
            ),
            Expanded(
              flex: flex[3],
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Tooltip(
                  message: '${e.readiness}% project-ready',
                  child: Row(
                    children: [
                      Expanded(child: MeterBar(value: e.readiness / 100, height: 7)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 38,
                        child: Text('${e.readiness}%',
                            textAlign: TextAlign.end,
                            style: HomeText.body(13.5,
                                weight: FontWeight.w700, color: HomeColors.ink)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: flex[4],
              child: Text('${e.skillCount}',
                  textAlign: TextAlign.center,
                  style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink)),
            ),
            Expanded(
              flex: flex[5],
              child: Text('${e.gapCount}',
                  textAlign: TextAlign.center,
                  style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink)),
            ),
            Expanded(
              flex: flex[6],
              child: Align(
                alignment: Alignment.centerLeft,
                child: _statusWithProjects(e),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "On 2 projects" while allocated (the number of projects is what Team
/// Leads and HRD staff by); otherwise Available / On leave.
Widget _statusWithProjects(EmployeeRecord e) {
  final count = e.projects.length;
  if (e.status != EmployeeStatus.allocated || count == 0) return StatusPill.employee(e.status);
  return Tooltip(
    message: e.projects.join('\n'),
    child: StatusPill(
      label: count == 1 ? 'On 1 project' : 'On $count projects',
      icon: Icons.work_outline_rounded,
      background: HomeColors.blueTint,
      foreground: HomeColors.blueDeep,
    ),
  );
}

// ---------------------------------------------------------------- cards

class _EmployeeCards extends StatelessWidget {
  const _EmployeeCards({required this.employees, required this.columns, required this.onOpen});

  final List<EmployeeRecord> employees;
  final int columns;
  final ValueChanged<EmployeeRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    return EqualHeightGrid(
      columns: columns,
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final e in employees) _EmployeeCard(employee: e, onTap: () => onOpen(e)),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.onTap});

  final EmployeeRecord employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = employee;
    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        side: BorderSide(color: HomeColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(initials: e.initials, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(16,
                                weight: FontWeight.w700, color: HomeColors.ink)),
                        Text('${e.designation} · ${e.department}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(13, color: HomeColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Readiness',
                      style: HomeText.body(13, weight: FontWeight.w600)),
                  const Spacer(),
                  Text('${e.readiness}%',
                      style: HomeText.body(13.5,
                          weight: FontWeight.w800, color: HomeColors.ink)),
                ],
              ),
              const SizedBox(height: 6),
              MeterBar(value: e.readiness / 100, height: 7),
              const SizedBox(height: 12),
              Text(
                  '${e.projects.length} ${e.projects.length == 1 ? 'project' : 'projects'} · '
                  '${e.skillCount} skills · ${e.gapCount} gaps · Reports to ${e.reportsTo}',
                  style: HomeText.body(13, color: HomeColors.body)),
              const Spacer(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusWithProjects(e),
                  for (final skill in e.topSkills.take(2))
                    StatusPill(
                      label: skill,
                      background: HomeColors.neutralTint,
                      foreground: HomeColors.ink,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
