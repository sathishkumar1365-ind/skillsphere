// Organisation structure: Division → Group → Department.
//
// A division (top level, e.g. Research & Development) contains groups; a
// group (business unit) contains departments; every employee belongs to one
// department, and so to that department's group and division. Moving a
// department to another group – or a group to another division – therefore
// changes the group/division of everyone in it, and each of those changes is
// logged (Profile Changes).
//
// Spring Boot API later:
//   GET  /api/org/divisions  GET /api/org/groups  GET /api/org/departments
//   POST /api/org/divisions | groups | departments          (SUPER_ADMIN)
//   POST /api/org/structure/bulk                            (SUPER_ADMIN)
//   PUT  /api/org/groups/{id}/division (SUPER_ADMIN) – moves a group
//   PUT  /api/org/departments/{id}/group (SUPER_ADMIN) – moves a department

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import 'admin_base.dart';
import 'admin_sample_data.dart';
import 'employees.dart';

/// Top level of the structure, e.g. "Research & Development".
class OrgDivision {
  const OrgDivision({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
    this.headId,
    this.description = '',
    this.crowdGroup,
    this.source = RecordSource.existing,
  });

  /// e.g. "DIV-01".
  final String id;
  final String name;

  /// Short code, e.g. "RND".
  final String code;

  /// Employee ID of the division head, if they are in SkillSphere.
  final String? headId;
  final String description;

  /// Name of the matching Crowd group, e.g. "div-research-development".
  final String? crowdGroup;
  final DateTime createdAt;
  final RecordSource source;

  String get key => nameKey(name);

  OrgDivision copyWith({Object? headId = _keep}) => OrgDivision(
        id: id,
        name: name,
        code: code,
        createdAt: createdAt,
        headId: identical(headId, _keep) ? this.headId : headId as String?,
        description: description,
        crowdGroup: crowdGroup,
        source: source,
      );

  static const Object _keep = Object();
}

class OrgGroup {
  const OrgGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.divisionId,
    required this.createdAt,
    this.description = '',
    this.crowdGroup,
    this.source = RecordSource.existing,
  });

  /// e.g. "GRP-01".
  final String id;
  final String name;

  /// Short code, e.g. "SWD".
  final String code;

  /// The division this group belongs to.
  final String divisionId;
  final String description;

  /// Name of the matching Crowd group, e.g. "grp-software-development".
  final String? crowdGroup;
  final DateTime createdAt;
  final RecordSource source;

  String get key => nameKey(name);

  OrgGroup copyWith({String? divisionId}) => OrgGroup(
        id: id,
        name: name,
        code: code,
        divisionId: divisionId ?? this.divisionId,
        createdAt: createdAt,
        description: description,
        crowdGroup: crowdGroup,
        source: source,
      );
}

class OrgDepartment {
  const OrgDepartment({
    required this.id,
    required this.name,
    required this.code,
    required this.groupId,
    required this.createdAt,
    this.headId,
    this.description = '',
    this.crowdGroup,
    this.source = RecordSource.existing,
  });

  /// e.g. "DEP-01".
  final String id;
  final String name;
  final String code;
  final String groupId;

  /// Employee ID of the department head (Team Lead), if any.
  final String? headId;
  final String description;

  /// Name of the matching Crowd group, e.g. "dept-engineering". Crowd users
  /// in this group are placed in this department when synchronised.
  final String? crowdGroup;
  final DateTime createdAt;
  final RecordSource source;

  String get key => nameKey(name);

  OrgDepartment copyWith({String? groupId, Object? headId = _keep}) => OrgDepartment(
        id: id,
        name: name,
        code: code,
        groupId: groupId ?? this.groupId,
        createdAt: createdAt,
        headId: identical(headId, _keep) ? this.headId : headId as String?,
        description: description,
        crowdGroup: crowdGroup,
        source: source,
      );

  static const Object _keep = Object();
}

/// A division + group + department to add (form, Excel/CSV row or Crowd
/// group). Leave the lower levels empty to add only a division or a group.
class StructureDraft {
  const StructureDraft({
    this.divisionName = '',
    this.divisionCode = '',
    this.divisionDescription = '',
    this.divisionHeadId,
    this.divisionCrowd,
    this.groupName = '',
    this.groupCode = '',
    this.groupDescription = '',
    this.departmentName = '',
    this.departmentCode = '',
    this.headId,
    this.departmentDescription = '',
    this.groupCrowd,
    this.departmentCrowd,
  });

