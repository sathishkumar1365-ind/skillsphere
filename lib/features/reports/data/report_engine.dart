// Works out every report from the live data (see report_models.dart).
//
// Scope: HRD (Super Admin) sees the whole organisation; a Team Lead only
// their own department – the department comes from the signed-in user,
// never from the filters, so a Team Lead can't widen it. Inactive
// employees are left out of every report.
//
// Rules are the same as on the profile (insights.dart): required level =
// the highest level the employee's open projects need from their role;
// gap = required − held (not held counts from below L0); readiness is
// level-weighted.

import '../../../core/auth/app_user.dart';
import '../../additional_competency/data/additional_competency_repository.dart';
import '../../admin/data/admin_base.dart';
import '../../admin/data/approvals.dart';
import '../../admin/data/employees.dart';
import '../../admin/data/insights.dart';
import '../../admin/data/job_roles.dart';
import '../../admin/data/org_structure.dart';
import '../../admin/data/projects.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/data/competency_repository.dart';
import '../../training_plan/data/training_plans.dart';
import 'report_models.dart';

/// Who a report is for and what they may see.
class ReportScope {
  const ReportScope._({required this.viewer, required this.departmentIds, required this.label});

  /// HRD: everything. Team Lead: own department. Anyone else: nothing.
  factory ReportScope.of(AppUser user) {
    if (user.role.canManageOrganization) {
      return ReportScope._(viewer: user, departmentIds: null, label: 'Whole organisation');
    }
    if (user.role.canEditTeamProfiles) {
      final department = OrgStructureRepository.instance.departmentByName(user.department);
      return ReportScope._(
        viewer: user,
        departmentIds: department == null ? const <String>{} : <String>{department.id},
        label: '${user.department} department',
      );
    }
    return ReportScope._(viewer: user, departmentIds: const <String>{}, label: 'No access');
  }

  final AppUser viewer;

  /// Null = every department.
  final Set<String>? departmentIds;

  /// "Whole organisation" / "Engineering department".
  final String label;

  bool get isOrganisation => departmentIds == null;

  bool get hasAccess {
    final ids = departmentIds;
    return ids == null || ids.isNotEmpty;
  }

  bool includesDepartment(String departmentId) {
    final ids = departmentIds;
    return ids == null || ids.contains(departmentId);
  }
}

class ReportEngine {
  ReportEngine._();

  /// Runs [type] for [scope] with [filters]. [grouping] picks the chart's
  /// grouping (ignored when the report doesn't offer it).
  static ReportResult run(
    ReportType type, {
    required ReportScope scope,
    ReportFilters filters = ReportFilters.none,
    ReportGrouping? grouping,
  }) {
    final f = filters.forType(type);
    final g = grouping != null && type.groupings.contains(grouping) ? grouping : defaultGrouping(type, scope);
    final ctx = _Context(scope, scope.isOrganisation ? f : f.copyWith(divisionId: null, groupId: null, departmentId: null));
    final built = switch (type) {
      ReportType.competencyInventory => _competencyInventory(ctx, g),
      ReportType.levelDistribution => _levelDistribution(ctx, g),
      ReportType.employeeCompetencies => _employeeCompetencies(ctx, g),
      ReportType.headcount => _headcount(ctx, g),
      ReportType.orgReadiness => _orgReadiness(ctx, g),
      ReportType.teamReadiness => _teamReadiness(ctx, g),
      ReportType.currentVsRequired => _currentVsRequired(ctx, g),
      ReportType.topGaps => _topGaps(ctx, g),
      ReportType.projectStaffing => _projectStaffing(ctx, g),
      ReportType.projectAllocation => _projectAllocation(ctx, g),
      ReportType.trainingPlans => _trainingPlans(ctx, g),
      ReportType.levelUpRequests => _levelUpRequests(ctx, g),
      ReportType.additionalSkills => _additionalSkills(ctx, g),
    };
    return ReportResult(
      type: type,
      scopeLabel: scope.label,
      filterLabel: describeFilters(ctx.filters),
      columns: built.columns,
      rows: List<ReportRow>.unmodifiable(built.rows),
      kpis: built.kpis,
      chart: built.chart,
      grouping: g,
      generatedAt: DateTime.now(),
      note: built.note,
    );
  }

  /// The grouping a widget starts with. A Team Lead's "by department" chart
  /// would have one bar, so team-scoped reports start on role instead.
  static ReportGrouping defaultGrouping(ReportType type, ReportScope scope) {
    final first = type.groupings.first;
    final orgLevel = first == ReportGrouping.department ||
        first == ReportGrouping.group ||
        first == ReportGrouping.division;
    if (!scope.isOrganisation && orgLevel) {
      for (final g in type.groupings) {
        if (g != ReportGrouping.department && g != ReportGrouping.group && g != ReportGrouping.division) return g;
      }
    }
    return first;
  }

  /// Groupings that make sense for [scope] (a team has one department).
  static List<ReportGrouping> groupingsFor(ReportType type, ReportScope scope) => scope.isOrganisation
      ? type.groupings
      : type.groupings
          .where((g) => g != ReportGrouping.department && g != ReportGrouping.group && g != ReportGrouping.division)
          .toList();

  /// "Division: Research & Development · Gaps only", or "No filters".
  static String describeFilters(ReportFilters f) {
    final structure = OrgStructureRepository.instance;
    final parts = <String>[
      if (f.divisionId != null) 'Division: ${structure.divisionById(f.divisionId)?.name ?? f.divisionId}',
      if (f.groupId != null) 'Group: ${structure.groupById(f.groupId)?.name ?? f.groupId}',
      if (f.departmentId != null) 'Department: ${structure.departmentName(f.departmentId)}',
      if (f.roleId != null) 'Role: ${RoleRepository.instance.nameOf(f.roleId)}',
      if (f.projectId != null) 'Project: ${ProjectRepository.instance.byId(f.projectId)?.code ?? f.projectId}',
      if (f.category != null) 'Category: ${f.category?.label}',
      if (f.competencyId != null)
        'Competency: ${CompetencyRepository.instance.byId(f.competencyId ?? '')?.name ?? f.competencyId}',
      if (f.gapsOnly) 'Gaps only',
      if (f.includeNotRequired) 'Incl. competencies no project needs',
    ];
    return parts.isEmpty ? 'No filters' : parts.join(' · ');
  }
}

// ============================================================== context

/// Everything one report run needs, worked out once.
class _Context {
  _Context(this.scope, this.filters) {
    final structure = OrgStructureRepository.instance;
    departmentIds = <String>{
      for (final d in structure.departments.value)
        if (scope.includesDepartment(d.id) && _orgMatch(d)) d.id,
    };
    final role = filters.roleId;
    employees = EmployeeRepository.instance.employees.value
        .where((e) => e.isActive && departmentIds.contains(e.departmentId) && (role == null || e.roleId == role))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    employeeIds = {for (final e in employees) e.id};
    final projectId = filters.projectId;
    final project = projectId == null ? null : ProjectRepository.instance.byId(projectId);
    people = project == null ? employees : employees.where((e) => project.memberIds.contains(e.id)).toList();
  }

  final ReportScope scope;
  final ReportFilters filters;

  /// Departments in scope after the division/group/department filters.
  late final Set<String> departmentIds;

  /// Active employees in scope (+ role filter), by name.
  late final List<EmployeeProfile> employees;
  late final Set<String> employeeIds;

