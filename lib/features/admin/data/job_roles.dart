// Roles: what an employee does on a project (Software Developer, Test
// Engineer, Functional Safety Engineer…). Not the same as the designation
// (job title such as "Senior Software Engineer") and not the app access
// level (UserRole: Super Admin / Admin / End User).
//
// Project requirements can be set per role, so a Test Engineer and a
// Software Developer on the same project are measured against different
// competencies.
//
// Spring Boot API later:
//   GET  /api/roles
//   POST /api/roles        (SUPER_ADMIN)   POST /api/roles/bulk (SUPER_ADMIN)
//   PATCH /api/roles/{id}  (SUPER_ADMIN, e.g. {"active": false})

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import 'admin_base.dart';
import 'admin_sample_data.dart';

class JobRole {
  const JobRole({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
    this.description = '',
    this.active = true,
    this.source = RecordSource.existing,
  });

  /// e.g. "ROL-03".
  final String id;
  final String name;

  /// Short code, e.g. "TE".
  final String code;
  final String description;

  /// Inactive roles can't be given to new employees or used in new
  /// project requirements; existing data keeps them.
  final bool active;
  final DateTime createdAt;
  final RecordSource source;

  String get key => nameKey(name);

  JobRole copyWith({bool? active}) => JobRole(
        id: id,
        name: name,
        code: code,
        createdAt: createdAt,
        description: description,
        active: active ?? this.active,
        source: source,
      );
}

class RoleDraft {
  const RoleDraft({required this.name, this.code = '', this.description = ''});

  final String name;
  final String code;
  final String description;
}

class RoleRules {
  RoleRules._();

  static const int nameMax = 50;
  static const int codeMax = 10;
  static const int descriptionMax = 240;

  static bool isValidCode(String code) => RegExp(r'^[A-Za-z0-9_\-]{1,10}$').hasMatch(code);
}

class RoleRepository {
  RoleRepository._();

  static final RoleRepository instance = RoleRepository._();

  final ValueNotifier<List<JobRole>> roles =
      ValueNotifier<List<JobRole>>(List<JobRole>.unmodifiable(sampleRoles));

  final Set<String> _addedThisSession = <String>{};

  bool isNew(String id) => _addedThisSession.contains(id);

  List<JobRole> get active => roles.value.where((r) => r.active).toList();

  JobRole? byId(String? id) {
    if (id == null) return null;
    for (final r in roles.value) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// By name or code, ignoring case.
  JobRole? byName(String name) {
    final key = nameKey(name);
    if (key.isEmpty) return null;
    for (final r in roles.value) {
      if (r.key == key || nameKey(r.code) == key) return r;
    }
    return null;
  }

  String nameOf(String? id) => byId(id)?.name ?? '—';

  /// The first rule a new role breaks, or null.
  String? problemWith(RoleDraft draft) {
    final name = cleanText(draft.name);
    final code = draft.code.trim();
    if (name.isEmpty) return 'Enter the role name.';
    if (name.length > RoleRules.nameMax) return 'Keep the name under ${RoleRules.nameMax} characters.';
    if (code.isNotEmpty && !RoleRules.isValidCode(code)) {
      return 'The code can have up to ${RoleRules.codeMax} letters, digits, - or _.';
    }
    if (draft.description.trim().length > RoleRules.descriptionMax) {
      return 'Keep the description under ${RoleRules.descriptionMax} characters.';
    }
    final existing = byName(name);
    if (existing != null) return '"${existing.name}" already exists.';
    if (code.isNotEmpty && byName(code) != null) return 'The code "${code.toUpperCase()}" is already used.';
    return null;
  }

  Future<JobRole> add({required AppUser by, required RoleDraft draft}) async {
    requireHrd(by, 'add roles');
    final problem = problemWith(draft);
    if (problem != null) throw AdminException(problem);
    final added = await addAll(by: by, drafts: [draft]);
    if (added.isEmpty) throw const AdminException('This role could not be added.');
    return added.first;
  }

  /// Adds the valid, new roles among [drafts] and returns them.
  Future<List<JobRole>> addAll({
    required AppUser by,
    required List<RoleDraft> drafts,
    RecordSource source = RecordSource.manual,
  }) async {
    requireHrd(by, 'add roles');
    await apiPause(400);
    final all = [...roles.value];
    final added = <JobRole>[];
    for (final draft in drafts) {
      final name = cleanText(draft.name);
      if (name.isEmpty || name.length > RoleRules.nameMax) continue;
      if (all.any((r) => r.key == nameKey(name))) continue;
      var code = draft.code.trim().toUpperCase();
      if (code.isEmpty || !RoleRules.isValidCode(code) || all.any((r) => r.code.toUpperCase() == code)) {
        code = _codeFor(name, all);
      }
      final role = JobRole(
        id: nextId('ROL-', all.map((r) => r.id), width: 2),
        name: name,
        code: code,
        description: draft.description.trim(),
        createdAt: DateTime.now(),
        source: source,
      );
      all.add(role);
      added.add(role);
    }
    if (added.isNotEmpty) {
      _addedThisSession.addAll(added.map((r) => r.id));
      roles.value = List<JobRole>.unmodifiable(all);
    }
    return added;
  }

  void setActive({required AppUser by, required String roleId, required bool active}) {
    requireHrd(by, 'change roles');
    roles.value = List<JobRole>.unmodifiable([
      for (final r in roles.value) r.id == roleId ? r.copyWith(active: active) : r,
    ]);
  }

  static String _codeFor(String name, List<JobRole> taken) {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    var base = words.length == 1
        ? words.first.substring(0, words.first.length < 3 ? words.first.length : 3).toUpperCase()
        : words.take(4).map((w) => w[0].toUpperCase()).join();
    base = base.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (base.isEmpty) base = 'ROLE';
    final used = {for (final r in taken) r.code.toUpperCase()};
    if (!used.contains(base)) return base;
    for (var i = 2; i < 100; i++) {
      if (!used.contains('$base$i')) return '$base$i';
    }
    return base;
  }
}
