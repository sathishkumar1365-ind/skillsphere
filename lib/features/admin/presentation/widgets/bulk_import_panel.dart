import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../competency/data/sheet_file_reader.dart';
import '../../../competency/presentation/widgets/competency_common.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/admin_import.dart';
import 'admin_common.dart';

const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const XTypeGroup _spreadsheets = XTypeGroup(
  label: 'Excel or CSV',
  extensions: <String>['xlsx', 'csv'],
  mimeTypes: <String>[_xlsxMime, 'text/csv'],
  uniformTypeIdentifiers: <String>[
    'org.openxmlformats.spreadsheetml.sheet',
    'public.comma-separated-values-text',
  ],
);

const XTypeGroup _excel = XTypeGroup(
  label: 'Excel workbook',
  extensions: <String>['xlsx'],
  mimeTypes: <String>[_xlsxMime],
  uniformTypeIdentifiers: <String>['org.openxmlformats.spreadsheetml.sheet'],
);

/// What a [BulkImportPanel] imports and how.
class BulkImportConfig<T> {
  const BulkImportConfig({
    required this.title,
    required this.subtitle,
    required this.templateAsset,
    required this.templateFileName,
    required this.templateDescription,
    required this.columnsHelp,
    required this.singular,
    required this.plural,
    required this.parse,
    required this.commit,
  });

  final String title;
  final String subtitle;
  final String templateAsset;
  final String templateFileName;
  final String templateDescription;
  final String columnsHelp;

  /// "employee" / "employees"
  final String singular;
  final String plural;

  /// Reads and checks a file (throws [SheetFileException] when unreadable).
  final ImportPreview<T> Function(Uint8List bytes, String fileName) parse;

  /// Saves the ready rows; returns how many were added.
  final Future<int> Function(List<T> values) commit;
}

enum _RowFilter { all, ready, skipped }

/// Download template → choose file → check every row → import the ready
/// ones. Same flow as the competency import.
class BulkImportPanel<T> extends StatefulWidget {
  const BulkImportPanel({super.key, required this.config, required this.onImported});

  final BulkImportConfig<T> config;

  /// Called with the number of records added.
  final ValueChanged<int> onImported;

  @override
  State<BulkImportPanel<T>> createState() => _BulkImportPanelState<T>();
}

class _BulkImportPanelState<T> extends State<BulkImportPanel<T>> {
  static const _pageSize = 25;

  ImportPreview<T>? _result;
  String? _readError;
  bool _reading = false;
  bool _importing = false;
  _RowFilter _filter = _RowFilter.all;
  int _limit = _pageSize;

  BulkImportConfig<T> get _config => widget.config;