  /// [employees], limited to the project filter's team when set.
  late final List<EmployeeProfile> people;

  final Map<String, EmployeeInsight> _insights = <String, EmployeeInsight>{};

  EmployeeInsight insight(EmployeeProfile e) => _insights[e.id] ??= Insights.of(e);

  bool _orgMatch(OrgDepartment d) {
    if (filters.departmentId != null && d.id != filters.departmentId) return false;
    if (filters.groupId != null && d.groupId != filters.groupId) return false;
    if (filters.divisionId != null &&
        OrgStructureRepository.instance.divisionOfGroup(d.groupId)?.id != filters.divisionId) {
      return false;
    }
    return true;
  }

  bool competencyMatch(Competency c) =>
      (filters.category == null || c.category == filters.category) &&
      (filters.competencyId == null || c.id == filters.competencyId);

  /// The library, after the category / competency filters, by name.
  List<Competency> get competencies => CompetencyRepository.instance.competencies.value
      .where(competencyMatch)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Open projects run by a department in scope or with someone in scope
  /// on the team (and only the filtered project, when set).
  List<ProjectRecord> get projects => ProjectRepository.instance.projects.value
      .where((p) =>
          p.status != ProjectStatus.completed &&
          (filters.projectId == null || p.id == filters.projectId) &&
          (departmentIds.contains(p.departmentId) || p.memberIds.any(employeeIds.contains)))
      .toList()
    ..sort((a, b) => a.code.compareTo(b.code));

  /// (employee, competency) pairs their projects need – with the project
  /// filter, only that project's needs. [includeNotRequired] adds held
  /// competencies nobody needs (required level null).
  List<_Req> requirements({bool includeNotRequired = false}) {
    final out = <_Req>[];
    final projectId = filters.projectId;
    for (final e in people) {
      for (final r in insight(e).rows) {
        if (!competencyMatch(r.competency)) continue;
        var sources = r.sources;
        var requiredLevel = r.requiredLevel;
        if (projectId != null) {
          sources = r.sources.where((s) => s.project.id == projectId).toList();
          requiredLevel = sources.isEmpty
              ? null
              : sources.fold<int>(0, (highest, s) => s.level > highest ? s.level : highest);
        }
        final holder = r.holder;
        if (requiredLevel == null && !(includeNotRequired && holder != null)) continue;
        out.add(_Req(
          employee: e,
          competency: r.competency,
          requiredLevel: requiredLevel,
          heldLevel: holder?.level,
          verified: holder?.verified ?? false,
          sources: sources,
        ));
      }
    }
    return out;
  }

  // -------------------------------------------------------- placement

  String departmentOf(EmployeeProfile e) => OrgStructureRepository.instance.departmentName(e.departmentId);

  String groupOf(EmployeeProfile e) => OrgStructureRepository.instance.groupNameOfDepartment(e.departmentId);

  String divisionOf(EmployeeProfile e) => OrgStructureRepository.instance.divisionNameOfDepartment(e.departmentId);

  String roleOf(EmployeeProfile e) => e.roleId == null ? 'Role not set' : RoleRepository.instance.nameOf(e.roleId);

  /// The label [e] falls under for an org/role grouping.
  String unitOf(EmployeeProfile e, ReportGrouping g) => switch (g) {
        ReportGrouping.division => divisionOf(e),
        ReportGrouping.group => groupOf(e),
        ReportGrouping.role => roleOf(e),
        _ => departmentOf(e),
      };
}

/// One requirement (or, with includeNotRequired, one held competency).
class _Req {
  const _Req({
    required this.employee,
    required this.competency,
    required this.requiredLevel,
    required this.heldLevel,
    required this.verified,
    required this.sources,
  });

  final EmployeeProfile employee;
  final Competency competency;

  /// Null when no project needs it.
  final int? requiredLevel;

  /// Null when not held.
  final int? heldLevel;
  final bool verified;
  final List<RequirementSource> sources;

  bool get isRequired => requiredLevel != null;

  /// Levels short (0 = met or not required).
  int get size {
    final required = requiredLevel;
    if (required == null) return 0;
    final held = heldLevel;
    if (held == null) return required + 1;
    return held >= required ? 0 : required - held;
  }

  bool get isGap => size > 0;

  /// Level-weighted points reached / needed (readiness).
  int get reached {
    final required = requiredLevel;
    final held = heldLevel;
    if (required == null || held == null) return 0;
    return held >= required ? required + 1 : held + 1;
  }

  int get needed {
    final required = requiredLevel;
    return required == null ? 0 : required + 1;
  }

  /// "PAY-MIG L2 · ANP-27 L1 (Data Engineer)"
  String get projectsText => sources.isEmpty
      ? '—'
      : sources.map((s) => '${s.project.code} L${s.level}${s.roleName == null ? '' : ' (${s.roleName})'}').join(' · ');
}

/// What each report function returns.
class _Built {
  const _Built({required this.columns, required this.rows, required this.kpis, this.chart, this.note});

  final List<ReportColumn> columns;
  final List<ReportRow> rows;
  final List<ReportKpi> kpis;
  final ReportChart? chart;
  final String? note;
}

// ============================================================== helpers

int _pct(num part, num whole) => whole == 0 ? 0 : (part * 100 / whole).round();

String _one(double v) => v.toStringAsFixed(1);

String _plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

void _count(Map<String, int> map, String key, [int by = 1]) => map[key] = (map[key] ?? 0) + by;

/// Chart data from a count map: in [order] when given (zeros kept),
/// otherwise largest first.
List<ChartDatum> _data(Map<String, int> counts, {List<String>? order, Map<String, String>? notes}) {
  final keys = order ?? (counts.keys.toList()..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0)));
  return [
    for (final k in keys) ChartDatum(k, (counts[k] ?? 0).toDouble(), note: notes?[k]),
  ];
}

List<String> get _categoryOrder => [for (final c in CompetencyCategory.values) c.plural];

List<String> get _levelOrder => [for (var l = CompetencyLevel.min; l <= CompetencyLevel.max; l++) 'L$l ${CompetencyLevel.name(l)}'];

String _levelKey(int level) => 'L$level ${CompetencyLevel.name(level)}';

// ===================================================== 1 all competencies

