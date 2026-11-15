// Dashboards & Reports – the HRD console option and the Team Lead's own
// page (TeamReportsPage, own department only).
//
// * My dashboards: tabs for each dashboard, Add widget, export the whole
//   dashboard to Excel (one sheet per widget + a summary), rename,
//   duplicate, delete; widgets can be edited, re-ordered, resized, switched
//   between views, opened in full or exported one by one.
// * Report library: every report type, opened in full or added to a
//   dashboard.
// * Skill maps: one person's projects → required → current levels → gaps,
//   joined by animated beams (same scope as the reports).

import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/sphere_page_route.dart';
import '../../admin/data/admin_base.dart';
import '../../admin/data/insights.dart';
import '../../admin/presentation/employees/employee_profile_page.dart';
import '../../admin/presentation/widgets/admin_common.dart';
import '../../admin/presentation/widgets/console_top_bar.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/drifting_clouds.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../home/presentation/widgets/lift_card.dart';
import '../../home/presentation/widgets/smooth_wheel_scroll.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../../skill_map/presentation/skill_map_explorer.dart';
import '../data/dashboards.dart';
import '../data/report_engine.dart';
import '../data/report_export.dart';
import '../data/report_models.dart';
import 'dashboard_widget_card.dart';
import 'report_controls.dart';
import 'report_panel.dart';
import 'report_visuals.dart';
import 'widget_editor.dart';

enum _Mode { dashboards, library, skillMaps }

enum _DashboardAction { rename, duplicate, delete }

class ReportsView extends StatefulWidget {
  const ReportsView({super.key, required this.user, required this.onOpenEmployee});

  final AppUser user;
  final ValueChanged<String> onOpenEmployee;

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  _Mode _mode = _Mode.dashboards;
  String? _dashboardId;
  int _turn = 0;
  bool _busy = false;

  AppUser get _user => widget.user;

  DashboardRepository get _repo => DashboardRepository.instance;

