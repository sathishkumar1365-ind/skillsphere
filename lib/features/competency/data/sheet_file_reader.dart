// Reads the rows of an Excel (.xlsx) or CSV file as plain text, for the
// competency bulk import. Works on the web and on every other platform.
//
// .xlsx is a zip of XML files; it is unzipped with `package:archive` and the
// few XML parts needed (workbook, shared strings, one worksheet) are read
// directly. Only cell text is read: formulas give their last saved value and
// formatting is ignored.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The file can't be read. [message] is safe to show to the user.
class SheetFileException implements Exception {
  const SheetFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One spreadsheet row. [number] is the row number the user sees in Excel
/// (or the record number in a CSV file), starting at 1.
class SheetRow {
  const SheetRow(this.number, this.cells);

  final int number;
  final List<String> cells;

  String cell(int index) => index >= 0 && index < cells.length ? cells[index] : '';

  bool get isEmpty => cells.every((c) => c.trim().isEmpty);
}

class SheetData {
  const SheetData({required this.sheetName, required this.rows});

  /// Worksheet name for .xlsx, "CSV" for CSV files.
  final String sheetName;
  final List<SheetRow> rows;
}

class SheetFileReader {
  SheetFileReader._();

  /// Stops runaway files; the importer allows far fewer competencies.
  static const int maxRows = 5000;

  /// Reads [bytes] as .xlsx or .csv, chosen by [fileName]'s extension (or by
  /// the content when the extension is unknown). For .xlsx, the worksheet
  /// named [preferredSheet] is used when it exists, otherwise the first one.
  static SheetData read(
    Uint8List bytes, {
    required String fileName,
    String preferredSheet = '',
  }) {
    if (bytes.isEmpty) throw const SheetFileException('The file is empty.');
    final lower = fileName.toLowerCase();
    final looksZipped = bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B; // "PK"

    if (lower.endsWith('.xls') || lower.endsWith('.xlsb')) {
      throw const SheetFileException(
          'This Excel format can\'t be read. In Excel choose File › Save As › '
          'Excel Workbook (.xlsx), or CSV UTF-8, and upload that file.');
    }
    if (lower.endsWith('.xlsx') || lower.endsWith('.xlsm') || (!lower.endsWith('.csv') && looksZipped)) {
      return _XlsxReader.read(bytes, preferredSheet: preferredSheet);
    }
    return SheetData(sheetName: 'CSV', rows: CsvParser.parse(decodeText(bytes)));
  }

  /// Text of a CSV file. Handles UTF-8 (with or without BOM), UTF-16 and the
  /// Windows-1252 encoding Excel uses for "CSV (Comma delimited)".
  static String decodeText(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _utf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _utf16(bytes.sublist(2), littleEndian: false);
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return _windows1252(bytes);
    }
  }

  static String _utf16(Uint8List bytes, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(littleEndian ? bytes[i] | (bytes[i + 1] << 8) : (bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  // Characters 0x80–0x9F in Windows-1252 (curly quotes, dashes, €…).
  static const _cp1252 = <int, int>{
    0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026,
    0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160,
    0x8B: 0x2039, 0x8C: 0x0152, 0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019,
    0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
    0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153,
    0x9E: 0x017E, 0x9F: 0x0178,
  };

  static String _windows1252(Uint8List bytes) =>
      String.fromCharCodes([for (final b in bytes) _cp1252[b] ?? b]);
}

/// RFC 4180 CSV: quoted fields, doubled quotes, line breaks inside quotes.
/// The separator (comma, semicolon or tab) is detected from the first line,
/// because Excel in many European locales saves CSV with semicolons.
class CsvParser {
  CsvParser._();

  static List<SheetRow> parse(String text) {
    final separator = _detectSeparator(text);
    final rows = <SheetRow>[];
    var cells = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var record = 1;

    void endField() {
      cells.add(field.toString());
      field.clear();
    }

    void endRecord() {
      endField();
      rows.add(SheetRow(record++, cells));
      cells = <String>[];
      if (rows.length > SheetFileReader.maxRows) {
        throw const SheetFileException('The file has too many rows.');
      }
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"' && field.isEmpty) {
        inQuotes = true;
      } else if (ch == separator) {
        endField();
      } else if (ch == '\r' || ch == '\n') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endRecord();
      } else {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || cells.isNotEmpty) endRecord();
    return rows;
  }

  static String _detectSeparator(String text) {
    var commas = 0, semicolons = 0, tabs = 0;
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '"') inQuotes = !inQuotes;
      if (inQuotes) continue;
      if (ch == '\n' || ch == '\r') break;
      if (ch == ',') commas++;
      if (ch == ';') semicolons++;
      if (ch == '\t') tabs++;
    }
    if (tabs > commas && tabs > semicolons) return '\t';
    if (semicolons > commas) return ';';
    return ',';
  }
}