_Built _competencyInventory(_Context c, ReportGrouping g) {
  final comps = c.competencies;
  final peopleCount = c.employees.length;
  final reqs = c.requirements();
  final reqBy = <String, List<_Req>>{};
  for (final r in reqs) {
    (reqBy[r.competency.id] ??= <_Req>[]).add(r);
  }

  final rows = <ReportRow>[];
  var holdings = 0;
  var levelSum = 0;
  var heldBySomeone = 0;
  var shortComps = 0;
  final byCategory = <String, int>{};
  final byCompetency = <String, int>{};
  final byLevel = <String, int>{};
  for (final comp in comps) {
    final holders = comp.holders.where((h) => c.employeeIds.contains(h.employeeId)).toList();
    final count = holders.length;
    final levels = holders.fold<int>(0, (s, h) => s + h.level);
    holdings += count;
    levelSum += levels;
    if (count > 0) heldBySomeone++;
    _count(byCategory, comp.category.plural, count);
    if (count > 0) byCompetency[comp.name] = count;
    for (final h in holders) {
      _count(byLevel, _levelKey(h.level));
    }
    final needs = reqBy[comp.id] ?? const <_Req>[];
    final highest = needs.isEmpty
        ? null
        : needs.fold<int>(0, (m, r) => (r.requiredLevel ?? 0) > m ? (r.requiredLevel ?? 0) : m);
    final short = needs.where((r) => r.isGap).length;
    if (short > 0) shortComps++;
    final projects = <String>{for (final r in needs) for (final s in r.sources) s.project.code}.toList()..sort();
    rows.add(ReportRow(
      [
        comp.category.label,
        comp.name,
        count,
        _pct(count, peopleCount),
        holders.where((h) => h.verified).length,
        count == 0 ? null : levels / count,
        holders.where((h) => h.level >= 4).length,
        highest,
        needs.length,
        short,
        projects.isEmpty ? '—' : projects.join(', '),
      ],
      competencyId: comp.id,
      alert: short > 0,
    ));
  }
  rows.sort((a, b) {
    final byCount = compareReportCells(b.cells[2], a.cells[2]);
    return byCount != 0 ? byCount : compareReportCells(a.cells[1], b.cells[1]);
  });

  final ReportChart chart = switch (g) {
    ReportGrouping.competency => ReportChart(
        title: 'Employees per competency',
        valueLabel: 'Employees',
        data: _data(byCompetency),
      ),
    ReportGrouping.level => ReportChart(
        title: 'Holdings by level',
        valueLabel: 'Holdings',
        data: _data(byLevel, order: _levelOrder),
        ordered: true,
        palette: ChartPalette.levels,
      ),
    _ => ReportChart(
        title: 'Holdings by category',
        valueLabel: 'Holdings',
        data: _data(byCategory, order: _categoryOrder),
        ordered: true,
      ),
  };

  return _Built(
    columns: const [
      ReportColumn('Category', flex: 9),
      ReportColumn('Competency', flex: 16),
      ReportColumn('Employees', kind: CellKind.number, flex: 8),
      ReportColumn('Share of people', kind: CellKind.percent, flex: 8),
      ReportColumn('Verified', kind: CellKind.number, flex: 7),
      ReportColumn('Average level', kind: CellKind.decimal, flex: 8),
      ReportColumn('At L4–L5', kind: CellKind.number, flex: 7),
      ReportColumn('Highest level needed', kind: CellKind.level, flex: 9),
      ReportColumn('People needing it', kind: CellKind.number, flex: 8),
      ReportColumn('Below the need', kind: CellKind.number, flex: 8),
      ReportColumn('Projects', flex: 14),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Competencies', '${comps.length}', caption: '$heldBySomeone held by someone'),
      ReportKpi('Holdings', '$holdings',
          caption: holdings == 0 ? 'Across $peopleCount people' : 'Average level ${_one(levelSum / holdings)}'),
      ReportKpi('Not held by anyone', '${comps.length - heldBySomeone}', alert: comps.length - heldBySomeone > 0),
      ReportKpi('Short of project needs', '$shortComps', caption: 'Competencies with people below', alert: shortComps > 0),
    ],
    chart: chart,
  );
}

// ================================================== 2 proficiency levels

_Built _levelDistribution(_Context c, ReportGrouping g) {
  final perLevel = List<int>.filled(CompetencyLevel.count, 0);
  final verifiedPerLevel = List<int>.filled(CompetencyLevel.count, 0);
  final perLevelCategory = <String, int>{};
  final byCategory = <String, int>{};
  var total = 0;
  var verified = 0;
  var levelSum = 0;
  for (final comp in c.competencies) {
    for (final h in comp.holders) {
      if (!c.employeeIds.contains(h.employeeId)) continue;
      final level = h.level.clamp(CompetencyLevel.min, CompetencyLevel.max).toInt();
      perLevel[level]++;
      if (h.verified) {
        verifiedPerLevel[level]++;
        verified++;
      }
      _count(perLevelCategory, '$level|${comp.category.name}');
      _count(byCategory, comp.category.plural);
      total++;
      levelSum += level;
    }
  }
  final rows = <ReportRow>[
    for (var l = CompetencyLevel.min; l <= CompetencyLevel.max; l++)
      ReportRow([
        l,
        CompetencyLevel.name(l),
        perLevel[l],
        _pct(perLevel[l], total),
        verifiedPerLevel[l],
        for (final cat in CompetencyCategory.values) perLevelCategory['$l|${cat.name}'] ?? 0,
      ]),
  ];
  final advanced = perLevel[4] + perLevel[5];
  final ReportChart chart = g == ReportGrouping.category
      ? ReportChart(
          title: 'Holdings by category',
          valueLabel: 'Holdings',
          data: _data(byCategory, order: _categoryOrder),
          ordered: true,
        )
      : ReportChart(
          title: 'Holdings by level',
          valueLabel: 'Holdings',
          data: [
            for (var l = CompetencyLevel.min; l <= CompetencyLevel.max; l++)
              ChartDatum(_levelKey(l), perLevel[l].toDouble(), note: '${verifiedPerLevel[l]} verified'),
          ],
          ordered: true,
          palette: ChartPalette.levels,
        );
  return _Built(
    columns: [
      const ReportColumn('Level', kind: CellKind.level, flex: 6),
      const ReportColumn('Name', flex: 10),
      const ReportColumn('Holdings', kind: CellKind.number, flex: 8),
      const ReportColumn('Share', kind: CellKind.percent, flex: 7),
      const ReportColumn('Verified', kind: CellKind.number, flex: 7),
      for (final cat in CompetencyCategory.values) ReportColumn(cat.plural, kind: CellKind.number, flex: 7),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Holdings', '$total', caption: 'Employee × competency'),
      ReportKpi('Verified', '${_pct(verified, total)}%', caption: '$verified confirmed by a Team Lead or HR'),
      ReportKpi('At L4–L5', '$advanced', caption: '${_pct(advanced, total)}% advanced or expert'),
      ReportKpi('Average level', total == 0 ? '—' : _one(levelSum / total)),
    ],
    chart: chart,
  );
}

// =========================================== 3 employees & competency sets

