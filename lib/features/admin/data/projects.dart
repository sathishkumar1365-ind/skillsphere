// Projects employees are onboarded to, with the competencies each project
// needs (optionally per role) and its team members.
//
// HRD adds projects one by one or in bulk (Excel/CSV). More project fields
// will follow; the model keeps them in one place.
//
// Spring Boot API later:
//   GET  /api/projects                 GET /api/projects/{id}
//   POST /api/projects (SUPER_ADMIN)   POST /api/projects/bulk (SUPER_ADMIN)
//   PUT  /api/projects/{id} (SUPER_ADMIN)
//   PUT  /api/employees/{id}/projects (SUPER_ADMIN, or ADMIN for own department)

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/data/competency_repository.dart';
import 'admin_base.dart';
import 'admin_sample_data.dart';
import 'employees.dart';

enum ProjectStatus {
  planned('Planned'),
  active('Active'),
  onHold('On hold'),
  completed('Completed');

  const ProjectStatus(this.label);
  final String label;

  static ProjectStatus? tryParse(String value) {
    final key = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (key.isEmpty) return null;
    for (final s in ProjectStatus.values) {
      if (key == s.label.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') || key == s.name.toLowerCase()) {
        return s;
      }
    }
    if (key == 'ongoing' || key == 'inprogress') return ProjectStatus.active;
    if (key == 'closed' || key == 'done') return ProjectStatus.completed;
    return null;
  }
}

/// One competency a project needs, at least at [level]. [roleId] limits it
/// to people in that role; null means everyone on the project.
class ProjectRequirement {
  const ProjectRequirement(this.competencyId, this.level, {this.roleId});

  final String competencyId;
  final int level;
  final String? roleId;

  bool appliesTo(String? employeeRoleId) => roleId == null || roleId == employeeRoleId;
}

class ProjectRecord {
  const ProjectRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.departmentId,
    required this.startDate,
    required this.status,
    required this.createdAt,
    this.customer = '',
    this.managerId,
    this.endDate,
    this.description = '',
    this.plannedTeamSize = 0,
    this.requirements = const [],
    this.memberIds = const [],
    this.source = RecordSource.existing,
  });

  /// Internal id, e.g. "PRJ-004".
  final String id;

  /// Code people use, unique, e.g. "PAY-MIG".
  final String code;
  final String name;

  /// Customer / programme, e.g. "Hyundai Motor Company".
  final String customer;
  final String departmentId;
  final String? managerId;
  final DateTime startDate;
  final DateTime? endDate;
  final ProjectStatus status;
  final String description;

  /// How many people the project needs in total.
  final int plannedTeamSize;
  final List<ProjectRequirement> requirements;
  final List<String> memberIds;
  final DateTime createdAt;
  final RecordSource source;

  String get key => nameKey(name);

  /// "Since Aug 2026", "Starts Jan 2027", "Ended Oct 2026", "On hold".
  String get period {
    final now = DateTime.now();
    if (status == ProjectStatus.completed) {
      return endDate == null ? 'Completed' : 'Ended ${monthYear(endDate!)}';
    }
    if (status == ProjectStatus.onHold) return 'On hold';
    if (startDate.isAfter(now)) return 'Starts ${monthYear(startDate)}';
    return 'Since ${monthYear(startDate)}';
  }

  /// "Aug 2026 – Mar 2027"
  String get dateRange =>
      '${monthYear(startDate)} – ${endDate == null ? 'open' : monthYear(endDate!)}';

  List<ProjectRequirement> requirementsFor(String? roleId) =>
      requirements.where((r) => r.appliesTo(roleId)).toList();

  ProjectRecord copyWith({
    String? code,
    String? name,
    String? customer,
    String? departmentId,
    Object? managerId = _keep,
    DateTime? startDate,
    Object? endDate = _keep,
    ProjectStatus? status,
    String? description,
    int? plannedTeamSize,
    List<ProjectRequirement>? requirements,
    List<String>? memberIds,
  }) =>
      ProjectRecord(
        id: id,
        code: code ?? this.code,
        name: name ?? this.name,
        customer: customer ?? this.customer,
        departmentId: departmentId ?? this.departmentId,
        managerId: identical(managerId, _keep) ? this.managerId : managerId as String?,
        startDate: startDate ?? this.startDate,
        endDate: identical(endDate, _keep) ? this.endDate : endDate as DateTime?,
        status: status ?? this.status,
        description: description ?? this.description,
        plannedTeamSize: plannedTeamSize ?? this.plannedTeamSize,
        requirements: requirements ?? this.requirements,
        memberIds: memberIds ?? this.memberIds,
        createdAt: createdAt,
        source: source,
      );

  static const Object _keep = Object();

  String get searchText => '$code $name $customer $description'.toLowerCase();
}

