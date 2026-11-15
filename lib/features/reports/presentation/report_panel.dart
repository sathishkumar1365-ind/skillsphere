import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../admin/data/admin_base.dart';
import '../../admin/data/insights.dart';
import '../../admin/presentation/widgets/admin_common.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../data/dashboards.dart';
import '../data/report_engine.dart';
import '../data/report_models.dart';
import 'report_controls.dart';
import 'report_visuals.dart';

/// Opens a report in full: filters, key numbers, the chart, every row
/// (search + sort) and Excel / CSV export. [onOpenEmployee] opens a
/// profile from a row.
Future<void> showReportPanel({
  required BuildContext context,
  required AppUser user,
  required ReportType type,
  ReportFilters filters = ReportFilters.none,
  ReportGrouping? grouping,
  ReportView? chartView,
  String? title,
  ValueChanged<String>? onOpenEmployee,
}) {
  return showSwingPanel<void>(
    context: context,
    title: title ?? type.title,
    subtitle: type.description,
    width: 1200,
    builder: (panelContext) => ReportExplorer(
      user: user,
      type: type,
      initialFilters: filters,
      initialGrouping: grouping,
      initialChartView: chartView,
      title: title,
      onOpenEmployee: onOpenEmployee,
    ),
  );
}

class ReportExplorer extends StatefulWidget {
  const ReportExplorer({
    super.key,
    required this.user,
    required this.type,
    this.initialFilters = ReportFilters.none,
    this.initialGrouping,
    this.initialChartView,
    this.title,
    this.onOpenEmployee,
  });

  final AppUser user;
  final ReportType type;
  final ReportFilters initialFilters;
  final ReportGrouping? initialGrouping;
  final ReportView? initialChartView;
  final String? title;
  final ValueChanged<String>? onOpenEmployee;

  @override
  State<ReportExplorer> createState() => _ReportExplorerState();
}

class _ReportExplorerState extends State<ReportExplorer> {
  static const int _pageSize = 50;

  late final ReportScope _scope = ReportScope.of(widget.user);
  late ReportFilters _filters = widget.initialFilters.forType(widget.type);
  late ReportGrouping? _grouping = widget.initialGrouping;
  late ReportView? _chartView = _firstChartView();
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _limit = _pageSize;