_Built _employeeCompetencies(_Context c, ReportGrouping g) {
  final competencies = CompetencyRepository.instance;
  final additional = AdditionalCompetencyRepository.instance;
  final rows = <ReportRow>[];
  final byUnit = <String, int>{};
  final bySize = <String, int>{};
  var total = 0;
  var verifiedTotal = 0;
  var withNone = 0;
  const sizeOrder = ['None', '1–2', '3–5', '6–9', '10 or more'];
  for (final e in c.people) {
    final held = competencies.levelsFor(e.id).where((h) => c.competencyMatch(h.competency)).toList();
    if (c.filters.competencyId != null && held.isEmpty) continue;
    final info = c.insight(e);
    final verified = held.where((h) => h.verified).length;
    final extra = additional.forEmployee(e.id);
    total += held.length;
    verifiedTotal += verified;
    if (held.isEmpty) withNone++;
    _count(byUnit, g == ReportGrouping.role ? c.roleOf(e) : c.departmentOf(e));
    final n = held.length;
    _count(bySize, n == 0 ? sizeOrder[0] : (n <= 2 ? sizeOrder[1] : (n <= 5 ? sizeOrder[2] : (n <= 9 ? sizeOrder[3] : sizeOrder[4]))));
    rows.add(ReportRow(
      [
        e.id,
        e.name,
        c.divisionOf(e),
        c.groupOf(e),
        c.departmentOf(e),
        e.designation.isEmpty ? '—' : e.designation,
        c.roleOf(e),
        n,
        held.isEmpty
            ? '—'
            : held.map((h) => '${h.competency.name} L${h.level}${h.verified ? '' : ' (self)'}').join(' · '),
        verified,
        extra.isEmpty ? '—' : extra.map((a) => a.name).join(', '),
        info.projects.length,
        info.readiness,
      ],
      employeeId: e.id,
    ));
  }
  final people = rows.length;
  final ReportChart chart = g == ReportGrouping.competencyCount
      ? ReportChart(
          title: 'Competencies per person',
          valueLabel: 'Employees',
          data: _data(bySize, order: sizeOrder),
          ordered: true,
          palette: ChartPalette.levels,
        )
      : ReportChart(
          title: g == ReportGrouping.role ? 'Employees by role' : 'Employees by department',
          valueLabel: 'Employees',
          data: _data(byUnit),
        );
  return _Built(
    columns: const [
      ReportColumn('Employee ID', flex: 8),
      ReportColumn('Name', flex: 12),
      ReportColumn('Division', flex: 11),
      ReportColumn('Group', flex: 11),
      ReportColumn('Department', flex: 11),
      ReportColumn('Designation', flex: 12),
      ReportColumn('Role', flex: 10),
      ReportColumn('Competencies', kind: CellKind.number, flex: 7),
      ReportColumn('Competency set (level)', flex: 30),
      ReportColumn('Verified', kind: CellKind.number, flex: 6),
      ReportColumn('Additional skills', flex: 12),
      ReportColumn('Projects', kind: CellKind.number, flex: 6),
      ReportColumn('Readiness', kind: CellKind.percent, flex: 7),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Employees', '$people'),
      ReportKpi('Competencies per person', people == 0 ? '—' : _one(total / people), caption: '$total holdings'),
      ReportKpi('Verified', '${_pct(verifiedTotal, total)}%', caption: 'Of all holdings'),
      ReportKpi('Without any competency', '$withNone', alert: withNone > 0),
    ],
    chart: chart,
  );
}

// ================================================= 4 headcount by org unit

_Built _headcount(_Context c, ReportGrouping g) {
  final structure = OrgStructureRepository.instance;
  final employees = EmployeeRepository.instance;
  final departments = structure.departments.value.where((d) => c.departmentIds.contains(d.id)).toList()
    ..sort((a, b) {
      final byDivision = structure.divisionNameOfDepartment(a.id).compareTo(structure.divisionNameOfDepartment(b.id));
      if (byDivision != 0) return byDivision;
      final byGroup = structure.groupNameOfDepartment(a.id).compareTo(structure.groupNameOfDepartment(b.id));
      return byGroup != 0 ? byGroup : a.name.compareTo(b.name);
    });
  final rows = <ReportRow>[];
  final byUnit = <String, int>{};
  var onProjects = 0;
  for (final d in departments) {
    final people = c.employees.where((e) => e.departmentId == d.id).toList();
    final insights = [for (final e in people) c.insight(e)];
    final allocated = insights.where((i) => i.projects.isNotEmpty).length;
    final ready = insights.where((i) => i.readiness != null).toList();
    onProjects += allocated;
    final unit = switch (g) {
      ReportGrouping.division => structure.divisionNameOfDepartment(d.id),
      ReportGrouping.group => structure.groupNameOfDepartment(d.id),
      _ => d.name,
    };
    _count(byUnit, unit, people.length);
    final headId = d.headId;
    rows.add(ReportRow([
      structure.divisionNameOfDepartment(d.id),
      structure.groupNameOfDepartment(d.id),
      d.name,
      headId == null ? '—' : employees.nameOf(headId),
      people.length,
      allocated,
      people.length - allocated,
      ready.isEmpty ? null : (ready.fold<int>(0, (s, i) => s + (i.readiness ?? 0)) / ready.length).round(),
      insights.fold<int>(0, (s, i) => s + i.gapCount),
    ], alert: people.length - allocated > 0));
  }
  final total = c.employees.length;
  final divisionCount = {for (final d in departments) structure.divisionNameOfDepartment(d.id)}.length;
  return _Built(
    columns: const [
      ReportColumn('Division', flex: 12),
      ReportColumn('Group', flex: 12),
      ReportColumn('Department', flex: 12),
      ReportColumn('Head', flex: 11),
      ReportColumn('Employees', kind: CellKind.number, flex: 8),
      ReportColumn('On projects', kind: CellKind.number, flex: 8),
      ReportColumn('Not on a project', kind: CellKind.number, flex: 8),
      ReportColumn('Average readiness', kind: CellKind.percent, flex: 8),
      ReportColumn('Open gaps', kind: CellKind.number, flex: 7),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Employees', '$total', caption: _plural(departments.length, 'department')),
      ReportKpi('On projects', '$onProjects', caption: '${_pct(onProjects, total)}% of people'),
      ReportKpi('Not on a project', '${total - onProjects}', alert: total - onProjects > 0),
      ReportKpi('Divisions', '$divisionCount'),
    ],
    chart: ReportChart(
      title: 'Employees ${g.byLabel.toLowerCase()}',
      valueLabel: 'Employees',
      data: _data(byUnit),
    ),
  );
}

// ================================================ 5 overall readiness

