// Competency gaps and readiness, worked out from the data instead of being
// stored: projects (what they need, per role) × the employee's levels.
//
// Rules
// * Required level of a competency = the highest level any of the
//   employee's active projects needs from someone in their role. Common
//   competencies are combined into one row (e.g. Java needed at L3 by one
//   project and L4 by another → one row, required L4, both projects listed).
// * Gap = required level not reached (or competency not held at all).
// * Readiness = share of the required levels reached, weighted by level:
//   Σ min(held + 1, required + 1) / Σ (required + 1). Holding L2 of a
//   required L4 counts 3/5; not holding it counts 0.
//
// The Spring Boot API should calculate the same thing server-side for the
// dashboards (GET /api/employees/{id}/gaps).

import 'package:flutter/foundation.dart';

import '../../additional_competency/data/additional_competency_repository.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/data/competency_repository.dart';
import '../../organization/data/org_models.dart';
import 'approvals.dart';
import 'employees.dart';
import 'job_roles.dart';
import 'org_structure.dart';
import 'projects.dart';

enum RowState {
  /// Required and the level is reached.
  met('Met'),

  /// Required; held but below the required level.
  below('Below required'),

  /// Required but not held at all.
  missing('Not acquired'),

  /// Held but no project needs it.
  extra('Not required');

  const RowState(this.label);
  final String label;

  bool get isGap => this == RowState.below || this == RowState.missing;
}

/// A project that needs a competency, and at which level.
class RequirementSource {
  const RequirementSource(this.project, this.level, {this.roleName});

  final ProjectRecord project;
  final int level;

  /// Set when the requirement is for a specific role.
  final String? roleName;
}

/// One row of the combined competency table on the profile.
class CompetencyRow {
  const CompetencyRow({
    required this.competency,
    required this.sources,
    this.requiredLevel,
    this.holder,
    this.pending,
  });

  final Competency competency;

  /// Highest level needed (null when no project needs it).
  final int? requiredLevel;
  final List<RequirementSource> sources;
  final CompetencyHolder? holder;

  /// A level-up waiting for HR, if any.
  final LevelUpRequest? pending;

  int? get acquiredLevel => holder?.level;

  RowState get state {
    final required = requiredLevel;
    final held = holder;
    if (required == null) return RowState.extra;
    if (held == null) return RowState.missing;
    return held.level >= required ? RowState.met : RowState.below;
  }

  /// Levels still to go: required L4, held L2 → 2. Not held → required + 1.
  int get gapSize {
    final required = requiredLevel;
    if (required == null) return 0;
    final held = holder;
    if (held == null) return required + 1;
    return held.level >= required ? 0 : required - held.level;
  }
}

class EmployeeInsight {
  const EmployeeInsight({
    required this.profile,
    required this.projects,
    required this.rows,
    required this.additionalCount,
  });

  final EmployeeProfile profile;
  final List<ProjectRecord> projects;
  final List<CompetencyRow> rows;
  final int additionalCount;

  List<CompetencyRow> get requiredRows => rows.where((r) => r.requiredLevel != null).toList();

  int get requiredCount => rows.where((r) => r.requiredLevel != null).length;

  int get metCount => rows.where((r) => r.state == RowState.met).length;

  int get gapCount => rows.where((r) => r.state.isGap).length;

  int get acquiredCount => rows.where((r) => r.holder != null).length;

  int get pendingCount => rows.where((r) => r.pending != null).length;

  /// 0–100, or null when no project needs anything from this employee.
  int? get readiness {
    var reached = 0;
    var needed = 0;
    for (final r in rows) {
      final required = r.requiredLevel;
      if (required == null) continue;
      needed += required + 1;
      final held = r.holder;
      if (held != null) reached += (held.level + 1) < (required + 1) ? held.level + 1 : required + 1;
    }
    if (needed == 0) return null;
    return (reached * 100 / needed).round();
  }

  /// Readiness for the dashboards: the calculated one, or the baseline for
  /// people without a project yet.
  int get displayReadiness => readiness ?? profile.baselineReadiness ?? 0;
}

class Insights {
  Insights._();

  /// Everything the calculations depend on; listen to it to stay current.
  static final Listenable listenable = Listenable.merge([
    EmployeeRepository.instance.employees,
    EmployeeRepository.instance.changes,
    CompetencyRepository.instance.competencies,
    ProjectRepository.instance.projects,
    OrgStructureRepository.instance.groups,
    OrgStructureRepository.instance.departments,
    RoleRepository.instance.roles,
    ApprovalRepository.instance.requests,
    AdditionalCompetencyRepository.instance.entries,
  ]);

  static EmployeeInsight of(EmployeeProfile profile) {
    final projects = ProjectRepository.instance.forEmployee(profile.id);
    final competencies = CompetencyRepository.instance;
    final roles = RoleRepository.instance;

    // Required level per competency, combined across projects.
    final required = <String, int>{};
    final sources = <String, List<RequirementSource>>{};
    for (final p in projects) {
      for (final r in p.requirementsFor(profile.roleId)) {
        if (competencies.byId(r.competencyId) == null) continue;
        final current = required[r.competencyId];
        if (current == null || r.level > current) required[r.competencyId] = r.level;
        (sources[r.competencyId] ??= <RequirementSource>[]).add(RequirementSource(
          p,
          r.level,
          roleName: r.roleId == null ? null : roles.nameOf(r.roleId),
        ));
      }
    }

    final held = {for (final h in competencies.levelsFor(profile.id)) h.competency.id: h};
    final ids = {...required.keys, ...held.keys};
    final approvals = ApprovalRepository.instance;
    final rows = <CompetencyRow>[
      for (final id in ids)
        if (competencies.byId(id) case final Competency competency)
          CompetencyRow(
            competency: competency,
            requiredLevel: required[id],
            sources: List<RequirementSource>.unmodifiable(
                [...?sources[id]]..sort((a, b) => b.level.compareTo(a.level))),
            holder: held[id]?.holder,
            pending: approvals.pendingFor(profile.id, id),
          ),
    ]..sort(_rowOrder);

    return EmployeeInsight(
      profile: profile,
      projects: projects,
      rows: List<CompetencyRow>.unmodifiable(rows),
      additionalCount: AdditionalCompetencyRepository.instance.forEmployee(profile.id).length,
    );
  }

