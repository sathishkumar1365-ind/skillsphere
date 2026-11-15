// Employee profiles (onboarding, update profile) and the log of profile
// changes (re-orgs, transfers, promotions).
//
// Who can do what (the Spring Boot API must enforce the same rules):
// * HRD (Super Admin): everything, for every employee.
// * Team Lead (Admin): view and update profiles of their OWN department,
//   except division, group, department and status; not their own profile. Skill level
//   changes they make become level-up requests for HR approval.
// * Employee (End User): view their own profile.
//
// Spring Boot API later:
//   GET  /api/employees?divisionId=&groupId=&departmentId=&status=&q=   (SUPER_ADMIN; ADMIN gets own dept)
//   GET  /api/employees/{id}                                (rules above)
//   POST /api/employees (SUPER_ADMIN)    POST /api/employees/bulk (SUPER_ADMIN)
//   PUT  /api/employees/{id}             (rules above; logs profile changes)
//   POST /api/employees/moves            (SUPER_ADMIN, re-org of many employees)
//   GET  /api/employees/changes?from=&to=&field=&departmentId=  (SUPER_ADMIN)
//   POST /api/employees/{id}/certificates (multipart upload)

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import '../../additional_competency/data/additional_competency_repository.dart';
import '../../competency/data/competency_repository.dart';
import '../../competency/data/level_progress.dart';
import 'admin_base.dart';
import 'admin_sample_data.dart';
import 'job_roles.dart';
import 'org_structure.dart';

enum Gender {
  male('Male'),
  female('Female'),
  other('Other'),
  undisclosed('Prefer not to say');

  const Gender(this.label);
  final String label;

  static Gender? tryParse(String value) {
    final key = value.trim().toLowerCase();
    if (key.isEmpty) return null;
    if (key == 'm' || key == 'male' || key == 'man') return Gender.male;
    if (key == 'f' || key == 'female' || key == 'woman') return Gender.female;
    if (key == 'o' || key == 'other' || key == 'non-binary' || key == 'nonbinary') return Gender.other;
    if (key.startsWith('prefer') || key == 'na' || key == 'n/a' || key == 'undisclosed') {
      return Gender.undisclosed;
    }
    return null;
  }
}

enum EmploymentStatus {
  active('Active'),
  inactive('Inactive');

  const EmploymentStatus(this.label);
  final String label;

  static EmploymentStatus? tryParse(String value) => switch (value.trim().toLowerCase()) {
        'active' || 'a' || 'yes' || 'y' || 'true' || '1' => EmploymentStatus.active,
        'inactive' || 'i' || 'no' || 'n' || 'false' || '0' || 'disabled' => EmploymentStatus.inactive,
        _ => null,
      };
}

class EmployeeLocation {
  const EmployeeLocation({this.country = '', this.state = '', this.city = ''});

  final String country;
  final String state;
  final String city;

  bool get isEmpty => country.isEmpty;

  /// "Hyderabad, Telangana, India"
  String get label {
    final parts = [city, state, country].where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  /// "Hyderabad, India"
  String get short {
    final parts = [city.isNotEmpty ? city : state, country].where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? '—' : parts.join(', ');
  }
}

/// A certificate or proof file attached to a profile. On this temporary
/// build the bytes stay in the browser's memory; later they are uploaded to
/// the server and only the file details are kept here.
class CertificateFile {
  const CertificateFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.addedAt,
    this.bytes,
    this.mimeType,
  });

  /// e.g. "CRT-0004".
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime addedAt;

  /// File content (null for sample data / files stored on the server).
  final Uint8List? bytes;
  final String? mimeType;

  /// "pdf", "png", "docx"… (empty when the name has no extension).
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 || dot == name.length - 1 ? '' : name.substring(dot + 1).toLowerCase();
  }

  String get sizeLabel => fileSizeLabel(sizeBytes);

  bool get canDownload => bytes != null;
}