_Built _orgReadiness(_Context c, ReportGrouping g) {
  final reqs = c.requirements();
  final byComp = <String, List<_Req>>{};
  for (final r in reqs) {
    (byComp[r.competency.id] ??= <_Req>[]).add(r);
  }
  final rows = <ReportRow>[];
  final pairsByCategory = <String, List<int>>{}; // [have, needed]
  var met = 0;
  var below = 0;
  var missing = 0;
  for (final entry in byComp.entries) {
    final list = entry.value;
    final comp = list.first.competency;
    final have = list.where((r) => !r.isGap).length;
    final under = list.where((r) => r.isGap && r.heldLevel != null).length;
    final none = list.where((r) => r.heldLevel == null).length;
    met += have;
    below += under;
    missing += none;
    final highest = list.fold<int>(0, (m, r) => (r.requiredLevel ?? 0) > m ? (r.requiredLevel ?? 0) : m);
    final projects = <String>{for (final r in list) for (final s in r.sources) s.project.code}.toList()..sort();
    final pair = pairsByCategory[comp.category.plural] ??= <int>[0, 0];
    pair[0] += have;
    pair[1] += list.length;
    rows.add(ReportRow(
      [
        comp.category.label,
        comp.name,
        highest,
        list.length,
        have,
        under,
        none,
        _pct(have, list.length),
        projects.join(', '),
      ],
      competencyId: comp.id,
      alert: have < list.length,
    ));
  }
  rows.sort((a, b) {
    final shortA = (a.cells[3] as int) - (a.cells[4] as int);
    final shortB = (b.cells[3] as int) - (b.cells[4] as int);
    final byShort = shortB.compareTo(shortA);
    return byShort != 0 ? byShort : compareReportCells(a.cells[1], b.cells[1]);
  });

  final reached = reqs.fold<int>(0, (s, r) => s + r.reached);
  final needed = reqs.fold<int>(0, (s, r) => s + r.needed);
  final byPerson = <String, bool>{};
  for (final r in reqs) {
    byPerson[r.employee.id] = (byPerson[r.employee.id] ?? true) && !r.isGap;
  }
  final ready = byPerson.values.where((v) => v).length;

  final ReportChart chart = switch (g) {
    ReportGrouping.status => ReportChart(
        title: 'Requirements by status',
        valueLabel: 'Requirements',
        data: [
          ChartDatum('Met', met.toDouble()),
          ChartDatum('Below the level', below.toDouble()),
          ChartDatum('Not acquired', missing.toDouble()),
        ],
        ordered: true,
        palette: ChartPalette.gaps,
      ),
    ReportGrouping.category => ReportChart(
        title: 'Have vs need by category',
        valueLabel: 'Have the level',
        secondaryLabel: 'Needed',
        data: [
          for (final cat in _categoryOrder)
            if (pairsByCategory[cat] case final List<int> p)
              ChartDatum(cat, p[0].toDouble(), secondary: p[1].toDouble()),
        ],
        palette: ChartPalette.paired,
        pieAllowed: false,
      ),
    _ => ReportChart(
        title: 'Have vs need per competency',
        valueLabel: 'Have the level',
        secondaryLabel: 'Needed',
        data: [
          for (final row in rows)
            ChartDatum('${row.cells[1]}', (row.cells[4] as int).toDouble(),
                secondary: (row.cells[3] as int).toDouble(), note: 'Needed at up to L${row.cells[2]}'),
        ],
        ordered: true,
        palette: ChartPalette.paired,
        pieAllowed: false,
      ),
  };

  return _Built(
    columns: const [
      ReportColumn('Category', flex: 8),
      ReportColumn('Competency', flex: 15),
      ReportColumn('Highest level needed', kind: CellKind.level, flex: 9),
      ReportColumn('People needing it', kind: CellKind.number, flex: 9),
      ReportColumn('Have the level', kind: CellKind.number, flex: 8),
      ReportColumn('Below the level', kind: CellKind.number, flex: 8),
      ReportColumn('Not acquired', kind: CellKind.number, flex: 8),
      ReportColumn('Coverage', kind: CellKind.percent, flex: 8),
      ReportColumn('Projects', flex: 14),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Overall readiness', needed == 0 ? '—' : '${_pct(reached, needed)}%',
          caption: 'Level-weighted, of what projects need'),
      ReportKpi('Requirements met', '$met of ${reqs.length}', caption: '${_pct(met, reqs.length)}% of person × competency'),
      ReportKpi('Fully ready people', '$ready of ${byPerson.length}', caption: 'Every project need met'),
      ReportKpi('Open gaps', '${below + missing}', caption: '$below below the level · $missing not acquired',
          alert: below + missing > 0),
    ],
    chart: chart,
    note: reqs.isEmpty ? 'No project needs anything from the people in this scope yet.' : null,
  );
}

// ================================================== 6 readiness by team

_Built _teamReadiness(_Context c, ReportGrouping g) {
  final units = <String, List<EmployeeProfile>>{};
  for (final e in c.people) {
    (units[c.unitOf(e, g)] ??= <EmployeeProfile>[]).add(e);
  }
  final rows = <ReportRow>[];
  final chartData = <ChartDatum>[];
  var below60 = 0;
  var allReady = 0;
  var gapsTotal = 0;
  final readinessAll = <int>[];
  final keys = units.keys.toList()..sort();
  for (final key in keys) {
    final people = units[key] ?? const <EmployeeProfile>[];
    final insights = [for (final e in people) c.insight(e)];
    final withNeeds = insights.where((i) => i.readiness != null).toList();
    final average = withNeeds.isEmpty
        ? null
        : (withNeeds.fold<int>(0, (s, i) => s + (i.readiness ?? 0)) / withNeeds.length).round();
    final ready = withNeeds.where((i) => i.readiness == 100).length;
    final requirements = insights.fold<int>(0, (s, i) => s + i.requiredCount);
    final met = insights.fold<int>(0, (s, i) => s + i.metCount);
    final gaps = insights.fold<int>(0, (s, i) => s + i.gapCount);
    final gapNames = <String, int>{};
    for (final i in insights) {
      for (final r in i.rows) {
        if (r.state.isGap) _count(gapNames, r.competency.name);
      }
    }
    String biggest = '—';
    if (gapNames.isNotEmpty) {
      final top = gapNames.entries.reduce((a, b) => b.value > a.value ? b : a);
      biggest = '${top.key} (${top.value})';
    }
    allReady += ready;
    gapsTotal += gaps;
    for (final i in withNeeds) {
      readinessAll.add(i.readiness ?? 0);
    }
    if (average != null && average < 60) below60++;
    rows.add(ReportRow(
      [key, people.length, withNeeds.length, average, ready, requirements, met, gaps, biggest],
      alert: average != null && average < 60,
    ));
    if (average != null) {
      chartData.add(ChartDatum(key, average.toDouble(), note: '${_plural(withNeeds.length, 'person', 'people')} with project needs'));
    }
  }
  chartData.sort((a, b) => b.value.compareTo(a.value));
  final overall = readinessAll.isEmpty ? null : (readinessAll.fold<int>(0, (s, v) => s + v) / readinessAll.length).round();
  return _Built(
    columns: [
      ReportColumn(g.label, flex: 16),
      const ReportColumn('Employees', kind: CellKind.number, flex: 8),
      const ReportColumn('With project needs', kind: CellKind.number, flex: 9),
      const ReportColumn('Average readiness', kind: CellKind.percent, flex: 9),
      const ReportColumn('Fully ready', kind: CellKind.number, flex: 8),
      const ReportColumn('Requirements', kind: CellKind.number, flex: 8),
      const ReportColumn('Met', kind: CellKind.number, flex: 6),
      const ReportColumn('Gaps', kind: CellKind.number, flex: 6),
      const ReportColumn('Most common gap', flex: 14),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Average readiness', overall == null ? '—' : '$overall%', caption: 'Of people with project needs'),
      ReportKpi('Fully ready people', '$allReady', caption: 'Every project need met'),
      ReportKpi('${g.label}s below 60%', '$below60', alert: below60 > 0),
      ReportKpi('Open gaps', '$gapsTotal', alert: gapsTotal > 0),
    ],
    chart: ReportChart(
      title: 'Average readiness ${g.byLabel.toLowerCase()}',
      valueLabel: 'Average readiness',
      data: chartData,
      unit: '%',
      pieAllowed: false,
    ),
  );
}

// ======================================== 7 current vs required (gaps)