class _XlsxReader {
  _XlsxReader._();

  static final _sheetTag = RegExp(r'<(?:\w+:)?sheet\b([^>]*)>');
  static final _relationshipTag = RegExp(r'<(?:\w+:)?Relationship\b([^>]*)>');
  static final _sharedItem = RegExp(r'<(?:\w+:)?si\b[^>]*>(.*?)</(?:\w+:)?si>', dotAll: true);
  static final _phonetic = RegExp(r'<(?:\w+:)?rPh\b.*?</(?:\w+:)?rPh>', dotAll: true);
  static final _textRun = RegExp(r'<(?:\w+:)?t\b[^>]*?(?:/>|>(.*?)</(?:\w+:)?t>)', dotAll: true);
  static final _row = RegExp(r'<(?:\w+:)?row\b([^>]*?)(?:/>|>(.*?)</(?:\w+:)?row>)', dotAll: true);
  static final _cell = RegExp(r'<(?:\w+:)?c\b([^>]*?)(?:/>|>(.*?)</(?:\w+:)?c>)', dotAll: true);
  static final _value = RegExp(r'<(?:\w+:)?v\b[^>]*>(.*?)</(?:\w+:)?v>', dotAll: true);
  static final _inline = RegExp(r'<(?:\w+:)?is\b[^>]*>(.*?)</(?:\w+:)?is>', dotAll: true);

