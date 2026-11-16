// Reports & dashboards: the report catalogue and the shapes a report
// produces (columns + rows for the table and the export, one chart, a few
// key numbers).
//
// Every report is worked out from the live data (employees, competency
// levels, projects, plans, approvals) – nothing is stored. The Spring Boot
// API should run the same calculations server-side later
// (GET /api/reports/{type}?filters…, see CHANGES-reports-and-allocation.md),
// always limited to the caller's scope: HRD = whole organisation, Team Lead =
// own department (taken from the JWT, never from the request).

import '../../admin/data/admin_base.dart';
import '../../competency/data/competency_models.dart';

/// Groups of reports in the catalogue.
enum ReportDataset {
  competencies('Competencies', 'The competency library and who holds what, at which level.'),
  employees('Employees', 'People, their competency sets and where they sit.'),
  readiness('Readiness & gaps', 'What projects need against what people have.'),
  projects('Projects', 'Staffing, team match and who is allocated where.'),
  development('Development', 'Training plans, level-up requests and self-declared skills.');

  const ReportDataset(this.label, this.blurb);
  final String label;
  final String blurb;
}

/// How a report is shown on a dashboard.
enum ReportView {
  table('Table'),
  pie('Pie chart'),
  bar('Bar chart'),
  kpi('Key numbers');

  const ReportView(this.label);
  final String label;

  bool get isChart => this == ReportView.pie || this == ReportView.bar;
}

/// What a chart (and, for some reports, the table) groups by.
enum ReportGrouping {
  category('Category'),
  competency('Competency'),
  level('Level'),
  division('Division'),
  group('Group'),
  department('Department'),
  role('Role'),
  gapRange('Gap range'),
  status('Status'),
  project('Project'),
  trainingType('Training type'),
  competencyCount('Competencies per person'),
  projectCount('Projects per person'),
  skill('Skill');

  const ReportGrouping(this.label);
  final String label;

  /// "By category"
  String get byLabel => 'By ${label[0].toLowerCase()}${label.substring(1)}';
}

/// Filters a report offers in the editor and the full report.
enum ReportFilterKind {
  /// Division › group › department (HRD only; a Team Lead is always on
  /// their own department).
  orgUnit,
  role,
  project,
  category,
  competency,

  /// Current vs required: only rows with a gap.
  gapsOnly,

  /// Current vs required: also competencies no project needs.
  includeNotRequired,
}