_Built _currentVsRequired(_Context c, ReportGrouping g) {
  var reqs = c.requirements(includeNotRequired: c.filters.includeNotRequired);
  if (c.filters.gapsOnly) reqs = reqs.where((r) => r.isGap).toList();
  reqs.sort((a, b) {
    final byName = a.employee.name.toLowerCase().compareTo(b.employee.name.toLowerCase());
    if (byName != 0) return byName;
    final bySize = b.size.compareTo(a.size);
    return bySize != 0 ? bySize : a.competency.name.toLowerCase().compareTo(b.competency.name.toLowerCase());
  });
  final rows = <ReportRow>[
    for (final r in reqs)
      ReportRow(
        [
          r.employee.id,
          r.employee.name,
          c.divisionOf(r.employee),
          c.groupOf(r.employee),
          c.departmentOf(r.employee),
          c.roleOf(r.employee),
          r.competency.category.label,
          r.competency.name,
          r.heldLevel,
          r.requiredLevel,
          r.isRequired ? -r.size : null,
          r.isRequired ? gapRangeLabel(r.size) : 'Not required',
          r.projectsText,
        ],
        employeeId: r.employee.id,
        competencyId: r.competency.id,
        alert: r.isGap,
      ),
  ];
  final required = reqs.where((r) => r.isRequired).toList();
  final gaps = required.where((r) => r.isGap).toList();
  final metCount = required.length - gaps.length;
  final peopleShort = {for (final r in gaps) r.employee.id}.length;
  final sizeSum = gaps.fold<int>(0, (s, r) => s + r.size);

  final ReportChart chart;
  if (g == ReportGrouping.competency || g == ReportGrouping.department) {
    final counts = <String, int>{};
    for (final r in gaps) {
      _count(counts, g == ReportGrouping.competency ? r.competency.name : c.departmentOf(r.employee));
    }
    chart = ReportChart(
      title: g == ReportGrouping.competency ? 'People short per competency' : 'Gaps per department',
      valueLabel: g == ReportGrouping.competency ? 'People short' : 'Gaps',
      data: _data(counts),
    );
  } else {
    final counts = <String, int>{};
    for (final r in required) {
      _count(counts, gapRangeLabel(r.size));
    }
    chart = ReportChart(
      title: 'Requirements by gap range',
      valueLabel: 'Requirements',
      data: _data(counts, order: gapRangeLabels),
      ordered: true,
      palette: ChartPalette.gaps,
    );
  }

  return _Built(
    columns: const [
      ReportColumn('Employee ID', flex: 8),
      ReportColumn('Name', flex: 12),
      ReportColumn('Division', flex: 11),
      ReportColumn('Group', flex: 11),
      ReportColumn('Department', flex: 11),
      ReportColumn('Role', flex: 10),
      ReportColumn('Category', flex: 8),
      ReportColumn('Competency', flex: 12),
      ReportColumn('Current level', kind: CellKind.level, flex: 7),
      ReportColumn('Required level', kind: CellKind.level, flex: 7),
      ReportColumn('Gap', kind: CellKind.gap, flex: 6),
      ReportColumn('Gap range', flex: 10),
      ReportColumn('Required by projects', flex: 16),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Requirements', '${required.length}', caption: _plural({for (final r in required) r.employee.id}.length, 'person', 'people')),
      ReportKpi('Met', '$metCount', caption: '${_pct(metCount, required.length)}% of requirements'),
      ReportKpi('Gaps', '${gaps.length}', caption: '${_plural(peopleShort, 'person', 'people')} short', alert: gaps.isNotEmpty),
      ReportKpi('Average gap', gaps.isEmpty ? '—' : _one(sizeSum / gaps.length), caption: 'Levels short per gap'),
    ],
    chart: chart,
  );
}

// ======================================================== 8 top skill gaps

_Built _topGaps(_Context c, ReportGrouping g) {
  final gaps = c.requirements().where((r) => r.isGap).toList();
  final byComp = <String, List<_Req>>{};
  for (final r in gaps) {
    (byComp[r.competency.id] ??= <_Req>[]).add(r);
  }
  final plans = TrainingPlanRepository.instance;
  final approvals = ApprovalRepository.instance;
  final rows = <ReportRow>[];
  final byCategory = <String, int>{};
  var withPlan = 0;
  var pending = 0;
  for (final list in byComp.values) {
    final comp = list.first.competency;
    final planned = list.where((r) => plans.forCompetency(r.employee.id, comp.id).isNotEmpty).length;
    final waiting = list.where((r) => approvals.pendingFor(r.employee.id, comp.id) != null).length;
    final largest = list.fold<int>(0, (m, r) => r.size > m ? r.size : m);
    final sizeSum = list.fold<int>(0, (s, r) => s + r.size);
    final projects = <String>{for (final r in list) for (final s in r.sources) s.project.code}.toList()..sort();
    withPlan += planned;
    pending += waiting;
    _count(byCategory, comp.category.plural, list.length);
    rows.add(ReportRow(
      [
        comp.name,
        comp.category.label,
        list.length,
        sizeSum / list.length,
        -largest,
        planned,
        list.length - planned,
        waiting,
        projects.join(', '),
      ],
      competencyId: comp.id,
      alert: list.length - planned > 0,
    ));
  }
  rows.sort((a, b) {
    final byPeople = compareReportCells(b.cells[2], a.cells[2]);
    return byPeople != 0 ? byPeople : compareReportCells(b.cells[3], a.cells[3]);
  });
  final ReportChart chart = g == ReportGrouping.category
      ? ReportChart(
          title: 'Gaps by category',
          valueLabel: 'Gaps',
          data: _data(byCategory, order: _categoryOrder),
          ordered: true,
        )
      : ReportChart(
          title: 'People short per competency',
          valueLabel: 'People short',
          data: [
            for (final row in rows)
              ChartDatum('${row.cells[0]}', (row.cells[2] as int).toDouble(),
                  note: '${row.cells[5]} with a training plan'),
          ],
          ordered: true,
        );
  return _Built(
    columns: const [
      ReportColumn('Competency', flex: 14),
      ReportColumn('Category', flex: 8),
      ReportColumn('People short', kind: CellKind.number, flex: 8),
      ReportColumn('Average gap (levels)', kind: CellKind.decimal, flex: 8),
      ReportColumn('Largest gap', kind: CellKind.gap, flex: 7),
      ReportColumn('With a training plan', kind: CellKind.number, flex: 9),
      ReportColumn('Without a plan', kind: CellKind.number, flex: 8),
      ReportColumn('Level-up pending', kind: CellKind.number, flex: 8),
      ReportColumn('Projects', flex: 14),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Competencies short', '${rows.length}', alert: rows.isNotEmpty),
      ReportKpi('People short', '${{for (final r in gaps) r.employee.id}.length}', caption: _plural(gaps.length, 'gap')),
      ReportKpi('Gaps with a plan', '${_pct(withPlan, gaps.length)}%', caption: '$withPlan of ${gaps.length}'),
      ReportKpi('Level-ups pending', '$pending', caption: 'Waiting for HR'),
    ],
    chart: chart,
  );
}

// ===================================================== 9 project staffing