  /// Gaps first (biggest first), then met, then not required; by name.
  static int _rowOrder(CompetencyRow a, CompetencyRow b) {
    int rank(CompetencyRow r) => switch (r.state) {
          RowState.missing || RowState.below => 0,
          RowState.met => 1,
          RowState.extra => 2,
        };
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    final byGap = b.gapSize.compareTo(a.gapSize);
    if (byGap != 0) return byGap;
    return a.competency.name.toLowerCase().compareTo(b.competency.name.toLowerCase());
  }

  /// The old dashboard's row for [profile], built from live data.
  static EmployeeRecord record(EmployeeProfile profile, [EmployeeInsight? insight]) {
    final info = insight ?? of(profile);
    final employees = EmployeeRepository.instance;
    final top = [...info.rows.where((r) => r.holder != null)]
      ..sort((a, b) => (b.acquiredLevel ?? 0).compareTo(a.acquiredLevel ?? 0));
    return EmployeeRecord(
      id: profile.id,
      name: profile.name,
      designation: profile.designation.isEmpty ? '—' : profile.designation,
      department: employees.departmentNameOf(profile),
      reportsTo: employees.managerLabel(profile),
      readiness: info.displayReadiness,
      skillCount: info.acquiredCount + info.additionalCount,
      gapCount: info.gapCount,
      topSkills: [for (final r in top.take(3)) r.competency.name],
      projects: [for (final p in info.projects) p.name],
      status: profile.onLeave
          ? EmployeeStatus.onLeave
          : (info.projects.isEmpty ? EmployeeStatus.available : EmployeeStatus.allocated),
    );
  }

  /// Rows for every (active) employee, ordered by employee ID.
  static List<EmployeeRecord> records({bool includeInactive = false}) {
    final list = EmployeeRepository.instance.employees.value
        .where((e) => includeInactive || e.isActive)
        .map((e) => record(e))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  /// How well a project's team covers what it needs (0–100), level-weighted
  /// like readiness but only for this project's requirements.
  static int projectMatch(ProjectRecord project) {
    var reached = 0;
    var needed = 0;
    final competencies = CompetencyRepository.instance;
    for (final id in project.memberIds) {
      final e = EmployeeRepository.instance.byId(id);
      if (e == null || !e.isActive) continue;
      for (final r in project.requirementsFor(e.roleId)) {
        needed += r.level + 1;
        final held = competencies.holderOf(r.competencyId, id);
        if (held != null) reached += held.level >= r.level ? r.level + 1 : held.level + 1;
      }
    }
    if (needed == 0) return project.memberIds.isEmpty ? 0 : 100;
    return (reached * 100 / needed).round();
  }

  /// Required competencies no team member (of the right role) has at the
  /// required level.
  static List<Competency> projectMissing(ProjectRecord project) {
    final competencies = CompetencyRepository.instance;
    final members = [
      for (final id in project.memberIds)
        if (EmployeeRepository.instance.byId(id) case final EmployeeProfile e when e.isActive) e,
    ];
    final missing = <Competency>[];
    final seen = <String>{};
    for (final r in project.requirements) {
      final covered = members.any((m) {
        if (!r.appliesTo(m.roleId)) return false;
        final held = competencies.holderOf(r.competencyId, m.id);
        return held != null && held.level >= r.level;
      });
      if (covered || !seen.add(r.competencyId)) continue;
      final c = competencies.byId(r.competencyId);
      if (c != null) missing.add(c);
    }
    return missing;
  }

  /// The old dashboard's project card, built from live data.
  static OrgProject orgProject(ProjectRecord project) {
    final match = projectMatch(project);
    final members = project.memberIds.where((id) => EmployeeRepository.instance.byId(id)?.isActive ?? false).length;
    final needed = project.plannedTeamSize < members ? members : project.plannedTeamSize;
    final ProjectHealth health;
    if (project.status == ProjectStatus.planned || needed - members >= 2) {
      health = ProjectHealth.staffing;
    } else if (match < 75 || project.status == ProjectStatus.onHold) {
      health = ProjectHealth.atRisk;
    } else {
      health = ProjectHealth.onTrack;
    }
    return OrgProject(
      name: project.name,
      department: OrgStructureRepository.instance.departmentName(project.departmentId),
      period: project.period,
      members: members,
      needed: needed,
      matchPercent: match,
      health: health,
      missingSkills: [for (final c in projectMissing(project).take(3)) c.name],
    );
  }

  static List<OrgProject> orgProjects() => [
        for (final p in ProjectRepository.instance.projects.value)
          if (p.status != ProjectStatus.completed) orgProject(p),
      ];
}