/// A project that hasn't been saved yet (form or file row).
class ProjectDraft {
  const ProjectDraft({
    required this.code,
    required this.name,
    required this.departmentId,
    required this.startDate,
    required this.status,
    this.customer = '',
    this.managerId,
    this.endDate,
    this.description = '',
    this.plannedTeamSize = 0,
    this.requirements = const [],
    this.memberIds = const [],
  });

  final String code;
  final String name;
  final String departmentId;
  final DateTime startDate;
  final ProjectStatus status;
  final String customer;
  final String? managerId;
  final DateTime? endDate;
  final String description;
  final int plannedTeamSize;
  final List<ProjectRequirement> requirements;
  final List<String> memberIds;
}

class ProjectRules {
  ProjectRules._();

  static const int codeMax = 20;
  static const int nameMax = 80;
  static const int customerMax = 80;
  static const int descriptionMax = 400;
  static const int teamMax = 500;

  /// "PAY-MIG", "THR_2026", "P1042".
  static bool isValidCode(String code) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9_\-]{0,19}$').hasMatch(code);
}

class ProjectRepository {
  ProjectRepository._();

  static final ProjectRepository instance = ProjectRepository._();

  final ValueNotifier<List<ProjectRecord>> projects =
      ValueNotifier<List<ProjectRecord>>(List<ProjectRecord>.unmodifiable(sampleProjects));

  final Set<String> _addedThisSession = <String>{};

  bool isNew(String id) => _addedThisSession.contains(id);

  ProjectRecord? byId(String? id) {
    if (id == null) return null;
    for (final p in projects.value) {
      if (p.id == id) return p;
    }
    return null;
  }

  ProjectRecord? byCode(String code) {
    final key = nameKey(code);
    if (key.isEmpty) return null;
    for (final p in projects.value) {
      if (nameKey(p.code) == key) return p;
    }
    return null;
  }