_Built _projectStaffing(_Context c, ReportGrouping g) {
  final employees = EmployeeRepository.instance;
  final structure = OrgStructureRepository.instance;
  final projects = c.projects;
  final rows = <ReportRow>[];
  final byStatus = <String, int>{};
  final byDepartment = <String, int>{};
  final matchData = <ChartDatum>[];
  final allocated = <String>{};
  var openSeats = 0;
  var matchSum = 0;
  for (final p in projects) {
    final members = p.memberIds.where((id) => employees.byId(id)?.isActive ?? false).toList();
    allocated.addAll(members);
    final planned = p.plannedTeamSize;
    final open = planned > members.length ? planned - members.length : 0;
    openSeats += open;
    final match = Insights.projectMatch(p);
    matchSum += match;
    final missing = Insights.projectMissing(p);
    _count(byStatus, p.status.label);
    _count(byDepartment, structure.departmentName(p.departmentId), members.length);
    matchData.add(ChartDatum(p.code, match.toDouble(), note: p.name));
    final managerId = p.managerId;
    rows.add(ReportRow(
      [
        p.code,
        p.name,
        p.customer.isEmpty ? '—' : p.customer,
        structure.departmentName(p.departmentId),
        p.status.label,
        p.dateRange,
        members.length,
        planned,
        open,
        match,
        missing.isEmpty ? '—' : missing.map((m) => m.name).join(', '),
        managerId == null ? '—' : employees.nameOf(managerId),
      ],
      projectId: p.id,
      alert: open > 0 || missing.isNotEmpty,
    ));
  }
  matchData.sort((a, b) => a.value.compareTo(b.value));
  final ReportChart chart = switch (g) {
    ReportGrouping.status => ReportChart(
        title: 'Projects by status',
        valueLabel: 'Projects',
        data: _data(byStatus, order: [
          for (final s in ProjectStatus.values)
            if (s != ProjectStatus.completed) s.label,
        ]),
        ordered: true,
      ),
    ReportGrouping.department => ReportChart(
        title: 'Team members by department',
        valueLabel: 'Team members',
        data: _data(byDepartment),
      ),
    _ => ReportChart(
        title: 'Team match per project',
        valueLabel: 'Team match',
        data: matchData,
        unit: '%',
        ordered: true,
        pieAllowed: false,
      ),
  };
  return _Built(
    columns: const [
      ReportColumn('Code', flex: 8),
      ReportColumn('Project', flex: 14),
      ReportColumn('Customer', flex: 11),
      ReportColumn('Department', flex: 10),
      ReportColumn('Status', flex: 7),
      ReportColumn('Period', flex: 12),
      ReportColumn('Team', kind: CellKind.number, flex: 6),
      ReportColumn('Planned', kind: CellKind.number, flex: 6),
      ReportColumn('Open seats', kind: CellKind.number, flex: 6),
      ReportColumn('Team match', kind: CellKind.percent, flex: 7),
      ReportColumn('Not covered yet', flex: 15),
      ReportColumn('Project manager', flex: 11),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Open projects', '${projects.length}'),
      ReportKpi('People allocated', '${allocated.length}', caption: 'On at least one of them'),
      ReportKpi('Open seats', '$openSeats', caption: 'Planned team size not reached', alert: openSeats > 0),
      ReportKpi('Average team match', projects.isEmpty ? '—' : '${(matchSum / projects.length).round()}%'),
    ],
    chart: chart,
  );
}

// =================================================== 10 project allocation

_Built _projectAllocation(_Context c, ReportGrouping g) {
  final rows = <ReportRow>[];
  const bucketOrder = ['Not on a project', '1 project', '2 projects', '3 or more'];
  final buckets = <String, int>{};
  final byProject = <String, int>{};
  final byDepartment = <String, int>{};
  var allocated = 0;
  var three = 0;
  var projectTotal = 0;
  for (final e in c.people) {
    final info = c.insight(e);
    final projects = info.projects;
    final n = projects.length;
    projectTotal += n;
    if (n > 0) allocated++;
    if (n >= 3) three++;
    _count(buckets, n == 0 ? bucketOrder[0] : (n == 1 ? bucketOrder[1] : (n == 2 ? bucketOrder[2] : bucketOrder[3])));
    if (n > 0) _count(byDepartment, c.departmentOf(e));
    final fits = [for (final p in projects) Insights.fit(e, p)];
    for (final p in projects) {
      _count(byProject, p.code);
    }
    rows.add(ReportRow(
      [
        e.id,
        e.name,
        c.departmentOf(e),
        c.roleOf(e),
        n,
        fits.isEmpty ? '—' : fits.map((f) => '${f.project.code} (${f.percent}% fit)').join(' · '),
        fits.isEmpty ? null : (fits.fold<int>(0, (s, f) => s + f.percent) / fits.length).round(),
        info.gapCount,
      ],
      employeeId: e.id,
      alert: n == 0,
    ));
  }
  final people = c.people.length;
  final ReportChart chart = switch (g) {
    ReportGrouping.project => ReportChart(
        title: 'People per project',
        valueLabel: 'People',
        data: _data(byProject),
      ),
    ReportGrouping.department => ReportChart(
        title: 'Allocated people by department',
        valueLabel: 'Allocated people',
        data: _data(byDepartment),
      ),
    _ => ReportChart(
        title: 'Projects per person',
        valueLabel: 'Employees',
        data: _data(buckets, order: bucketOrder),
        ordered: true,
      ),
  };
  return _Built(
    columns: const [
      ReportColumn('Employee ID', flex: 8),
      ReportColumn('Name', flex: 13),
      ReportColumn('Department', flex: 11),
      ReportColumn('Role', flex: 11),
      ReportColumn('Projects', kind: CellKind.number, flex: 6),
      ReportColumn('Allocated to (fit)', flex: 26),
      ReportColumn('Average fit', kind: CellKind.percent, flex: 7),
      ReportColumn('Gaps from projects', kind: CellKind.number, flex: 8),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Allocated', '$allocated of $people', caption: '${_pct(allocated, people)}% on a project'),
      ReportKpi('Not on a project', '${people - allocated}', alert: people - allocated > 0),
      ReportKpi('Projects per person', people == 0 ? '—' : _one(projectTotal / people), caption: 'Average'),
      ReportKpi('On 3 or more', '$three', caption: 'Check the load'),
    ],
    chart: chart,
  );
}

// ======================================================= 11 training plans

_Built _trainingPlans(_Context c, ReportGrouping g) {
  final repo = TrainingPlanRepository.instance;
  final competencies = CompetencyRepository.instance;
  final now = DateTime.now();
  final rows = <ReportRow>[];
  final byStatus = <String, int>{};
  final byType = <String, int>{};
  final byComp = <String, int>{};
  var inProgress = 0;
  var completed = 0;
  var overdue = 0;
  for (final e in c.people) {
    for (final p in repo.forEmployee(e.id)) {
      final comp = competencies.byId(p.competencyId);
      if (comp == null || !c.competencyMatch(comp)) continue;
      final overdueNow = p.isOverdue(now);
      if (p.status == PlanStatus.inProgress) inProgress++;
      if (p.status == PlanStatus.completed) completed++;
      if (overdueNow) overdue++;
      _count(byStatus, p.status.label);
      _count(byType, p.type.label);
      _count(byComp, comp.name);
      final from = p.currentLevel;
      rows.add(ReportRow(
        [
          p.id,
          e.id,
          e.name,
          c.departmentOf(e),
          comp.name,
          '${from == null ? 'New' : 'L$from'} → L${p.targetLevel}',
          p.type.label,
          p.provider.isEmpty ? '—' : p.provider,
          p.status.label,
          p.startDate,
          p.targetDate,
          p.plannedHours,
          p.completedHours,
          (p.progress * 100).round(),
          overdueNow ? 'Overdue' : 'No',
        ],
        employeeId: e.id,
        competencyId: comp.id,
        alert: overdueNow,
      ));
    }
  }
  final ReportChart chart = switch (g) {
    ReportGrouping.trainingType => ReportChart(title: 'Plans by type', valueLabel: 'Plans', data: _data(byType)),
    ReportGrouping.competency => ReportChart(title: 'Plans per competency', valueLabel: 'Plans', data: _data(byComp)),
    _ => ReportChart(
        title: 'Plans by status',
        valueLabel: 'Plans',
        data: _data(byStatus, order: [for (final s in PlanStatus.values) s.label]),
        ordered: true,
      ),
  };
  return _Built(
    columns: const [
      ReportColumn('Plan', flex: 7),
      ReportColumn('Employee ID', flex: 8),
      ReportColumn('Name', flex: 12),
      ReportColumn('Department', flex: 10),
      ReportColumn('Competency', flex: 11),
      ReportColumn('Levels', flex: 8),
      ReportColumn('Type', flex: 10),
      ReportColumn('Provider', flex: 10),
      ReportColumn('Status', flex: 8),
      ReportColumn('Start', kind: CellKind.date, flex: 9),
      ReportColumn('Target date', kind: CellKind.date, flex: 9),
      ReportColumn('Planned hours', kind: CellKind.number, flex: 7),
      ReportColumn('Hours done', kind: CellKind.number, flex: 7),
      ReportColumn('Progress', kind: CellKind.percent, flex: 7),
      ReportColumn('Overdue', flex: 7),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Training plans', '${rows.length}', caption: _plural({for (final r in rows) r.employeeId}.length, 'person', 'people')),
      ReportKpi('In progress', '$inProgress'),
      ReportKpi('Completed', '$completed'),
      ReportKpi('Overdue', '$overdue', caption: 'Open and past the target date', alert: overdue > 0),
    ],
    chart: chart,
  );
}