  static SheetData read(Uint8List bytes, {required String preferredSheet}) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const SheetFileException(
          'This file isn\'t a valid Excel workbook. Save it again as .xlsx or CSV.');
    }

    String? part(String path) {
      final file = _find(archive, path);
      return file == null ? null : utf8.decode(file.content, allowMalformed: true);
    }

    final workbook = part('xl/workbook.xml');
    if (workbook == null) {
      throw const SheetFileException('This file isn\'t an Excel workbook (.xlsx).');
    }

    // Relationship id → worksheet file.
    final targets = <String, String>{};
    for (final m in _relationshipTag.allMatches(part('xl/_rels/workbook.xml.rels') ?? '')) {
      final attrs = m.group(1) ?? '';
      final id = _attr(attrs, 'Id');
      final target = _attr(attrs, 'Target');
      if (id != null && target != null) targets[id] = target;
    }

    final sheets = <(String, String)>[];
    for (final m in _sheetTag.allMatches(workbook)) {
      final attrs = m.group(1) ?? '';
      final name = _unescape(_attr(attrs, 'name') ?? '');
      final relId = RegExp(r'(?:^|\s)\w+:id\s*=\s*"([^"]*)"').firstMatch(attrs)?.group(1);
      final target = relId == null ? null : targets[relId];
      if (target != null) sheets.add((name, _resolve(target)));
    }
    if (sheets.isEmpty) {
      throw const SheetFileException('No worksheet was found in this workbook.');
    }
    final wanted = preferredSheet.trim().toLowerCase();
    final chosen = sheets.firstWhere(
      (s) => wanted.isNotEmpty && s.$1.trim().toLowerCase() == wanted,
      orElse: () => sheets.first,
    );

    final shared = <String>[
      for (final m in _sharedItem.allMatches(part('xl/sharedStrings.xml') ?? ''))
        _runs(m.group(1) ?? ''),
    ];

    final sheetXml = part(chosen.$2);
    if (sheetXml == null) {
      throw SheetFileException('The worksheet "${chosen.$1}" could not be opened.');
    }

    final rows = <SheetRow>[];
    var nextRowNumber = 1;
    for (final rowMatch in _row.allMatches(sheetXml)) {
      final rowNumber = int.tryParse(_attr(rowMatch.group(1) ?? '', 'r') ?? '') ?? nextRowNumber;
      nextRowNumber = rowNumber + 1;
      final body = rowMatch.group(2);
      if (body == null) continue; // empty row

      final cells = <String>[];
      var nextColumn = 0;
      for (final cellMatch in _cell.allMatches(body)) {
        final attrs = cellMatch.group(1) ?? '';
        final ref = _attr(attrs, 'r');
        final column = ref == null ? nextColumn : _columnIndex(ref);
        nextColumn = column + 1;
        final text = _cellText(_attr(attrs, 't'), cellMatch.group(2) ?? '', shared);
        while (cells.length < column) {
          cells.add('');
        }
        if (cells.length == column) {
          cells.add(text);
        } else {
          cells[column] = text;
        }
      }
      rows.add(SheetRow(rowNumber, cells));
      if (rows.length > SheetFileReader.maxRows) {
        throw const SheetFileException('The worksheet has too many rows.');
      }
    }
    return SheetData(sheetName: chosen.$1, rows: rows);
  }

  static String _cellText(String? type, String body, List<String> shared) {
    switch (type) {
      case 's':
        final index = int.tryParse(_value.firstMatch(body)?.group(1)?.trim() ?? '');
        return index != null && index >= 0 && index < shared.length ? shared[index] : '';
      case 'inlineStr':
        return _runs(_inline.firstMatch(body)?.group(1) ?? '');
      case 'b':
        return _value.firstMatch(body)?.group(1)?.trim() == '1' ? 'TRUE' : 'FALSE';
      default:
        return _unescape(_value.firstMatch(body)?.group(1) ?? '');
    }
  }

  /// Joins the text runs of a string item, leaving out phonetic hints.
  static String _runs(String xml) {
    final clean = xml.replaceAll(_phonetic, '');
    final buffer = StringBuffer();
    for (final m in _textRun.allMatches(clean)) {
      buffer.write(_unescape(m.group(1) ?? ''));
    }
    return buffer.toString();
  }

  static ArchiveFile? _find(Archive archive, String path) {
    final exact = archive.findFile(path);
    if (exact != null) return exact;
    final lower = path.toLowerCase();
    for (final f in archive.files) {
      if (f.isFile && f.name.toLowerCase() == lower) return f;
    }
    return null;
  }

  /// "worksheets/sheet1.xml" or "/xl/worksheets/sheet1.xml" → path in zip.
  static String _resolve(String target) {
    if (target.startsWith('/')) return target.substring(1);
    var path = 'xl/$target';
    // Resolve "../" segments.
    final parts = <String>[];
    for (final segment in path.split('/')) {
      if (segment == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (segment.isNotEmpty && segment != '.') {
        parts.add(segment);
      }
    }
    path = parts.join('/');
    return path;
  }

  static final _attrPatterns = <String, RegExp>{};

  static String? _attr(String attrs, String name) {
    final pattern = _attrPatterns.putIfAbsent(
        name, () => RegExp('(?:^|\\s)$name\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')'));
    final m = pattern.firstMatch(attrs);
    return m == null ? null : (m.group(1) ?? m.group(2));
  }

  /// "AB12" → 27 (zero-based column).
  static int _columnIndex(String ref) {
    var index = 0;
    for (final code in ref.toUpperCase().codeUnits) {
      if (code < 65 || code > 90) break;
      index = index * 26 + (code - 64);
    }
    return index == 0 ? 0 : index - 1;
  }

  static final _numericEntity = RegExp(r'&#(x?)([0-9A-Fa-f]+);');
  static final _escapedChar = RegExp(r'_x([0-9A-Fa-f]{4})_');

  static String _unescape(String text) {
    if (!text.contains('&') && !text.contains('_x')) return text;
    var out = text.replaceAllMapped(_numericEntity, (m) {
      final code = int.tryParse(m.group(2)!, radix: m.group(1)!.isEmpty ? 10 : 16);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
    out = out
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
    // Excel writes some characters as _xHHHH_ (e.g. _x000D_ for a carriage return).
    return out.replaceAllMapped(
        _escapedChar, (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
  }
}