  void _select(String id) {
    if (id == _dashboardId) return;
    setState(() {
      _dashboardId = id;
      _turn++;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on AdminException catch (e) {
      if (mounted) showAdminMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newDashboard() => _run(() async {
        final created = await showNewDashboard(context: context, user: _user);
        if (created == null || !mounted) return;
        _select(created.id);
        setState(() => _mode = _Mode.dashboards);
        showAdminMessage(context, 'Dashboard "${created.name}" created.');
      });

  Future<void> _createFrom(DashboardTemplate template) => _run(() async {
        final created = await _repo.create(
          by: _user,
          name: template == DashboardTemplate.blank ? 'My dashboard' : template.label,
          template: template,
        );
        if (mounted) _select(created.id);
      });

  Future<void> _addWidget(Dashboard dashboard, {ReportType? type}) => _run(() async {
        final config = await showWidgetEditor(
          context: context,
          user: _user,
          initialType: type,
          dashboardName: dashboard.name,
        );
        if (config == null || !mounted) return;
        _repo.addWidget(by: _user, dashboardId: dashboard.id, config: config);
        showAdminMessage(context, 'Added "${config.displayTitle}" to ${dashboard.name}.');
      });

  Future<void> _editWidget(Dashboard dashboard, DashboardWidgetConfig current) => _run(() async {
        final config = await showWidgetEditor(
          context: context,
          user: _user,
          initial: current,
          dashboardName: dashboard.name,
        );
        if (config == null || !mounted) return;
        _repo.updateWidget(by: _user, dashboardId: dashboard.id, config: config);
      });

  void _removeWidget(Dashboard dashboard, DashboardWidgetConfig config) {
    try {
      final removed = _repo.removeWidget(by: _user, dashboardId: dashboard.id, widgetId: config.id);
      if (removed == null) return;
      showAdminMessage(
        context,
        'Removed "${config.displayTitle}".',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _repo.restoreWidget(
            by: _user,
            dashboardId: dashboard.id,
            widget: removed.widget,
            index: removed.index,
          ),
        ),
      );
    } on AdminException catch (e) {
      showAdminMessage(context, e.message);
    }
  }

  void _change(Dashboard dashboard, DashboardWidgetConfig config) {
    try {
      _repo.updateWidget(by: _user, dashboardId: dashboard.id, config: config);
    } on AdminException catch (e) {
      showAdminMessage(context, e.message);
    }
  }

  void _move(Dashboard dashboard, DashboardWidgetConfig config, int delta) {
    try {
      _repo.moveWidget(by: _user, dashboardId: dashboard.id, widgetId: config.id, delta: delta);
    } on AdminException catch (e) {
      showAdminMessage(context, e.message);
    }
  }

  void _openFull(DashboardWidgetConfig config) {
    showReportPanel(
      context: context,
      user: _user,
      type: config.type,
      filters: config.filters,
      grouping: config.grouping,
      chartView: config.view,
      title: config.displayTitle,
      onOpenEmployee: widget.onOpenEmployee,
    );
  }

  void _openReport(ReportType type) {
    showReportPanel(context: context, user: _user, type: type, onOpenEmployee: widget.onOpenEmployee);
  }

  Future<void> _exportDashboard(Dashboard dashboard) async {
    if (dashboard.widgets.isEmpty) {
      showAdminMessage(context, 'Add a widget first: the export has one sheet per widget.');
      return;
    }
    final scope = ReportScope.of(_user);
    final results = [
      for (final w in dashboard.widgets)
        ReportEngine.run(w.type, scope: scope, filters: w.filters, grouping: w.grouping),
    ];
    await saveReportFile(
      context,
      bytes: ReportExport.xlsx(results, title: dashboard.name, names: [for (final w in dashboard.widgets) w.displayTitle]),
      fileName: ReportExport.fileName(dashboard.name, 'xlsx'),
      excel: true,
    );
  }

  Future<void> _dashboardAction(Dashboard dashboard, _DashboardAction action) async {
    switch (action) {
      case _DashboardAction.rename:
        final name = await showTextPrompt(
          context: context,
          title: 'Rename dashboard',
          message: 'Up to ${DashboardRules.nameMax} characters.',
          hint: dashboard.name,
          confirmLabel: 'Rename',
          maxLength: DashboardRules.nameMax,
        );
        if (name == null || !mounted) return;
        try {
          _repo.rename(by: _user, dashboardId: dashboard.id, name: name);
        } on AdminException catch (e) {
          showAdminMessage(context, e.message);
        }
      case _DashboardAction.duplicate:
        await _run(() async {
          final copy = await _repo.duplicate(by: _user, dashboardId: dashboard.id);
          if (!mounted) return;
          _select(copy.id);
          showAdminMessage(context, 'Duplicated as "${copy.name}".');
        });
      case _DashboardAction.delete:
        final ok = await showConfirm(
          context: context,
          title: 'Delete dashboard?',
          message: '"${dashboard.name}" and its ${dashboard.widgets.length} widgets will be deleted. '
              'The reports themselves are not affected.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok || !mounted) return;
        try {
          final removed = _repo.delete(by: _user, dashboardId: dashboard.id);
          setState(() => _dashboardId = null);
          showAdminMessage(
            context,
            'Deleted "${removed.name}".',
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                _repo.restore(by: _user, dashboard: removed);
                if (mounted) _select(removed.id);
              },
            ),
          );
        } on AdminException catch (e) {
          showAdminMessage(context, e.message);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = ReportScope.of(_user);
    if (!scope.hasAccess || !DashboardRepository.canUse(_user)) {
      return const EmptyState(
        title: 'No access',
        message: 'Dashboards and reports are for the HRD team and Team Leads.',
        icon: Icons.lock_outline_rounded,
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge([Insights.listenable, _repo.dashboards]),
      builder: (context, _) {
        final dashboards = _repo.forUser(_user);
        Dashboard? found;
        for (final d in dashboards) {
          if (d.id == _dashboardId) found = d;
        }
        final Dashboard? selected = found ?? (dashboards.isEmpty ? null : dashboards.first);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'DASHBOARDS & REPORTS',
              subtitle: scope.isOrganisation
                  ? 'Build your own dashboards from ready-made reports – competencies, employees, '
                      'readiness, gaps, projects and development – as tables, pie or bar charts and key '
                      'numbers. Export any widget or a whole dashboard to Excel. Skill maps trace one '
                      'person\'s projects, required and current levels and gaps with animated beams.'
                  : 'Your own dashboards for the ${_user.department} department: competencies, your '
                      'team\'s competency sets, readiness against project needs and every gap. Other '
                      'departments are never included. Export to Excel or CSV. Skill maps trace one team '
                      'member\'s projects, required and current levels and gaps with animated beams.',
              // At most 520px, never wider than the space there is (the
              // switch sizes itself from what it gets – no negative width).
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ModeSwitch<_Mode>(
                  options: const [
                    ModeOption(_Mode.dashboards, 'My dashboards', Icons.dashboard_customize_outlined),
                    ModeOption(_Mode.library, 'Report library', Icons.insights_rounded),
                    ModeOption(_Mode.skillMaps, 'Skill maps', Icons.hub_outlined),
                  ],
                  selected: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft, child: ReportScopeBanner(scope: scope)),
            const SizedBox(height: 22),
            if (_mode == _Mode.skillMaps)
              TurnIn(
                replayKey: _mode,
                child: SkillMapExplorer(user: _user, onOpenEmployee: widget.onOpenEmployee),
              )
            else if (_mode == _Mode.library)
              TurnIn(
                replayKey: _mode,
                child: _Library(
                  onOpenSkillMaps: () => setState(() => _mode = _Mode.skillMaps),
                  onOpen: _openReport,
                  onAdd: (type) async {
                    var target = selected;
                    if (target == null) {
                      // No dashboard yet: create "My dashboard" first.
                      try {
                        target = await _repo.create(by: _user, name: 'My dashboard');
                      } on AdminException catch (e) {
                        if (mounted) showAdminMessage(context, e.message);
                        return;
                      }
                      if (!mounted) return;
                      _select(target.id);
                    }
                    await _addWidget(target, type: type);
                  },
                  targetName: selected?.name,
                ),
              )
            else if (selected == null)
              _StartPanel(onPick: _createFrom, onCustom: _newDashboard)
            else
              _dashboard(context, dashboards, selected, scope),
          ],
        );
      },
    );
  }

  Widget _dashboard(BuildContext context, List<Dashboard> dashboards, Dashboard dashboard, ReportScope scope) {
    final narrow = MediaQuery.sizeOf(context).width < 640;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- tabs
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final d in dashboards)
              _DashboardTab(
                name: d.name,
                count: d.widgets.length,
                selected: d.id == dashboard.id,
                onTap: () => _select(d.id),
              ),
            if (dashboards.length < DashboardRules.maxDashboards)
              _NewTab(onTap: _busy ? null : _newDashboard),
          ],
        ),
        const SizedBox(height: 18),
        // ---- toolbar
        LiftCard(
          padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
          liftBy: 4,
          tiltDegrees: 2,
          color: const Color.fromRGBO(255, 255, 255, 0.92),
          borderColor: Colors.white,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 14,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dashboard.name.toUpperCase(), style: HomeText.display(narrow ? 26 : 32, height: 1.05)),
                    const SizedBox(height: 4),
                    Text(
                      '${dashboard.widgets.length} ${dashboard.widgets.length == 1 ? 'widget' : 'widgets'} · '
                      'updated ${relativeDays(dashboard.updatedAt)} · live data',
                      style: HomeText.body(13, color: HomeColors.muted),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PillButton(
                    label: 'Add widget',
                    height: 46,
                    fontSize: 14,
                    onPressed: _busy || dashboard.widgets.length >= DashboardRules.maxWidgets
                        ? null
                        : () => _addWidget(dashboard),
                  ),
                  PillButton(
                    label: 'Export dashboard',
                    variant: PillVariant.outline,
                    height: 46,
                    fontSize: 14,
                    onPressed: () => _exportDashboard(dashboard),
                  ),
                  PopupMenuButton<_DashboardAction>(
                    tooltip: 'Dashboard options',
                    icon: const Icon(Icons.more_vert_rounded, color: HomeColors.ink),
                    color: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                    onSelected: (a) => _dashboardAction(dashboard, a),
                    itemBuilder: (context) => [
                      _menuItem(_DashboardAction.rename, Icons.edit_outlined, 'Rename'),
                      _menuItem(_DashboardAction.duplicate, Icons.copy_all_outlined, 'Duplicate'),
                      _menuItem(_DashboardAction.delete, Icons.delete_outline_rounded, 'Delete'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (dashboard.widgets.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EmptyState(
                title: 'This dashboard is empty',
                message: 'Add widgets: pick a report, show it as a table, pie or bar chart or key numbers, '
                    'and filter it.',
                icon: Icons.dashboard_customize_outlined,
              ),
              const SizedBox(height: 14),
              Center(child: PillButton(label: 'Add your first widget', onPressed: () => _addWidget(dashboard))),
            ],
          )
        else
          _WidgetGrid(
            key: ValueKey<String>(dashboard.id),
            dashboard: dashboard,
            scope: scope,
            turn: _turn,
            onEdit: (w) => _editWidget(dashboard, w),
            onOpenFull: _openFull,
            onChange: (w) => _change(dashboard, w),
            onMove: (w, delta) => _move(dashboard, w, delta),
            onRemove: (w) => _removeWidget(dashboard, w),
            onOpenRow: (row) {
              final id = row.employeeId;
              if (id != null) widget.onOpenEmployee(id);
            },
          ),
      ],
    );
  }

  PopupMenuItem<_DashboardAction> _menuItem(_DashboardAction value, IconData icon, String label) {
    final danger = value == _DashboardAction.delete;
    final color = danger ? const Color(0xFFB4232A) : HomeColors.ink;
    return PopupMenuItem<_DashboardAction>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: HomeText.body(14, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ================================================================ layout

/// Widgets in two columns (half width) or across (full width); one column
/// on narrow screens. Each card turns in in 3D, one after the other.
class _WidgetGrid extends StatelessWidget {
  const _WidgetGrid({
    super.key,
    required this.dashboard,
    required this.scope,
    required this.turn,
    required this.onEdit,
    required this.onOpenFull,
    required this.onChange,
    required this.onMove,
    required this.onRemove,
    required this.onOpenRow,
  });

  final Dashboard dashboard;
  final ReportScope scope;
  final int turn;
  final ValueChanged<DashboardWidgetConfig> onEdit;
  final ValueChanged<DashboardWidgetConfig> onOpenFull;
  final ValueChanged<DashboardWidgetConfig> onChange;
  final void Function(DashboardWidgetConfig config, int delta) onMove;
  final ValueChanged<DashboardWidgetConfig> onRemove;
  final ValueChanged<ReportRow> onOpenRow;

  @override
  Widget build(BuildContext context) {
    final widgets = dashboard.widgets;
    final repo = DashboardRepository.instance;

    Widget card(int index) {
      final w = widgets[index];
      return TurnIn(
        key: ValueKey<String>(w.id),
        replayKey: repo.isNew(w.id) ? '${w.id}-new' : turn,
        delay: Duration(milliseconds: 70 * (index < 8 ? index : 8)),
        child: DashboardWidgetCard(
          scope: scope,
          config: w,
          isFirst: index == 0,
          isLast: index == widgets.length - 1,
          onEdit: () => onEdit(w),
          onOpenFull: () => onOpenFull(w),
          onChange: onChange,
          onMove: (delta) => onMove(w, delta),
          onRemove: () => onRemove(w),
          onOpenRow: onOpenRow,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 18.0;
        final twoColumns = constraints.maxWidth >= 860;
        final rows = <Widget>[];
        var i = 0;
        while (i < widgets.length) {
          final half = widgets[i].width == WidgetWidth.half;
          if (!twoColumns || !half) {
            rows.add(card(i));
            i++;
            continue;
          }
          final pairs = i + 1 < widgets.length && widgets[i + 1].width == WidgetWidth.half;
          rows.add(Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card(i)),
              const SizedBox(width: gap),
              Expanded(child: pairs ? card(i + 1) : const SizedBox.shrink()),
            ],
          ));
          i += pairs ? 2 : 1;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              rows[r],
            ],
          ],
        );
      },
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.name, required this.count, required this.selected, required this.onTap});

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : HomeColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: HoverRaise(
        child: Material(
          color: selected ? HomeColors.ink : Colors.white,
          shape: StadiumBorder(side: BorderSide(color: selected ? HomeColors.ink : HomeColors.chipBorder)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.space_dashboard_outlined, size: 17, color: fg),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HomeText.body(13.5, weight: FontWeight.w700, color: fg)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected ? const Color.fromRGBO(255, 255, 255, 0.18) : HomeColors.blueTint,
                      borderRadius: const BorderRadius.all(Radius.circular(999)),
                    ),
                    child: Text('$count',
                        style: HomeText.body(11.5,
                            weight: FontWeight.w800, color: selected ? Colors.white : HomeColors.blueDeep)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewTab extends StatelessWidget {
  const _NewTab({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HoverRaise(
      child: DashedOutline(
        color: HomeColors.ink,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: HomeColors.ink),
                  const SizedBox(width: 6),
                  Text('New dashboard', style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// No dashboards yet: start from a template.
class _StartPanel extends StatelessWidget {
  const _StartPanel({required this.onPick, required this.onCustom});

  final ValueChanged<DashboardTemplate> onPick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return OrgPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelTitle('Create your first dashboard',
              subtitle: 'Start from a ready-made set of widgets and change it as you like.'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 560 ? 2 : 1);
              final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final t in DashboardTemplate.values)
                    SizedBox(width: width, child: TemplateTile(template: t, onTap: () => onPick(t))),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: PillButton(label: 'Name it myself…', variant: PillVariant.outline, onPressed: onCustom),
          ),
        ],
      ),
    );
  }
}

/// A dashboard template: name, what's in it and its widgets' views.
class TemplateTile extends StatelessWidget {
  const TemplateTile({super.key, required this.template, required this.onTap, this.selected = false});

  final DashboardTemplate template;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final widgets = template.widgets(organisation: true);
    return LiftCard(
      padding: EdgeInsets.zero,
      radius: 20,
      color: selected ? const Color(0xFFF2F7FE) : Colors.white,
      borderColor: selected ? HomeColors.ink : HomeColors.cardBorder,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      template == DashboardTemplate.blank ? Icons.add_box_outlined : Icons.space_dashboard_outlined,
                      size: 20,
                      color: HomeColors.blueDeep,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(template.label,
                          style: HomeText.body(15, weight: FontWeight.w800, color: HomeColors.ink)),
                    ),
                    if (selected) const Icon(Icons.check_circle_rounded, size: 20, color: HomeColors.ink),
                  ],
                ),
                const SizedBox(height: 6),
                Text(template.blurb, style: HomeText.body(12.5, color: HomeColors.muted, height: 1.4)),
                if (widgets.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final w in widgets)
                        Tooltip(
                          message: '${w.displayTitle} · ${w.view.label}',
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: HomeColors.blueTint,
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            child: Icon(reportViewIcon(w.view), size: 15, color: HomeColors.blueDeep),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================ library

class _Library extends StatelessWidget {
  const _Library({required this.onOpenSkillMaps, required this.onOpen, required this.onAdd, required this.targetName});

  final VoidCallback onOpenSkillMaps;
  final ValueChanged<ReportType> onOpen;
  final ValueChanged<ReportType> onAdd;

  /// The dashboard "Add to dashboard" adds to (null = a new one).
  final String? targetName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkillMapTile(onOpen: onOpenSkillMaps),
        const SizedBox(height: 28),
        for (final dataset in ReportDataset.values) ...[
          PanelTitle(dataset.label, subtitle: dataset.blurb),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 560 ? 2 : 1);
              final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final t in ReportType.values.where((t) => t.dataset == dataset))
                    SizedBox(
                      width: width,
                      child: _LibraryTile(
                        type: t,
                        targetName: targetName,
                        onOpen: () => onOpen(t),
                        onAdd: () => onAdd(t),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
        ],
      ],
    );
  }
}

