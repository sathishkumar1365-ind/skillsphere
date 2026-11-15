import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/employees.dart';
import '../../data/org_structure.dart';
import '../widgets/admin_common.dart';

enum _Period {
  days30('Last 30 days'),
  days90('Last 90 days'),
  year('This year'),
  all('All time');

  const _Period(this.label);
  final String label;

  bool includes(DateTime date, DateTime now) {
    final today = dateOnly(now);
    return switch (this) {
      _Period.days30 => !date.isBefore(today.subtract(const Duration(days: 30))),
      _Period.days90 => !date.isBefore(today.subtract(const Duration(days: 90))),
      _Period.year => date.year == today.year,
      _Period.all => true,
    };
  }
}

enum _FieldFilter {
  placement('Division, group & dept'),
  all('All changes'),
  manager('Reporting manager'),
  designation('Designation'),
  role('Role'),
  status('Status');

  const _FieldFilter(this.label);
  final String label;

  bool matches(ChangeField f) => switch (this) {
        _FieldFilter.placement => f.isPlacement,
        _FieldFilter.all => true,
        _FieldFilter.manager => f == ChangeField.manager,
        _FieldFilter.designation => f == ChangeField.designation,
        _FieldFilter.role => f == ChangeField.role,
        _FieldFilter.status => f == ChangeField.status,
      };
}

/// Changes that belong together on the timeline: one re-org batch, or one
/// employee's changes on one date.
class _Entry {
  _Entry(this.key, this.batchLabel, this.date, this.reason);

  final String key;
  final String? batchLabel;
  final DateTime date;
  final ChangeReason reason;
  final List<ProfileChange> changes = [];

  Set<String> get employeeIds => {for (final c in changes) c.employeeId};
}

/// Console › Profile Changes: who moved between divisions, groups and departments
/// (re-orgs, transfers) and other profile changes, with a re-org tool to
/// move several people at once.
class ProfileChangesView extends StatefulWidget {
  const ProfileChangesView({super.key, required this.user, required this.onOpenEmployee});

  final AppUser user;
  final ValueChanged<String> onOpenEmployee;

  @override
  State<ProfileChangesView> createState() => _ProfileChangesViewState();
}

class _ProfileChangesViewState extends State<ProfileChangesView> {
  static const _pageSize = 12;

  final TextEditingController _search = TextEditingController();
  String _query = '';
  _Period _period = _Period.days90;
  _FieldFilter _field = _FieldFilter.placement;
  String? _divisionName;
  String? _groupName;
  String? _departmentName;
  ChangeReason? _reason;
  int _limit = _pageSize;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() => _limit = _pageSize;

