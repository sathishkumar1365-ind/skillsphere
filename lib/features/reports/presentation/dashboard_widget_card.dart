import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/lift_card.dart';
import '../data/dashboards.dart';
import '../data/report_engine.dart';
import '../data/report_models.dart';
import 'report_controls.dart';
import 'report_visuals.dart';

enum _WidgetAction { edit, open, excel, csv, earlier, later, width, remove }

/// One widget on a dashboard: a report in its view. Charts can be switched
/// between the views the report supports right from the header.
class DashboardWidgetCard extends StatelessWidget {
  const DashboardWidgetCard({
    super.key,
    required this.scope,
    required this.config,
    this.onEdit,
    this.onOpenFull,
    this.onChange,
    this.onMove,
    this.onRemove,
    this.onOpenRow,
    this.isFirst = false,
    this.isLast = false,
    this.preview = false,
  });

  final ReportScope scope;
  final DashboardWidgetConfig config;
  final VoidCallback? onEdit;
  final VoidCallback? onOpenFull;

  /// The widget with a new view / width (saved by the dashboard).
  final ValueChanged<DashboardWidgetConfig>? onChange;

  /// −1 earlier, +1 later.
  final ValueChanged<int>? onMove;
  final VoidCallback? onRemove;
  final ValueChanged<ReportRow>? onOpenRow;
  final bool isFirst;
  final bool isLast;

  /// Editor preview: no menu, no actions.
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final result = ReportEngine.run(
      config.type,
      scope: scope,
      filters: config.filters,
      grouping: config.grouping,
    );
    final grouping = result.grouping;
    final subtitle = [
      if (config.title.trim().isNotEmpty) config.type.title,
      if (config.view.isChart && grouping != null) grouping.byLabel,
      if (config.type.groupsTable && config.view == ReportView.table && grouping != null) grouping.byLabel,
      result.filterLabel,
    ].join(' · ');
    final change = onChange;
    // Phones: the view switch stays in "Edit widget" to leave room for the title.
    final roomy = MediaQuery.sizeOf(context).width >= 640;
    final total = matchingRows(result, '').length;
    final shown = config.limit > 0 ? math.min(config.limit, total) : total;

    return LiftCard(
      padding: EdgeInsets.zero,
      liftBy: 5,
      tiltDegrees: 2.5,
      radius: 24,
      color: Colors.white,
      borderColor: HomeColors.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ViewBadge(icon: reportTypeIcon(config.type)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(config.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: HomeText.body(15.5, weight: FontWeight.w800, color: HomeColors.ink)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: HomeText.body(12, color: HomeColors.muted, height: 1.35)),
                    ],
                  ),
                ),
                if (!preview && change != null && roomy)
                  for (final v in config.type.views)
                    _ViewButton(
                      view: v,
                      selected: v == config.view,
                      onTap: () => change(config.copyWith(view: v)),
                    ),
                if (!preview && onOpenFull != null)
                  IconButton(
                    tooltip: 'Open the full report',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.open_in_full_rounded, size: 18, color: HomeColors.ink),
                    onPressed: onOpenFull,
                  ),
                if (!preview) _menu(context, result),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: ReportVisual(
              result: result,
              view: config.view,
              limit: config.limit,
              onOpenRow: preview ? null : onOpenRow,
            ),
          ),
          if (config.view == ReportView.table && total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing $shown of $total ${total == 1 ? 'row' : 'rows'}'
                      '${onOpenRow != null && result.rows.any((r) => r.employeeId != null) ? ' · click a row for the profile' : ''}',
                      style: HomeText.body(12, color: HomeColors.muted),
                    ),
                  ),
                  if (!preview && onOpenFull != null && shown < total)
                    TextButton(
                      onPressed: onOpenFull,
                      style: TextButton.styleFrom(
                        foregroundColor: HomeColors.ink,
                        textStyle: HomeText.body(12.5, weight: FontWeight.w700),
                      ),
                      child: const Text('See all'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, ReportResult result) {
    final full = config.width == WidgetWidth.full;
    return PopupMenuButton<_WidgetAction>(
      tooltip: 'Widget options',
      icon: const Icon(Icons.more_vert_rounded, color: HomeColors.ink),
      color: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      onSelected: (action) {
        switch (action) {
          case _WidgetAction.edit:
            onEdit?.call();
          case _WidgetAction.open:
            onOpenFull?.call();
          case _WidgetAction.excel:
            exportReport(context, result, excel: true, title: config.displayTitle);
          case _WidgetAction.csv:
            exportReport(context, result, excel: false, title: config.displayTitle);
          case _WidgetAction.earlier:
            onMove?.call(-1);
          case _WidgetAction.later:
            onMove?.call(1);
          case _WidgetAction.width:
            onChange?.call(config.copyWith(width: full ? WidgetWidth.half : WidgetWidth.full));
          case _WidgetAction.remove:
            onRemove?.call();
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null) _item(_WidgetAction.edit, Icons.tune_rounded, 'Edit widget'),
        if (onOpenFull != null) _item(_WidgetAction.open, Icons.open_in_full_rounded, 'Open full report'),
        _item(_WidgetAction.excel, Icons.file_download_outlined, 'Export to Excel'),
        _item(_WidgetAction.csv, Icons.file_download_outlined, 'Export to CSV'),
        if (onMove != null && !isFirst) _item(_WidgetAction.earlier, Icons.arrow_upward_rounded, 'Move earlier'),
        if (onMove != null && !isLast) _item(_WidgetAction.later, Icons.arrow_downward_rounded, 'Move later'),
        if (onChange != null)
          _item(_WidgetAction.width, Icons.width_normal_outlined, full ? 'Make half width' : 'Make full width'),
        if (onRemove != null) _item(_WidgetAction.remove, Icons.delete_outline_rounded, 'Remove from dashboard'),
      ],
    );
  }

  PopupMenuItem<_WidgetAction> _item(_WidgetAction value, IconData icon, String label) => PopupMenuItem<_WidgetAction>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: value == _WidgetAction.remove ? const Color(0xFFB4232A) : HomeColors.ink),
            const SizedBox(width: 12),
            Text(label,
                style: HomeText.body(14,
                    weight: FontWeight.w600,
                    color: value == _WidgetAction.remove ? const Color(0xFFB4232A) : HomeColors.ink)),
          ],
        ),
      );
}

class _ViewBadge extends StatelessWidget {
  const _ViewBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C7BE8), HomeColors.ink],
        ),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(15, 27, 45, 0.3), blurRadius: 12, spreadRadius: -5, offset: Offset(0, 6)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 19),
    );
  }
}

/// Small square button that switches the widget's view.
class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.view, required this.selected, required this.onTap});

  final ReportView view;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Show as ${view.label.toLowerCase()}',
      child: Semantics(
        button: true,
        selected: selected,
        label: view.label,
        child: Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Material(
            color: selected ? HomeColors.ink : const Color.fromRGBO(255, 255, 255, 0),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: selected ? null : onTap,
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(reportViewIcon(view), size: 17, color: selected ? Colors.white : HomeColors.muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
