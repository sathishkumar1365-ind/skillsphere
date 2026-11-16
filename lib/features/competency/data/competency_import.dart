// Bulk import of competency definitions from an Excel (.xlsx) or CSV file.
//
// One row per competency. Columns (found by their header text, in any
// order; extra columns are ignored):
//   Category | Name | Description | Logo URL (optional) |
//   Level 0 … Level 5 (header may continue, e.g. "Level 0 – Beginner")
//
// Every row is checked with the same rules as the Add form. Nothing is saved
// here: the import panel shows the result and HRD confirms.

import 'dart:typed_data';

import 'competency_models.dart';
import 'sheet_file_reader.dart';

enum ImportRowStatus {
  /// Valid and new: will be added.
  ready,

  /// Already in the library, or repeats an earlier row: skipped.
  duplicate,

  /// Breaks a rule (missing level, unknown category…): skipped.
  problem,
}

class CompetencyImportRow {
  CompetencyImportRow({
    required this.rowNumber,
    required this.categoryText,
    required this.category,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.levels,
    required this.problems,
    this.existing,
    this.sameAsRow,
  });

  /// Row number as shown in Excel.
  final int rowNumber;
  final String categoryText;
  final CompetencyCategory? category;
  final String name;
  final String description;
  final String logoUrl;
  final List<String> levels;
  final List<String> problems;

  /// The library competency with the same name, if any.
  final Competency? existing;

  /// Earlier row in the same file with the same name, if any.
  final int? sameAsRow;

  ImportRowStatus get status {
    if (problems.isNotEmpty) return ImportRowStatus.problem;
    if (existing != null || sameAsRow != null) return ImportRowStatus.duplicate;
    return ImportRowStatus.ready;
  }

  CompetencyDraft? get draft {
    final c = category;
    if (status != ImportRowStatus.ready || c == null) return null;
    return CompetencyDraft(
      category: c,
      name: name,
      description: description,
      levelDescriptions: levels,
      logoUrl: logoUrl.isEmpty ? null : logoUrl,
    );
  }
}

class CompetencyImportResult {
  const CompetencyImportResult({
    required this.fileName,
    required this.sheetName,
    required this.rows,
    this.fileProblem,
  });

  final String fileName;
  final String sheetName;
  final List<CompetencyImportRow> rows;

  /// Set when the file as a whole can't be used (missing columns, too many
  /// rows…). [rows] is empty then.
  final String? fileProblem;

  List<CompetencyImportRow> rowsWith(ImportRowStatus status) =>
      rows.where((r) => r.status == status).toList();

  int count(ImportRowStatus status) => rows.where((r) => r.status == status).length;

  List<CompetencyDraft> get drafts => [
        for (final r in rows) ?r.draft,
      ];
}

class CompetencyImporter {
  CompetencyImporter._();

  /// Most competencies accepted in one file.
  static const int maxCompetencies = 500;

  /// Worksheet read from the template (otherwise the first worksheet).
  static const String sheetName = 'Competencies';

  /// The Excel template bundled with the app (see pubspec.yaml assets).
  static const String templateAsset = 'assets/templates/competency_import_template.xlsx';
  static const String templateFileName = 'SkillSphere_competency_import_template.xlsx';