  Future<void> _openMove() async {
    final moved = await showSwingPanel<int>(
      context: context,
      title: 'Move employees',
      subtitle: 'Re-org: move several people to another department (and so group and division) at once. '
          'Every change is logged here.',
      width: 820,
      builder: (panelContext) => _MoveForm(user: widget.user, onDone: (n) => Navigator.of(panelContext).pop(n)),
    );
    if (moved == null || !mounted) return;
    showAdminMessage(context, '$moved ${moved == 1 ? 'employee' : 'employees'} moved. The changes are listed below.');
    setState(() {
      _period = _Period.all;
      _field = _FieldFilter.placement;
      _reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final employees = EmployeeRepository.instance;
    final structure = OrgStructureRepository.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([employees.changes, employees.employees, structure.listenable]),
      builder: (context, _) {
        final now = DateTime.now();
        final inPeriod = employees.changes.value.where((c) => _period.includes(c.effectiveDate, now)).toList();
        final placement = inPeriod.where((c) => c.field.isPlacement).toList();
        final divisionMoves = placement.where((c) => c.field == ChangeField.division).length;
        final groupMoves = placement.where((c) => c.field == ChangeField.group).length;
        final departmentMoves = placement.where((c) => c.field == ChangeField.department).length;
        final affected = {for (final c in placement) c.employeeId}.length;

        final query = _query.trim().toLowerCase();
        final filtered = inPeriod.where((c) {
          if (!_field.matches(c.field)) return false;
          if (_reason != null && c.reason != _reason) return false;
          if (_divisionName != null) {
            final e = employees.byId(c.employeeId);
            final touchesDivision =
                (c.field == ChangeField.division && (c.from == _divisionName || c.to == _divisionName)) ||
                    (e != null && employees.divisionNameOf(e) == _divisionName);
            if (!touchesDivision) return false;
          }
          if (_groupName != null) {
            final e = employees.byId(c.employeeId);
            final touchesGroup = (c.field == ChangeField.group && (c.from == _groupName || c.to == _groupName)) ||
                (e != null && employees.groupNameOf(e) == _groupName);
            if (!touchesGroup) return false;
          }
          if (_departmentName != null) {
            final e = employees.byId(c.employeeId);
            final touchesDepartment =
                (c.field == ChangeField.department && (c.from == _departmentName || c.to == _departmentName)) ||
                    (e != null && employees.departmentNameOf(e) == _departmentName);
            if (!touchesDepartment) return false;
          }
          if (query.isNotEmpty) {
            final text = '${c.employeeId} ${employees.nameOf(c.employeeId)} ${c.from} ${c.to} ${c.note} '
                    '${c.batchLabel ?? ''} ${c.changedBy}'
                .toLowerCase();
            if (!text.contains(query)) return false;
          }
          return true;
        }).toList()
          ..sort((a, b) {
            final byDate = b.effectiveDate.compareTo(a.effectiveDate);
            return byDate != 0 ? byDate : b.changedAt.compareTo(a.changedAt);
          });

        // Group into timeline entries.
        final entries = <_Entry>[];
        final byKey = <String, _Entry>{};
        for (final c in filtered) {
          final key = c.batchLabel != null
              ? 'batch|${c.batchLabel}|${isoDate(c.effectiveDate)}'
              : 'one|${c.employeeId}|${isoDate(c.effectiveDate)}|${c.reason.name}';
          final entry = byKey.putIfAbsent(key, () {
            final e = _Entry(key, c.batchLabel, c.effectiveDate, c.reason);
            entries.add(e);
            return e;
          });
          entry.changes.add(c);
        }
        final shown = entries.take(_limit).toList();

        final divisionNames = [for (final d in structure.divisions.value) d.name]..sort();
        final groupNames = [for (final g in structure.groups.value) g.name]..sort();
        final departmentNames = [for (final d in structure.departments.value) d.name]..sort();
        final width = MediaQuery.sizeOf(context).width;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'PROFILE CHANGES',
              subtitle: 'Track re-orgs: every move between divisions, groups and departments, plus changes of '
                  'manager, designation, role and status, with the reason and the date it takes effect.',
              trailing: PillButton(label: 'Move employees (re-org)', onPressed: _openMove),
            ),
            const SizedBox(height: 24),
            EqualHeightGrid(
              columns: width >= 1100 ? 5 : (width >= 700 ? 3 : 2),
              spacing: 14,
              runSpacing: 14,
              children: [
                KpiCard(value: affected, label: 'Employees moved', caption: _period.label),
                KpiCard(value: divisionMoves, label: 'Division changes', caption: 'Incl. group moves'),
                KpiCard(value: groupMoves, label: 'Group changes', caption: 'Incl. department moves'),
                KpiCard(value: departmentMoves, label: 'Department changes'),
                KpiCard(value: inPeriod.length, label: 'All profile changes', dark: true),
              ],
            ),
            const SizedBox(height: 20),
            _FlowPanel(changes: placement, divisions: divisionNames, departments: departmentNames, groups: groupNames),
            const SizedBox(height: 22),
            ChoicePills<_Period>(
              options: _Period.values,
              selected: _period,
              labelOf: (p) => p.label,
              onSelected: (p) => setState(() {
                _period = p;
                _reset();
              }),
            ),
            const SizedBox(height: 10),
            ChoicePills<_FieldFilter>(
              options: _FieldFilter.values,
              selected: _field,
              labelOf: (f) => f.label,
              onSelected: (f) => setState(() {
                _field = f;
                _reset();
              }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width < 560 ? width - 40 : 300,
                  child: AdminSearchField(
                    controller: _search,
                    hint: 'Search person, department, note…',
                    onChanged: (v) => setState(() {
                      _query = v;
                      _reset();
                    }),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: AdminDropdown<String>(
                    value: _divisionName ?? '',
                    items: ['', ...divisionNames],
                    labelOf: (n) => n.isEmpty ? 'Any division' : n,
                    onChanged: (n) => setState(() {
                      _divisionName = n.isEmpty ? null : n;
                      _reset();
                    }),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: AdminDropdown<String>(
                    value: _groupName ?? '',
                    items: ['', ...groupNames],
                    labelOf: (n) => n.isEmpty ? 'Any group' : n,
                    onChanged: (n) => setState(() {
                      _groupName = n.isEmpty ? null : n;
                      _reset();
                    }),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: AdminDropdown<String>(
                    value: _departmentName ?? '',
                    items: ['', ...departmentNames],
                    labelOf: (n) => n.isEmpty ? 'Any department' : n,
                    onChanged: (n) => setState(() {
                      _departmentName = n.isEmpty ? null : n;
                      _reset();
                    }),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: AdminDropdown<String>(
                    value: _reason?.name ?? '',
                    items: ['', for (final r in ChangeReason.values) r.name],
                    labelOf: (n) => n.isEmpty ? 'Any reason' : ChangeReason.values.byName(n).label,
                    onChanged: (n) => setState(() {
                      _reason = n.isEmpty ? null : ChangeReason.values.byName(n);
                      _reset();
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${filtered.length} ${filtered.length == 1 ? 'change' : 'changes'} in ${entries.length} '
              '${entries.length == 1 ? 'entry' : 'entries'}',
              style: HomeText.body(13.5, weight: FontWeight.w600, color: HomeColors.muted),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const EmptyState(
                title: 'No changes match',
                message: 'Try a longer period or another filter.',
                icon: Icons.history_toggle_off_rounded,
              )
            else
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TurnIn(
                    key: ValueKey<String>(shown[i].key),
                    delay: Duration(milliseconds: math.min(i, 6) * 60),
                    child: _EntryCard(entry: shown[i], onOpenEmployee: widget.onOpenEmployee),
                  ),
                ),
            if (entries.length > shown.length)
              Center(
                child: PillButton(
                  label: 'Show more (${entries.length - shown.length} left)',
                  variant: PillVariant.outline,
                  height: 46,
                  fontSize: 14,
                  onPressed: () => setState(() => _limit += _pageSize),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// People in and out per division, group and department in the period.
class _FlowPanel extends StatelessWidget {
  const _FlowPanel({
    required this.changes,
    required this.divisions,
    required this.departments,
    required this.groups,
  });

  final List<ProfileChange> changes;
  final List<String> divisions;
  final List<String> departments;
  final List<String> groups;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, int, int, ChangeField)>[];
    void collect(List<String> names, ChangeField field) {
      for (final name in names) {
        final inCount = changes.where((c) => c.field == field && c.to == name).length;
        final outCount = changes.where((c) => c.field == field && c.from == name).length;
        if (inCount + outCount > 0) rows.add((name, inCount, outCount, field));
      }
    }

    collect(divisions, ChangeField.division);
    collect(groups, ChangeField.group);
    collect(departments, ChangeField.department);
    final most = rows.fold<int>(1, (m, r) => math.max(m, math.max(r.$2, r.$3)));
    return OrgPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelTitle('Movement in the period',
              subtitle: 'People who joined (in) or left (out) each division, group and department.'),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Text('No moves in this period.', style: HomeText.body(13.5, color: HomeColors.muted))
          else
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 560;
                    final label = Row(
                      children: [
                        Tooltip(
                          message: r.$4.label,
                          child: Icon(
                            switch (r.$4) {
                              ChangeField.division => Icons.domain_rounded,
                              ChangeField.group => Icons.account_tree_outlined,
                              _ => Icons.apartment_rounded,
                            },
                            size: 16,
                            color: HomeColors.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(r.$1,
                              overflow: TextOverflow.ellipsis,
                              style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink)),
                        ),
                      ],
                    );
                    final bars = Row(
                      children: [
                        Expanded(child: _FlowBar(label: 'In', value: r.$2, max: most, color: HomeColors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _FlowBar(label: 'Out', value: r.$3, max: most, color: HomeColors.body)),
                      ],
                    );
                    return narrow
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label, const SizedBox(height: 6), bars])
                        : Row(children: [SizedBox(width: 230, child: label), Expanded(child: bars)]);
                  },
                ),
              ),
        ],
      ),
    );
  }
}

class _FlowBar extends StatelessWidget {
  const _FlowBar({required this.label, required this.value, required this.max, required this.color});

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label: $value',
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(label, style: HomeText.body(12, weight: FontWeight.w700, color: HomeColors.muted))),
          Expanded(child: MeterBar(value: value / max, color: color)),
          const SizedBox(width: 8),
          SizedBox(
            width: 22,
            child: Text('$value', style: HomeText.body(13, weight: FontWeight.w800, color: HomeColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onOpenEmployee});

  final _Entry entry;
  final ValueChanged<String> onOpenEmployee;

  @override
  Widget build(BuildContext context) {
    final employees = EmployeeRepository.instance;
    final batch = entry.batchLabel;
    final people = entry.employeeIds.toList();
    final first = entry.changes.first;
    return LiftCard(
      padding: const EdgeInsets.all(20),
      liftBy: 4,
      tiltDegrees: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBlock(date: entry.date),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch ?? employees.nameOf(first.employeeId),
                      style: HomeText.body(16, weight: FontWeight.w800, color: HomeColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _ReasonPill(reason: entry.reason),
                        if (batch != null)
                          StatusPill(
                            label: '${people.length} ${people.length == 1 ? 'employee' : 'employees'}',
                            icon: Icons.groups_outlined,
                            background: HomeColors.neutralTint,
                            foreground: HomeColors.ink,
                          ),
                        Text('by ${first.changedBy} · logged ${relativeDays(first.changedAt)}',
                            style: HomeText.body(12.5, color: HomeColors.muted)),
                      ],
                    ),
                    if (first.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('“${first.note}”', style: HomeText.body(13, color: HomeColors.body, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final id in people.take(batch == null ? 1 : 12))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PersonChanges(
                employeeId: id,
                changes: entry.changes.where((c) => c.employeeId == id).toList(),
                showName: batch != null,
                onOpen: () => onOpenEmployee(id),
              ),
            ),
          if (batch != null && people.length > 12)
            Text('+ ${people.length - 12} more', style: HomeText.body(12.5, color: HomeColors.muted)),
        ],
      ),
    );
  }
}

class _PersonChanges extends StatelessWidget {
  const _PersonChanges({
    required this.employeeId,
    required this.changes,
    required this.showName,
    required this.onOpen,
  });

  final String employeeId;
  final List<ProfileChange> changes;
  final bool showName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final profile = EmployeeRepository.instance.byId(employeeId);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAFE),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName && profile != null) ...[
                  PersonLine(profile: profile, size: 30),
                  const SizedBox(height: 8),
                ],
                for (final c in changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(c.field.label,
                              style: HomeText.body(12.5, weight: FontWeight.w700, color: HomeColors.muted)),
                        ),
                        _ValueChip(text: c.from, strike: true),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: HomeColors.ink),
                        _ValueChip(text: c.to, highlight: c.field.isPlacement),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              foregroundColor: HomeColors.blue,
              textStyle: HomeText.body(12.5, weight: FontWeight.w700),
            ),
            child: const Text('Profile'),
          ),
        ],
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.text, this.strike = false, this.highlight = false});

  final String text;
  final bool strike;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? HomeColors.blueTint : Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: highlight ? const Color(0xFFC9DBF6) : HomeColors.cardBorder),
      ),
      child: Text(
        text.isEmpty ? '—' : text,
        style: HomeText.body(12.5,
                weight: FontWeight.w700, color: strike ? HomeColors.muted : (highlight ? HomeColors.blueDeep : HomeColors.ink))
            .copyWith(decoration: strike ? TextDecoration.lineThrough : null),
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C7BE8), HomeColors.ink],
        ),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(15, 27, 45, 0.3), blurRadius: 12, spreadRadius: -5, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Text('${date.day}', style: HomeText.display(24, color: Colors.white, height: 1)),
          Text(months[date.month - 1],
              style: HomeText.body(11, weight: FontWeight.w800, color: HomeColors.onInk, letterSpacing: 1)),
          Text('${date.year}', style: HomeText.body(10.5, color: HomeColors.onInkMuted)),
        ],
      ),
    );
  }
}

