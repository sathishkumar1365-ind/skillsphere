// Groups and departments. A group (business unit) contains departments;
// every employee belongs to one department, and so to that department's
// group. Moving a department to another group therefore changes the group
// of everyone in it, and each of those changes is logged (Profile Changes).
//
// Spring Boot API later:
//   GET  /api/org/groups                     GET  /api/org/departments
//   POST /api/org/groups        (SUPER_ADMIN) POST /api/org/departments (SUPER_ADMIN)
//   POST /api/org/structure/bulk (SUPER_ADMIN)
//   PUT  /api/org/departments/{id}/group (SUPER_ADMIN) – moves a department

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import 'admin_base.dart';
import 'admin_sample_data.dart';
import 'employees.dart';

class OrgGroup {
  const OrgGroup({
    required this.id,
    required this.name,
    required this.code,
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
  final String description;

  /// Name of the matching Crowd group, e.g. "grp-software-development".
  final String? crowdGroup;
  final DateTime createdAt;
  final RecordSource source;

  String get key => nameKey(name);
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

/// A group + department pair to add (form, Excel/CSV row or Crowd group).
class StructureDraft {
  const StructureDraft({
    required this.groupName,
    this.groupCode = '',
    this.groupDescription = '',
    this.departmentName = '',
    this.departmentCode = '',
    this.headId,
    this.departmentDescription = '',
    this.groupCrowd,
    this.departmentCrowd,
  });

  final String groupName;
  final String groupCode;
  final String groupDescription;

  /// Empty when the row only adds a group.
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

/// Result of adding many groups/departments at once.
class StructureAddResult {
  const StructureAddResult({required this.groups, required this.departments});

  final List<OrgGroup> groups;
  final List<OrgDepartment> departments;

  bool get isEmpty => groups.isEmpty && departments.isEmpty;
}

class OrgStructureRepository {
  OrgStructureRepository._();

  static final OrgStructureRepository instance = OrgStructureRepository._();

  final ValueNotifier<List<OrgGroup>> groups =
      ValueNotifier<List<OrgGroup>>(List<OrgGroup>.unmodifiable(sampleGroups));
  final ValueNotifier<List<OrgDepartment>> departments =
      ValueNotifier<List<OrgDepartment>>(List<OrgDepartment>.unmodifiable(sampleDepartments));

  /// Ids added in this session (shown with a "NEW" label).
  final Set<String> _addedThisSession = <String>{};

  bool isNew(String id) => _addedThisSession.contains(id);

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

  Future<OrgGroup> addGroup({
    required AppUser by,
    required String name,
    required String code,
    String description = '',
  }) async {
    requireHrd(by, 'add groups');
    final problem = groupProblem(name, code);
    if (problem != null) throw AdminException(problem);
    final result = await addAll(
      by: by,
      drafts: [StructureDraft(groupName: name, groupCode: code, groupDescription: description)],
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
    if (existing != null) return '"${existing.name}" already exists.';
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

  /// Adds groups and departments from a file or from Crowd (HRD only).
  /// A row whose group doesn't exist creates it; a department that already
  /// exists is skipped.
  Future<StructureAddResult> addAll({
    required AppUser by,
    required List<StructureDraft> drafts,
    RecordSource source = RecordSource.manual,
    bool pause = true,
  }) async {
    requireHrd(by, 'change groups and departments');
    if (pause) await apiPause(450);

    final newGroups = <OrgGroup>[];
    final newDepartments = <OrgDepartment>[];
    final allGroups = [...groups.value];
    final allDepartments = [...departments.value];
    final now = DateTime.now();

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
      final groupName = cleanText(draft.groupName);
      if (groupName.isEmpty) continue;
      var group = findGroup(groupName);
      if (group == null) {
        if (groupName.length > StructureRules.nameMax) continue;
        var code = draft.groupCode.trim().toUpperCase();
        if (code.isEmpty || !StructureRules.isValidCode(code) || findGroup(code) != null) {
          code = _uniqueCode(StructureRules.suggestCode(groupName), allGroups.map((g) => g.code));
        }
        group = OrgGroup(
          id: nextId('GRP-', allGroups.map((g) => g.id), width: 2),
          name: groupName,
          code: code,
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

    if (newGroups.isNotEmpty) {
      _addedThisSession.addAll(newGroups.map((g) => g.id));
      groups.value = List<OrgGroup>.unmodifiable(allGroups);
    }
    if (newDepartments.isNotEmpty) {
      _addedThisSession.addAll(newDepartments.map((d) => d.id));
      departments.value = List<OrgDepartment>.unmodifiable(allDepartments);
    }
    return StructureAddResult(groups: newGroups, departments: newDepartments);
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

  /// Moves a department (and everyone in it) to another group. One profile
  /// change is logged per employee so their history shows the new group.
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

    departments.value = List<OrgDepartment>.unmodifiable([
      for (final d in departments.value) d.id == departmentId ? d.copyWith(groupId: toGroupId) : d,
    ]);
    return EmployeeRepository.instance.logDepartmentGroupMove(
      by: by,
      department: department,
      fromGroup: from?.name ?? '—',
      toGroup: to.name,
      reason: reason,
      effectiveDate: effectiveDate,
      note: note,
    );
  }

  /// Makes [employeeId] the head of [departmentId] (HRD only).
  void setHead({required AppUser by, required String departmentId, String? employeeId}) {
    requireHrd(by, 'change department heads');
    departments.value = List<OrgDepartment>.unmodifiable([
      for (final d in departments.value) d.id == departmentId ? d.copyWith(headId: employeeId) : d,
    ]);
  }
}
