import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../admin/presentation/widgets/admin_common.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../data/dashboards.dart';
import '../data/report_engine.dart';
import '../data/report_models.dart';
import 'dashboard_widget_card.dart';
import 'report_controls.dart';
import 'report_visuals.dart';

/// Opens the widget editor. [initial] edits an existing widget; otherwise a
/// new one starts on [initialType] (or the first report). Returns the
/// widget to save, or null when cancelled.
Future<DashboardWidgetConfig?> showWidgetEditor({
  required BuildContext context,
  required AppUser user,
  DashboardWidgetConfig? initial,
  ReportType? initialType,
  String? dashboardName,
}) {
  return showSwingPanel<DashboardWidgetConfig>(
    context: context,
    title: initial == null ? 'Add a widget' : 'Edit widget',
    subtitle: [
      if (dashboardName != null) 'Dashboard: $dashboardName',
      'Pick a report, how to show it and its filters. The preview updates as you go.',
    ].join(' · '),
    width: 1060,
    builder: (panelContext) => _WidgetEditor(
      user: user,
      initial: initial,
      initialType: initialType,
      onDone: (config) => Navigator.of(panelContext).pop(config),
    ),
  );
}

class _WidgetEditor extends StatefulWidget {
  const _WidgetEditor({required this.user, required this.initial, required this.initialType, required this.onDone});

  final AppUser user;
  final DashboardWidgetConfig? initial;
  final ReportType? initialType;
  final ValueChanged<DashboardWidgetConfig?> onDone;

  @override
  State<_WidgetEditor> createState() => _WidgetEditorState();
}

class _WidgetEditorState extends State<_WidgetEditor> {
  late final ReportScope _scope = ReportScope.of(widget.user);
  late ReportType _type = widget.initial?.type ?? widget.initialType ?? ReportType.competencyInventory;
  late ReportView _view = widget.initial?.view ?? _type.defaultView;
  late ReportGrouping? _grouping = widget.initial?.grouping;
  late ReportFilters _filters = widget.initial?.filters ?? ReportFilters.none;
  late WidgetWidth _width = widget.initial?.width ?? _defaultWidth(_view);
  late int _limit = widget.initial?.limit ?? 8;
  late final TextEditingController _title = TextEditingController(text: widget.initial?.title ?? '');
  ReportDataset? _dataset;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  static WidgetWidth _defaultWidth(ReportView view) =>
      view == ReportView.table || view == ReportView.kpi ? WidgetWidth.full : WidgetWidth.half;