enum ReportType {
  competencyInventory(
    title: 'All competencies',
    dataset: ReportDataset.competencies,
    description: 'Every competency with how many employees hold it, their share of people, the average '
        'level, how many are verified and what the projects need.',
    views: [ReportView.table, ReportView.pie, ReportView.bar, ReportView.kpi],
    groupings: [ReportGrouping.category, ReportGrouping.competency, ReportGrouping.level],
    filters: [ReportFilterKind.orgUnit, ReportFilterKind.role, ReportFilterKind.category],
  ),
  levelDistribution(
    title: 'Proficiency levels',
    dataset: ReportDataset.competencies,
    description: 'How many competency holdings sit at each level (L0 Beginner to L5 Expert), split by category.',
    views: [ReportView.bar, ReportView.pie, ReportView.table, ReportView.kpi],
    groupings: [ReportGrouping.level, ReportGrouping.category],
    filters: [ReportFilterKind.orgUnit, ReportFilterKind.role, ReportFilterKind.category, ReportFilterKind.competency],
  ),
  employeeCompetencies(
    title: 'Employees & competency sets',
    dataset: ReportDataset.employees,
    description: 'Every employee with their division, group, department, role and full competency set '
        '(levels, verified), additional skills, projects and readiness.',
    views: [ReportView.table, ReportView.bar, ReportView.pie, ReportView.kpi],
    groupings: [ReportGrouping.department, ReportGrouping.competencyCount, ReportGrouping.role],
    filters: [
      ReportFilterKind.orgUnit,
      ReportFilterKind.role,
      ReportFilterKind.project,
      ReportFilterKind.category,
      ReportFilterKind.competency,
    ],
  ),
  headcount(
    title: 'Headcount by org unit',
    dataset: ReportDataset.employees,
    description: 'Employees per division, group and department, how many are on projects, average '
        'readiness and open gaps.',
    views: [ReportView.table, ReportView.pie, ReportView.bar, ReportView.kpi],
    groupings: [ReportGrouping.department, ReportGrouping.group, ReportGrouping.division],
    filters: [ReportFilterKind.orgUnit, ReportFilterKind.role],
  ),
  orgReadiness(
    title: 'Overall readiness: have vs need',
    dataset: ReportDataset.readiness,
    description: 'Per competency, how many people their projects need it from, how many have the level, '
        'how many are below it or don\'t have it yet, and the coverage.',
    views: [ReportView.bar, ReportView.table, ReportView.pie, ReportView.kpi],
    groupings: [ReportGrouping.competency, ReportGrouping.status, ReportGrouping.category],
    filters: [
      ReportFilterKind.orgUnit,
      ReportFilterKind.role,
      ReportFilterKind.project,
      ReportFilterKind.category,
    ],
  ),
  teamReadiness(
    title: 'Readiness by team',
    dataset: ReportDataset.readiness,
    description: 'Average project readiness, fully ready people and open gaps per department, group, '
        'division or role.',
    views: [ReportView.bar, ReportView.table, ReportView.kpi],
    groupings: [ReportGrouping.department, ReportGrouping.role, ReportGrouping.group, ReportGrouping.division],
    filters: [ReportFilterKind.orgUnit, ReportFilterKind.project],
    groupsTable: true,
  ),
  currentVsRequired(
    title: 'Current vs required (gap register)',
    dataset: ReportDataset.readiness,
    description: 'One row per employee and competency: division, group, department, category, current '
        'level, the level projects require, the gap and its range, and the projects that need it.',
    views: [ReportView.table, ReportView.pie, ReportView.bar, ReportView.kpi],
    groupings: [ReportGrouping.gapRange, ReportGrouping.competency, ReportGrouping.department],
    filters: [
      ReportFilterKind.orgUnit,
      ReportFilterKind.role,
      ReportFilterKind.project,
      ReportFilterKind.category,
      ReportFilterKind.competency,
      ReportFilterKind.gapsOnly,
      ReportFilterKind.includeNotRequired,
    ],
  ),
  topGaps(
    title: 'Top skill gaps',
    dataset: ReportDataset.readiness,
    description: 'Competencies with the most people below the level their projects need, the size of the '
        'gaps and how many are already covered by a training plan or a level-up request.',
    views: [ReportView.bar, ReportView.table, ReportView.pie, ReportView.kpi],
    groupings: [ReportGrouping.competency, ReportGrouping.category],
    filters: [ReportFilterKind.orgUnit, ReportFilterKind.role, ReportFilterKind.project, ReportFilterKind.category],
  ),
  projectStaffing(
    title: 'Project staffing & match',
    dataset: ReportDataset.projects,
    description: 'Open projects with their team size against the plan, open seats, how well the team '
        'covers what the project needs, and the competencies nobody covers yet.',
    views: [ReportView.table, ReportView.bar, ReportView.pie, ReportView.kpi],
    groupings: [ReportGrouping.project, ReportGrouping.status, ReportGrouping.department],
    filters: [ReportFilterKind.orgUnit, ReportFilterKind.project],
  ),
  projectAllocation(
    title: 'Project allocation',
    dataset: ReportDataset.projects,
    description: 'How many projects each employee is allocated to, which ones, their fit for each, and '
        'who is not on a project.',
    views: [ReportView.table, ReportView.pie, ReportView.bar, ReportView.kpi],
    groupings: [ReportGrouping.projectCount, ReportGrouping.project, ReportGrouping.department],
    filters: [ReportFilterKind.orgUnit, ReportFilterKind.role, ReportFilterKind.project],
  ),
  trainingPlans(
    title: 'Training plans',
    dataset: ReportDataset.development,
    description: 'Every training plan with its competency, levels, type, dates, hours, progress and '
        'whether it is overdue.',
    views: [ReportView.table, ReportView.pie, ReportView.bar, ReportView.kpi],
    groupings: [ReportGrouping.status, ReportGrouping.trainingType, ReportGrouping.competency],
    filters: [ReportFilterKind.orgUnit, ReportFilterKind.role, ReportFilterKind.category, ReportFilterKind.competency],
  ),
  levelUpRequests(
    title: 'Level-up requests',
    dataset: ReportDataset.development,
    description: 'Level-ups raised by Team Leads with the hours acquired against the hours policy, and '
        'HR\'s decisions.',
    views: [ReportView.table, ReportView.pie, ReportView.bar, ReportView.kpi],
    groupings: [ReportGrouping.status, ReportGrouping.competency, ReportGrouping.department],
    filters: [ReportFilterKind.orgUnit, ReportFilterKind.category, ReportFilterKind.competency],
  ),
  additionalSkills(
    title: 'Additional (self-declared) skills',
    dataset: ReportDataset.development,
    description: 'Skills people added themselves outside the library, how many have each and in which '
        'departments.',
    views: [ReportView.bar, ReportView.table, ReportView.pie, ReportView.kpi],
    groupings: [ReportGrouping.skill, ReportGrouping.department],
    filters: [ReportFilterKind.orgUnit, ReportFilterKind.role],
  );

