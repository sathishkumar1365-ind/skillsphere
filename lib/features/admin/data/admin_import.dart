// Bulk import (Excel .xlsx or CSV) for the HRD console: employees,
// projects, roles, and the organisation structure (divisions, groups &
// departments).
//
// Same approach as the competency import: the header row is found by its
// text (any order, extra columns ignored), every row is checked with the
// same rules as the forms, and nothing is saved until HRD presses Import.
// Only "ready" rows are imported; duplicates and rows with problems are
// listed with the Excel row number and the exact reason.

import 'dart:typed_data';

import '../../competency/data/competency_models.dart';
import '../../competency/data/competency_repository.dart';
import '../../competency/data/sheet_file_reader.dart';
import 'admin_base.dart';
import 'employees.dart';
import 'job_roles.dart';
import 'locations.dart';
import 'org_structure.dart';
import 'projects.dart';

enum ImportStatus { ready, duplicate, problem }

/// A column the importer looks for. [aliases] are other header texts that
/// mean the same thing ("Emp ID" for "Employee ID").
class ImportField {
  const ImportField(this.key, this.label, {this.aliases = const [], this.required = false});

  final String key;
  final String label;
  final List<String> aliases;
  final bool required;

  /// "Employee ID *" → "employeeid", "Email (required)" → "email".
  static String normal(String header) {
    var h = header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final suffix in const ['required', 'mandatory', 'optional']) {
      if (h.length > suffix.length && h.endsWith(suffix)) h = h.substring(0, h.length - suffix.length);
    }
    return h;
  }

  bool matches(String header) {
    final h = normal(header);
    if (h.isEmpty) return false;
    return h == normal(label) || aliases.any((a) => normal(a) == h);
  }
}

/// One checked file row.
class ImportRow<T> {
  const ImportRow({
    required this.rowNumber,
    required this.title,
    this.subtitle = '',
    this.problems = const [],
    this.duplicateNote,
    this.value,
  });

  /// Row number as shown in Excel.
  final int rowNumber;
  final String title;
  final String subtitle;
  final List<String> problems;

  /// Why the row is skipped as a duplicate ("Already onboarded as …").
  final String? duplicateNote;

  /// What would be imported (null when the row has problems).
  final T? value;

  ImportStatus get status {
    if (problems.isNotEmpty) return ImportStatus.problem;
    if (duplicateNote != null) return ImportStatus.duplicate;
    return ImportStatus.ready;
  }
}

class ImportPreview<T> {
  const ImportPreview({
    required this.fileName,
    required this.sheetName,
    required this.rows,
    this.fileProblem,
  });

  final String fileName;
  final String sheetName;
  final List<ImportRow<T>> rows;

  /// Set when the file as a whole can't be used; [rows] is empty then.
  final String? fileProblem;

  int count(ImportStatus status) => rows.where((r) => r.status == status).length;

  List<T> get readyValues => [
        for (final r in rows)
          if (r.status == ImportStatus.ready) ?r.value,
      ];
}

/// The header and data rows of a sheet, with columns found by name.
class _Table {
  _Table(this.sheet, this.columns, this.rows);

  final SheetData sheet;
  final Map<String, int> columns;
  final List<SheetRow> rows;

  String cell(SheetRow row, String key) {
    final index = columns[key];
    return index == null ? '' : row.cell(index).trim();
  }

  bool has(String key) => columns.containsKey(key);
}

class _TableResult {
  const _TableResult(this.table, this.sheetName, this.problem);

  final _Table? table;
  final String sheetName;
  final String? problem;
}