/// The skill map, at the top of the library (it is per person, so it opens
/// its own view instead of a report panel).
class _SkillMapTile extends StatelessWidget {
  const _SkillMapTile({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('EMPLOYEE SKILL MAP', style: HomeText.display(narrow ? 24 : 28, color: Colors.white, height: 1.05)),
        const SizedBox(height: 8),
        Text(
          'One person on one picture: their projects, what each needs from their role, the levels they '
          'hold and the gaps – joined by animated beams. Hover to trace a project or a competency, '
          'filter by project, save it as an image.',
          style: HomeText.body(13.5, color: HomeColors.onInk, height: 1.5),
        ),
        const SizedBox(height: 14),
        PillButton(label: 'Open skill maps', variant: PillVariant.light, height: 44, fontSize: 13.5, onPressed: onOpen),
      ],
    );
    return LiftCard(
      padding: const EdgeInsets.all(22),
      radius: 24,
      liftBy: 6,
      tiltDegrees: 3,
      color: HomeColors.ink,
      child: narrow
          ? text
          : Row(
              children: [
                const _BeamGlyph(),
                const SizedBox(width: 22),
                Expanded(child: text),
              ],
            ),
    );
  }
}

/// A small still drawing of the map (three inputs → a hub → two outputs).
class _BeamGlyph extends StatelessWidget {
  const _BeamGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 150, height: 96, child: CustomPaint(painter: _BeamGlyphPainter()));
  }
}