  ReportView? _firstChartView() {
    final wanted = widget.initialChartView;
    if (wanted != null && wanted.isChart && widget.type.views.contains(wanted)) return wanted;
    for (final v in widget.type.views) {
      if (v.isChart) return v;
    }
    return null;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _addToDashboard(Dashboard dashboard) {
    final type = widget.type;
    try {
      final view = _chartView ?? type.defaultView;
      DashboardRepository.instance.addWidget(
        by: widget.user,
        dashboardId: dashboard.id,
        config: DashboardWidgetConfig(
          id: '',
          type: type,
          view: view,
          grouping: _grouping,
          filters: _filters,
          width: view == ReportView.table || view == ReportView.kpi ? WidgetWidth.full : WidgetWidth.half,
        ),
      );
      showAdminMessage(context, 'Added to "${dashboard.name}".');
    } on AdminException catch (e) {
      showAdminMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    return ListenableBuilder(
      listenable: Listenable.merge([Insights.listenable, DashboardRepository.instance.dashboards]),
      builder: (context, _) {
        final result = ReportEngine.run(type, scope: _scope, filters: _filters, grouping: _grouping);
        final groupings = ReportEngine.groupingsFor(type, _scope);
        final grouping = result.grouping;
        final chart = result.chart;
        final chartView = _chartView;
        final matching = matchingRows(result, _query).length;
        final shown = matching < _limit ? matching : _limit;
        final dashboards = DashboardRepository.instance.forUser(widget.user);
        final open = widget.onOpenEmployee;
        final narrow = MediaQuery.sizeOf(context).width < 640;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ReportScopeBanner(scope: _scope),
                PillButton(
                  label: 'Export Excel',
                  height: 44,
                  fontSize: 13.5,
                  horizontalPadding: 20,
                  onPressed: () => exportReport(context, result, excel: true, title: widget.title),
                ),
                PillButton(
                  label: 'Export CSV',
                  variant: PillVariant.outline,
                  height: 44,
                  fontSize: 13.5,
                  horizontalPadding: 20,
                  onPressed: () => exportReport(context, result, excel: false, title: widget.title),
                ),
                if (dashboards.isNotEmpty)
                  PopupMenuButton<Dashboard>(
                    tooltip: 'Add this report to one of your dashboards',
                    color: Colors.white,
                    offset: const Offset(0, 48),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                    onSelected: _addToDashboard,
                    itemBuilder: (context) => [
                      for (final d in dashboards)
                        PopupMenuItem<Dashboard>(
                          value: d,
                          child: Text('${d.name} (${d.widgets.length})',
                              style: HomeText.body(14, weight: FontWeight.w600, color: HomeColors.ink)),
                        ),
                    ],
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.all(Radius.circular(999)),
                        border: Border.all(color: HomeColors.chipBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.dashboard_customize_outlined, size: 18, color: HomeColors.ink),
                          const SizedBox(width: 8),
                          Text('Add to dashboard',
                              style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            OrgPanel(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: PanelTitle('Filters', subtitle: result.filterLabel)),
                      if (!_filters.isEmpty)
                        TextButton(
                          onPressed: () => setState(() {
                            _filters = ReportFilters.none;
                            _limit = _pageSize;
                          }),
                          style: TextButton.styleFrom(
                            foregroundColor: HomeColors.ink,
                            textStyle: HomeText.body(13, weight: FontWeight.w700),
                          ),
                          child: const Text('Clear filters'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ReportFilterControls(
                    scope: _scope,
                    type: type,
                    filters: _filters,
                    onChanged: (f) => setState(() {
                      _filters = f;
                      _limit = _pageSize;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ReportKpiGrid(kpis: result.kpis),
            if (chart != null && chartView != null) ...[
              const SizedBox(height: 18),
              OrgPanel(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        PanelTitle(chart.title),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (groupings.length > 1)
                              SizedBox(
                                width: narrow ? 220 : 240,
                                child: AdminDropdown<ReportGrouping>(
                                  value: grouping,
                                  items: groupings,
                                  labelOf: (g) => g.byLabel,
                                  onChanged: (g) => setState(() => _grouping = g),
                                ),
                              ),
                            for (final v in type.views.where((v) => v.isChart))
                              OrgFilterPill(
                                label: v.label,
                                selected: v == chartView,
                                onTap: () => setState(() => _chartView = v),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ReportVisual(result: result, view: chartView),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            OrgPanel(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      PanelTitle(
                        'All rows',
                        subtitle: 'Showing $shown of $matching'
                            '${matching == result.rows.length ? '' : ' (${result.rows.length} before search)'}'
                            ' · click a header to sort'
                            '${open != null && result.rows.any((r) => r.employeeId != null) ? ' · click a row for the profile' : ''}',
                      ),
                      SizedBox(
                        width: narrow ? 260 : 300,
                        child: AdminSearchField(
                          controller: _search,
                          hint: 'Search every column…',
                          onChanged: (v) => setState(() {
                            _query = v;
                            _limit = _pageSize;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ReportTable(
                    result: result,
                    limit: _limit,
                    query: _query,
                    onOpenRow: open == null
                        ? null
                        : (row) {
                            final id = row.employeeId;
                            if (id != null) open(id);
                          },
                  ),
                  if (matching > shown) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: PillButton(
                        label: 'Show more (${matching - shown} left)',
                        variant: PillVariant.outline,
                        height: 44,
                        fontSize: 13.5,
                        onPressed: () => setState(() => _limit += _pageSize),
                      ),
                    ),
                  ],
                  if (result.note != null) ...[
                    const SizedBox(height: 14),
                    InfoNote(text: result.note!),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