class _ReasonPill extends StatelessWidget {
  const _ReasonPill({required this.reason});

  final ChangeReason reason;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color bg, Color fg) = switch (reason) {
      ChangeReason.reorg => (Icons.account_tree_outlined, HomeColors.blueTint, HomeColors.blueDeep),
      ChangeReason.transfer => (Icons.swap_horiz_rounded, HomeColors.blueTint, HomeColors.blueDeep),
      ChangeReason.promotion => (Icons.trending_up_rounded, OrgColors.goodTint, OrgColors.good),
      ChangeReason.correction => (Icons.edit_outlined, HomeColors.neutralTint, HomeColors.body),
      ChangeReason.crowdSync => (Icons.sync_rounded, HomeColors.neutralTint, HomeColors.body),
      ChangeReason.other => (Icons.more_horiz_rounded, HomeColors.neutralTint, HomeColors.body),
    };
    return StatusPill(label: reason.label, icon: icon, background: bg, foreground: fg);
  }
}

// ============================================================ re-org tool

class _MoveForm extends StatefulWidget {
  const _MoveForm({required this.user, required this.onDone});

  final AppUser user;
  final ValueChanged<int> onDone;

  @override
  State<_MoveForm> createState() => _MoveFormState();
}

class _MoveFormState extends State<_MoveForm> {
  final _label = TextEditingController();
  final _note = TextEditingController();
  List<String> _people = [];
  String? _fromDepartmentId;
  String? _divisionId;
  String? _groupId;
  String? _departmentId;
  String? _managerId;
  ChangeReason _reason = ChangeReason.reorg;
  DateTime _effective = dateOnly(DateTime.now());
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _move() async {
    final target = _departmentId;
    if (_people.isEmpty) {
      setState(() => _error = 'Add the people to move.');
      return;
    }
    if (target == null) {
      setState(() => _error = 'Choose the division, group and department they move to.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final moved = await EmployeeRepository.instance.moveEmployees(
        by: widget.user,
        employeeIds: _people,
        toDepartmentId: target,
        managerId: _managerId,
        reason: _reason,
        effectiveDate: _effective,
        note: _note.text,
        batchLabel: _label.text,
      );
      if (mounted) widget.onDone(moved);
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = EmployeeRepository.instance;
    final structure = OrgStructureRepository.instance;
    final active = [...employees.active]..sort((a, b) => a.name.compareTo(b.name));
    final departments = [...structure.departments.value]..sort((a, b) => a.name.compareTo(b.name));
    final divisions = [...structure.divisions.value]..sort((a, b) => a.name.compareTo(b.name));
    final groups = _divisionId == null ? const <OrgGroup>[] : structure.groupsIn(_divisionId!);
    final targetDepartments = _groupId == null ? const <OrgDepartment>[] : structure.departmentsIn(_groupId!);
    final target = structure.departmentById(_departmentId);
    final targetGroup = structure.groupOfDepartment(_departmentId);
    final targetDivision = structure.divisionOfDepartment(_departmentId);
    final selected = [for (final id in _people) if (employees.byId(id) case final EmployeeProfile e) e];
    final divisionChanges =
        target == null ? 0 : selected.where((e) => employees.divisionNameOf(e) != targetDivision?.name).length;
    final groupChanges = target == null ? 0 : selected.where((e) => employees.groupNameOf(e) != targetGroup?.name).length;
    final departmentChanges = target == null ? 0 : selected.where((e) => e.departmentId != target.id).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepPanel(
          number: 1,
          title: 'Who moves',
          subtitle: 'Search people, or add a whole department at once.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AdminDropdown<String>(
                      value: _fromDepartmentId,
                      items: [for (final d in departments) d.id],
                      labelOf: (id) => structure.departmentName(id),
                      hint: 'Add everyone from a department…',
                      onChanged: (id) => setState(() => _fromDepartmentId = id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PillButton(
                    label: 'Add all',
                    variant: PillVariant.outline,
                    height: 48,
                    fontSize: 14,
                    horizontalPadding: 18,
                    onPressed: _fromDepartmentId == null
                        ? null
                        : () => setState(() {
                              final ids = employees.inDepartment(_fromDepartmentId!).map((e) => e.id);
                              _people = {..._people, ...ids}.toList();
                            }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              EmployeeMultiPicker(
                options: active,
                selectedIds: _people,
                onChanged: (ids) => setState(() => _people = ids),
                lookup: employees.byId,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StepPanel(
          number: 2,
          title: 'Where to',
          subtitle: 'The new department (its group and division come with it) and, optionally, a new '
              'manager for all.',
          child: FieldGrid(
            children: [
              LabeledField(
                label: 'Division',
                required: true,
                child: AdminDropdown<String>(
                  value: _divisionId,
                  items: [for (final d in divisions) d.id],
                  labelOf: (id) => structure.divisionById(id)?.name ?? id,
                  hint: 'Choose a division',
                  onChanged: (id) => setState(() {
                    _divisionId = id;
                    _groupId = null;
                    _departmentId = null;
                  }),
                ),
              ),
              LabeledField(
                label: 'Group',
                required: true,
                child: AdminDropdown<String>(
                  value: _groupId,
                  items: [for (final g in groups) g.id],
                  labelOf: (id) => structure.groupById(id)?.name ?? id,
                  hint: 'Choose a group',
                  disabledText: 'Choose a division first',
                  onChanged: _divisionId == null
                      ? null
                      : (id) => setState(() {
                            _groupId = id;
                            _departmentId = null;
                          }),
                ),
              ),
              LabeledField(
                label: 'Department',
                required: true,
                child: AdminDropdown<String>(
                  value: _departmentId,
                  items: [for (final d in targetDepartments) d.id],
                  labelOf: (id) => structure.departmentName(id),
                  hint: 'Choose a department',
                  disabledText: 'Choose a group first',
                  onChanged: _groupId == null ? null : (id) => setState(() => _departmentId = id),
                ),
              ),
              LabeledField(
                label: 'New reporting manager',
                optional: true,
                child: EmployeePickerField(
                  options: active,
                  selected: employees.byId(_managerId),
                  hint: 'Keep current managers, or pick one',
                  onChanged: (id) => setState(() => _managerId = id),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StepPanel(
          number: 3,
          title: 'Why and when',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChoicePills<ChangeReason>(
                options: ChangeReason.selectable,
                selected: _reason,
                labelOf: (r) => r.label,
                onSelected: (r) => setState(() => _reason = r),
              ),
              const SizedBox(height: 14),
              FieldGrid(
                children: [
                  LabeledField(
                    label: 'Effective from',
                    required: true,
                    child: DateField(value: _effective, onChanged: (d) => setState(() => _effective = d ?? _effective)),
                  ),
                  LabeledField(
                    label: 'Name of this move',
                    optional: true,
                    child: TextField(
                      controller: _label,
                      style: adminInputStyle,
                      maxLength: 80,
                      decoration: adminDecoration(hint: 'e.g. Q1 2027 re-org: ADAS validation team'),
                    ),
                  ),
                  LabeledField(
                    label: 'Note',
                    optional: true,
                    child: TextField(
                      controller: _note,
                      style: adminInputStyle,
                      maxLength: 160,
                      decoration: adminDecoration(hint: 'Why they move'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (target != null && selected.isNotEmpty)
          InfoNote(
            text: '${selected.length} ${selected.length == 1 ? 'person' : 'people'} → ${target.name} '
                '(${targetDivision?.name ?? '—'} › ${targetGroup?.name ?? '—'}): $departmentChanges department, '
                '$groupChanges group and $divisionChanges division '
                '${divisionChanges + groupChanges + departmentChanges == 1 ? 'change' : 'changes'} will be logged.',
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          InfoNote(tone: NoteTone.error, text: _error!),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PillButton(
              label: _saving ? 'Moving…' : 'Move ${selected.length} ${selected.length == 1 ? 'person' : 'people'}',
              onPressed: _saving ? null : _move,
            ),
            PillButton(
              label: 'Cancel',
              variant: PillVariant.outline,
              onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }
}