class EmployeeProfile {
  const EmployeeProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.gender,
    required this.status,
    required this.departmentId,
    required this.designation,
    required this.onboardedAt,
    this.roleId,
    this.managerId,
    this.managerName,
    this.location = const EmployeeLocation(),
    this.intro = '',
    this.certificates = const [],
    this.onLeave = false,
    this.baselineReadiness,
    this.crowdUsername,
    this.source = RecordSource.existing,
  });

  /// e.g. "EMP-1002" (fixed once onboarded).
  final String id;
  final String name;
  final String email;
  final Gender gender;
  final EmploymentStatus status;
  final String departmentId;

  /// Job title, e.g. "Senior Software Engineer".
  final String designation;

  /// Project role (see RoleRepository). Null until HRD sets it (e.g. after a
  /// Crowd sync, which doesn't know roles).
  final String? roleId;

  /// Reporting manager inside SkillSphere…
  final String? managerId;

  /// …or a manager outside it (e.g. "Delivery Head") when [managerId] is null.
  final String? managerName;
  final EmployeeLocation location;

  /// Short introduction shown on the profile.
  final String intro;
  final List<CertificateFile> certificates;
  final bool onLeave;

  /// Readiness from the old system, shown while the employee has no project.
  final int? baselineReadiness;

  /// Crowd user name when the profile came from (or is linked to) Crowd.
  final String? crowdUsername;
  final DateTime onboardedAt;
  final RecordSource source;

  bool get isActive => status == EmploymentStatus.active;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  /// Fields HRD still has to fill in (e.g. after a Crowd sync).
  List<String> get missingFields => [
        if (roleId == null) 'Role',
        if (designation.trim().isEmpty) 'Designation',
        if (location.isEmpty) 'Location',
        if (managerId == null && (managerName ?? '').isEmpty) 'Reporting manager',
      ];

  bool get isComplete => missingFields.isEmpty;

  EmployeeProfile copyWith({
    String? name,
    String? email,
    Gender? gender,
    EmploymentStatus? status,
    String? departmentId,
    String? designation,
    Object? roleId = _keep,
    Object? managerId = _keep,
    Object? managerName = _keep,
    EmployeeLocation? location,
    String? intro,
    List<CertificateFile>? certificates,
    bool? onLeave,
    Object? crowdUsername = _keep,
  }) =>
      EmployeeProfile(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        gender: gender ?? this.gender,
        status: status ?? this.status,
        departmentId: departmentId ?? this.departmentId,
        designation: designation ?? this.designation,
        onboardedAt: onboardedAt,
        roleId: identical(roleId, _keep) ? this.roleId : roleId as String?,
        managerId: identical(managerId, _keep) ? this.managerId : managerId as String?,
        managerName: identical(managerName, _keep) ? this.managerName : managerName as String?,
        location: location ?? this.location,
        intro: intro ?? this.intro,
        certificates: certificates ?? this.certificates,
        onLeave: onLeave ?? this.onLeave,
        baselineReadiness: baselineReadiness,
        crowdUsername: identical(crowdUsername, _keep) ? this.crowdUsername : crowdUsername as String?,
        source: source,
      );

  static const Object _keep = Object();
}

/// One competency level entered for a new employee.
class AcquiredLevel {
  const AcquiredLevel(this.competencyId, this.level);

  final String competencyId;
  final int level;
}

/// What the onboarding form, a file row or a Crowd user produces.
class EmployeeDraft {
  const EmployeeDraft({
    required this.id,
    required this.name,
    required this.email,
    required this.gender,
    required this.status,
    required this.departmentId,
    required this.designation,
    this.roleId,
    this.managerId,
    this.managerName,
    this.location = const EmployeeLocation(),
    this.intro = '',
    this.certificates = const [],
    this.acquired = const [],
    this.additional = const [],
    this.crowdUsername,
  });

  final String id;
  final String name;
  final String email;
  final Gender gender;
  final EmploymentStatus status;
  final String departmentId;
  final String designation;
  final String? roleId;
  final String? managerId;
  final String? managerName;
  final EmployeeLocation location;
  final String intro;
  final List<CertificateFile> certificates;
  final List<AcquiredLevel> acquired;

  /// Additional (self-declared) competency names, optional.
  final List<String> additional;
  final String? crowdUsername;
}

class EmployeeRules {
  EmployeeRules._();

  static const int idMax = 20;
  static const int nameMax = 80;
  static const int designationMax = 60;
  static const int introMax = 500;
  static const int maxCertificates = 10;
  static const int maxCertificateBytes = 10 * 1024 * 1024;

