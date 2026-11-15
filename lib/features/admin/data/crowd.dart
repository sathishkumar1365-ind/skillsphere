// Atlassian Crowd integration: synchronise employees and groups/departments
// from the company's Crowd directory.
//
// HOW IT WILL WORK (Spring Boot):
// The browser never talks to Crowd. Crowd's REST API
// (<crowd>/rest/usermanagement/1/…) is called by the Spring Boot server with
// the Crowd *application* name + password (HTTP Basic), which are stored
// encrypted on the server only. The app only sends settings and asks for
// previews:
//   GET  /api/integrations/crowd                 settings (password never returned)
//   PUT  /api/integrations/crowd                 save settings {password?}
//   POST /api/integrations/crowd/test            test the connection
//   POST /api/integrations/crowd/preview/users   what would change
//   POST /api/integrations/crowd/apply/users     apply the chosen changes
//   POST /api/integrations/crowd/preview/groups  /apply/groups
// The scheduled sync (hourly/daily) runs on the server.
//
// TEMPORARY: [CrowdService] simulates a Crowd directory (sample users and
// groups in admin_sample_data.dart) so the screens can be built and tried.

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import 'admin_base.dart';
import 'admin_sample_data.dart';
import 'employees.dart';
import 'locations.dart';
import 'org_structure.dart';

enum CrowdSchedule {
  manual('Manual only'),
  hourly('Every hour'),
  daily('Every day at 02:00');

  const CrowdSchedule(this.label);
  final String label;
}

class CrowdSettings {
  const CrowdSettings({
    required this.serverUrl,
    required this.applicationName,
    required this.passwordSaved,
    this.userGroup = 'mobis-employees',
    this.employeeIdAttribute = 'employeeNumber',
    this.groupPrefix = 'grp-',
    this.departmentPrefix = 'dept-',
    this.schedule = CrowdSchedule.manual,
    this.deactivateDisabled = true,
  });

  /// e.g. "https://crowd.mobis.co.in/crowd".
  final String serverUrl;

  /// The application configured in Crowd for SkillSphere.
  final String applicationName;

  /// True once a password was saved (it is never sent back to the app).
  final bool passwordSaved;

  /// Only members of this Crowd group are synchronised.
  final String userGroup;

  /// Crowd user attribute holding the employee ID.
  final String employeeIdAttribute;

  /// Crowd groups named "grp-…" become groups, "dept-…" departments.
  final String groupPrefix;
  final String departmentPrefix;
  final CrowdSchedule schedule;

  /// Employees whose Crowd account is disabled become Inactive.
  final bool deactivateDisabled;

  String get restBase {
    final base = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/rest/usermanagement/1';
  }
}

/// A user as Crowd returns it (with the attributes SkillSphere reads).
class CrowdUser {
  const CrowdUser({
    required this.username,
    required this.employeeNumber,
    required this.displayName,
    required this.email,
    required this.active,
    required this.groups,
    this.title = '',
    this.country = '',
    this.city = '',
  });

  final String username;
  final String employeeNumber;
  final String displayName;
  final String email;
  final bool active;

  /// Crowd groups the user is a member of.
  final List<String> groups;

  /// Job title attribute → designation.
  final String title;
  final String country;
  final String city;
}

/// A Crowd group; departments name their parent group.
class CrowdGroup {
  const CrowdGroup({required this.name, this.description = '', this.parent, this.members = 0});

  final String name;
  final String description;

  /// For "dept-…" groups: the "grp-…" group it is nested in.
  final String? parent;
  final int members;
}

enum CrowdChangeKind {
  added('New in Crowd'),
  updated('Changed in Crowd'),
  disabled('Disabled in Crowd');

  const CrowdChangeKind(this.label);
  final String label;
}

/// One thing a user sync would change.
class CrowdUserChange {
  const CrowdUserChange({
    required this.kind,
    required this.user,
    this.employee,
    this.departmentId,
    this.differences = const [],
  });

  final CrowdChangeKind kind;
  final CrowdUser user;

  /// The matching SkillSphere employee (updated / disabled).
  final EmployeeProfile? employee;

  /// Department found from the user's "dept-…" Crowd group (added).
  final String? departmentId;