class _BeamGlyphPainter extends CustomPainter {
  const _BeamGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final hub = Offset(size.width / 2, size.height / 2);
    final inputs = [for (var i = 0; i < 3; i++) Offset(10, 14 + i * (size.height - 28) / 2)];
    final outputs = [Offset(size.width - 10, size.height * 0.3), Offset(size.width - 10, size.height * 0.7)];
    Path curve(Offset a, Offset b) {
      final dx = (b.dx - a.dx) / 2;
      return Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);
    }

    final blue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF8FC2FF);
    final orange = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = HomeColors.peach;
    for (var i = 0; i < inputs.length; i++) {
      canvas.drawPath(curve(inputs[i], hub), i == 2 ? orange : blue);
      canvas.drawCircle(inputs[i], 6, Paint()..color = Colors.white);
    }
    for (var i = 0; i < outputs.length; i++) {
      canvas.drawPath(curve(hub, outputs[i]), i == 1 ? orange : blue);
      canvas.drawCircle(outputs[i], 6, Paint()..color = i == 1 ? HomeColors.peach : Colors.white);
    }
    canvas.drawCircle(hub, 17, Paint()..color = const Color(0xFF3C7BE8));
    canvas.drawCircle(
      hub,
      21,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_BeamGlyphPainter oldDelegate) => false;
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({required this.type, required this.targetName, required this.onOpen, required this.onAdd});

  final ReportType type;
  final String? targetName;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LiftCard(
      padding: const EdgeInsets.all(18),
      radius: 22,
      color: Colors.white,
      borderColor: HomeColors.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3C7BE8), HomeColors.ink],
                  ),
                ),
                child: Icon(reportTypeIcon(type), size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(type.title, style: HomeText.body(15.5, weight: FontWeight.w800, color: HomeColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(type.description, style: HomeText.body(13, color: HomeColors.body, height: 1.45)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in type.views)
                StatusPill(
                  label: v.label,
                  icon: reportViewIcon(v),
                  background: HomeColors.neutralTint,
                  foreground: HomeColors.ink,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillButton(label: 'Open report', height: 42, fontSize: 13, horizontalPadding: 18, onPressed: onOpen),
              Tooltip(
                message: targetName == null ? 'Creates "My dashboard" first' : 'Adds it to "$targetName"',
                child: PillButton(
                  label: 'Add to dashboard',
                  variant: PillVariant.outline,
                  height: 42,
                  fontSize: 13,
                  horizontalPadding: 18,
                  onPressed: onAdd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ========================================================= new dashboard

/// Asks for a name and a template, then creates the dashboard.
Future<Dashboard?> showNewDashboard({required BuildContext context, required AppUser user}) {
  return showSwingPanel<Dashboard>(
    context: context,
    title: 'New dashboard',
    subtitle: 'Give it a name and choose what it starts with. You can add, change and remove widgets later.',
    width: 820,
    builder: (panelContext) => _NewDashboardForm(
      user: user,
      onDone: (d) => Navigator.of(panelContext).pop(d),
    ),
  );
}

class _NewDashboardForm extends StatefulWidget {
  const _NewDashboardForm({required this.user, required this.onDone});

  final AppUser user;
  final ValueChanged<Dashboard?> onDone;

  @override
  State<_NewDashboardForm> createState() => _NewDashboardFormState();
}

class _NewDashboardFormState extends State<_NewDashboardForm> {
  final TextEditingController _name = TextEditingController();
  DashboardTemplate _template = DashboardTemplate.overview;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final repo = DashboardRepository.instance;
    final problem = repo.nameProblem(widget.user, _name.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await repo.create(by: widget.user, name: _name.text, template: _template);
      if (mounted) widget.onDone(created);
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepPanel(
          number: 1,
          title: 'Name',
          child: TextField(
            controller: _name,
            autofocus: true,
            maxLength: DashboardRules.nameMax,
            style: adminInputStyle,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _create(),
            decoration: adminDecoration(hint: 'e.g. Q1 staffing review', errorText: _error, counter: true),
          ),
        ),
        const SizedBox(height: 18),
        StepPanel(
          number: 2,
          title: 'Start with',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 2 : 1;
              final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final t in DashboardTemplate.values)
                    SizedBox(
                      width: width,
                      child: TemplateTile(
                        template: t,
                        selected: t == _template,
                        onTap: () => setState(() => _template = t),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 22),
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
              label: _saving ? 'Creating…' : 'Create dashboard',
              height: 48,
              fontSize: 14,
              onPressed: _saving ? null : _create,
            ),
          ],
        ),
      ],
    );
  }
}

// ======================================================= Team Lead page

/// Dashboards & reports as their own page – how Team Leads open them
/// (from My Team on the Home page). Always their own department only.
class TeamReportsPage extends StatefulWidget {
  const TeamReportsPage({super.key, required this.user, this.onLogout});

  final AppUser user;
  final VoidCallback? onLogout;

  static Route<void> route({required AppUser user, VoidCallback? onLogout}) =>
      SpherePageRoute<void>(builder: (_) => TeamReportsPage(user: user, onLogout: onLogout));

  @override
  State<TeamReportsPage> createState() => _TeamReportsPageState();
}

class _TeamReportsPageState extends State<TeamReportsPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openEmployee(String id) {
    Navigator.of(context).push(EmployeeProfilePage.route(
      user: widget.user,
      employeeId: id,
      onLogout: widget.onLogout,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
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
                      title: user.role.canManageOrganization
                          ? 'Dashboards & reports'
                          : '${user.department} · Dashboards & reports',
                      user: user,
                      onBack: () => Navigator.of(context).maybePop(),
                      onProfile: () => _openEmployee(user.id),
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
                              constraints: const BoxConstraints(maxWidth: ConsoleFrame.contentWidth),
                              child: TurnIn(child: ReportsView(user: user, onOpenEmployee: _openEmployee)),
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