// ==================================================== 12 level-up requests

_Built _levelUpRequests(_Context c, ReportGrouping g) {
  final competencies = CompetencyRepository.instance;
  final employees = EmployeeRepository.instance;
  final list = ApprovalRepository.instance.requests.value.where((r) => c.employeeIds.contains(r.employeeId)).toList()
    ..sort((a, b) => b.raisedAt.compareTo(a.raisedAt));
  final rows = <ReportRow>[];
  final byStatus = <String, int>{};
  final byComp = <String, int>{};
  final byDepartment = <String, int>{};
  var pending = 0;
  var approved = 0;
  var belowPolicy = 0;
  for (final r in list) {
    final comp = competencies.byId(r.competencyId);
    if (comp == null || !c.competencyMatch(comp)) continue;
    final e = employees.byId(r.employeeId);
    if (e == null) continue;
    if (r.isPending) pending++;
    if (r.status == ApprovalStatus.approved) approved++;
    if (r.isPending && r.belowPolicy) belowPolicy++;
    _count(byStatus, r.status.label);
    _count(byComp, comp.name);
    _count(byDepartment, c.departmentOf(e));
    final decided = r.decidedAt;
    rows.add(ReportRow(
      [
        r.id,
        e.id,
        e.name,
        c.departmentOf(e),
        comp.name,
        r.fromLevel,
        r.toLevel,
        r.hours,
        r.requiredHours,
        r.raisedByName,
        r.raisedAt,
        r.status.label,
        decided,
      ],
      employeeId: e.id,
      competencyId: comp.id,
      alert: r.isPending && r.belowPolicy,
    ));
  }
  final ReportChart chart = switch (g) {
    ReportGrouping.competency =>
      ReportChart(title: 'Requests per competency', valueLabel: 'Requests', data: _data(byComp)),
    ReportGrouping.department =>
      ReportChart(title: 'Requests by department', valueLabel: 'Requests', data: _data(byDepartment)),
    _ => ReportChart(
        title: 'Requests by status',
        valueLabel: 'Requests',
        data: _data(byStatus, order: [for (final s in ApprovalStatus.values) s.label]),
        ordered: true,
      ),
  };
  return _Built(
    columns: const [
      ReportColumn('Request', flex: 8),
      ReportColumn('Employee ID', flex: 8),
      ReportColumn('Name', flex: 12),
      ReportColumn('Department', flex: 10),
      ReportColumn('Competency', flex: 11),
      ReportColumn('From', kind: CellKind.level, flex: 5),
      ReportColumn('To', kind: CellKind.level, flex: 5),
      ReportColumn('Hours', kind: CellKind.number, flex: 6),
      ReportColumn('Policy hours', kind: CellKind.number, flex: 7),
      ReportColumn('Raised by', flex: 11),
      ReportColumn('Raised on', kind: CellKind.date, flex: 9),
      ReportColumn('Status', flex: 8),
      ReportColumn('Decided on', kind: CellKind.date, flex: 9),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Requests', '${rows.length}'),
      ReportKpi('Pending', '$pending', caption: 'Waiting for HR', alert: pending > 0),
      ReportKpi('Approved', '$approved'),
      ReportKpi('Pending below hours policy', '$belowPolicy', alert: belowPolicy > 0),
    ],
    chart: chart,
    note: 'From: "—" means the competency was new for the employee.',
  );
}

// ===================================================== 13 additional skills

_Built _additionalSkills(_Context c, ReportGrouping g) {
  final repo = AdditionalCompetencyRepository.instance;
  final skills = <String, List<EmployeeProfile>>{};
  final display = <String, String>{};
  final byDepartment = <String, int>{};
  var entries = 0;
  final withAny = <String>{};
  for (final e in c.people) {
    final list = repo.forEmployee(e.id);
    if (list.isEmpty) continue;
    withAny.add(e.id);
    _count(byDepartment, c.departmentOf(e));
    for (final a in list) {
      final key = nameKey(a.name);
      display[key] ??= a.name;
      (skills[key] ??= <EmployeeProfile>[]).add(e);
      entries++;
    }
  }
  final people = c.people.length;
  final keys = skills.keys.toList()
    ..sort((a, b) {
      final byCount = (skills[b]?.length ?? 0).compareTo(skills[a]?.length ?? 0);
      return byCount != 0 ? byCount : (display[a] ?? a).compareTo(display[b] ?? b);
    });
  final rows = <ReportRow>[
    for (final k in keys)
      ReportRow([
        display[k] ?? k,
        skills[k]?.length ?? 0,
        _pct(skills[k]?.length ?? 0, people),
        {for (final e in skills[k] ?? const <EmployeeProfile>[]) c.departmentOf(e)}.join(', '),
        (skills[k] ?? const <EmployeeProfile>[]).map((e) => '${e.name} (${e.id})').join(', '),
      ]),
  ];
  final top = keys.isEmpty ? '—' : (display[keys.first] ?? keys.first);
  return _Built(
    columns: const [
      ReportColumn('Skill', flex: 12),
      ReportColumn('People', kind: CellKind.number, flex: 6),
      ReportColumn('Share of people', kind: CellKind.percent, flex: 7),
      ReportColumn('Departments', flex: 14),
      ReportColumn('Employees', flex: 26),
    ],
    rows: rows,
    kpis: [
      ReportKpi('Different skills', '${keys.length}'),
      ReportKpi('People with extra skills', '${withAny.length}', caption: '${_pct(withAny.length, people)}% of people'),
      ReportKpi('Entries', '$entries'),
      ReportKpi('Most common', top),
    ],
    chart: g == ReportGrouping.department
        ? ReportChart(title: 'People with extra skills by department', valueLabel: 'People', data: _data(byDepartment))
        : ReportChart(
            title: 'People per skill',
            valueLabel: 'People',
            data: [for (final k in keys) ChartDatum(display[k] ?? k, (skills[k]?.length ?? 0).toDouble())],
            ordered: true,
          ),
    note: 'Self-declared by employees, outside the competency library; not verified.',
  );
}