_TableResult _readTable(
  Uint8List bytes, {
  required String fileName,
  required String sheetName,
  required List<ImportField> fields,
  required int maxRows,
  required String itemPlural,
}) {
  final sheet = SheetFileReader.read(bytes, fileName: fileName, preferredSheet: sheetName);
  Map<String, int> columnsOf(SheetRow row) {
    final found = <String, int>{};
    for (var i = 0; i < row.cells.length; i++) {
      for (final f in fields) {
        if (!found.containsKey(f.key) && f.matches(row.cells[i])) {
          found[f.key] = i;
          break;
        }
      }
    }
    return found;
  }

  final required = fields.where((f) => f.required).toList();
  final firstRows = sheet.rows.take(10).toList();
  final headerIndex = firstRows.indexWhere((row) {
    final found = columnsOf(row);
    // At least two required columns: a title row above the header is fine.
    return required.where((f) => found.containsKey(f.key)).length >= (required.length < 2 ? 1 : 2);
  });
  if (headerIndex < 0) {
    return _TableResult(null, sheet.sheetName,
        'No header row found. The first row must name the columns '
        '(${required.map((f) => f.label).join(', ')} …). Download the template to see the layout.');
  }
  final columns = columnsOf(sheet.rows[headerIndex]);
  final missing = required.where((f) => !columns.containsKey(f.key)).map((f) => f.label).toList();
  if (missing.isNotEmpty) {
    return _TableResult(null, sheet.sheetName,
        'Missing ${missing.length == 1 ? 'column' : 'columns'}: ${missing.join(', ')}. '
        'Use the header row from the template.');
  }
  final data = sheet.rows.skip(headerIndex + 1).where((r) => !r.isEmpty).toList();
  if (data.isEmpty) {
    return _TableResult(null, sheet.sheetName, 'The file has a header row but no $itemPlural under it.');
  }
  if (data.length > maxRows) {
    return _TableResult(null, sheet.sheetName,
        'The file has ${data.length} $itemPlural. Import up to $maxRows at a time.');
  }
  return _TableResult(_Table(sheet, columns, data), sheet.sheetName, null);
}