  void _pickType(ReportType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _view = type.views.contains(_view) ? _view : type.defaultView;
      _grouping = null;
      _filters = _filters.forType(type);
      _width = _defaultWidth(_view);
    });
  }

  void _pickView(ReportView view) {
    setState(() {
      // Follow the view's natural width unless the user changed it.
      if (_width == _defaultWidth(_view)) _width = _defaultWidth(view);
      _view = view;
    });
  }

  DashboardWidgetConfig get _config => DashboardWidgetConfig(
        id: widget.initial?.id ?? '',
        type: _type,
        view: _view,
        grouping: _grouping,
        filters: _filters.forType(_type),
        title: _title.text,
        width: _width,
        limit: _limit,
      );

  @override
  Widget build(BuildContext context) {
    final groupings = ReportEngine.groupingsFor(_type, _scope);
    final grouping = _grouping != null && groupings.contains(_grouping)
        ? _grouping
        : ReportEngine.defaultGrouping(_type, _scope);
    final showGrouping =
        groupings.length > 1 && (_view.isChart || (_type.groupsTable && _view == ReportView.table));
    final reports = ReportType.values.where((t) => _dataset == null || t.dataset == _dataset).toList();
    final narrow = MediaQuery.sizeOf(context).width < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepPanel(
          number: 1,
          title: 'Choose a report',
          subtitle: _scope.isOrganisation
              ? 'Every report covers the whole organisation; narrow it down with the filters in step 3.'
              : 'Every report covers ${_scope.label} only.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OrgFilterPill(label: 'All reports', selected: _dataset == null, onTap: () => setState(() => _dataset = null)),
                  for (final d in ReportDataset.values)
                    OrgFilterPill(label: d.label, selected: _dataset == d, onTap: () => setState(() => _dataset = d)),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 860 ? 3 : (constraints.maxWidth >= 520 ? 2 : 1);
                  final tileWidth = (constraints.maxWidth - 10 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final t in reports)
                        SizedBox(
                          width: tileWidth,
                          child: ReportChoiceTile(type: t, selected: t == _type, onTap: () => _pickType(t)),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        StepPanel(
          number: 2,
          title: 'Show it as',
          subtitle: 'Pie charts show up to five parts and "Other", with each share in %.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final v in _type.views)
                    _ViewChoice(view: v, selected: v == _view, onTap: () => _pickView(v)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  if (showGrouping)
                    SizedBox(
                      width: narrow ? double.infinity : 240,
                      child: LabeledField(
                        label: _view == ReportView.table ? 'Rows' : 'Group the chart',
                        child: AdminDropdown<ReportGrouping>(
                          value: grouping,
                          items: groupings,
                          labelOf: (g) => g.byLabel,
                          onChanged: (g) => setState(() => _grouping = g),
                        ),
                      ),
                    ),
                  if (_view != ReportView.kpi)
                    SizedBox(
                      width: narrow ? double.infinity : 200,
                      child: LabeledField(
                        label: _view == ReportView.table ? 'Rows shown' : (_view == ReportView.bar ? 'Bars shown' : 'Shown'),
                        child: AdminDropdown<int>(
                          value: _limit,
                          items: DashboardRules.limits,
                          labelOf: (n) => n == 0 ? 'All' : (_view == ReportView.pie ? 'Top 5 + Other' : 'First $n'),
                          onChanged: _view == ReportView.pie ? null : (n) => setState(() => _limit = n),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: narrow ? double.infinity : 320,
                    child: LabeledField(
                      label: 'Size on the dashboard',
                      child: ModeSwitch<WidgetWidth>(
                        options: const [
                          ModeOption(WidgetWidth.half, 'Half width', Icons.width_normal_outlined),
                          ModeOption(WidgetWidth.full, 'Full width', Icons.width_full_outlined),
                        ],
                        selected: _width,
                        onChanged: (w) => setState(() => _width = w),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        StepPanel(
          number: 3,
          title: 'Filters',
          subtitle: _scope.isOrganisation
              ? 'Optional. Division, group and department narrow the people in the report.'
              : 'Optional. Your department is always applied.',
          trailing: _filters.forType(_type).isEmpty
              ? null
              : TextButton(
                  onPressed: () => setState(() => _filters = ReportFilters.none),
                  style: TextButton.styleFrom(
                    foregroundColor: HomeColors.ink,
                    textStyle: HomeText.body(13, weight: FontWeight.w700),
                  ),
                  child: const Text('Clear'),
                ),
          child: ReportFilterControls(
            scope: _scope,
            type: _type,
            filters: _filters.forType(_type),
            onChanged: (f) => setState(() => _filters = f),
          ),
        ),
        const SizedBox(height: 18),
        StepPanel(
          number: 4,
          title: 'Title',
          subtitle: 'Optional. Leave empty to use the report\'s name.',
          child: TextField(
            controller: _title,
            maxLength: DashboardRules.titleMax,
            style: adminInputStyle,
            onChanged: (_) => setState(() {}),
            decoration: adminDecoration(hint: _type.title, counter: true),
          ),
        ),
        const SizedBox(height: 18),
        Text('PREVIEW', style: HomeText.body(12, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.topLeft,
          child: FractionallySizedBox(
            widthFactor: _width == WidgetWidth.half && !narrow ? 0.6 : 1,
            child: TurnIn(
              replayKey: '${_type.name}|${_view.name}',
              child: DashboardWidgetCard(scope: _scope, config: _config, preview: true),
            ),
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
              onPressed: () => widget.onDone(null),
            ),
            PillButton(
              label: widget.initial == null ? 'Add to dashboard' : 'Save widget',
              height: 48,
              fontSize: 14,
              onPressed: () => widget.onDone(_config),
            ),
          ],
        ),
      ],
    );
  }
}

/// A report in the catalogue: icon, name, what it shows and its views.
class ReportChoiceTile extends StatefulWidget {
  const ReportChoiceTile({super.key, required this.type, required this.selected, required this.onTap});

  final ReportType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<ReportChoiceTile> createState() => _ReportChoiceTileState();
}

class _ReportChoiceTileState extends State<ReportChoiceTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.type;
    final selected = widget.selected;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: t.title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: selected ? 1 : (_hover ? 0.6 : 0)),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
            curve: HomeMotion.ease,
            builder: (context, lift, child) {
              final matrix = lift == 0
                  ? Matrix4.identity()
                  : (Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..multiply(Matrix4.translationValues(0, -3 * lift, 0))
                    ..multiply(Matrix4.rotationX(-0.08 * lift)));
              return Transform(alignment: Alignment.center, transform: matrix, child: child);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFF2F7FE) : Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                border: Border.all(color: selected ? HomeColors.ink : HomeColors.cardBorder, width: selected ? 1.6 : 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? HomeColors.ink : HomeColors.blueTint,
                      borderRadius: const BorderRadius.all(Radius.circular(11)),
                    ),
                    child: Icon(reportTypeIcon(t), size: 18, color: selected ? Colors.white : HomeColors.blueDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(14, weight: FontWeight.w800, color: HomeColors.ink)),
                        const SizedBox(height: 3),
                        Text(t.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(12, color: HomeColors.muted, height: 1.4)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final v in t.views)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Tooltip(
                                  message: v.label,
                                  child: Icon(reportViewIcon(v), size: 16, color: HomeColors.muted),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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

class _ViewChoice extends StatelessWidget {
  const _ViewChoice({required this.view, required this.selected, required this.onTap});

  final ReportView view;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? HomeColors.ink : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: selected ? HomeColors.ink : HomeColors.chipBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 128,
            height: 82,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(reportViewIcon(view), size: 26, color: selected ? Colors.white : HomeColors.ink),
                const SizedBox(height: 6),
                Text(view.label,
                    style: HomeText.body(13, weight: FontWeight.w700, color: selected ? Colors.white : HomeColors.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