  /// Reads [bytes] and checks every row. Throws [SheetFileException] when
  /// the file can't be read at all.
  ///
  /// [findExisting] returns the library competency with a given name, if
  /// any (CompetencyRepository.findByName).
  static CompetencyImportResult parse(
    Uint8List bytes, {
    required String fileName,
    required Competency? Function(String name) findExisting,
  }) {
    final sheet = SheetFileReader.read(bytes, fileName: fileName, preferredSheet: sheetName);

    CompetencyImportResult fail(String problem) => CompetencyImportResult(
          fileName: fileName,
          sheetName: sheet.sheetName,
          rows: const [],
          fileProblem: problem,
        );

    // The header is the first row (of the first 10) naming both a Category
    // and a Name column, so a title row above it is fine.
    final headerIndex = sheet.rows.take(10).toList().indexWhere((row) {
      final columns = _Columns.from(row);
      return columns.category >= 0 && columns.name >= 0;
    });
    if (headerIndex < 0) {
      return fail('No header row found. The first row must name the columns: '
          'Category, Name, Description, Logo URL, Level 0 … Level 5. '
          'Download the template to see the layout.');
    }
    final columns = _Columns.from(sheet.rows[headerIndex]);
    final missing = columns.missing;
    if (missing.isNotEmpty) {
      return fail('Missing ${missing.length == 1 ? 'column' : 'columns'}: '
          '${missing.join(', ')}. Use the header row from the template.');
    }

    final dataRows = sheet.rows.skip(headerIndex + 1).where((r) => !r.isEmpty).toList();
    if (dataRows.isEmpty) {
      return fail('The file has a header row but no competencies under it.');
    }
    if (dataRows.length > maxCompetencies) {
      return fail('The file has ${dataRows.length} competencies. '
          'Import up to $maxCompetencies at a time.');
    }

    final firstRowByName = <String, int>{};
    final rows = <CompetencyImportRow>[];
    for (final row in dataRows) {
      final categoryText = row.cell(columns.category).trim();
      final category = CompetencyCategory.tryParse(categoryText);
      final name = row.cell(columns.name).trim().replaceAll(RegExp(r'\s+'), ' ');
      final description = row.cell(columns.description).trim();
      final logo = columns.logo < 0 ? '' : row.cell(columns.logo).trim();
      final levels = [for (final index in columns.levels) row.cell(index).trim()];

      final problems = <String>[];
      if (categoryText.isEmpty) {
        problems.add('Category is empty.');
      } else if (category == null) {
        problems.add('Category "$categoryText" must be Skill, Tool, Language or Domain.');
      }
      if (name.isEmpty) {
        problems.add('Name is empty.');
      } else if (name.length > CompetencyRules.nameMax) {
        problems.add('Name is longer than ${CompetencyRules.nameMax} characters.');
      }
      if (description.isEmpty) {
        problems.add('Description is empty.');
      } else if (description.length < CompetencyRules.descriptionMin) {
        problems.add('Description is shorter than ${CompetencyRules.descriptionMin} characters.');
      } else if (description.length > CompetencyRules.descriptionMax) {
        problems.add('Description is longer than ${CompetencyRules.descriptionMax} characters.');
      }
      if (logo.isNotEmpty && !CompetencyRules.isValidLink(logo)) {
        problems.add('Logo URL must be a full link starting with https://');
      }
      final emptyLevels = [
        for (var i = 0; i < levels.length; i++)
          if (levels[i].isEmpty) 'Level $i',
      ];
      if (emptyLevels.isNotEmpty) {
        problems.add('${emptyLevels.join(', ')} ${emptyLevels.length == 1 ? 'is' : 'are'} empty.');
      }
      final longLevels = [
        for (var i = 0; i < levels.length; i++)
          if (levels[i].length > CompetencyRules.levelMax) 'Level $i',
      ];
      if (longLevels.isNotEmpty) {
        problems.add('${longLevels.join(', ')} ${longLevels.length == 1 ? 'is' : 'are'} '
            'longer than ${CompetencyRules.levelMax} characters.');
      }

      Competency? existing;
      int? sameAsRow;
      if (name.isNotEmpty) {
        final key = Competency.keyFor(name);
        existing = findExisting(name);
        sameAsRow = firstRowByName[key];
        firstRowByName.putIfAbsent(key, () => row.number);
      }

      rows.add(CompetencyImportRow(
        rowNumber: row.number,
        categoryText: categoryText,
        category: category,
        name: name,
        description: description,
        logoUrl: logo,
        levels: levels,
        problems: problems,
        existing: existing,
        sameAsRow: sameAsRow,
      ));
    }

    return CompetencyImportResult(fileName: fileName, sheetName: sheet.sheetName, rows: rows);
  }
}

/// Where each field is in the file, found from the header text.
class _Columns {
  _Columns({
    required this.category,
    required this.name,
    required this.description,
    required this.logo,
    required this.levels,
  });

  final int category;
  final int name;
  final int description;
  final int logo;

  /// Column of Level 0 … Level 5 (-1 when missing).
  final List<int> levels;

  /// "Level 0 – Beginner" → "level0beginner".
  static String _normal(String header) =>
      header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  factory _Columns.from(SheetRow header) {
    var category = -1, name = -1, description = -1, logo = -1;
    final levels = List<int>.filled(CompetencyLevel.count, -1);
    for (var i = 0; i < header.cells.length; i++) {
      final h = _normal(header.cells[i]);
      if (h.isEmpty) continue;
      final level = RegExp(r'^(?:level|lvl|l)([0-5])(?![0-9])').firstMatch(h);
      if (level != null) {
        final n = int.parse(level.group(1)!);
        if (levels[n] < 0) levels[n] = i;
      } else if (category < 0 && (h.startsWith('category') || h == 'type')) {
        category = i;
      } else if (name < 0 &&
          (h == 'name' || h == 'competency' || h == 'competencyname' || h.startsWith('name'))) {
        name = i;
      } else if (description < 0 && (h.startsWith('description') || h.startsWith('shortdescription'))) {
        description = i;
      } else if (logo < 0 && h.startsWith('logo')) {
        logo = i;
      }
    }
    return _Columns(
      category: category,
      name: name,
      description: description,
      logo: logo,
      levels: levels,
    );
  }

  List<String> get missing => [
        if (category < 0) 'Category',
        if (name < 0) 'Name',
        if (description < 0) 'Description',
        for (var i = 0; i < levels.length; i++)
          if (levels[i] < 0) 'Level $i',
      ];
}