/// Splits "Java:3; Python:2", "Java:3, Python:2" or one item per line.
List<String> _splitList(String text) => text
    .split(RegExp(r'[;,\n|]+'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// "Java:3", "Java = L3", "Java (3)", "Java - 3" → (Java, 3). Null if no level.
({String name, int? level, String rest})? _nameLevel(String item) {
  final rolePart = item.split('@');
  final main = rolePart.first.trim();
  final rest = rolePart.length > 1 ? rolePart.sublist(1).join('@').trim() : '';
  final m = RegExp(r'^(.+?)\s*(?:[:=]|\s-\s|\()\s*[Ll]?(\d)\s*\)?$').firstMatch(main);
  if (m == null) return (name: main, level: null, rest: rest);
  return (name: m.group(1)!.trim(), level: int.parse(m.group(2)!), rest: rest);
}

// ============================================================= employees

class EmployeeImporter {
  EmployeeImporter._();

  static const int maxRows = 1000;
  static const String sheetName = 'Employees';
  static const String templateAsset = 'assets/templates/employee_import_template.xlsx';
  static const String templateFileName = 'SkillSphere_employee_import_template.xlsx';

  static const fields = [
    ImportField('id', 'Employee ID', aliases: ['Emp ID', 'Employee No', 'Employee Number', 'ID'], required: true),
    ImportField('name', 'Full Name', aliases: ['Name', 'Employee Name'], required: true),
    ImportField('email', 'Work Email', aliases: ['Email', 'Email ID', 'Mail'], required: true),
    ImportField('gender', 'Gender', required: true),
    ImportField('status', 'Status', aliases: ['Employment Status']),
    // Optional: the department already decides the group and division; when
    // given, it must match.
    ImportField('division', 'Division', aliases: ['Division Name']),
    ImportField('group', 'Group', aliases: ['Business Group', 'Group Name'], required: true),
    ImportField('department', 'Department', aliases: ['Dept', 'Department Name'], required: true),
    ImportField('manager', 'Reporting Manager', aliases: ['Manager', 'Reporting Manager ID', 'Reports To']),
    ImportField('designation', 'Designation', aliases: ['Job Title', 'Title'], required: true),
    ImportField('role', 'Role', aliases: ['Project Role'], required: true),
    ImportField('country', 'Country', required: true),
    ImportField('state', 'State', aliases: ['State / Province', 'Province', 'Region']),
    ImportField('city', 'City', aliases: ['Location', 'Office']),
    ImportField('acquired', 'Acquired Skills', aliases: ['Acquired Competencies', 'Skills', 'Competencies']),
    ImportField('additional', 'Additional Skills', aliases: ['Additional Competencies']),
    ImportField('intro', 'Short Intro', aliases: ['Intro', 'About', 'Introduction']),
  ];

  static ImportPreview<EmployeeDraft> parse(Uint8List bytes, {required String fileName}) {
    final read = _readTable(bytes,
        fileName: fileName, sheetName: sheetName, fields: fields, maxRows: maxRows, itemPlural: 'employees');
    final table = read.table;
    if (table == null) {
      return ImportPreview(fileName: fileName, sheetName: read.sheetName, rows: const [], fileProblem: read.problem);
    }
    final employees = EmployeeRepository.instance;
    final structure = OrgStructureRepository.instance;
    final roles = RoleRepository.instance;
    final competencies = CompetencyRepository.instance;

    // IDs in this file, so a manager can be another new row.
    final fileIds = <String, int>{};
    for (final row in table.rows) {
      final id = table.cell(row, 'id').toLowerCase();
      if (id.isNotEmpty) fileIds.putIfAbsent(id, () => row.number);
    }
    final firstById = <String, int>{};
    final firstByEmail = <String, int>{};
    final rows = <ImportRow<EmployeeDraft>>[];

    for (final row in table.rows) {
      String c(String key) => table.cell(row, key);
      final problems = <String>[];
      String? duplicate;

      final id = c('id');
      final name = cleanText(c('name'));
      final email = c('email');

      if (id.isEmpty) {
        problems.add('Employee ID is empty.');
      } else if (!EmployeeRules.isValidId(id)) {
        problems.add('Employee ID "$id" can only have letters, digits, - _ or / (2–20).');
      } else {
        final existing = employees.byId(id);
        final earlier = firstById[id.toLowerCase()];
        if (existing != null) {
          duplicate = 'Already onboarded: ${existing.id} ${existing.name}.';
        } else if (earlier != null) {
          duplicate = 'Same Employee ID as row $earlier.';
        }
        firstById.putIfAbsent(id.toLowerCase(), () => row.number);
      }

      if (name.isEmpty) {
        problems.add('Full Name is empty.');
      } else if (name.length > EmployeeRules.nameMax) {
        problems.add('Full Name is longer than ${EmployeeRules.nameMax} characters.');
      }

      if (email.isEmpty) {
        problems.add('Work Email is empty.');
      } else if (!isValidEmail(email)) {
        problems.add('Work Email "$email" is not a valid email.');
      } else if (duplicate == null) {
        final owner = employees.byEmail(email);
        final earlier = firstByEmail[email.toLowerCase()];
        if (owner != null) {
          problems.add('Work Email is already used by ${owner.name} (${owner.id}).');
        } else if (earlier != null) {
          problems.add('Same Work Email as row $earlier.');
        }
        firstByEmail.putIfAbsent(email.toLowerCase(), () => row.number);
      }

      final genderText = c('gender');
      final gender = Gender.tryParse(genderText);
      if (genderText.isEmpty) {
        problems.add('Gender is empty.');
      } else if (gender == null) {
        problems.add('Gender "$genderText" must be Male, Female, Other or Prefer not to say.');
      }

      final statusText = c('status');
      final status = statusText.isEmpty ? EmploymentStatus.active : EmploymentStatus.tryParse(statusText);
      if (status == null) problems.add('Status "$statusText" must be Active or Inactive.');

      final groupText = c('group');
      final departmentText = c('department');
      final group = groupText.isEmpty ? null : structure.groupByName(groupText);
      final department = departmentText.isEmpty ? null : structure.departmentByName(departmentText);
      if (groupText.isEmpty) {
        problems.add('Group is empty.');
      } else if (group == null) {
        problems.add('Group "$groupText" doesn\'t exist. Add it under Org Structure first.');
      }
      if (departmentText.isEmpty) {
        problems.add('Department is empty.');
      } else if (department == null) {
        problems.add('Department "$departmentText" doesn\'t exist.');
      } else if (group != null && department.groupId != group.id) {
        problems.add('Department ${department.name} is in '
            '${structure.groupNameOfDepartment(department.id)}, not ${group.name}.');
      }
      final divisionText = c('division');
      if (divisionText.isNotEmpty) {
        final division = structure.divisionByName(divisionText);
        final actual = department == null ? null : structure.divisionOfDepartment(department.id);
        if (division == null) {
          problems.add('Division "$divisionText" doesn\'t exist.');
        } else if (actual != null && actual.id != division.id) {
          problems.add('Department ${department!.name} is in the ${actual.name} division, not ${division.name}.');
        }
      }

      final managerText = c('manager');
      String? managerId;
      if (managerText.isNotEmpty) {
        final manager = employees.find(managerText);
        if (manager != null) {
          managerId = manager.id;
        } else if (fileIds.containsKey(managerText.toLowerCase())) {
          managerId = managerText;
        } else {
          problems.add('Reporting Manager "$managerText" is not an employee ID, email or name.');
        }
        if (managerId != null && managerId.toLowerCase() == id.toLowerCase()) {
          problems.add('An employee can\'t report to themselves.');
        }
      }

      final designation = cleanText(c('designation'));
      if (designation.isEmpty) {
        problems.add('Designation is empty.');
      } else if (designation.length > EmployeeRules.designationMax) {
        problems.add('Designation is longer than ${EmployeeRules.designationMax} characters.');
      }

      final roleText = c('role');
      final role = roleText.isEmpty ? null : roles.byName(roleText);
      if (roleText.isEmpty) {
        problems.add('Role is empty.');
      } else if (role == null) {
        problems.add('Role "$roleText" doesn\'t exist. Add it under Roles first.');
      } else if (!role.active) {
        problems.add('Role ${role.name} is inactive.');
      }

      final countryText = c('country');
      final country = LocationCatalog.matchCountry(countryText);
      var state = '';
      var city = cleanText(c('city'));
      if (countryText.isEmpty) {
        problems.add('Country is empty.');
      } else if (country == null) {
        problems.add('Country "$countryText" is not in the list (see the Lists sheet).');
      } else {
        final stateText = c('state');
        if (stateText.isNotEmpty) {
          final matched = LocationCatalog.matchState(country, stateText);
          if (matched == null) {
            problems.add('State "$stateText" is not a listed state of $country.');
          } else {
            state = matched;
            city = LocationCatalog.matchCity(country, matched, city) ?? city;
          }
        }
      }

      final acquired = <AcquiredLevel>[];
      final seenCompetencies = <String>{};
      for (final item in _splitList(c('acquired'))) {
        final parsed = _nameLevel(item);
        final level = parsed?.level;
        final competency = parsed == null ? null : competencies.findByName(parsed.name);
        if (parsed == null || level == null) {
          problems.add('Acquired skill "$item" needs a level, e.g. "Java:3".');
        } else if (competency == null) {
          problems.add('"${parsed.name}" is not in the competency library.');
        } else if (level < CompetencyLevel.min || level > CompetencyLevel.max) {
          problems.add('Level of ${competency.name} must be 0–5.');
        } else if (!seenCompetencies.add(competency.id)) {
          problems.add('${competency.name} is listed twice.');
        } else {
          acquired.add(AcquiredLevel(competency.id, level));
        }
      }

      final additional = <String>[];
      for (final item in _splitList(c('additional'))) {
        final core = competencies.findByName(item);
        if (core != null) {
          problems.add('"${core.name}" is in the competency library: list it under Acquired Skills with a level.');
        } else if (item.length > 40) {
          problems.add('Additional skill "$item" is longer than 40 characters.');
        } else {
          additional.add(cleanText(item));
        }
      }

      final intro = c('intro');
      if (intro.length > EmployeeRules.introMax) {
        problems.add('Short Intro is longer than ${EmployeeRules.introMax} characters.');
      }

      rows.add(ImportRow<EmployeeDraft>(
        rowNumber: row.number,
        title: [if (id.isNotEmpty) id, if (name.isNotEmpty) name].join(' · ').ifEmpty('(no name)'),
        subtitle: [
          if (department != null) department.name,
          if (role != null) role.name,
          if (acquired.isNotEmpty) '${acquired.length} skill${acquired.length == 1 ? '' : 's'}',
        ].join(' · '),
        problems: problems,
        duplicateNote: duplicate,
        value: problems.isEmpty && gender != null && status != null && department != null
            ? EmployeeDraft(
                id: id,
                name: name,
                email: email,
                gender: gender,
                status: status,
                departmentId: department.id,
                designation: designation,
                roleId: role?.id,
                managerId: managerId,
                location: EmployeeLocation(country: country ?? '', state: state, city: city),
                intro: intro,
                acquired: acquired,
                additional: additional,
              )
            : null,
      ));
    }
    return ImportPreview(fileName: fileName, sheetName: table.sheet.sheetName, rows: rows);
  }
}

// ============================================================== projects

class ProjectImporter {
  ProjectImporter._();

  static const int maxRows = 500;
  static const String sheetName = 'Projects';
  static const String templateAsset = 'assets/templates/project_import_template.xlsx';
  static const String templateFileName = 'SkillSphere_project_import_template.xlsx';

  static const fields = [
    ImportField('code', 'Project Code', aliases: ['Code', 'Project ID'], required: true),
    ImportField('name', 'Project Name', aliases: ['Name', 'Project'], required: true),
    ImportField('customer', 'Customer', aliases: ['Client', 'Customer / Programme', 'Programme']),
    ImportField('department', 'Department', aliases: ['Dept', 'Owning Department'], required: true),
    ImportField('manager', 'Project Manager', aliases: ['Manager', 'PM']),
    ImportField('start', 'Start Date', aliases: ['Start'], required: true),
    ImportField('end', 'End Date', aliases: ['End']),
    ImportField('status', 'Status'),
    ImportField('team', 'Planned Team Size', aliases: ['Team Size', 'Headcount']),
    ImportField('description', 'Description'),
    ImportField('requirements', 'Required Competencies', aliases: ['Required Skills', 'Requirements']),
    ImportField('members', 'Team Members', aliases: ['Members', 'Employees']),
  ];

  static ImportPreview<ProjectDraft> parse(Uint8List bytes, {required String fileName}) {
    final read = _readTable(bytes,
        fileName: fileName, sheetName: sheetName, fields: fields, maxRows: maxRows, itemPlural: 'projects');
    final table = read.table;
    if (table == null) {
      return ImportPreview(fileName: fileName, sheetName: read.sheetName, rows: const [], fileProblem: read.problem);
    }
    final projects = ProjectRepository.instance;
    final structure = OrgStructureRepository.instance;
    final employees = EmployeeRepository.instance;
    final roles = RoleRepository.instance;
    final competencies = CompetencyRepository.instance;
    final firstByCode = <String, int>{};
    final firstByName = <String, int>{};
    final rows = <ImportRow<ProjectDraft>>[];
    final today = dateOnly(DateTime.now());

    for (final row in table.rows) {
      String c(String key) => table.cell(row, key);
      final problems = <String>[];
      String? duplicate;

      final code = c('code').toUpperCase();
      final name = cleanText(c('name'));
      if (code.isEmpty) {
        problems.add('Project Code is empty.');
      } else if (!ProjectRules.isValidCode(code)) {
        problems.add('Project Code "$code" can only have letters, digits, - or _ (up to 20).');
      } else {
        final existing = projects.byCode(code);
        final earlier = firstByCode[code];
        if (existing != null) {
          duplicate = 'Already exists: ${existing.code} ${existing.name}.';
        } else if (earlier != null) {
          duplicate = 'Same Project Code as row $earlier.';
        }
        firstByCode.putIfAbsent(code, () => row.number);
      }
      if (name.isEmpty) {
        problems.add('Project Name is empty.');
      } else if (name.length > ProjectRules.nameMax) {
        problems.add('Project Name is longer than ${ProjectRules.nameMax} characters.');
      } else if (duplicate == null) {
        final existing = projects.byName(name);
        final earlier = firstByName[nameKey(name)];
        if (existing != null) {
          duplicate = 'A project named "${existing.name}" already exists (${existing.code}).';
        } else if (earlier != null) {
          duplicate = 'Same Project Name as row $earlier.';
        }
        firstByName.putIfAbsent(nameKey(name), () => row.number);
      }

      final customer = cleanText(c('customer'));
      if (customer.length > ProjectRules.customerMax) {
        problems.add('Customer is longer than ${ProjectRules.customerMax} characters.');
      }

      final departmentText = c('department');
      final department = departmentText.isEmpty ? null : structure.departmentByName(departmentText);
      if (departmentText.isEmpty) {
        problems.add('Department is empty.');
      } else if (department == null) {
        problems.add('Department "$departmentText" doesn\'t exist.');
      }

      final managerText = c('manager');
      final manager = managerText.isEmpty ? null : employees.find(managerText);
      if (managerText.isNotEmpty && manager == null) {
        problems.add('Project Manager "$managerText" is not an employee ID, email or name.');
      }

      final startText = c('start');
      final start = parseFlexibleDate(startText);
      if (startText.isEmpty) {
        problems.add('Start Date is empty.');
      } else if (start == null) {
        problems.add('Start Date "$startText" is not a date (use YYYY-MM-DD).');
      }
      final endText = c('end');
      final end = parseFlexibleDate(endText);
      if (endText.isNotEmpty && end == null) {
        problems.add('End Date "$endText" is not a date (use YYYY-MM-DD).');
      } else if (start != null && end != null && end.isBefore(start)) {
        problems.add('End Date is before Start Date.');
      }

      final statusText = c('status');
      var status = ProjectStatus.tryParse(statusText);
      if (statusText.isNotEmpty && status == null) {
        problems.add('Status "$statusText" must be Planned, Active, On hold or Completed.');
      }
      if (statusText.isEmpty && start != null) {
        status = start.isAfter(today) ? ProjectStatus.planned : ProjectStatus.active;
      }

      final teamText = c('team');
      var team = 0;
      if (teamText.isNotEmpty) {
        final parsed = double.tryParse(teamText);
        if (parsed == null || parsed < 0 || parsed > ProjectRules.teamMax || parsed != parsed.roundToDouble()) {
          problems.add('Planned Team Size "$teamText" must be a whole number 0–${ProjectRules.teamMax}.');
        } else {
          team = parsed.round();
        }
      }

      final description = c('description');
      if (description.length > ProjectRules.descriptionMax) {
        problems.add('Description is longer than ${ProjectRules.descriptionMax} characters.');
      }

      final requirements = <ProjectRequirement>[];
      final seen = <String>{};
      for (final item in _splitList(c('requirements'))) {
        final parsed = _nameLevel(item);
        final level = parsed?.level;
        final competency = parsed == null ? null : competencies.findByName(parsed.name);
        JobRole? role;
        if (parsed != null && parsed.rest.isNotEmpty) role = roles.byName(parsed.rest);
        if (parsed == null || level == null) {
          problems.add('Required competency "$item" needs a level, e.g. "Java:4".');
        } else if (competency == null) {
          problems.add('"${parsed.name}" is not in the competency library.');
        } else if (level < CompetencyLevel.min || level > CompetencyLevel.max) {
          problems.add('Level of ${competency.name} must be 0–5.');
        } else if (parsed.rest.isNotEmpty && role == null) {
          problems.add('Role "${parsed.rest}" (after @ in "$item") doesn\'t exist.');
        } else if (!seen.add('${competency.id}|${role?.id ?? '*'}')) {
          problems.add('${competency.name} is listed twice for the same role.');
        } else {
          requirements.add(ProjectRequirement(competency.id, level, roleId: role?.id));
        }
      }

      final members = <String>[];
      for (final item in _splitList(c('members'))) {
        final e = employees.find(item);
        if (e == null) {
          problems.add('Team member "$item" is not an employee ID, email or name.');
        } else if (!members.contains(e.id)) {
          members.add(e.id);
        }
      }

      rows.add(ImportRow<ProjectDraft>(
        rowNumber: row.number,
        title: [if (code.isNotEmpty) code, if (name.isNotEmpty) name].join(' · ').ifEmpty('(no name)'),
        subtitle: [
          if (department != null) department.name,
          if (status != null) status.label,
          if (requirements.isNotEmpty) '${requirements.length} required',
          if (members.isNotEmpty) '${members.length} members',
        ].join(' · '),
        problems: problems,
        duplicateNote: duplicate,
        value: problems.isEmpty && department != null && start != null && status != null
            ? ProjectDraft(
                code: code,
                name: name,
                departmentId: department.id,
                startDate: start,
                status: status,
                customer: customer,
                managerId: manager?.id,
                endDate: end,
                description: description,
                plannedTeamSize: team,
                requirements: requirements,
                memberIds: members,
              )
            : null,
      ));
    }
    return ImportPreview(fileName: fileName, sheetName: table.sheet.sheetName, rows: rows);
  }
}

// ================================================================= roles

class RoleImporter {
  RoleImporter._();

  static const int maxRows = 300;
  static const String sheetName = 'Roles';
  static const String templateAsset = 'assets/templates/role_import_template.xlsx';
  static const String templateFileName = 'SkillSphere_role_import_template.xlsx';

  static const fields = [
    ImportField('name', 'Role Name', aliases: ['Role', 'Name'], required: true),
    ImportField('code', 'Role Code', aliases: ['Code']),
    ImportField('description', 'Description', aliases: ['Role Description']),
  ];

  static ImportPreview<RoleDraft> parse(Uint8List bytes, {required String fileName}) {
    final read = _readTable(bytes,
        fileName: fileName, sheetName: sheetName, fields: fields, maxRows: maxRows, itemPlural: 'roles');
    final table = read.table;
    if (table == null) {
      return ImportPreview(fileName: fileName, sheetName: read.sheetName, rows: const [], fileProblem: read.problem);
    }
    final roles = RoleRepository.instance;
    final firstByName = <String, int>{};
    final firstByCode = <String, int>{};
    final rows = <ImportRow<RoleDraft>>[];
    for (final row in table.rows) {
      final name = cleanText(table.cell(row, 'name'));
      final code = table.cell(row, 'code').toUpperCase();
      final description = table.cell(row, 'description');
      final problems = <String>[];
      String? duplicate;
      if (name.isEmpty) {
        problems.add('Role Name is empty.');
      } else if (name.length > RoleRules.nameMax) {
        problems.add('Role Name is longer than ${RoleRules.nameMax} characters.');
      } else {
        final existing = roles.byName(name);
        final earlier = firstByName[nameKey(name)];
        if (existing != null) {
          duplicate = 'Already exists: ${existing.name} (${existing.code}).';
        } else if (earlier != null) {
          duplicate = 'Same Role Name as row $earlier.';
        }
        firstByName.putIfAbsent(nameKey(name), () => row.number);
      }
      if (code.isNotEmpty) {
        if (!RoleRules.isValidCode(code)) {
          problems.add('Role Code "$code" can only have letters, digits, - or _ (up to ${RoleRules.codeMax}).');
        } else if (duplicate == null) {
          final existing = roles.byName(code);
          final earlier = firstByCode[code];
          if (existing != null) {
            problems.add('Role Code $code is used by ${existing.name}.');
          } else if (earlier != null) {
            problems.add('Same Role Code as row $earlier.');
          }
          firstByCode.putIfAbsent(code, () => row.number);
        }
      }
      if (description.length > RoleRules.descriptionMax) {
        problems.add('Description is longer than ${RoleRules.descriptionMax} characters.');
      }
      rows.add(ImportRow<RoleDraft>(
        rowNumber: row.number,
        title: name.ifEmpty('(no name)'),
        subtitle: [if (code.isNotEmpty) code, if (description.isNotEmpty) description].join(' · '),
        problems: problems,
        duplicateNote: duplicate,
        value: problems.isEmpty ? RoleDraft(name: name, code: code, description: description) : null,
      ));
    }
    return ImportPreview(fileName: fileName, sheetName: table.sheet.sheetName, rows: rows);
  }
}

// ============================================ divisions, groups & departments

class StructureImporter {
  StructureImporter._();

  static const int maxRows = 500;
  static const String sheetName = 'Structure';
  static const String templateAsset = 'assets/templates/group_department_import_template.xlsx';
  static const String templateFileName = 'SkillSphere_org_structure_import_template.xlsx';

  static const fields = [
    // Division is optional in the header so older files (Group + Department
    // only) still work; a NEW group needs it on its row.
    ImportField('division', 'Division', aliases: ['Division Name']),
    ImportField('divisionCode', 'Division Code'),
    ImportField('divisionHead', 'Division Head', aliases: ['Division Head ID']),
    ImportField('divisionDescription', 'Division Description'),
    ImportField('group', 'Group', aliases: ['Group Name', 'Business Group'], required: true),
    ImportField('groupCode', 'Group Code'),
    ImportField('groupDescription', 'Group Description'),
    ImportField('department', 'Department', aliases: ['Department Name', 'Dept'], required: true),
    ImportField('departmentCode', 'Department Code', aliases: ['Dept Code']),
    ImportField('head', 'Department Head', aliases: ['Head', 'Head Employee ID', 'Team Lead']),
    ImportField('departmentDescription', 'Department Description', aliases: ['Description']),
  ];

  static ImportPreview<StructureDraft> parse(Uint8List bytes, {required String fileName}) {
    final read = _readTable(bytes,
        fileName: fileName, sheetName: sheetName, fields: fields, maxRows: maxRows, itemPlural: 'rows');
    final table = read.table;
    if (table == null) {
      return ImportPreview(fileName: fileName, sheetName: read.sheetName, rows: const [], fileProblem: read.problem);
    }
    final structure = OrgStructureRepository.instance;
    final employees = EmployeeRepository.instance;
    final firstDepartment = <String, int>{};
    final newDivisions = <String>{};
    final newGroups = <String>{};
    final rows = <ImportRow<StructureDraft>>[];

    for (final row in table.rows) {
      String c(String key) => table.cell(row, key);
      final problems = <String>[];
      String? duplicate;
      final divisionName = cleanText(c('division'));
      final divisionCode = c('divisionCode').toUpperCase();
      final groupName = cleanText(c('group'));
      final groupCode = c('groupCode').toUpperCase();
      final departmentName = cleanText(c('department'));
      final departmentCode = c('departmentCode').toUpperCase();

      final division = divisionName.isEmpty ? null : structure.divisionByName(divisionName);
      final group = groupName.isEmpty ? null : structure.groupByName(groupName);

      if (divisionName.isEmpty && groupName.isEmpty && departmentName.isEmpty) {
        problems.add('Division, Group and Department are empty.');
      }
      if (divisionName.length > StructureRules.nameMax) {
        problems.add('Division is longer than ${StructureRules.nameMax} characters.');
      }
      if (groupName.length > StructureRules.nameMax) {
        problems.add('Group is longer than ${StructureRules.nameMax} characters.');
      }
      if (departmentName.isNotEmpty && groupName.isEmpty) {
        problems.add('Group is empty: a department needs its group.');
      }
      if (groupName.isNotEmpty && group == null && divisionName.isEmpty) {
        problems.add('Division is empty: the new group $groupName needs its division.');
      }
      if (group != null && divisionName.isNotEmpty && division?.id != group.divisionId) {
        final actual = structure.divisionOfGroup(group.id)?.name ?? '—';
        problems.add('Group ${group.name} is in $actual, not $divisionName. '
            'Move it under Org Structure instead.');
      }
      for (final (label, code) in [
        ('Division Code', divisionCode),
        ('Group Code', groupCode),
        ('Department Code', departmentCode),
      ]) {
        if (code.isNotEmpty && !StructureRules.isValidCode(code)) {
          problems.add('$label "$code" can only have letters, digits, - or _ (up to 12).');
        }
      }

      if (groupName.isEmpty) {
        // Division only.
        if (division != null) {
          duplicate = 'Division ${division.name} already exists.';
        } else if (divisionName.isNotEmpty && !newDivisions.add(nameKey(divisionName))) {
          duplicate = 'Division $divisionName is already added by an earlier row.';
        }
      } else if (departmentName.isEmpty) {
        // Division (optional) + group.
        if (group != null) {
          duplicate = 'Group ${group.name} already exists.';
        } else if (!newGroups.add(nameKey(groupName))) {
          duplicate = 'Group $groupName is already added by an earlier row.';
        }
      } else if (departmentName.length > StructureRules.nameMax) {
        problems.add('Department is longer than ${StructureRules.nameMax} characters.');
      } else {
        final existing = structure.departmentByName(departmentName);
        final earlier = firstDepartment[nameKey(departmentName)];
        if (existing != null) {
          final inGroup = structure.groupNameOfDepartment(existing.id);
          duplicate = group != null && existing.groupId == group.id
              ? 'Already exists: $inGroup › ${existing.name}.'
              : '${existing.name} already exists in $inGroup. Move it under Org Structure.';
        } else if (earlier != null) {
          duplicate = 'Same Department as row $earlier.';
        } else if (departmentCode.isNotEmpty && structure.departmentByName(departmentCode) != null) {
          problems.add('Department Code $departmentCode is already used.');
        }
        firstDepartment.putIfAbsent(nameKey(departmentName), () => row.number);
        if (group == null && groupName.isNotEmpty) newGroups.add(nameKey(groupName));
      }
      if (division == null && divisionName.isNotEmpty && groupName.isNotEmpty) {
        newDivisions.add(nameKey(divisionName));
      }

      final headText = c('head');
      final head = headText.isEmpty ? null : employees.find(headText);
      if (headText.isNotEmpty && head == null) {
        problems.add('Department Head "$headText" is not an employee ID, email or name.');
      }
      final divisionHeadText = c('divisionHead');
      final divisionHead = divisionHeadText.isEmpty ? null : employees.find(divisionHeadText);
      if (divisionHeadText.isNotEmpty && divisionHead == null) {
        problems.add('Division Head "$divisionHeadText" is not an employee ID, email or name.');
      }
      final divisionDescription = c('divisionDescription');
      final groupDescription = c('groupDescription');
      final departmentDescription = c('departmentDescription');
      if (divisionDescription.length > StructureRules.descriptionMax ||
          groupDescription.length > StructureRules.descriptionMax ||
          departmentDescription.length > StructureRules.descriptionMax) {
        problems.add('Descriptions can be up to ${StructureRules.descriptionMax} characters.');
      }

      final path = [
        if (divisionName.isNotEmpty) division?.name ?? divisionName,
        if (groupName.isNotEmpty) group?.name ?? groupName,
        if (departmentName.isNotEmpty) departmentName,
      ].join(' › ');
      rows.add(ImportRow<StructureDraft>(
        rowNumber: row.number,
        title: path.ifEmpty('(empty row)'),
        subtitle: [
          if (divisionName.isNotEmpty) division == null ? 'New division' : 'Existing division',
          if (groupName.isNotEmpty) group == null ? 'New group' : 'Existing group',
          if (departmentName.isNotEmpty) 'New department',
          if (divisionHead != null) 'Division head: ${divisionHead.name}',
          if (head != null) 'Head: ${head.name}',
        ].join(' · '),
        problems: problems,
        duplicateNote: duplicate,
        value: problems.isEmpty
            ? StructureDraft(
                divisionName: division?.name ?? divisionName,
                divisionCode: divisionCode,
                divisionDescription: divisionDescription,
                divisionHeadId: divisionHead?.id,
                groupName: group?.name ?? groupName,
                groupCode: groupCode,
                groupDescription: groupDescription,
                departmentName: departmentName,
                departmentCode: departmentCode,
                headId: head?.id,
                departmentDescription: departmentDescription,
              )
            : null,
      ));
    }
    return ImportPreview(fileName: fileName, sheetName: table.sheet.sheetName, rows: rows);
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