  /// "EMP-1037", "100245", "HMI/2026/07".
  static bool isValidId(String id) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9_\-/]{1,19}$').hasMatch(id);
}

// --------------------------------------------------------------- changes

enum ChangeField {
  division('Division'),
  group('Group'),
  department('Department'),
  manager('Reporting manager'),
  designation('Designation'),
  role('Role'),
  status('Status');

  const ChangeField(this.label);
  final String label;

  /// Division, group and department moves – what re-orgs are tracked by.
  bool get isPlacement =>
      this == ChangeField.division || this == ChangeField.group || this == ChangeField.department;
}

enum ChangeReason {
  reorg('Re-org'),
  transfer('Transfer'),
  promotion('Promotion'),
  correction('Correction'),
  crowdSync('Crowd sync'),
  other('Other');

  const ChangeReason(this.label);
  final String label;

  /// Reasons HRD can pick in forms (Crowd sync is set by the system).
  static const List<ChangeReason> selectable = [
    ChangeReason.reorg,
    ChangeReason.transfer,
    ChangeReason.promotion,
    ChangeReason.correction,
    ChangeReason.other,
  ];
}

/// One logged change of one field of one employee.
class ProfileChange {
  const ProfileChange({
    required this.id,
    required this.employeeId,
    required this.field,
    required this.from,
    required this.to,
    required this.reason,
    required this.effectiveDate,
    required this.changedBy,
    required this.changedAt,
    this.note = '',
    this.batchLabel,
  });

  /// e.g. "CHG-0012".
  final String id;
  final String employeeId;
  final ChangeField field;

  /// Display values ("Engineering" → "Quality Assurance").
  final String from;
  final String to;
  final ChangeReason reason;
  final String note;
  final DateTime effectiveDate;
  final String changedBy;
  final DateTime changedAt;

  /// Set when the change was part of a bigger move, e.g.
  /// "DevOps & Cloud moved to Data & Cloud Platforms".
  final String? batchLabel;
}

// ------------------------------------------------------------ repository

class EmployeeRepository {
  EmployeeRepository._();

  static final EmployeeRepository instance = EmployeeRepository._();

  final ValueNotifier<List<EmployeeProfile>> employees =
      ValueNotifier<List<EmployeeProfile>>(List<EmployeeProfile>.unmodifiable(sampleEmployeeProfiles()));

  /// Newest first.
  final ValueNotifier<List<ProfileChange>> changes =
      ValueNotifier<List<ProfileChange>>(List<ProfileChange>.unmodifiable(sampleProfileChanges()));

  final Set<String> _addedThisSession = <String>{};

  bool isNew(String id) => _addedThisSession.contains(id);

  OrgStructureRepository get _structure => OrgStructureRepository.instance;

  EmployeeProfile? byId(String? id) {
    if (id == null) return null;
    final key = id.trim().toLowerCase();
    for (final e in employees.value) {
      if (e.id.toLowerCase() == key) return e;
    }
    return null;
  }