  const ReportType({
    required this.title,
    required this.dataset,
    required this.description,
    required this.views,
    required this.groupings,
    required this.filters,
    this.groupsTable = false,
  });

  final String title;
  final ReportDataset dataset;
  final String description;

  /// Views this report supports; the first is the default.
  final List<ReportView> views;

  /// Chart groupings; the first is the default.
  final List<ReportGrouping> groupings;
  final List<ReportFilterKind> filters;

  /// True when the table's rows follow the chosen grouping too.
  final bool groupsTable;

  ReportView get defaultView => views.first;

  /// API value, e.g. "CURRENT_VS_REQUIRED".
  String get apiValue => name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]}').toUpperCase();

  static ReportType? tryParse(String value) {
    for (final t in ReportType.values) {
      if (t.name == value || t.apiValue == value) return t;
    }
    return null;
  }
}

/// Filters chosen for one report or dashboard widget. Null = no filter.
class ReportFilters {
  const ReportFilters({
    this.divisionId,
    this.groupId,
    this.departmentId,
    this.roleId,
    this.projectId,
    this.category,
    this.competencyId,
    this.gapsOnly = false,
    this.includeNotRequired = false,
  });

  final String? divisionId;
  final String? groupId;
  final String? departmentId;
  final String? roleId;
  final String? projectId;
  final CompetencyCategory? category;
  final String? competencyId;
  final bool gapsOnly;
  final bool includeNotRequired;

  static const ReportFilters none = ReportFilters();

  bool get isEmpty =>
      divisionId == null &&
      groupId == null &&
      departmentId == null &&
      roleId == null &&
      projectId == null &&
      category == null &&
      competencyId == null &&
      !gapsOnly &&
      !includeNotRequired;

  /// Number of filters set (for the "Filters (2)" label).
  int get count => [
        divisionId,
        groupId,
        departmentId,
        roleId,
        projectId,
        category,
        competencyId,
      ].where((v) => v != null).length +
      (gapsOnly ? 1 : 0) +
      (includeNotRequired ? 1 : 0);

  ReportFilters copyWith({
    Object? divisionId = _keep,
    Object? groupId = _keep,
    Object? departmentId = _keep,
    Object? roleId = _keep,
    Object? projectId = _keep,
    Object? category = _keep,
    Object? competencyId = _keep,
    bool? gapsOnly,
    bool? includeNotRequired,
  }) =>
      ReportFilters(
        divisionId: identical(divisionId, _keep) ? this.divisionId : divisionId as String?,
        groupId: identical(groupId, _keep) ? this.groupId : groupId as String?,
        departmentId: identical(departmentId, _keep) ? this.departmentId : departmentId as String?,
        roleId: identical(roleId, _keep) ? this.roleId : roleId as String?,
        projectId: identical(projectId, _keep) ? this.projectId : projectId as String?,
        category: identical(category, _keep) ? this.category : category as CompetencyCategory?,
        competencyId: identical(competencyId, _keep) ? this.competencyId : competencyId as String?,
        gapsOnly: gapsOnly ?? this.gapsOnly,
        includeNotRequired: includeNotRequired ?? this.includeNotRequired,
      );

  /// Keeps only the filters [type] offers.
  ReportFilters forType(ReportType type) {
    final kinds = type.filters;
    final org = kinds.contains(ReportFilterKind.orgUnit);
    return ReportFilters(
      divisionId: org ? divisionId : null,
      groupId: org ? groupId : null,
      departmentId: org ? departmentId : null,
      roleId: kinds.contains(ReportFilterKind.role) ? roleId : null,
      projectId: kinds.contains(ReportFilterKind.project) ? projectId : null,
      category: kinds.contains(ReportFilterKind.category) ? category : null,
      competencyId: kinds.contains(ReportFilterKind.competency) ? competencyId : null,
      gapsOnly: kinds.contains(ReportFilterKind.gapsOnly) && gapsOnly,
      includeNotRequired: kinds.contains(ReportFilterKind.includeNotRequired) && includeNotRequired,
    );
  }

  static const Object _keep = Object();
}

/// How a cell is shown and exported.
enum CellKind {
  text,
  number,

  /// int 0–100, shown "45%".
  percent,

  /// int 0–5 or null (not held), shown "L3" / "—".
  level,

  /// int ≤ 0: levels short as a negative number ("−2"), 0 = met.
  gap,
  date,

  /// double with one decimal.
  decimal,
}

class ReportColumn {
  const ReportColumn(this.label, {this.kind = CellKind.text, this.flex = 10});

