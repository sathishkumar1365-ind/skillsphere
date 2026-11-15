// Exports reports as Excel (.xlsx) or CSV.
//
// The .xlsx is written by hand (a zip of SpreadsheetML parts, zipped with
// package:archive – already a dependency), so no new package is needed:
// * a "Summary" sheet with every report's key numbers and filters;
// * one sheet per report: title, scope · filters · date, then the table with
//   a bold header row that stays in view (frozen) and has filter buttons.
// Numbers stay numbers: levels show as "L3" but sort as 3, gaps as −2 /
// "Met", percentages as 45%, dates as real Excel dates.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../admin/data/admin_base.dart';
import 'report_models.dart';

class ReportExport {
  ReportExport._();

  static const String xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const String csvMime = 'text/csv';

  /// "SkillSphere_All_competencies_2026-11-15.xlsx"
  static String fileName(String title, String extension, {DateTime? at}) {
    final cleaned = title
        .replaceAll(RegExp(r'[^A-Za-z0-9 _\-]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final base = cleaned.isEmpty ? 'Report' : (cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned);
    return 'SkillSphere_${base}_${isoDate(at ?? DateTime.now())}.$extension';
  }

  // ------------------------------------------------------------------ CSV

  /// One report as CSV (UTF-8 with a byte-order mark so Excel reads
  /// accents and symbols correctly). Header row first.
  static Uint8List csv(ReportResult result) {
    final buffer = StringBuffer('﻿');
    buffer.writeln(result.columns.map((c) => _csvField(c.label, guard: true)).join(','));
    for (final row in result.rows) {
      final fields = <String>[];
      for (var i = 0; i < result.columns.length; i++) {
        final column = result.columns[i];
        final value = i < row.cells.length ? row.cells[i] : null;
        fields.add(_csvField(_csvText(value, column.kind), guard: column.kind == CellKind.text));
      }
      buffer.writeln(fields.join(','));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String _csvText(Object? value, CellKind kind) {
    if (value == null) return '';
    switch (kind) {
      case CellKind.gap:
        if (value is int) return value == 0 ? 'Met' : '$value';
        return '$value';
      case CellKind.date:
        return value is DateTime ? isoDate(value) : '$value';
      case CellKind.decimal:
        return value is num ? value.toStringAsFixed(1) : '$value';
      case CellKind.percent:
        return value is num ? '${value.round()}' : '$value';
      case CellKind.level:
      case CellKind.number:
      case CellKind.text:
        return reportCellText(value, kind);
    }
  }

  static String _csvField(String text, {bool guard = false}) {
    var value = text;
    // A text cell starting with = + @ would run as a formula in Excel.
    if (guard && value.isNotEmpty && '=+@'.contains(value[0])) value = "'$value";
    final needsQuotes = value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    return needsQuotes ? '"${value.replaceAll('"', '""')}"' : value;
  }

  // ----------------------------------------------------------------- XLSX

  /// [results] as one workbook: a Summary sheet, then a sheet per result.
  /// [title] heads the Summary sheet (dashboard or report name); [names]
  /// optionally names the result sheets (widget titles).
  static Uint8List xlsx(List<ReportResult> results, {required String title, List<String>? names}) {
    final sheetNames = <String>['Summary'];
    for (var i = 0; i < results.length; i++) {
      final wanted = names != null && i < names.length && names[i].trim().isNotEmpty ? names[i] : results[i].title;
      sheetNames.add(_uniqueSheetName(wanted, sheetNames));
    }
    final now = results.isEmpty ? DateTime.now() : results.first.generatedAt;

    final sheets = <String>[
      _summarySheet(results, sheetNames, title: title, at: now),
      for (final result in results) _reportSheet(result),
    ];

    final archive = Archive();
    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes(sheets.length));
    add('_rels/.rels', _rootRels);
    add('xl/workbook.xml', _workbook(sheetNames, results));
    add('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length));
    add('xl/styles.xml', _styles);
    for (var i = 0; i < sheets.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', sheets[i]);
    }
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  // Style ids in styles.xml (cellXfs order).
  static const int _sHeader = 1;
  static const int _sTitle = 2;
  static const int _sInfo = 3;
  static const int _sInteger = 4;
  static const int _sDecimal = 5;
  static const int _sPercent = 6;
  static const int _sBold = 7;
  static const int _sLevel = 8;
  static const int _sGap = 9;
  static const int _sDate = 10;
  static const int _sWrap = 11;

  /// Data starts on this row (1-based); the header is the row above.
  static const int _headerRow = 4;

  static String _summarySheet(List<ReportResult> results, List<String> sheetNames,
      {required String title, required DateTime at}) {
    final rows = StringBuffer();
    var r = 1;
    void row(List<String> cells) {
      rows.write('<row r="$r">');
      rows.writeAll(cells);
      rows.write('</row>');
      r++;
    }

    row([_text(1, r, title, _sTitle)]);
    final scope = results.isEmpty ? '' : results.first.scopeLabel;
    row([_text(1, r, 'SkillSphere · $scope · generated ${dayMonthYear(at)} ${_time(at)}', _sInfo)]);
    r++;
    for (var i = 0; i < results.length; i++) {
      final res = results[i];
      row([
        _text(1, r, sheetNames[i + 1], _sHeader),
        _text(2, r, 'Value', _sHeader),
        _text(3, r, 'Details', _sHeader),
      ]);
      row([
        _text(1, r, 'Report', _sBold),
        _text(2, r, res.title, 0),
        _text(3, r, '${res.filterLabel} · ${res.rows.length} rows (sheet "${sheetNames[i + 1]}")', _sWrap),
      ]);
      for (final k in res.kpis) {
        row([
          _text(1, r, k.label, _sBold),
          _text(2, r, k.value, 0),
          _text(3, r, k.caption ?? '', _sWrap),
        ]);
      }
      final note = res.note;
      if (note != null) row([_text(1, r, 'Note', _sBold), _text(3, r, note, _sWrap)]);
      r++;
    }
    return _worksheet(
      rows.toString(),
      widths: const [34, 30, 70],
      frozenRows: 0,
    );
  }

  static String _reportSheet(ReportResult result) {
    final rows = StringBuffer();
    final columns = result.columns;
    rows.write('<row r="1">${_text(1, 1, result.title, _sTitle)}</row>');
    rows.write('<row r="2">${_text(1, 2, '${result.scopeLabel} · ${result.filterLabel} · '
        'generated ${dayMonthYear(result.generatedAt)} ${_time(result.generatedAt)}', _sInfo)}</row>');
    final header = StringBuffer('<row r="$_headerRow">');
    for (var c = 0; c < columns.length; c++) {
      header.write(_text(c + 1, _headerRow, columns[c].label, _sHeader));
    }
    header.write('</row>');
    rows.write(header);
    var r = _headerRow + 1;
    for (final row in result.rows) {
      rows.write('<row r="$r">');
      for (var c = 0; c < columns.length; c++) {
        final value = c < row.cells.length ? row.cells[c] : null;
        rows.write(_cell(c + 1, r, value, columns[c].kind));
      }
      rows.write('</row>');
      r++;
    }
    final lastRow = result.rows.isEmpty ? _headerRow : r - 1;
    final widths = <double>[
      for (var c = 0; c < columns.length; c++) _width(columns[c], result.rows, c),
    ];
    final filterRef = 'A$_headerRow:${_columnName(columns.length)}$lastRow';
    return _worksheet(rows.toString(), widths: widths, frozenRows: _headerRow, autoFilter: filterRef);
  }

  static String _worksheet(String rows, {required List<double> widths, required int frozenRows, String? autoFilter}) {
    final cols = StringBuffer('<cols>');
    for (var i = 0; i < widths.length; i++) {
      cols.write('<col min="${i + 1}" max="${i + 1}" width="${widths[i].toStringAsFixed(1)}" customWidth="1"/>');
    }
    cols.write('</cols>');
    final pane = frozenRows <= 0
        ? '<sheetView workbookViewId="0"/>'
        : '<sheetView workbookViewId="0"><pane ySplit="$frozenRows" topLeftCell="A${frozenRows + 1}" '
            'activePane="bottomLeft" state="frozen"/><selection pane="bottomLeft" activeCell="A${frozenRows + 1}" '
            'sqref="A${frozenRows + 1}"/></sheetView>';
    final filter = autoFilter == null ? '' : '<autoFilter ref="$autoFilter"/>';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheetViews>$pane</sheetViews>'
        '<sheetFormatPr defaultRowHeight="15"/>'
        '$cols'
        '<sheetData>$rows</sheetData>'
        '$filter'
        '</worksheet>';
  }

  /// One data cell; numbers stay numbers with a display format.
  static String _cell(int column, int row, Object? value, CellKind kind) {
    final ref = '${_columnName(column)}$row';
    if (value == null) {
      // "—" says "not held / not needed" more clearly than an empty cell.
      return kind == CellKind.level || kind == CellKind.gap ? _text(column, row, '—', 0) : '';
    }
    switch (kind) {
      case CellKind.number:
        return value is num ? _number(ref, value, _sInteger) : _text(column, row, '$value', 0);
      case CellKind.decimal:
        return value is num ? _number(ref, value, _sDecimal) : _text(column, row, '$value', 0);
      case CellKind.percent:
        return value is num ? _number(ref, value.round(), _sPercent) : _text(column, row, '$value', 0);
      case CellKind.level:
        return value is num ? _number(ref, value, _sLevel) : _text(column, row, '$value', 0);
      case CellKind.gap:
        return value is num ? _number(ref, value, _sGap) : _text(column, row, '$value', 0);
      case CellKind.date:
        if (value is DateTime) {
          final serial = DateTime.utc(value.year, value.month, value.day).difference(DateTime.utc(1899, 12, 30)).inDays;
          return _number(ref, serial, _sDate);
        }
        return _text(column, row, '$value', 0);
      case CellKind.text:
        return _text(column, row, value is double ? value.toStringAsFixed(1) : '$value', 0);
    }
  }

  static String _number(String ref, num value, int style) {
    if (value is double && (value.isNaN || value.isInfinite)) return '';
    final text = value is int ? '$value' : _plainDouble(value.toDouble());
    return '<c r="$ref" s="$style"><v>$text</v></c>';
  }

  static String _plainDouble(double v) {
    final fixed = v.toStringAsFixed(6);
    return fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
  }

  static String _text(int column, int row, String text, int style) {
    final ref = '${_columnName(column)}$row';
    final s = style == 0 ? '' : ' s="$style"';
    return '<c r="$ref" t="inlineStr"$s><is><t xml:space="preserve">${_xml(text)}</t></is></c>';
  }

  /// Excel column letters: 1 → A, 27 → AA.
  static String _columnName(int column) {
    var n = column;
    var name = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      name = String.fromCharCode(65 + rem) + name;
      n = (n - 1) ~/ 26;
    }
    return name;
  }

  static double _width(ReportColumn column, List<ReportRow> rows, int index) {
    var longest = column.label.length;
    final sample = rows.length > 300 ? rows.take(300) : rows;
    for (final row in sample) {
      final value = index < row.cells.length ? row.cells[index] : null;
      final length = reportCellText(value, column.kind).length;
      if (length > longest) longest = length;
    }
    final width = longest * 1.1 + 3;
    return width < 9 ? 9 : (width > 60 ? 60 : width);
  }

  static String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Escapes XML and drops characters XML can't hold.
  static String _xml(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (rune == 0x26) {
        out.write('&amp;');
      } else if (rune == 0x3C) {
        out.write('&lt;');
      } else if (rune == 0x3E) {
        out.write('&gt;');
      } else if (rune == 0x22) {
        out.write('&quot;');
      } else if (rune == 0x09 || rune == 0x0A || rune == 0x0D || (rune >= 0x20 && rune != 0xFFFE && rune != 0xFFFF)) {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// Sheet names: up to 31 characters, none of []:*?/\, unique.
  static String _uniqueSheetName(String wanted, List<String> taken) {
    var base = wanted.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (base.startsWith("'")) base = base.substring(1);
    if (base.endsWith("'")) base = base.substring(0, base.length - 1);
    if (base.isEmpty) base = 'Report';
    if (base.length > 31) base = base.substring(0, 31).trim();
    var name = base;
    var n = 2;
    bool used(String candidate) => taken.any((t) => t.toLowerCase() == candidate.toLowerCase());
    while (used(name)) {
      final suffix = ' ($n)';
      final room = 31 - suffix.length;
      name = '${base.length > room ? base.substring(0, room).trim() : base}$suffix';
      n++;
    }
    return name;
  }

  static String _contentTypes(int sheetCount) {
    final sheets = StringBuffer();
    for (var i = 1; i <= sheetCount; i++) {
      sheets.write('<Override PartName="/xl/worksheets/sheet$i.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '$sheets'
        '<Override PartName="/xl/styles.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>';
  }

  static const String _rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="xl/workbook.xml"/>'
      '</Relationships>';

  static String _workbook(List<String> sheetNames, List<ReportResult> results) {
    final sheets = StringBuffer();
    for (var i = 0; i < sheetNames.length; i++) {
      sheets.write('<sheet name="${_xml(sheetNames[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
    }
    // Excel keeps the filter range of each sheet as a hidden name.
    final names = StringBuffer();
    for (var i = 0; i < results.length; i++) {
      final res = results[i];
      final lastRow = res.rows.isEmpty ? _headerRow : _headerRow + res.rows.length;
      final quoted = sheetNames[i + 1].replaceAll("'", "''");
      final last = _columnName(res.columns.length);
      names.write('<definedName name="_xlnm._FilterDatabase" localSheetId="${i + 1}" hidden="1">'
          '${_xml("'$quoted'")}!\$A\$$_headerRow:\$$last\$$lastRow</definedName>');
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<bookViews><workbookView activeTab="${results.isEmpty ? 0 : 1}"/></bookViews>'
        '<sheets>$sheets</sheets>'
        '${names.isEmpty ? '' : '<definedNames>$names</definedNames>'}'
        '</workbook>';
  }

  static String _workbookRels(int sheetCount) {
    final rels = StringBuffer();
    for (var i = 1; i <= sheetCount; i++) {
      rels.write('<Relationship Id="rId$i" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
          'Target="worksheets/sheet$i.xml"/>');
    }
    rels.write('<Relationship Id="rId${sheetCount + 1}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
        'Target="styles.xml"/>');
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">$rels</Relationships>';
  }

  // numFmts: 164 one decimal, 165 "45%" for a whole number, 166 "L3",
  // 167 gap (−2 / Met), 168 date.
  static const String _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="5">'
      '<numFmt numFmtId="164" formatCode="0.0"/>'
      '<numFmt numFmtId="165" formatCode="0&quot;%&quot;"/>'
      '<numFmt numFmtId="166" formatCode="&quot;L&quot;0"/>'
      '<numFmt numFmtId="167" formatCode="0;\\−0;&quot;Met&quot;"/>'
      '<numFmt numFmtId="168" formatCode="dd mmm yyyy"/>'
      '</numFmts>'
      '<fonts count="4">'
      '<font><sz val="11"/><color rgb="FF0F1B2D"/><name val="Calibri"/><family val="2"/></font>'
      '<font><b/><sz val="11"/><color rgb="FF0F1B2D"/><name val="Calibri"/><family val="2"/></font>'
      '<font><b/><sz val="15"/><color rgb="FF0F1B2D"/><name val="Calibri"/><family val="2"/></font>'
      '<font><i/><sz val="10"/><color rgb="FF55667C"/><name val="Calibri"/><family val="2"/></font>'
      '</fonts>'
      '<fills count="3">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFE8F1FD"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="2">'
      '<border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left/><right/><top/><bottom style="thin"><color rgb="FF0F1B2D"/></bottom><diagonal/></border>'
      '</borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="12">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
      '<alignment vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="1" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="166" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="167" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="168" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1">'
      '<alignment vertical="top" wrapText="1"/></xf>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';
}