  ProjectRecord? byName(String name) {
    final key = nameKey(name);
    if (key.isEmpty) return null;
    for (final p in projects.value) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// Projects [employeeId] works on (not completed), newest first.
  List<ProjectRecord> forEmployee(String employeeId, {bool includeCompleted = false}) =>
      projects.value
          .where((p) =>
              p.memberIds.contains(employeeId) &&
              (includeCompleted || p.status != ProjectStatus.completed))
          .toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

  /// The first rule [draft] breaks, or null. [exceptId] skips that project
  /// in the duplicate checks (editing).
  String? problemWith(ProjectDraft draft, {String? exceptId}) {
    final code = draft.code.trim();
    final name = cleanText(draft.name);
    if (code.isEmpty) return 'Enter the project code.';
    if (!ProjectRules.isValidCode(code)) {
      return 'The code can have up to ${ProjectRules.codeMax} letters, digits, - or _.';
    }
    if (name.isEmpty) return 'Enter the project name.';
    if (name.length > ProjectRules.nameMax) return 'Keep the name under ${ProjectRules.nameMax} characters.';
    if (draft.customer.trim().length > ProjectRules.customerMax) {
      return 'Keep the customer under ${ProjectRules.customerMax} characters.';
    }
    if (draft.description.trim().length > ProjectRules.descriptionMax) {
      return 'Keep the description under ${ProjectRules.descriptionMax} characters.';
    }
    final end = draft.endDate;
    if (end != null && end.isBefore(draft.startDate)) return 'The end date is before the start date.';
    if (draft.plannedTeamSize < 0 || draft.plannedTeamSize > ProjectRules.teamMax) {
      return 'The planned team size must be between 0 and ${ProjectRules.teamMax}.';
    }
    final sameCode = byCode(code);
    if (sameCode != null && sameCode.id != exceptId) return 'The code $code is used by "${sameCode.name}".';
    final sameName = byName(name);
    if (sameName != null && sameName.id != exceptId) return '"${sameName.name}" already exists (${sameName.code}).';
    final seen = <String>{};
    for (final r in draft.requirements) {
      if (CompetencyRepository.instance.byId(r.competencyId) == null) {
        return 'A required competency is no longer in the library.';
      }
      if (!seen.add('${r.competencyId}|${r.roleId ?? '*'}')) {
        return 'A competency is listed twice for the same role.';
      }
    }
    return null;
  }

  Future<ProjectRecord> add({required AppUser by, required ProjectDraft draft}) async {
    requireHrd(by, 'add projects');
    final problem = problemWith(draft);
    if (problem != null) throw AdminException(problem);
    final added = await addAll(by: by, drafts: [draft]);
    if (added.isEmpty) throw const AdminException('This project could not be added.');
    return added.first;
  }

  /// Adds the valid, new projects among [drafts] and returns them.
  Future<List<ProjectRecord>> addAll({
    required AppUser by,
    required List<ProjectDraft> drafts,
    RecordSource source = RecordSource.manual,
  }) async {
    requireHrd(by, 'add projects');
    await apiPause(450);
    final added = <ProjectRecord>[];
    final all = [...projects.value];
    for (final draft in drafts) {
      if (problemWith(draft) != null) continue;
      final codeKey = nameKey(draft.code);
      final key = nameKey(draft.name);
      if (all.any((p) => nameKey(p.code) == codeKey || p.key == key)) continue;
      final project = ProjectRecord(
        id: nextId('PRJ-', all.map((p) => p.id)),
        code: draft.code.trim().toUpperCase(),
        name: cleanText(draft.name),
        customer: cleanText(draft.customer),
        departmentId: draft.departmentId,
        managerId: draft.managerId,
        startDate: dateOnly(draft.startDate),
        endDate: draft.endDate == null ? null : dateOnly(draft.endDate!),
        status: draft.status,
        description: draft.description.trim(),
        plannedTeamSize: draft.plannedTeamSize,
        requirements: List<ProjectRequirement>.unmodifiable(draft.requirements),
        memberIds: List<String>.unmodifiable(draft.memberIds.toSet()),
        createdAt: DateTime.now(),
        source: source,
      );
      all.add(project);
      added.add(project);
    }
    if (added.isNotEmpty) {
      _addedThisSession.addAll(added.map((p) => p.id));
      projects.value = List<ProjectRecord>.unmodifiable(all);
    }
    return added;
  }

  Future<ProjectRecord> update({
    required AppUser by,
    required String projectId,
    required ProjectDraft draft,
  }) async {
    requireHrd(by, 'change projects');
    final existing = byId(projectId);
    if (existing == null) throw const AdminException('This project no longer exists.');
    final problem = problemWith(draft, exceptId: projectId);
    if (problem != null) throw AdminException(problem);
    await apiPause(400);
    final updated = existing.copyWith(
      code: draft.code.trim().toUpperCase(),
      name: cleanText(draft.name),
      customer: cleanText(draft.customer),
      departmentId: draft.departmentId,
      managerId: draft.managerId,
      startDate: dateOnly(draft.startDate),
      endDate: draft.endDate == null ? null : dateOnly(draft.endDate!),
      status: draft.status,
      description: draft.description.trim(),
      plannedTeamSize: draft.plannedTeamSize,
      requirements: List<ProjectRequirement>.unmodifiable(draft.requirements),
      memberIds: List<String>.unmodifiable(draft.memberIds.toSet()),
    );
    projects.value = List<ProjectRecord>.unmodifiable([
      for (final p in projects.value) p.id == projectId ? updated : p,
    ]);
    return updated;
  }

  /// Puts [employeeId] on exactly [projectIds] (adds and removes them from
  /// team lists). HRD for anyone; a Team Lead for their own department.
  void setEmployeeProjects({
    required AppUser by,
    required String employeeId,
    required Set<String> projectIds,
  }) {
    final employee = EmployeeRepository.instance.byId(employeeId);
    if (employee == null) throw const AdminException('This employee no longer exists.');
    if (!EmployeeRepository.instance.canEdit(by, employee)) {
      throw const AdminException('You can only change projects for your own department.');
    }
    var changed = false;
    final next = <ProjectRecord>[];
    for (final p in projects.value) {
      final isMember = p.memberIds.contains(employeeId);
      final shouldBe = projectIds.contains(p.id);
      if (isMember == shouldBe) {
        next.add(p);
        continue;
      }
      changed = true;
      next.add(p.copyWith(
        memberIds: List<String>.unmodifiable(shouldBe
            ? [...p.memberIds, employeeId]
            : p.memberIds.where((id) => id != employeeId)),
      ));
    }
    if (changed) projects.value = List<ProjectRecord>.unmodifiable(next);
  }

  /// Competency → highest level any project needs (for the dashboard).
  Map<Competency, int> get demand {
    final result = <Competency, int>{};
    for (final p in projects.value) {
      if (p.status == ProjectStatus.completed) continue;
      for (final r in p.requirements) {
        final c = CompetencyRepository.instance.byId(r.competencyId);
        if (c == null) continue;
        final current = result[c];
        if (current == null || r.level > current) result[c] = r.level;
      }
    }
    return result;
  }
}