  /// "Email: old → new" lines (updated).
  final List<String> differences;

  String get key => '${kind.name}:${user.username}';
}

/// One Crowd group a structure sync would add.
class CrowdGroupChange {
  const CrowdGroupChange({
    required this.group,
    required this.isDepartment,
    required this.displayName,
    this.parentDisplayName,
  });

  final CrowdGroup group;
  final bool isDepartment;

  /// "Functional Safety" (from "dept-functional-safety" or its description).
  final String displayName;

  /// For departments: the group it will be placed in.
  final String? parentDisplayName;
}

/// A finished synchronisation, for the history list.
class CrowdSyncRun {
  const CrowdSyncRun({
    required this.at,
    required this.by,
    required this.summary,
    this.usersSync = true,
  });

  final DateTime at;
  final String by;
  final String summary;

  /// false = groups & departments sync.
  final bool usersSync;
}

class CrowdService {
  CrowdService._();

  static final CrowdService instance = CrowdService._();

  /// Null until HRD saves the connection.
  final ValueNotifier<CrowdSettings?> settings = ValueNotifier<CrowdSettings?>(null);
  final ValueNotifier<List<CrowdSyncRun>> history = ValueNotifier<List<CrowdSyncRun>>(const []);

  /// Result of the last successful connection test.
  final ValueNotifier<String?> lastTest = ValueNotifier<String?>(null);

  bool get isConfigured => settings.value != null;

