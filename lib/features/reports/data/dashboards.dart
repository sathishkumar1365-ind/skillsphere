// Personal dashboards: each HRD member or Team Lead builds their own
// dashboards from report widgets (a report + how it's shown + filters).
//
// TEMPORARY in-memory data like the rest of the console (lost on reload).
// Spring Boot API later (see CHANGES-reports-and-allocation.md):
//   GET    /api/dashboards                       (own dashboards)
//   POST   /api/dashboards                       {name, template}
//   PUT    /api/dashboards/{id}                  {name, widgets[]}
//   DELETE /api/dashboards/{id}
// A widget only stores WHAT to show; the data always comes from
// GET /api/reports/{type}, scoped to the caller (a Team Lead's widgets can
// never show another department, whatever their filters say).

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import '../../admin/data/admin_base.dart';
import 'report_models.dart';

enum WidgetWidth {
  half('Half width'),
  full('Full width');

  const WidgetWidth(this.label);
  final String label;
}

/// One widget on a dashboard: which report, shown how, with which filters.
class DashboardWidgetConfig {
  const DashboardWidgetConfig({
    required this.id,
    required this.type,
    required this.view,
    this.grouping,
    this.filters = ReportFilters.none,
    this.title = '',
    this.width = WidgetWidth.half,
    this.limit = 8,
  });

  /// e.g. "WGT-0004" ('' until added to a dashboard).
  final String id;
  final ReportType type;
  final ReportView view;

  /// Chart grouping (null = the report's default).
  final ReportGrouping? grouping;
  final ReportFilters filters;

  /// Custom title ('' = the report's title).
  final String title;
  final WidgetWidth width;

  /// Rows (table) or bars/slices (charts) shown; 0 = all.
  final int limit;

  String get displayTitle => title.trim().isEmpty ? type.title : title.trim();

  DashboardWidgetConfig copyWith({
    String? id,
    ReportType? type,
    ReportView? view,
    Object? grouping = _keep,
    ReportFilters? filters,
    String? title,
    WidgetWidth? width,
    int? limit,
  }) =>
      DashboardWidgetConfig(
        id: id ?? this.id,
        type: type ?? this.type,
        view: view ?? this.view,
        grouping: identical(grouping, _keep) ? this.grouping : grouping as ReportGrouping?,
        filters: filters ?? this.filters,
        title: title ?? this.title,
        width: width ?? this.width,
        limit: limit ?? this.limit,
      );

  static const Object _keep = Object();
}

class Dashboard {
  const Dashboard({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.widgets,
    required this.createdAt,
    required this.updatedAt,
  });

  /// e.g. "DSH-003".
  final String id;
  final String ownerId;
  final String name;
  final List<DashboardWidgetConfig> widgets;
  final DateTime createdAt;
  final DateTime updatedAt;