  final String label;
  final CellKind kind;

  /// Relative width in the on-screen table.
  final int flex;

  bool get isNumeric => kind != CellKind.text && kind != CellKind.date;
}

/// One table row. [cells] line up with the report's columns; the ids let a
/// row open the profile, competency or project it is about.
class ReportRow {
  const ReportRow(this.cells, {this.employeeId, this.competencyId, this.projectId, this.alert = false});

  final List<Object?> cells;
  final String? employeeId;
  final String? competencyId;
  final String? projectId;

  /// Highlight (e.g. a gap) – always together with a text value.
  final bool alert;
}

/// Colours a chart uses (the widget maps these to validated palettes).
enum ChartPalette {
  /// Identity: up to five hues + grey "Other" in a pie; one blue in bars.
  categorical,

  /// Ordered: met (blue), then the gap ramp light → dark orange.
  gaps,

  /// Ordered: L0 → L5 on a light → dark blue ramp.
  levels,

  /// Two measures: have (blue) vs need, shortfall in orange.
  paired,
}

class ChartDatum {
  const ChartDatum(this.label, this.value, {this.secondary, this.note});

  final String label;

  /// Count or percentage (see [ReportChart.unit]). For a paired chart:
  /// what people have.
  final double value;

  /// Paired chart: what is needed.
  final double? secondary;

  /// Extra line in the tooltip.
  final String? note;
}

class ReportChart {
  const ReportChart({
    required this.title,
    required this.data,
    required this.valueLabel,
    this.secondaryLabel,
    this.unit = '',
    this.ordered = false,
    this.palette = ChartPalette.categorical,
    this.pieAllowed = true,
  });

  final String title;
  final List<ChartDatum> data;

  /// "Employees", "Holdings", "Have the level"…
  final String valueLabel;

  /// Paired charts: "Needed".
  final String? secondaryLabel;

  /// "" for counts, "%" for percentages.
  final String unit;

  /// Keep the data order (levels, gap ranges) instead of largest first.
  final bool ordered;
  final ChartPalette palette;

  /// False for averages/percentages, which are not parts of a whole.
  final bool pieAllowed;

  double get total => data.fold<double>(0, (sum, d) => sum + d.value);
}

class ReportKpi {
  const ReportKpi(this.label, this.value, {this.caption, this.alert = false});

  final String label;
  final String value;
  final String? caption;
  final bool alert;
}

class ReportResult {
  const ReportResult({
    required this.type,
    required this.scopeLabel,
    required this.filterLabel,
    required this.columns,
    required this.rows,
    required this.kpis,
    required this.chart,
    required this.generatedAt,
    this.grouping,
    this.note,
  });

  final ReportType type;

  /// "Whole organisation" / "Engineering department".
  final String scopeLabel;

  /// "Division: R&D · Gaps only" or "No filters".
  final String filterLabel;
  final List<ReportColumn> columns;
  final List<ReportRow> rows;
  final List<ReportKpi> kpis;
  final ReportChart? chart;
  final ReportGrouping? grouping;
  final DateTime generatedAt;
  final String? note;

  String get title => type.title;

  bool get isEmpty => rows.isEmpty;
}

// ------------------------------------------------------------ formatting

/// Text shown in the table for [value].
String reportCellText(Object? value, CellKind kind) {
  if (value == null) return '—';
  switch (kind) {
    case CellKind.level:
      return value is int ? 'L$value' : '$value';
    case CellKind.percent:
      return value is num ? '${value.round()}%' : '$value';
    case CellKind.gap:
      if (value is int) return value == 0 ? 'Met' : '−${value.abs()}';
      return '$value';
    case CellKind.date:
      return value is DateTime ? dayMonthYear(value) : '$value';
    case CellKind.decimal:
      return value is num ? value.toStringAsFixed(1) : '$value';
    case CellKind.number:
    case CellKind.text:
      if (value is double) return value.toStringAsFixed(1);
      return '$value';
  }
}

/// Sort order for a column: numbers by value, text A–Z, empty last.
int compareReportCells(Object? a, Object? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  if (a is num && b is num) return a.compareTo(b);
  if (a is DateTime && b is DateTime) return a.compareTo(b);
  return a.toString().toLowerCase().compareTo(b.toString().toLowerCase());
}

/// "1 level short", "2 levels short", "3+ levels short", "Met".
String gapRangeLabel(int size) => switch (size) {
      <= 0 => 'Met',
      1 => '1 level short',
      2 => '2 levels short',
      _ => '3+ levels short',
    };

/// Ordered gap ranges (for charts).
const List<String> gapRangeLabels = ['Met', '1 level short', '2 levels short', '3+ levels short'];