  Future<void> _downloadTemplate() async {
    try {
      final data = await rootBundle.load(_config.templateAsset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final name = _config.templateFileName;
      // On the web the browser downloads the file; elsewhere ask where to save.
      final FileSaveLocation? location = kIsWeb
          ? const FileSaveLocation('')
          : await getSaveLocation(suggestedName: name, acceptedTypeGroups: const <XTypeGroup>[_excel]);
      if (location == null) return;
      await XFile.fromData(bytes, name: name, mimeType: _xlsxMime).saveTo(location.path);
      if (mounted) showAdminMessage(context, kIsWeb ? 'Template downloaded.' : 'Template saved.');
    } catch (e) {
      if (mounted) showAdminMessage(context, 'Could not save the template: $e');
    }
  }

  Future<void> _chooseFile() async {
    XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: const <XTypeGroup>[_spreadsheets]);
    } catch (e) {
      if (mounted) showAdminMessage(context, 'Could not open the file picker: $e');
      return;
    }
    if (file == null || !mounted) return;
    setState(() {
      _reading = true;
      _readError = null;
      _result = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final result = _config.parse(bytes, file.name);
      if (!mounted) return;
      setState(() {
        _result = result;
        _filter = _RowFilter.all;
        _limit = _pageSize;
      });
    } on SheetFileException catch (e) {
      if (mounted) setState(() => _readError = e.message);
    } catch (e) {
      if (mounted) setState(() => _readError = 'This file could not be read ($e).');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _import() async {
    final result = _result;
    if (result == null) return;
    final values = result.readyValues;
    if (values.isEmpty) return;
    setState(() => _importing = true);
    try {
      final added = await _config.commit(values);
      if (!mounted) return;
      setState(() {
        _result = null;
        _readError = null;
      });
      if (added == 0) {
        showAdminMessage(context, 'Nothing was imported: those ${_config.plural} already exist.');
      } else {
        widget.onImported(added);
      }
    } on AdminException catch (e) {
      if (mounted) showAdminMessage(context, e.message);
    } catch (e) {
      if (mounted) showAdminMessage(context, 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _reset() => setState(() {
        _result = null;
        _readError = null;
      });

  String _importLabel(int count) => switch (count) {
        0 => 'Nothing to import',
        1 => 'Import 1 ${_config.singular}',
        _ => 'Import $count ${_config.plural}',
      };

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final error = _readError ?? result?.fileProblem;
    final ready = result?.count(ImportStatus.ready) ?? 0;

    return StepPanel(
      icon: Icons.upload_file_rounded,
      title: _config.title,
      subtitle: _config.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(
            number: 1,
            title: 'Download the template',
            body: _config.templateDescription,
            action: PillButton(
              label: 'Download template (.xlsx)',
              variant: PillVariant.outline,
              height: 44,
              fontSize: 14,
              horizontalPadding: 20,
              onPressed: _downloadTemplate,
            ),
          ),
          const SizedBox(height: 12),
          _Step(
            number: 2,
            title: 'Fill in one row per ${_config.singular}',
            body: '${_config.columnsHelp} Save as .xlsx or CSV UTF-8.',
          ),
          const SizedBox(height: 12),
          _Step(
            number: 3,
            title: 'Upload and check',
            body: result == null
                ? 'Nothing is saved until you press Import.'
                : '${result.fileName}${result.sheetName == 'CSV' ? '' : ' · sheet "${result.sheetName}"'}',
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PillButton(
                  label: _reading
                      ? 'Reading…'
                      : (result == null && _readError == null ? 'Choose file' : 'Choose another file'),
                  height: 44,
                  fontSize: 14,
                  horizontalPadding: 20,
                  onPressed: _reading || _importing ? null : _chooseFile,
                ),
                if (result != null || _readError != null)
                  TextButton(
                    onPressed: _importing ? null : _reset,
                    style: TextButton.styleFrom(
                      foregroundColor: HomeColors.muted,
                      textStyle: HomeText.body(13.5, weight: FontWeight.w700),
                    ),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            InfoNote(tone: NoteTone.error, text: error),
          ] else if (result != null) ...[
            const SizedBox(height: 18),
            TurnIn(
              replayKey: result,
              child: _Results<T>(
                result: result,
                filter: _filter,
                limit: _limit,
                onFilter: (f) => setState(() {
                  _filter = f;
                  _limit = _pageSize;
                }),
                onShowMore: () => setState(() => _limit += _pageSize),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PillButton(
                  label: _importing ? 'Importing…' : _importLabel(ready),
                  onPressed: _importing || ready == 0 ? null : _import,
                ),
                PillButton(
                  label: 'Cancel',
                  variant: PillVariant.outline,
                  onPressed: _importing ? null : _reset,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Rows with problems and ${_config.plural} that already exist are skipped. '
              'Fix them in the file and upload it again.',
              style: HomeText.body(12.5, color: HomeColors.muted, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body, this.action});

  final int number;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final extra = action;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F8FC),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: levelBlockColor(number + 1), shape: BoxShape.circle),
            child: Text('$number', style: HomeText.body(13, weight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HomeText.body(14.5, weight: FontWeight.w700, color: HomeColors.ink)),
                const SizedBox(height: 3),
                Text(body, style: HomeText.body(13, color: HomeColors.body, height: 1.45)),
                if (extra != null) ...[const SizedBox(height: 10), extra],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Results<T> extends StatelessWidget {
  const _Results({
    required this.result,
    required this.filter,
    required this.limit,
    required this.onFilter,
    required this.onShowMore,
  });

  final ImportPreview<T> result;
  final _RowFilter filter;
  final int limit;
  final ValueChanged<_RowFilter> onFilter;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final ready = result.count(ImportStatus.ready);
    final duplicates = result.count(ImportStatus.duplicate);
    final problems = result.count(ImportStatus.problem);
    final rows = switch (filter) {
      _RowFilter.all => result.rows,
      _RowFilter.ready => result.rows.where((r) => r.status == ImportStatus.ready).toList(),
      _RowFilter.skipped => result.rows.where((r) => r.status != ImportStatus.ready).toList(),
    };
    final shown = rows.take(limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: '$ready ready',
                icon: Icons.check_circle_outline_rounded,
                background: OrgColors.goodTint,
                foreground: OrgColors.good,
              ),
              if (duplicates > 0)
                StatusPill(
                  label: '$duplicates already exist',
                  icon: Icons.content_copy_rounded,
                  background: HomeColors.neutralTint,
                  foreground: HomeColors.body,
                ),
              if (problems > 0)
                StatusPill(
                  label: '$problems with problems',
                  icon: Icons.error_outline_rounded,
                  background: const Color(0xFFFDECEC),
                  foreground: const Color(0xFFB4232A),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OrgFilterPill(
              label: 'All rows · ${result.rows.length}',
              selected: filter == _RowFilter.all,
              onTap: () => onFilter(_RowFilter.all),
            ),
            OrgFilterPill(
              label: 'Ready · $ready',
              selected: filter == _RowFilter.ready,
              onTap: () => onFilter(_RowFilter.ready),
            ),
            OrgFilterPill(
              label: 'Skipped · ${duplicates + problems}',
              selected: filter == _RowFilter.skipped,
              onTap: () => onFilter(_RowFilter.skipped),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Text('No rows here.', style: HomeText.body(13.5, color: HomeColors.muted))
        else
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _RowTile<T>(row: shown[i]),
          ],
        if (rows.length > shown.length) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: onShowMore,
              style: TextButton.styleFrom(
                foregroundColor: HomeColors.blue,
                textStyle: HomeText.body(13.5, weight: FontWeight.w700),
              ),
              child: Text('Show more rows (${rows.length - shown.length} left)'),
            ),
          ),
        ],
      ],
    );
  }
}

class _RowTile<T> extends StatelessWidget {
  const _RowTile({required this.row});

  final ImportRow<T> row;

  @override
  Widget build(BuildContext context) {
    final status = row.status;
    final border = switch (status) {
      ImportStatus.ready => HomeColors.cardBorder,
      ImportStatus.duplicate => HomeColors.chipBorder,
      ImportStatus.problem => const Color(0xFFF5C2C3),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F8FC),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text('${row.rowNumber}',
                    style: HomeText.body(12, weight: FontWeight.w800, color: HomeColors.muted)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink)),
                    Text(
                      'Row ${row.rowNumber}${row.subtitle.isEmpty ? '' : ' · ${row.subtitle}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.body(12, color: HomeColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              switch (status) {
                ImportStatus.ready => const StatusPill(
                    label: 'Ready',
                    icon: Icons.check_rounded,
                    background: OrgColors.goodTint,
                    foreground: OrgColors.good,
                  ),
                ImportStatus.duplicate => const StatusPill(
                    label: 'Skipped',
                    icon: Icons.content_copy_rounded,
                    background: HomeColors.neutralTint,
                    foreground: HomeColors.body,
                  ),
                ImportStatus.problem => const StatusPill(
                    label: 'Fix',
                    icon: Icons.error_outline_rounded,
                    background: Color(0xFFFDECEC),
                    foreground: Color(0xFFB4232A),
                  ),
              },
            ],
          ),
          if (status == ImportStatus.problem) ...[
            const SizedBox(height: 8),
            for (final p in row.problems)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $p', style: HomeText.body(12.5, color: const Color(0xFFB4232A), height: 1.4)),
              ),
          ] else if (status == ImportStatus.duplicate) ...[
            const SizedBox(height: 6),
            Text(row.duplicateNote ?? '', style: HomeText.body(12.5, color: HomeColors.body)),
          ],
        ],
      ),
    );
  }
}