  Dashboard copyWith({String? name, List<DashboardWidgetConfig>? widgets}) => Dashboard(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        widgets: widgets ?? this.widgets,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

/// Ready-made starting points for a new dashboard.
enum DashboardTemplate {
  overview('Competency overview', 'Competencies by category, have vs need, every employee\'s competency set and the gap register.'),
  gaps('Gaps & readiness', 'Gap ranges, the top gaps, readiness by team and every open gap.'),
  projects('Projects & allocation', 'Open seats, team match, projects per person and who is allocated where.'),
  development('Development', 'Training plans, level-ups, proficiency levels and self-declared skills.'),
  blank('Blank', 'Start empty and add the widgets you want.');

  const DashboardTemplate(this.label, this.blurb);
  final String label;
  final String blurb;

  /// The widgets of this template (ids are given when added). A Team Lead's
  /// charts group by role instead of department.
  List<DashboardWidgetConfig> widgets({required bool organisation}) {
    final unit = organisation ? ReportGrouping.department : ReportGrouping.role;
    return switch (this) {
      DashboardTemplate.overview => [
          const DashboardWidgetConfig(
              id: '', type: ReportType.orgReadiness, view: ReportView.kpi, width: WidgetWidth.full),
          const DashboardWidgetConfig(
              id: '', type: ReportType.competencyInventory, view: ReportView.pie, grouping: ReportGrouping.category),
          const DashboardWidgetConfig(
              id: '', type: ReportType.orgReadiness, view: ReportView.bar, grouping: ReportGrouping.competency),
          const DashboardWidgetConfig(
              id: '', type: ReportType.competencyInventory, view: ReportView.table, width: WidgetWidth.full),
          const DashboardWidgetConfig(
              id: '', type: ReportType.employeeCompetencies, view: ReportView.table, width: WidgetWidth.full),
          const DashboardWidgetConfig(
              id: '', type: ReportType.currentVsRequired, view: ReportView.table, width: WidgetWidth.full, limit: 10),
        ],
      DashboardTemplate.gaps => [
          const DashboardWidgetConfig(
              id: '', type: ReportType.currentVsRequired, view: ReportView.pie, grouping: ReportGrouping.gapRange),
          const DashboardWidgetConfig(id: '', type: ReportType.topGaps, view: ReportView.bar),
          DashboardWidgetConfig(
              id: '', type: ReportType.teamReadiness, view: ReportView.bar, grouping: unit, width: WidgetWidth.full),
          const DashboardWidgetConfig(
            id: '',
            type: ReportType.currentVsRequired,
            view: ReportView.table,
            width: WidgetWidth.full,
            filters: ReportFilters(gapsOnly: true),
            title: 'Open gaps',
            limit: 10,
          ),
        ],
      DashboardTemplate.projects => [
          const DashboardWidgetConfig(
              id: '', type: ReportType.projectStaffing, view: ReportView.kpi, width: WidgetWidth.full),
          const DashboardWidgetConfig(
              id: '', type: ReportType.projectStaffing, view: ReportView.bar, grouping: ReportGrouping.project),
          const DashboardWidgetConfig(
              id: '', type: ReportType.projectAllocation, view: ReportView.pie, grouping: ReportGrouping.projectCount),
          const DashboardWidgetConfig(
              id: '', type: ReportType.projectAllocation, view: ReportView.table, width: WidgetWidth.full),
        ],
      DashboardTemplate.development => [
          const DashboardWidgetConfig(
              id: '', type: ReportType.trainingPlans, view: ReportView.pie, grouping: ReportGrouping.status),
          const DashboardWidgetConfig(
              id: '', type: ReportType.levelUpRequests, view: ReportView.pie, grouping: ReportGrouping.status),
          const DashboardWidgetConfig(id: '', type: ReportType.levelDistribution, view: ReportView.bar),
          const DashboardWidgetConfig(id: '', type: ReportType.additionalSkills, view: ReportView.bar),
          const DashboardWidgetConfig(
              id: '', type: ReportType.topGaps, view: ReportView.table, width: WidgetWidth.full),
        ],
      DashboardTemplate.blank => const <DashboardWidgetConfig>[],
    };
  }
}

class DashboardRules {
  DashboardRules._();

  static const int nameMax = 40;
  static const int titleMax = 60;
  static const int maxDashboards = 12;
  static const int maxWidgets = 16;

  /// Choices for "rows / bars shown" (0 = all).
  static const List<int> limits = [5, 8, 10, 15, 25, 0];
}

class DashboardRepository {
  DashboardRepository._();

  static final DashboardRepository instance = DashboardRepository._();

  final ValueNotifier<List<Dashboard>> dashboards =
      ValueNotifier<List<Dashboard>>(List<Dashboard>.unmodifiable(_sampleDashboards()));

  final Set<String> _addedThisSession = <String>{};

  bool isNew(String widgetId) => _addedThisSession.contains(widgetId);

  /// [user]'s dashboards, oldest first.
  List<Dashboard> forUser(AppUser user) =>
      dashboards.value.where((d) => d.ownerId == user.id).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Dashboard? byId(String? id) {
    if (id == null) return null;
    for (final d in dashboards.value) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// HRD and Team Leads build dashboards.
  static bool canUse(AppUser user) => user.role.canManageOrganization || user.role.canEditTeamProfiles;

  String? nameProblem(AppUser user, String name, {String? exceptId}) {
    final value = cleanText(name);
    if (value.isEmpty) return 'Give the dashboard a name.';
    if (value.length > DashboardRules.nameMax) return 'Keep the name under ${DashboardRules.nameMax} characters.';
    for (final d in forUser(user)) {
      if (d.id != exceptId && nameKey(d.name) == nameKey(value)) return 'You already have a dashboard called "${d.name}".';
    }
    return null;
  }

  Future<Dashboard> create({
    required AppUser by,
    required String name,
    DashboardTemplate template = DashboardTemplate.blank,
  }) async {
    _requireAccess(by);
    final problem = nameProblem(by, name);
    if (problem != null) throw AdminException(problem);
    if (forUser(by).length >= DashboardRules.maxDashboards) {
      throw const AdminException('You can keep up to ${DashboardRules.maxDashboards} dashboards. Delete one first.');
    }
    await apiPause(300);
    final now = DateTime.now();
    var number = highestNumber(_allWidgetIds());
    final widgets = [
      for (final w in template.widgets(organisation: by.role.canManageOrganization))
        w.copyWith(id: 'WGT-${(++number).toString().padLeft(4, '0')}'),
    ];
    final dashboard = Dashboard(
      id: nextId('DSH-', dashboards.value.map((d) => d.id)),
      ownerId: by.id,
      name: cleanText(name),
      widgets: List<DashboardWidgetConfig>.unmodifiable(widgets),
      createdAt: now,
      updatedAt: now,
    );
    dashboards.value = List<Dashboard>.unmodifiable([...dashboards.value, dashboard]);
    return dashboard;
  }

  void rename({required AppUser by, required String dashboardId, required String name}) {
    final problem = nameProblem(by, name, exceptId: dashboardId);
    if (problem != null) throw AdminException(problem);
    _update(by, dashboardId, (d) => d.copyWith(name: cleanText(name)));
  }

  Future<Dashboard> duplicate({required AppUser by, required String dashboardId}) async {
    final source = _own(by, dashboardId);
    if (forUser(by).length >= DashboardRules.maxDashboards) {
      throw const AdminException('You can keep up to ${DashboardRules.maxDashboards} dashboards. Delete one first.');
    }
    await apiPause(250);
    var name = '${source.name} (copy)';
    var n = 2;
    while (nameProblem(by, name) != null && n < 50) {
      name = '${source.name} (copy $n)';
      n++;
    }
    if (name.length > DashboardRules.nameMax) name = name.substring(0, DashboardRules.nameMax).trim();
    var number = highestNumber(_allWidgetIds());
    final now = DateTime.now();
    final copy = Dashboard(
      id: nextId('DSH-', dashboards.value.map((d) => d.id)),
      ownerId: by.id,
      name: name,
      widgets: List<DashboardWidgetConfig>.unmodifiable([
        for (final w in source.widgets) w.copyWith(id: 'WGT-${(++number).toString().padLeft(4, '0')}'),
      ]),
      createdAt: now,
      updatedAt: now,
    );
    dashboards.value = List<Dashboard>.unmodifiable([...dashboards.value, copy]);
    return copy;
  }

  /// Deletes a dashboard and returns it (for Undo).
  Dashboard delete({required AppUser by, required String dashboardId}) {
    final removed = _own(by, dashboardId);
    dashboards.value = List<Dashboard>.unmodifiable(dashboards.value.where((d) => d.id != dashboardId));
    return removed;
  }

  void restore({required AppUser by, required Dashboard dashboard}) {
    if (dashboard.ownerId != by.id || byId(dashboard.id) != null) return;
    dashboards.value = List<Dashboard>.unmodifiable([...dashboards.value, dashboard]);
  }

  DashboardWidgetConfig addWidget({
    required AppUser by,
    required String dashboardId,
    required DashboardWidgetConfig config,
  }) {
    final dashboard = _own(by, dashboardId);
    if (dashboard.widgets.length >= DashboardRules.maxWidgets) {
      throw const AdminException('A dashboard holds up to ${DashboardRules.maxWidgets} widgets.');
    }
    final added = _clean(config).copyWith(id: 'WGT-${(highestNumber(_allWidgetIds()) + 1).toString().padLeft(4, '0')}');
    _addedThisSession.add(added.id);
    _update(by, dashboardId, (d) => d.copyWith(widgets: List<DashboardWidgetConfig>.unmodifiable([...d.widgets, added])));
    return added;
  }

  void updateWidget({required AppUser by, required String dashboardId, required DashboardWidgetConfig config}) {
    final cleaned = _clean(config);
    _update(
      by,
      dashboardId,
      (d) => d.copyWith(
        widgets: List<DashboardWidgetConfig>.unmodifiable([
          for (final w in d.widgets) w.id == config.id ? cleaned : w,
        ]),
      ),
    );
  }

  /// Removes a widget and returns it with its position (for Undo).
  ({DashboardWidgetConfig widget, int index})? removeWidget({
    required AppUser by,
    required String dashboardId,
    required String widgetId,
  }) {
    final dashboard = _own(by, dashboardId);
    final index = dashboard.widgets.indexWhere((w) => w.id == widgetId);
    if (index < 0) return null;
    final widget = dashboard.widgets[index];
    _update(
      by,
      dashboardId,
      (d) => d.copyWith(widgets: List<DashboardWidgetConfig>.unmodifiable(d.widgets.where((w) => w.id != widgetId))),
    );
    return (widget: widget, index: index);
  }

  void restoreWidget({
    required AppUser by,
    required String dashboardId,
    required DashboardWidgetConfig widget,
    required int index,
  }) {
    _update(by, dashboardId, (d) {
      if (d.widgets.any((w) => w.id == widget.id)) return d;
      final list = [...d.widgets];
      list.insert(index.clamp(0, list.length).toInt(), widget);
      return d.copyWith(widgets: List<DashboardWidgetConfig>.unmodifiable(list));
    });
  }

  /// Moves a widget [delta] places (−1 = earlier, +1 = later).
  void moveWidget({required AppUser by, required String dashboardId, required String widgetId, required int delta}) {
    _update(by, dashboardId, (d) {
      final list = [...d.widgets];
      final from = list.indexWhere((w) => w.id == widgetId);
      if (from < 0) return d;
      final to = (from + delta).clamp(0, list.length - 1).toInt();
      if (to == from) return d;
      final item = list.removeAt(from);
      list.insert(to, item);
      return d.copyWith(widgets: List<DashboardWidgetConfig>.unmodifiable(list));
    });
  }

  // --------------------------------------------------------- internals

  void _requireAccess(AppUser by) {
    if (!canUse(by)) throw const AdminException('Dashboards are for the HRD team and Team Leads.');
  }

  Dashboard _own(AppUser by, String dashboardId) {
    _requireAccess(by);
    final d = byId(dashboardId);
    if (d == null) throw const AdminException('This dashboard no longer exists.');
    if (d.ownerId != by.id) throw const AdminException('You can only change your own dashboards.');
    return d;
  }

  void _update(AppUser by, String dashboardId, Dashboard Function(Dashboard d) change) {
    _own(by, dashboardId);
    dashboards.value = List<Dashboard>.unmodifiable([
      for (final d in dashboards.value) d.id == dashboardId ? change(d) : d,
    ]);
  }

  Iterable<String> _allWidgetIds() sync* {
    for (final d in dashboards.value) {
      for (final w in d.widgets) {
        yield w.id;
      }
    }
  }

  /// Keeps only what the widget's report supports.
  static DashboardWidgetConfig _clean(DashboardWidgetConfig c) {
    final view = c.type.views.contains(c.view) ? c.view : c.type.defaultView;
    final grouping = c.grouping != null && c.type.groupings.contains(c.grouping) ? c.grouping : null;
    var title = cleanText(c.title);
    if (title.length > DashboardRules.titleMax) title = title.substring(0, DashboardRules.titleMax).trim();
    return c.copyWith(
      view: view,
      grouping: grouping,
      filters: c.filters.forType(c.type),
      title: title,
      limit: c.limit < 0 ? 0 : c.limit,
    );
  }
}

/// Starter dashboards of the two test users (HRD and the Engineering TL).
List<Dashboard> _sampleDashboards() {
  final created = DateTime(2026, 11, 2, 9, 30);
  var number = 0;
  List<DashboardWidgetConfig> numbered(List<DashboardWidgetConfig> list) => [
        for (final w in list) w.copyWith(id: 'WGT-${(++number).toString().padLeft(4, '0')}'),
      ];
  return [
    Dashboard(
      id: 'DSH-001',
      ownerId: 'EMP-1034',
      name: 'Competency overview',
      widgets: numbered(DashboardTemplate.overview.widgets(organisation: true)),
      createdAt: created,
      updatedAt: created,
    ),
    Dashboard(
      id: 'DSH-002',
      ownerId: 'EMP-1034',
      name: 'Gaps & readiness',
      widgets: numbered(DashboardTemplate.gaps.widgets(organisation: true)),
      createdAt: created.add(const Duration(minutes: 5)),
      updatedAt: created.add(const Duration(minutes: 5)),
    ),
    Dashboard(
      id: 'DSH-003',
      ownerId: 'EMP-1001',
      name: 'Engineering team',
      widgets: numbered(DashboardTemplate.overview.widgets(organisation: false)),
      createdAt: created.add(const Duration(minutes: 10)),
      updatedAt: created.add(const Duration(minutes: 10)),
    ),
  ];
}