  EmployeeProfile? byEmail(String email) {
    final key = email.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final e in employees.value) {
      if (e.email.toLowerCase() == key) return e;
    }
    return null;
  }

  /// By employee ID, email or exact name.
  EmployeeProfile? find(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    final byKey = byId(value) ?? byEmail(value);
    if (byKey != null) return byKey;
    final key = nameKey(value);
    for (final e in employees.value) {
      if (nameKey(e.name) == key) return e;
    }
    return null;
  }

  String nameOf(String id) => byId(id)?.name ?? id;

  List<EmployeeProfile> get active => employees.value.where((e) => e.isActive).toList();

  List<EmployeeProfile> inDepartment(String departmentId, {bool activeOnly = true}) => employees.value
      .where((e) => e.departmentId == departmentId && (!activeOnly || e.isActive))
      .toList();

  String departmentNameOf(EmployeeProfile e) => _structure.departmentName(e.departmentId);

  String groupNameOf(EmployeeProfile e) => _structure.groupNameOfDepartment(e.departmentId);

  String divisionNameOf(EmployeeProfile e) => _structure.divisionNameOfDepartment(e.departmentId);

  /// "Research & Development › Software Development › Engineering"
  String placementOf(EmployeeProfile e) =>
      '${divisionNameOf(e)} › ${groupNameOf(e)} › ${departmentNameOf(e)}';

  /// "Priya Raman", or the outside manager's name, or "—".
  String managerLabel(EmployeeProfile e) {
    final id = e.managerId;
    if (id != null) return byId(id)?.name ?? id;
    final name = e.managerName ?? '';
    return name.isEmpty ? '—' : name;
  }

  List<String> get designations {
    final seen = <String>{};
    final list = <String>[];
    for (final e in employees.value) {
      final d = e.designation.trim();
      if (d.isNotEmpty && seen.add(nameKey(d))) list.add(d);
    }
    return list..sort();
  }

  /// Next free "EMP-nnnn" number.
  String suggestNextId() {
    var highest = 1000;
    for (final e in employees.value) {
      final m = RegExp(r'^EMP-(\d+)$', caseSensitive: false).firstMatch(e.id);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        if (n > highest) highest = n;
      }
    }
    return 'EMP-${highest + 1}';
  }

  /// Profile changes of one employee, newest first.
  List<ProfileChange> changesFor(String employeeId) =>
      changes.value.where((c) => c.employeeId == employeeId).toList()
        ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));

  // ------------------------------------------------------- permissions

  /// HRD: everyone. Team Lead: own department and themselves.
  /// Employee: themselves.
  bool canView(AppUser user, EmployeeProfile e) {
    if (user.role.canManageOrganization || e.id == user.id) return true;
    return user.role.canEditTeamProfiles && departmentNameOf(e) == user.department;
  }

  /// HRD: everyone. Team Lead: own department, not themselves.
  bool canEdit(AppUser user, EmployeeProfile e) {
    if (user.role.canManageOrganization) return true;
    return user.role.canEditTeamProfiles && e.id != user.id && departmentNameOf(e) == user.department;
  }

  /// Division, group, department and status: HRD only.
  bool canChangePlacement(AppUser user) => user.role.canManageOrganization;

  /// Team Leads ask HR to raise levels; HRD sets them directly.
  bool canRequestLevelUp(AppUser user, EmployeeProfile e) =>
      user.role.canEditTeamProfiles && canEdit(user, e);

  // -------------------------------------------------------- validation

  String? idProblem(String id) {
    final value = id.trim();
    if (value.isEmpty) return 'Enter the employee ID.';
    if (!EmployeeRules.isValidId(value)) {
      return 'Use 2–${EmployeeRules.idMax} letters, digits, - _ or /, e.g. EMP-1037.';
    }
    final taken = byId(value);
    if (taken != null) return '${taken.id} belongs to ${taken.name}.';
    return null;
  }

  String? emailProblem(String email, {String? exceptId}) {
    final value = email.trim();
    if (value.isEmpty) return 'Enter the work email.';
    if (!isValidEmail(value)) return 'Enter a valid email, e.g. name@mobis.co.in.';
    final taken = byEmail(value);
    if (taken != null && taken.id != exceptId) return 'This email is used by ${taken.name} (${taken.id}).';
    return null;
  }

  /// The first problem with [d] (field rules, unknown references), or null.
  /// [isNew] also checks that the ID is free.
  String? problemWith(EmployeeDraft d, {bool isNew = true, String? exceptId}) {
    if (isNew) {
      final idIssue = idProblem(d.id);
      if (idIssue != null) return idIssue;
    }
    final name = cleanText(d.name);
    if (name.isEmpty) return 'Enter the employee name.';
    if (name.length > EmployeeRules.nameMax) return 'Keep the name under ${EmployeeRules.nameMax} characters.';
    final emailIssue = emailProblem(d.email, exceptId: exceptId);
    if (emailIssue != null) return emailIssue;
    if (_structure.departmentById(d.departmentId) == null) return 'Choose the division, group and department.';
    if (d.designation.trim().isEmpty) return 'Enter the designation.';
    if (d.designation.trim().length > EmployeeRules.designationMax) {
      return 'Keep the designation under ${EmployeeRules.designationMax} characters.';
    }
    if (d.roleId != null && RoleRepository.instance.byId(d.roleId) == null) return 'Choose a role.';
    if (d.managerId != null) {
      if (byId(d.managerId) == null) return 'The reporting manager is not an employee.';
      if (d.managerId == (exceptId ?? d.id)) return 'An employee can\'t report to themselves.';
    }
    if (d.intro.trim().length > EmployeeRules.introMax) {
      return 'Keep the intro under ${EmployeeRules.introMax} characters.';
    }
    if (d.certificates.length > EmployeeRules.maxCertificates) {
      return 'Attach up to ${EmployeeRules.maxCertificates} files.';
    }
    return null;
  }

  // ---------------------------------------------------------- onboarding

  /// Onboards one employee (HRD only): creates the profile, sets the
  /// acquired competency levels and adds the additional competencies.
  Future<EmployeeProfile> onboard({required AppUser by, required EmployeeDraft draft}) async {
    requireHrd(by, 'onboard employees');
    final problem = problemWith(draft);
    if (problem != null) throw AdminException(problem);
    await apiPause(550);
    final added = _addProfiles(by: by, drafts: [draft], source: RecordSource.manual);
    if (added.isEmpty) throw const AdminException('This employee could not be onboarded.');
    return added.first;
  }

  /// Onboards many employees (bulk import or Crowd sync). Drafts with a
  /// problem or a taken ID/email are skipped. Returns those added.
  ///
  /// Managers may be other drafts in the same batch, so all profiles are
  /// added before references are checked.
  Future<List<EmployeeProfile>> onboardAll({
    required AppUser by,
    required List<EmployeeDraft> drafts,
    RecordSource source = RecordSource.bulkImport,
  }) async {
    requireHrd(by, 'onboard employees');
    await apiPause(700);
    return _addProfiles(by: by, drafts: drafts, source: source);
  }

  List<EmployeeProfile> _addProfiles({
    required AppUser by,
    required List<EmployeeDraft> drafts,
    required RecordSource source,
  }) {
    final batchIds = {for (final d in drafts) d.id.trim().toLowerCase()};
    final added = <EmployeeProfile>[];
    final takenIds = {for (final e in employees.value) e.id.toLowerCase()};
    final takenEmails = {for (final e in employees.value) e.email.toLowerCase()};
    final now = DateTime.now();

    for (final d in drafts) {
      final id = d.id.trim();
      final email = d.email.trim();
      if (!EmployeeRules.isValidId(id) ||
          takenIds.contains(id.toLowerCase()) ||
          takenEmails.contains(email.toLowerCase()) ||
          !isValidEmail(email) ||
          cleanText(d.name).isEmpty ||
          _structure.departmentById(d.departmentId) == null) {
        continue;
      }
      // A manager in the same batch is fine; otherwise it must exist.
      final managerId = d.managerId?.trim();
      final managerOk = managerId == null ||
          byId(managerId) != null ||
          (batchIds.contains(managerId.toLowerCase()) && managerId.toLowerCase() != id.toLowerCase());
      takenIds.add(id.toLowerCase());
      takenEmails.add(email.toLowerCase());
      added.add(EmployeeProfile(
        id: id,
        name: cleanText(d.name),
        email: email,
        gender: d.gender,
        status: d.status,
        departmentId: d.departmentId,
        designation: cleanText(d.designation),
        roleId: RoleRepository.instance.byId(d.roleId)?.id,
        managerId: managerOk ? managerId : null,
        managerName: managerOk ? d.managerName : null,
        location: d.location,
        intro: d.intro.trim(),
        certificates: List<CertificateFile>.unmodifiable(d.certificates),
        crowdUsername: d.crowdUsername,
        onboardedAt: now,
        source: source,
      ));
    }
    if (added.isEmpty) return const [];

    _addedThisSession.addAll(added.map((e) => e.id));
    employees.value = List<EmployeeProfile>.unmodifiable([...employees.value, ...added]);

    // Competency levels and additional competencies live in their own
    // repositories (single source of truth for the library and HRD search).
    final addedIds = {for (final e in added) e.id};
    for (final d in drafts) {
      if (!addedIds.contains(d.id.trim())) continue;
      if (d.acquired.isNotEmpty) {
        CompetencyRepository.instance.setLevels(
          by: by,
          employeeId: d.id.trim(),
          levels: {for (final a in d.acquired) a.competencyId: a.level},
          source: LevelChangeSource.onboarding,
        );
      }
      if (d.additional.isNotEmpty) {
        AdditionalCompetencyRepository.instance
            .addForEmployee(by: by, employeeId: d.id.trim(), names: d.additional);
      }
    }
    return added;
  }

  // ------------------------------------------------------------- update

  /// Saves an updated profile and logs what changed in division, group,
  /// department, manager, designation, role and status.
  Future<EmployeeProfile> update({
    required AppUser by,
    required String employeeId,
    required EmployeeDraft draft,
    ChangeReason reason = ChangeReason.correction,
    DateTime? effectiveDate,
    String note = '',
  }) async {
    final current = byId(employeeId);
    if (current == null) throw const AdminException('This employee no longer exists.');
    if (!canEdit(by, current)) {
      throw const AdminException('You can only update profiles in your own department.');
    }
    if (!canChangePlacement(by) &&
        (draft.departmentId != current.departmentId || draft.status != current.status)) {
      throw const AdminException('Only the HRD team can change division, group, department or status.');
    }
    final problem = problemWith(draft, isNew: false, exceptId: employeeId);
    if (problem != null) throw AdminException(problem);
    await apiPause(450);

    final updated = current.copyWith(
      name: cleanText(draft.name),
      email: draft.email.trim(),
      gender: draft.gender,
      status: draft.status,
      departmentId: draft.departmentId,
      designation: cleanText(draft.designation),
      roleId: draft.roleId,
      managerId: draft.managerId,
      managerName: draft.managerId == null ? draft.managerName : null,
      location: draft.location,
      intro: draft.intro.trim(),
      certificates: List<CertificateFile>.unmodifiable(draft.certificates),
    );
    final logged = _diff(
      before: current,
      after: updated,
      by: by,
      reason: reason,
      effectiveDate: effectiveDate ?? DateTime.now(),
      note: note,
    );
    employees.value = List<EmployeeProfile>.unmodifiable([
      for (final e in employees.value) e.id == employeeId ? updated : e,
    ]);
    if (logged.isNotEmpty) {
      changes.value = List<ProfileChange>.unmodifiable([...logged, ...changes.value]);
    }
    return updated;
  }

  /// Re-org: moves several employees to [toDepartmentId] at once (HRD).
  /// [managerId] = a new reporting manager for all of them (null keeps each
  /// person's current manager). Returns how many were moved.
  Future<int> moveEmployees({
    required AppUser by,
    required List<String> employeeIds,
    required String toDepartmentId,
    String? managerId,
    required ChangeReason reason,
    required DateTime effectiveDate,
    String note = '',
    String? batchLabel,
  }) async {
    requireHrd(by, 'move employees');
    final department = _structure.departmentById(toDepartmentId);
    if (department == null) throw const AdminException('Choose the department to move them to.');
    if (managerId != null && byId(managerId) == null) {
      throw const AdminException('The new reporting manager is not an employee.');
    }
    await apiPause(500);

    final ids = employeeIds.toSet();
    final label = (batchLabel ?? '').trim().isEmpty
        ? 'Moved to ${department.name}'
        : batchLabel!.trim();
    final logged = <ProfileChange>[];
    var moved = 0;
    final next = <EmployeeProfile>[];
    for (final e in employees.value) {
      if (!ids.contains(e.id)) {
        next.add(e);
        continue;
      }
      final newManager = managerId != null && managerId != e.id ? managerId : e.managerId;
      final updated = e.copyWith(
        departmentId: toDepartmentId,
        managerId: newManager,
        managerName: newManager == null ? e.managerName : null,
      );
      final diff = _diff(
        before: e,
        after: updated,
        by: by,
        reason: reason,
        effectiveDate: effectiveDate,
        note: note,
        batchLabel: label,
        startNumber: highestNumber(changes.value.map((c) => c.id)) + logged.length,
      );
      if (diff.isNotEmpty) moved++;
      logged.addAll(diff);
      next.add(updated);
    }
    employees.value = List<EmployeeProfile>.unmodifiable(next);
    if (logged.isNotEmpty) {
      changes.value = List<ProfileChange>.unmodifiable([...logged, ...changes.value]);
    }
    return moved;
  }

  /// Called when a whole department moves to another group, or a group to
  /// another division: logs a [field] change for everyone in
  /// [departmentIds]. Returns the number of employees.
  int logStructureMove({
    required AppUser by,
    required Set<String> departmentIds,
    required ChangeField field,
    required String from,
    required String to,
    required ChangeReason reason,
    required DateTime effectiveDate,
    required String batchLabel,
    String note = '',
  }) {
    final people = employees.value.where((e) => departmentIds.contains(e.departmentId)).toList();
    var number = highestNumber(changes.value.map((c) => c.id));
    final now = DateTime.now();
    final logged = [
      for (final e in people)
        ProfileChange(
          id: 'CHG-${(++number).toString().padLeft(4, '0')}',
          employeeId: e.id,
          field: field,
          from: from,
          to: to,
          reason: reason,
          note: note.trim(),
          effectiveDate: dateOnly(effectiveDate),
          changedBy: by.name,
          changedAt: now,
          batchLabel: batchLabel,
        ),
    ];
    if (logged.isNotEmpty) {
      changes.value = List<ProfileChange>.unmodifiable([...logged, ...changes.value]);
    }
    return logged.length;
  }

  /// Applies name/email changes and deactivations found in Crowd (HRD).
  Future<int> applyCrowdUpdates({
    required AppUser by,
    required Map<String, ({String name, String email})> updates,
    required Set<String> deactivate,
  }) async {
    requireHrd(by, 'synchronise with Crowd');
    await apiPause(400);
    final logged = <ProfileChange>[];
    var count = 0;
    final next = <EmployeeProfile>[];
    for (final e in employees.value) {
      final change = updates[e.id];
      final off = deactivate.contains(e.id) && e.isActive;
      if (change == null && !off) {
        next.add(e);
        continue;
      }
      count++;
      final updated = e.copyWith(
        name: change?.name,
        email: change?.email,
        status: off ? EmploymentStatus.inactive : null,
      );
      logged.addAll(_diff(
        before: e,
        after: updated,
        by: by,
        reason: ChangeReason.crowdSync,
        effectiveDate: DateTime.now(),
        note: 'Synchronised from Crowd',
        startNumber: highestNumber(changes.value.map((c) => c.id)) + logged.length,
      ));
      next.add(updated);
    }
    employees.value = List<EmployeeProfile>.unmodifiable(next);
    if (logged.isNotEmpty) {
      changes.value = List<ProfileChange>.unmodifiable([...logged, ...changes.value]);
    }
    return count;
  }

  List<ProfileChange> _diff({
    required EmployeeProfile before,
    required EmployeeProfile after,
    required AppUser by,
    required ChangeReason reason,
    required DateTime effectiveDate,
    required String note,
    String? batchLabel,
    int? startNumber,
  }) {
    var number = startNumber ?? highestNumber(changes.value.map((c) => c.id));
    final now = DateTime.now();
    final result = <ProfileChange>[];
    void log(ChangeField field, String from, String to) {
      if (from == to) return;
      result.add(ProfileChange(
        id: 'CHG-${(++number).toString().padLeft(4, '0')}',
        employeeId: after.id,
        field: field,
        from: from,
        to: to,
        reason: reason,
        note: note.trim(),
        effectiveDate: dateOnly(effectiveDate),
        changedBy: by.name,
        changedAt: now,
        batchLabel: batchLabel,
      ));
    }

    log(ChangeField.division, _structure.divisionNameOfDepartment(before.departmentId),
        _structure.divisionNameOfDepartment(after.departmentId));
    log(ChangeField.group, _structure.groupNameOfDepartment(before.departmentId),
        _structure.groupNameOfDepartment(after.departmentId));
    log(ChangeField.department, _structure.departmentName(before.departmentId),
        _structure.departmentName(after.departmentId));
    log(ChangeField.manager, managerLabel(before), managerLabel(after));
    log(ChangeField.designation, before.designation, after.designation);
    log(ChangeField.role, RoleRepository.instance.nameOf(before.roleId),
        RoleRepository.instance.nameOf(after.roleId));
    log(ChangeField.status, before.status.label, after.status.label);
    return result;
  }
}