  /// Needed when the group is new; empty = the group's current division.
  final String divisionName;
  final String divisionCode;
  final String divisionDescription;
  final String? divisionHeadId;
  final String? divisionCrowd;

  /// Empty when the row only adds a division.
  final String groupName;
  final String groupCode;
  final String groupDescription;

  /// Empty when the row only adds a division or a group.
  final String departmentName;
  final String departmentCode;
  final String? headId;
  final String departmentDescription;
  final String? groupCrowd;
  final String? departmentCrowd;
}

class StructureRules {
  StructureRules._();

  static const int nameMax = 60;
  static const int codeMax = 12;
  static const int descriptionMax = 200;

  /// Letters, digits, dash and underscore: "SWD", "QA-01".
  static bool isValidCode(String code) => RegExp(r'^[A-Za-z0-9_\-]{1,12}$').hasMatch(code);

  /// "Quality & Validation" → "QV", "Engineering" → "ENG".
  static String suggestCode(String name) {
    final words = name
        .split(RegExp(r'[\s/&+\-]+'))
        .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    if (words.length == 1) {
      final w = words.first.toUpperCase();
      return w.length <= 3 ? w : w.substring(0, 3);
    }
    return words.take(4).map((w) => w[0].toUpperCase()).join();
  }
}

/// Result of adding many divisions/groups/departments at once.
class StructureAddResult {
  const StructureAddResult({this.divisions = const [], required this.groups, required this.departments});

  final List<OrgDivision> divisions;
  final List<OrgGroup> groups;
  final List<OrgDepartment> departments;

  bool get isEmpty => divisions.isEmpty && groups.isEmpty && departments.isEmpty;

  int get total => divisions.length + groups.length + departments.length;

  /// "1 division, 2 groups and 3 departments"
  String get summary {
    String part(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final parts = [
      if (divisions.isNotEmpty) part(divisions.length, 'division', 'divisions'),
      if (groups.isNotEmpty) part(groups.length, 'group', 'groups'),
      if (departments.isNotEmpty) part(departments.length, 'department', 'departments'),
    ];
    if (parts.isEmpty) return 'nothing';
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }
}

class OrgStructureRepository {
  OrgStructureRepository._();

  static final OrgStructureRepository instance = OrgStructureRepository._();

  final ValueNotifier<List<OrgDivision>> divisions =
      ValueNotifier<List<OrgDivision>>(List<OrgDivision>.unmodifiable(sampleDivisions));
  final ValueNotifier<List<OrgGroup>> groups =
      ValueNotifier<List<OrgGroup>>(List<OrgGroup>.unmodifiable(sampleGroups));
  final ValueNotifier<List<OrgDepartment>> departments =
      ValueNotifier<List<OrgDepartment>>(List<OrgDepartment>.unmodifiable(sampleDepartments));

  /// Ids added in this session (shown with a "NEW" label).
  final Set<String> _addedThisSession = <String>{};

  bool isNew(String id) => _addedThisSession.contains(id);

  /// Listen to this to follow any change of the structure.
  Listenable get listenable => Listenable.merge([divisions, groups, departments]);

  OrgDivision? divisionById(String? id) {
    if (id == null) return null;
    for (final d in divisions.value) {
      if (d.id == id) return d;
    }
    return null;
  }

  OrgDivision? divisionByName(String name) {
    final key = nameKey(name);
    for (final d in divisions.value) {
      if (d.key == key || nameKey(d.code) == key) return d;
    }
    return null;
  }

  OrgDivision? divisionByCrowdGroup(String crowdGroup) {
    final key = nameKey(crowdGroup);
    for (final d in divisions.value) {
      if (d.crowdGroup != null && nameKey(d.crowdGroup!) == key) return d;
    }
    return null;
  }

  /// Groups of [divisionId], by name.
  List<OrgGroup> groupsIn(String divisionId) =>
      groups.value.where((g) => g.divisionId == divisionId).toList()..sort((a, b) => a.name.compareTo(b.name));