  /// Why these settings can't be used, or null.
  static String? settingsProblem(CrowdSettings s, {required bool hasPassword}) {
    final uri = Uri.tryParse(s.serverUrl.trim());
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) {
      return 'Enter the Crowd server address, e.g. https://crowd.mobis.co.in/crowd';
    }
    if (uri.scheme != 'https') return 'Use an https:// address so the password is never sent in clear text.';
    if (s.applicationName.trim().isEmpty) return 'Enter the application name configured in Crowd.';
    if (!hasPassword) return 'Enter the application password.';
    if (s.userGroup.trim().isEmpty) return 'Enter the Crowd group whose members are employees.';
    if (s.employeeIdAttribute.trim().isEmpty) return 'Enter the attribute that holds the employee ID.';
    return null;
  }

  Future<void> save({
    required AppUser by,
    required CrowdSettings draft,
    String password = '',
  }) async {
    requireHrd(by, 'connect Crowd');
    final hasPassword = password.isNotEmpty || (settings.value?.passwordSaved ?? false);
    final problem = settingsProblem(draft, hasPassword: hasPassword);
    if (problem != null) throw AdminException(problem);
    await apiPause(400);
    // The password would be sent once to the server and stored encrypted
    // there. It is not kept in the app.
    settings.value = CrowdSettings(
      serverUrl: draft.serverUrl.trim(),
      applicationName: draft.applicationName.trim(),
      passwordSaved: true,
      userGroup: draft.userGroup.trim(),
      employeeIdAttribute: draft.employeeIdAttribute.trim(),
      groupPrefix: draft.groupPrefix.trim(),
      departmentPrefix: draft.departmentPrefix.trim(),
      schedule: draft.schedule,
      deactivateDisabled: draft.deactivateDisabled,
    );
  }

  /// Simulated "GET <crowd>/rest/usermanagement/1/search?entity-type=user".
  Future<String> testConnection({
    required AppUser by,
    required CrowdSettings draft,
    String password = '',
  }) async {
    requireHrd(by, 'connect Crowd');
    final hasPassword = password.isNotEmpty || (settings.value?.passwordSaved ?? false);
    final problem = settingsProblem(draft, hasPassword: hasPassword);
    if (problem != null) throw AdminException(problem);
    await apiPause(900);
    final host = Uri.parse(draft.serverUrl.trim()).host;
    if (host.contains('invalid') || host == 'localhost') {
      throw AdminException('Could not reach $host. Check the address and that the '
          'SkillSphere server can open it (firewall/proxy).');
    }
    final members = sampleCrowdUsers.where((u) => u.groups.contains(draft.userGroup.trim())).length;
    final message = 'Connected to Crowd at $host as "${draft.applicationName.trim()}". '
        '$members users in ${draft.userGroup.trim()}, ${sampleCrowdGroups.length} groups.';
    lastTest.value = message;
    return message;
  }

  CrowdSettings _requireSettings() {
    final s = settings.value;
    if (s == null) throw const AdminException('Save the Crowd connection first.');
    return s;
  }

  /// What a user sync would change right now.
  Future<List<CrowdUserChange>> previewUsers({required AppUser by}) async {
    requireHrd(by, 'synchronise with Crowd');
    final s = _requireSettings();
    await apiPause(800);
    final employees = EmployeeRepository.instance;
    final structure = OrgStructureRepository.instance;
    final changes = <CrowdUserChange>[];
    for (final u in sampleCrowdUsers) {
      if (!u.groups.contains(s.userGroup)) continue;
      final employee = employees.byId(u.employeeNumber) ?? employees.byEmail(u.email);
      if (employee == null) {
        if (!u.active) continue;
        String? departmentId;
        for (final g in u.groups) {
          final d = structure.departmentByCrowdGroup(g);
          if (d != null) {
            departmentId = d.id;
            break;
          }
        }
        changes.add(CrowdUserChange(kind: CrowdChangeKind.added, user: u, departmentId: departmentId));
        continue;
      }
      if (!u.active) {
        if (s.deactivateDisabled && employee.isActive) {
          changes.add(CrowdUserChange(kind: CrowdChangeKind.disabled, user: u, employee: employee));
        }
        continue;
      }
      final diffs = <String>[
        if (u.displayName.trim() != employee.name) 'Name: ${employee.name} → ${u.displayName.trim()}',
        if (u.email.trim().toLowerCase() != employee.email.toLowerCase())
          'Email: ${employee.email} → ${u.email.trim()}',
      ];
      if (diffs.isNotEmpty) {
        changes.add(CrowdUserChange(
          kind: CrowdChangeKind.updated,
          user: u,
          employee: employee,
          differences: diffs,
        ));
      }
    }
    return changes;
  }

  /// Applies the chosen changes. [departmentFor] gives the department for
  /// new users (from their Crowd group, or chosen by HRD).
  Future<String> applyUsers({
    required AppUser by,
    required List<CrowdUserChange> selected,
    required Map<String, String> departmentFor,
  }) async {
    requireHrd(by, 'synchronise with Crowd');
    final employees = EmployeeRepository.instance;
    final drafts = <EmployeeDraft>[];
    final updates = <String, ({String name, String email})>{};
    final deactivate = <String>{};
    var skipped = 0;
    for (final change in selected) {
      final u = change.user;
      switch (change.kind) {
        case CrowdChangeKind.added:
          final departmentId = departmentFor[u.username] ?? change.departmentId;
          if (departmentId == null) {
            skipped++;
          } else {
            drafts.add(_draftFor(u, departmentId));
          }
        case CrowdChangeKind.updated:
          final e = change.employee;
          if (e != null) updates[e.id] = (name: u.displayName.trim(), email: u.email.trim());
        case CrowdChangeKind.disabled:
          final e = change.employee;
          if (e != null) deactivate.add(e.id);
      }
    }

    final added = drafts.isEmpty
        ? const <EmployeeProfile>[]
        : await employees.onboardAll(by: by, drafts: drafts, source: RecordSource.crowd);
    final changed = updates.isEmpty && deactivate.isEmpty
        ? 0
        : await employees.applyCrowdUpdates(by: by, updates: updates, deactivate: deactivate);

    final parts = <String>[
      if (added.isNotEmpty) '${added.length} onboarded',
      if (updates.isNotEmpty) '${updates.length} updated',
      if (deactivate.isNotEmpty) '${deactivate.length} deactivated',
      if (skipped > 0) '$skipped skipped (no department)',
    ];
    final summary = parts.isEmpty ? 'Nothing changed' : parts.join(' · ');
    if (added.isNotEmpty || changed > 0) {
      history.value = List<CrowdSyncRun>.unmodifiable([
        CrowdSyncRun(at: DateTime.now(), by: by.name, summary: summary),
        ...history.value,
      ]);
    }
    return summary;
  }

  EmployeeDraft _draftFor(CrowdUser u, String departmentId) {
    final country = LocationCatalog.matchCountry(u.country) ?? u.country.trim();
    var state = '';
    var city = u.city.trim();
    for (final s in LocationCatalog.statesOf(country)) {
      final match = LocationCatalog.matchCity(country, s, city);
      if (match != null) {
        state = s;
        city = match;
        break;
      }
    }
    return EmployeeDraft(
      id: u.employeeNumber.trim().isEmpty ? u.username.toUpperCase() : u.employeeNumber.trim(),
      name: u.displayName.trim(),
      email: u.email.trim(),
      gender: Gender.undisclosed,
      status: EmploymentStatus.active,
      departmentId: departmentId,
      designation: u.title.trim(),
      location: EmployeeLocation(country: country, state: state, city: city),
      crowdUsername: u.username,
    );
  }

  /// Crowd groups that aren't in SkillSphere yet.
  Future<List<CrowdGroupChange>> previewGroups({required AppUser by}) async {
    requireHrd(by, 'synchronise with Crowd');
    final s = _requireSettings();
    await apiPause(700);
    final structure = OrgStructureRepository.instance;
    final byName = {for (final g in sampleCrowdGroups) g.name: g};
    final changes = <CrowdGroupChange>[];
    for (final g in sampleCrowdGroups) {
      final isGroup = g.name.startsWith(s.groupPrefix);
      final isDepartment = g.name.startsWith(s.departmentPrefix);
      if (!isGroup && !isDepartment) continue;
      final display = displayNameOf(g, isGroup ? s.groupPrefix : s.departmentPrefix);
      if (isGroup) {
        if (structure.groupByCrowdGroup(g.name) != null || structure.groupByName(display) != null) continue;
        changes.add(CrowdGroupChange(group: g, isDepartment: false, displayName: display));
      } else {
        if (structure.departmentByCrowdGroup(g.name) != null || structure.departmentByName(display) != null) {
          continue;
        }
        final parent = g.parent == null ? null : byName[g.parent!];
        final parentName = parent == null
            ? null
            : (structure.groupByCrowdGroup(parent.name)?.name ?? displayNameOf(parent, s.groupPrefix));
        changes.add(CrowdGroupChange(
          group: g,
          isDepartment: true,
          displayName: display,
          parentDisplayName: parentName,
        ));
      }
    }
    return changes;
  }

  Future<StructureAddResult> applyGroups({
    required AppUser by,
    required List<CrowdGroupChange> selected,
  }) async {
    requireHrd(by, 'synchronise with Crowd');
    final drafts = <StructureDraft>[];
    for (final c in selected.where((c) => !c.isDepartment)) {
      drafts.add(StructureDraft(
        groupName: c.displayName,
        groupDescription: c.group.description,
        groupCrowd: c.group.name,
      ));
    }
    for (final c in selected.where((c) => c.isDepartment)) {
      final parent = c.parentDisplayName;
      if (parent == null) continue;
      drafts.add(StructureDraft(
        groupName: parent,
        groupCrowd: c.group.parent,
        departmentName: c.displayName,
        departmentDescription: c.group.description,
        departmentCrowd: c.group.name,
      ));
    }
    final result = await OrgStructureRepository.instance
        .addAll(by: by, drafts: drafts, source: RecordSource.crowd);
    if (!result.isEmpty) {
      history.value = List<CrowdSyncRun>.unmodifiable([
        CrowdSyncRun(
          at: DateTime.now(),
          by: by.name,
          usersSync: false,
          summary: '${result.groups.length} groups and ${result.departments.length} departments added',
        ),
        ...history.value,
      ]);
    }
    return result;
  }

  /// "dept-functional-safety" → "Functional Safety" (or the description's
  /// first part when Crowd has one, e.g. "Functional Safety – ISO 26262").
  static String displayNameOf(CrowdGroup g, String prefix) {
    final description = g.description.split(RegExp(r'\s[–\-]\s')).first.trim();
    if (description.isNotEmpty && description.length <= StructureRules.nameMax) return description;
    final raw = g.name.startsWith(prefix) ? g.name.substring(prefix.length) : g.name;
    return raw
        .split(RegExp(r'[-_.]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.length <= 2 ? w.toUpperCase() : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