  /// Departments of every group in [divisionId], by name.
  List<OrgDepartment> departmentsInDivision(String divisionId) {
    final groupIds = {for (final g in groupsIn(divisionId)) g.id};
    return departments.value.where((d) => groupIds.contains(d.groupId)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  OrgDivision? divisionOfGroup(String? groupId) => divisionById(groupById(groupId)?.divisionId);

  OrgDivision? divisionOfDepartment(String? departmentId) => divisionOfGroup(departmentById(departmentId)?.groupId);

  String divisionNameOfDepartment(String? departmentId) => divisionOfDepartment(departmentId)?.name ?? '—';

  OrgGroup? groupById(String? id) {
    if (id == null) return null;
    for (final g in groups.value) {
      if (g.id == id) return g;
    }
    return null;
  }

  OrgDepartment? departmentById(String? id) {
    if (id == null) return null;
    for (final d in departments.value) {
      if (d.id == id) return d;
    }
    return null;
  }

  OrgGroup? groupByName(String name) {
    final key = nameKey(name);
    for (final g in groups.value) {
      if (g.key == key || nameKey(g.code) == key) return g;
    }
    return null;
  }

  OrgDepartment? departmentByName(String name) {
    final key = nameKey(name);
    for (final d in departments.value) {
      if (d.key == key || nameKey(d.code) == key) return d;
    }
    return null;
  }

  OrgDepartment? departmentByCrowdGroup(String crowdGroup) {
    final key = nameKey(crowdGroup);
    for (final d in departments.value) {
      if (d.crowdGroup != null && nameKey(d.crowdGroup!) == key) return d;
    }
    return null;
  }

  OrgGroup? groupByCrowdGroup(String crowdGroup) {
    final key = nameKey(crowdGroup);
    for (final g in groups.value) {
      if (g.crowdGroup != null && nameKey(g.crowdGroup!) == key) return g;
    }
    return null;
  }

  List<OrgDepartment> departmentsIn(String groupId) =>
      departments.value.where((d) => d.groupId == groupId).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  OrgGroup? groupOfDepartment(String? departmentId) =>
      groupById(departmentById(departmentId)?.groupId);

  String departmentName(String? id) => departmentById(id)?.name ?? '—';

  String groupNameOfDepartment(String? departmentId) =>
      groupOfDepartment(departmentId)?.name ?? '—';

  /// Department name → name of its head, in the dashboard's order.
  Map<String, String> departmentLeads(String Function(String employeeId) nameOf) => {
        for (final d in departments.value) d.name: d.headId == null ? '—' : nameOf(d.headId!),
      };

  // ------------------------------------------------------------ adding

  Future<OrgDivision> addDivision({
    required AppUser by,
    required String name,
    required String code,
    String? headId,
    String description = '',
  }) async {
    requireHrd(by, 'add divisions');
    final problem = divisionProblem(name, code);
    if (problem != null) throw AdminException(problem);
    final result = await addAll(
      by: by,
      drafts: [
        StructureDraft(divisionName: name, divisionCode: code, divisionDescription: description, divisionHeadId: headId),
      ],
      pause: true,
    );
    if (result.divisions.isEmpty) {
      throw AdminException(divisionProblem(name, code) ?? 'This division could not be added.');
    }
    return result.divisions.first;
  }

  Future<OrgGroup> addGroup({
    required AppUser by,
    required String divisionId,
    required String name,
    required String code,
    String description = '',
  }) async {
    requireHrd(by, 'add groups');
    final division = divisionById(divisionId);
    if (division == null) throw const AdminException('Choose the division this group belongs to.');
    final problem = groupProblem(name, code);
    if (problem != null) throw AdminException(problem);
    final result = await addAll(
      by: by,
      drafts: [
        StructureDraft(
          divisionName: division.name,
          groupName: name,
          groupCode: code,
          groupDescription: description,
        ),
      ],
      pause: true,
    );
    if (result.groups.isEmpty) {
      throw AdminException(groupProblem(name, code) ?? 'This group could not be added.');
    }
    return result.groups.first;
  }

  Future<OrgDepartment> addDepartment({
    required AppUser by,
    required String groupId,
    required String name,
    required String code,
    String? headId,
    String description = '',
  }) async {
    requireHrd(by, 'add departments');
    final group = groupById(groupId);
    if (group == null) throw const AdminException('Choose the group this department belongs to.');
    final problem = departmentProblem(name, code);
    if (problem != null) throw AdminException(problem);
    final result = await addAll(
      by: by,
      drafts: [
        StructureDraft(
          groupName: group.name,
          departmentName: name,
          departmentCode: code,
          headId: headId,
          departmentDescription: description,
        ),
      ],
      pause: true,
    );
    if (result.departments.isEmpty) throw const AdminException('This department could not be added.');
    return result.departments.first;
  }

  /// Why a new division can't use [name]/[code], or null.
  String? divisionProblem(String name, String code) {
    final clean = cleanText(name);
    if (clean.isEmpty) return 'Enter the division name.';
    if (clean.length > StructureRules.nameMax) {
      return 'Keep the name under ${StructureRules.nameMax} characters.';
    }
    if (code.trim().isNotEmpty && !StructureRules.isValidCode(code.trim())) {
      return 'The code can have up to 12 letters, digits, - or _.';
    }
    final existing = divisionByName(clean);
    if (existing != null) return '"${existing.name}" already exists.';
    if (code.trim().isNotEmpty && divisionByName(code) != null) {
      return 'The code "${code.trim().toUpperCase()}" is already used.';
    }
    return null;
  }

  /// Why a new group can't use [name]/[code], or null.
  String? groupProblem(String name, String code) {
    final clean = cleanText(name);
    if (clean.isEmpty) return 'Enter the group name.';
    if (clean.length > StructureRules.nameMax) {
      return 'Keep the name under ${StructureRules.nameMax} characters.';
    }
    if (code.trim().isNotEmpty && !StructureRules.isValidCode(code.trim())) {
      return 'The code can have up to 12 letters, digits, - or _.';
    }
    final existing = groupByName(clean);
    if (existing != null) {
      return '"${existing.name}" already exists in ${divisionOfGroup(existing.id)?.name ?? 'another division'}.';
    }
    if (code.trim().isNotEmpty && groupByName(code) != null) {
      return 'The code "${code.trim().toUpperCase()}" is already used.';
    }
    return null;
  }

  /// Why a new department can't use [name]/[code], or null.
  String? departmentProblem(String name, String code) {
    final clean = cleanText(name);
    if (clean.isEmpty) return 'Enter the department name.';
    if (clean.length > StructureRules.nameMax) {
      return 'Keep the name under ${StructureRules.nameMax} characters.';
    }
    if (code.trim().isNotEmpty && !StructureRules.isValidCode(code.trim())) {
      return 'The code can have up to 12 letters, digits, - or _.';
    }
    final existing = departmentByName(clean);
    if (existing != null) {
      return '"${existing.name}" already exists in ${groupNameOfDepartment(existing.id)}.';
    }
    if (code.trim().isNotEmpty && departmentByName(code) != null) {
      return 'The code "${code.trim().toUpperCase()}" is already used.';
    }
    return null;
  }

  /// Adds divisions, groups and departments from a form, a file or Crowd
  /// (HRD only). A row whose division or group doesn't exist creates it (a
  /// new group needs its division); a department that already exists is
  /// skipped. An existing group is never moved here (use [moveGroup]).
  Future<StructureAddResult> addAll({
    required AppUser by,
    required List<StructureDraft> drafts,
    RecordSource source = RecordSource.manual,
    bool pause = true,
  }) async {
    requireHrd(by, 'change the organisation structure');
    if (pause) await apiPause(450);

    final newDivisions = <OrgDivision>[];
    final newGroups = <OrgGroup>[];
    final newDepartments = <OrgDepartment>[];
    final allDivisions = [...divisions.value];
    final allGroups = [...groups.value];
    final allDepartments = [...departments.value];
    final now = DateTime.now();

    OrgDivision? findDivision(String name) {
      final key = nameKey(name);
      for (final d in allDivisions) {
        if (d.key == key || nameKey(d.code) == key) return d;
      }
      return null;
    }

    OrgGroup? findGroup(String name) {
      final key = nameKey(name);
      for (final g in allGroups) {
        if (g.key == key || nameKey(g.code) == key) return g;
      }
      return null;
    }

    bool departmentTaken(String name, String code) {
      final key = nameKey(name);
      final codeKey = nameKey(code);
      return allDepartments.any(
          (d) => d.key == key || (codeKey.isNotEmpty && nameKey(d.code) == codeKey));
    }

    for (final draft in drafts) {
      final divisionName = cleanText(draft.divisionName);
      OrgDivision? division;
      if (divisionName.isNotEmpty) {
        division = findDivision(divisionName);
        if (division == null) {
          if (divisionName.length > StructureRules.nameMax) continue;
          var code = draft.divisionCode.trim().toUpperCase();
          if (code.isEmpty || !StructureRules.isValidCode(code) || findDivision(code) != null) {
            code = _uniqueCode(StructureRules.suggestCode(divisionName), allDivisions.map((d) => d.code));
          }
          final head = draft.divisionHeadId == null ? null : EmployeeRepository.instance.byId(draft.divisionHeadId!);
          division = OrgDivision(
            id: nextId('DIV-', allDivisions.map((d) => d.id), width: 2),
            name: divisionName,
            code: code,
            headId: head?.id,
            description: draft.divisionDescription.trim(),
            crowdGroup: draft.divisionCrowd,
            createdAt: now,
            source: source,
          );
          allDivisions.add(division);
          newDivisions.add(division);
        }
      }

      final groupName = cleanText(draft.groupName);
      if (groupName.isEmpty) continue;
      var group = findGroup(groupName);
      if (group == null) {
        // A new group needs its division.
        if (groupName.length > StructureRules.nameMax || division == null) continue;
        var code = draft.groupCode.trim().toUpperCase();
        if (code.isEmpty || !StructureRules.isValidCode(code) || findGroup(code) != null) {
          code = _uniqueCode(StructureRules.suggestCode(groupName), allGroups.map((g) => g.code));
        }
        group = OrgGroup(
          id: nextId('GRP-', allGroups.map((g) => g.id), width: 2),
          name: groupName,
          code: code,
          divisionId: division.id,
          description: draft.groupDescription.trim(),
          crowdGroup: draft.groupCrowd,
          createdAt: now,
          source: source,
        );
        allGroups.add(group);
        newGroups.add(group);
      }

      final departmentName = cleanText(draft.departmentName);
      if (departmentName.isEmpty || departmentName.length > StructureRules.nameMax) continue;
      var code = draft.departmentCode.trim().toUpperCase();
      if (departmentTaken(departmentName, '')) continue;
      if (code.isEmpty || !StructureRules.isValidCode(code) || departmentTaken('', code)) {
        code = _uniqueCode(StructureRules.suggestCode(departmentName), allDepartments.map((d) => d.code));
      }
      final head = draft.headId == null ? null : EmployeeRepository.instance.byId(draft.headId!);
      final department = OrgDepartment(
        id: nextId('DEP-', allDepartments.map((d) => d.id), width: 2),
        name: departmentName,
        code: code,
        groupId: group.id,
        headId: head?.id,
        description: draft.departmentDescription.trim(),
        crowdGroup: draft.departmentCrowd,
        createdAt: now,
        source: source,
      );
      allDepartments.add(department);
      newDepartments.add(department);
    }

    if (newDivisions.isNotEmpty) {
      _addedThisSession.addAll(newDivisions.map((d) => d.id));
      divisions.value = List<OrgDivision>.unmodifiable(allDivisions);
    }
    if (newGroups.isNotEmpty) {
      _addedThisSession.addAll(newGroups.map((g) => g.id));
      groups.value = List<OrgGroup>.unmodifiable(allGroups);
    }
    if (newDepartments.isNotEmpty) {
      _addedThisSession.addAll(newDepartments.map((d) => d.id));
      departments.value = List<OrgDepartment>.unmodifiable(allDepartments);
    }
    return StructureAddResult(divisions: newDivisions, groups: newGroups, departments: newDepartments);
  }

  static String _uniqueCode(String base, Iterable<String> taken) {
    final used = {for (final c in taken) c.toUpperCase()};
    final start = base.isEmpty ? 'NEW' : base.toUpperCase();
    if (!used.contains(start)) return start;
    for (var i = 2; i < 100; i++) {
      final candidate = '$start$i';
      if (!used.contains(candidate)) return candidate;
    }
    return '$start${DateTime.now().millisecondsSinceEpoch % 1000}';
  }

  // ----------------------------------------------------------- re-org

  /// Moves a group (its departments and everyone in them) to another
  /// division. One division change is logged per employee.
  Future<int> moveGroup({
    required AppUser by,
    required String groupId,
    required String toDivisionId,
    required ChangeReason reason,
    required DateTime effectiveDate,
    String note = '',
  }) async {
    requireHrd(by, 'move groups');
    final group = groupById(groupId);
    final from = divisionOfGroup(groupId);
    final to = divisionById(toDivisionId);
    if (group == null || to == null) throw const AdminException('Choose a group and a division.');
    if (from?.id == to.id) throw AdminException('${group.name} is already in ${to.name}.');
    await apiPause(450);

    groups.value = List<OrgGroup>.unmodifiable([
      for (final g in groups.value) g.id == groupId ? g.copyWith(divisionId: toDivisionId) : g,
    ]);
    final departmentIds = {for (final d in departments.value) if (d.groupId == groupId) d.id};
    return EmployeeRepository.instance.logStructureMove(
      by: by,
      departmentIds: departmentIds,
      field: ChangeField.division,
      from: from?.name ?? '—',
      to: to.name,
      reason: reason,
      effectiveDate: effectiveDate,
      note: note,
      batchLabel: '${group.name} moved to ${to.name}',
    );
  }

  /// Moves a department (and everyone in it) to another group. One profile
  /// change is logged per employee so their history shows the new group
  /// (and the new division when the group is in another division).
  Future<int> moveDepartment({
    required AppUser by,
    required String departmentId,
    required String toGroupId,
    required ChangeReason reason,
    required DateTime effectiveDate,
    String note = '',
  }) async {
    requireHrd(by, 'move departments');
    final department = departmentById(departmentId);
    final from = groupOfDepartment(departmentId);
    final to = groupById(toGroupId);
    if (department == null || to == null) throw const AdminException('Choose a department and a group.');
    if (from?.id == to.id) throw AdminException('${department.name} is already in ${to.name}.');
    await apiPause(450);

    final fromDivision = divisionById(from?.divisionId);
    final toDivision = divisionById(to.divisionId);
    departments.value = List<OrgDepartment>.unmodifiable([
      for (final d in departments.value) d.id == departmentId ? d.copyWith(groupId: toGroupId) : d,
    ]);
    final batch = '${department.name} moved to ${to.name}';
    final employees = EmployeeRepository.instance;
    if (fromDivision?.id != toDivision?.id) {
      employees.logStructureMove(
        by: by,
        departmentIds: {departmentId},
        field: ChangeField.division,
        from: fromDivision?.name ?? '—',
        to: toDivision?.name ?? '—',
        reason: reason,
        effectiveDate: effectiveDate,
        note: note,
        batchLabel: batch,
      );
    }
    return employees.logStructureMove(
      by: by,
      departmentIds: {departmentId},
      field: ChangeField.group,
      from: from?.name ?? '—',
      to: to.name,
      reason: reason,
      effectiveDate: effectiveDate,
      note: note,
      batchLabel: batch,
    );
  }

  /// Makes [employeeId] the head of [divisionId] (HRD only).
  void setDivisionHead({required AppUser by, required String divisionId, String? employeeId}) {
    requireHrd(by, 'change division heads');
    divisions.value = List<OrgDivision>.unmodifiable([
      for (final d in divisions.value) d.id == divisionId ? d.copyWith(headId: employeeId) : d,
    ]);
  }

  /// Makes [employeeId] the head of [departmentId] (HRD only).
  void setHead({required AppUser by, required String departmentId, String? employeeId}) {
    requireHrd(by, 'change department heads');
    departments.value = List<OrgDepartment>.unmodifiable([
      for (final d in departments.value) d.id == departmentId ? d.copyWith(headId: employeeId) : d,
    ]);
  }
}
