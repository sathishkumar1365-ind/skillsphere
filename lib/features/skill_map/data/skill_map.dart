// Skill map: one employee's projects, what those projects need from their
// role, the levels they hold and the gaps, as a graph the animated beams
// are drawn on.
//
//   Projects → Required → Employee → Current levels → Gaps
//
// * Project → Required: one beam per competency a project needs from the
//   employee's role (blue when the held level reaches that project's level,
//   orange when it doesn't).
// * Required → Employee: one beam per required competency (highest level
//   any shown project needs – the same rule as the Gaps table and
//   readiness).
// * Employee → Current: one beam per competency held or needed. Needed but
//   not held = dashed. Held but not needed by the shown projects = grey.
// * Current → Gap: one beam per competency below the required level.
//
// Built from live data (same rules as insights.dart); nothing is stored.
// The Spring Boot API can serve the same graph later from
// GET /api/employees/{id}/skill-map?projectId=… (see CHANGES-skill-map.md).

import '../../admin/data/approvals.dart';
import '../../admin/data/employees.dart';
import '../../admin/data/insights.dart';
import '../../admin/data/job_roles.dart';
import '../../admin/data/projects.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/data/competency_repository.dart';
import '../../training_plan/data/training_plans.dart';

/// The five columns of the map (tiers on narrow screens), left to right.
enum SkillMapColumn {
  projects('Projects', 'Projects'),
  needs('Required', 'Required by the projects'),
  employee('Employee', 'Employee'),
  current('Current', 'Current levels'),
  gaps('Gaps', 'Gaps');

  const SkillMapColumn(this.short, this.long);

  /// Column heading on wide screens.
  final String short;

  /// Tier heading on narrow screens.
  final String long;
}

/// What a beam means; also its colours.
enum BeamTone {
  /// The level is reached.
  met,

  /// Below the required level, or not acquired.
  gap,

  /// Held, but no shown project needs it.
  other,
}

/// Node ids: one namespace per column, so the same competency can sit in
/// three columns (required, current, gap).
class SkillMapIds {
  SkillMapIds._();

  static const String hub = 'hub';

  static String project(String projectId) => 'p:$projectId';

  static String need(String competencyId) => 'n:$competencyId';

  static String current(String competencyId) => 'c:$competencyId';

  static String gap(String competencyId) => 'g:$competencyId';

  /// Placeholder for an empty column ("Not on a project", "No gaps"…).
  static String empty(SkillMapColumn column) => 'x:${column.name}';

  /// The competency behind a required/current/gap node id, else null.
  static String? competencyOf(String nodeId) {
    if (nodeId.startsWith('n:') || nodeId.startsWith('c:') || nodeId.startsWith('g:')) {
      return nodeId.substring(2);
    }
    return null;
  }

  /// The project behind a project node id, else null.
  static String? projectOf(String nodeId) => nodeId.startsWith('p:') ? nodeId.substring(2) : null;
}

/// One project the employee is on, with how well they fit what it needs
/// from their role.
class MapProject {
  const MapProject({required this.project, required this.fit});

  final ProjectRecord project;
  final ProjectFit fit;

  String get id => SkillMapIds.project(project.id);
}

/// One project needing one competency, at a level.
class MapSource {
  const MapSource({required this.project, required this.level, required this.held});

  final ProjectRecord project;
  final int level;

  /// Null when not held.
  final int? held;

  bool get met {
    final h = held;
    return h != null && h >= level;
  }

  /// Levels short; not held counts from below L0 (like the Gaps table).
  int get size {
    final h = held;
    if (h == null) return level + 1;
    return h >= level ? 0 : level - h;
  }
}

/// A competency the shown projects need (highest level across them).
class MapNeed {
  const MapNeed({required this.competency, required this.level, required this.sources, required this.held});

  final Competency competency;
  final int level;

  /// Highest level first.
  final List<MapSource> sources;
  final int? held;

  String get id => SkillMapIds.need(competency.id);

  bool get met {
    final h = held;
    return h != null && h >= level;
  }

  int get size {
    final h = held;
    if (h == null) return level + 1;
    return h >= level ? 0 : level - h;
  }
}

/// A competency on the "current" side: held, or needed but not held.
class MapCurrent {
  const MapCurrent({required this.competency, required this.holder, required this.neededLevel, required this.pending});

  final Competency competency;

  /// Null = not acquired.
  final CompetencyHolder? holder;

  /// Null = no shown project needs it.
  final int? neededLevel;

  /// A level-up waiting for HR.
  final LevelUpRequest? pending;

  String get id => SkillMapIds.current(competency.id);

  int? get level => holder?.level;

  bool get verified => holder?.verified ?? false;

  bool get isNeeded => neededLevel != null;

  bool get met {
    final need = neededLevel;
    final held = holder;
    return need != null && held != null && held.level >= need;
  }

  BeamTone get tone {
    if (neededLevel == null) return BeamTone.other;
    return met ? BeamTone.met : BeamTone.gap;
  }
}

/// A competency below the level the shown projects need.
class MapGap {
  const MapGap({
    required this.competency,
    required this.held,
    required this.neededLevel,
    required this.sources,
    required this.plan,
    required this.pending,
  });

  final Competency competency;

  /// Null = not acquired.
  final int? held;
  final int neededLevel;

  /// The projects reporting the gap (each with its own level), biggest
  /// gap first.
  final List<MapSource> sources;

  /// The main training plan for it (open, else the latest completed).
  final TrainingPlan? plan;
  final LevelUpRequest? pending;

  String get id => SkillMapIds.gap(competency.id);

  /// Levels short against the highest required level.
  int get size {
    final h = held;
    if (h == null) return neededLevel + 1;
    return h >= neededLevel ? 0 : neededLevel - h;
  }
}

/// One beam: [from] → [to] (node ids), in the direction the light travels.
class MapLink {
  const MapLink({required this.from, required this.to, required this.tone, required this.stage, this.dashed = false});

  final String from;
  final String to;
  final BeamTone tone;

  /// 0 project→required, 1 required→employee, 2 employee→current,
  /// 3 current→gap (drawn in this order; pulses are staggered by it).
  final int stage;

  /// Needed but not acquired.
  final bool dashed;

  String get id => '$from>$to';
}

class SkillMap {
  const SkillMap._({
    required this.profile,
    required this.roleName,
    required this.allProjects,
    required this.onlyProject,
    required this.projects,
    required this.needs,
    required this.current,
    required this.gaps,
    required this.links,
    required this.readiness,
    required this.otherCount,
    required this.showsOther,
  });

  final EmployeeProfile profile;
  final String roleName;

  /// Every open project the employee is on (for the project filter).
  final List<ProjectRecord> allProjects;

  /// Set when the map is limited to one project.
  final ProjectRecord? onlyProject;

  final List<MapProject> projects;
  final List<MapNeed> needs;
  final List<MapCurrent> current;
  final List<MapGap> gaps;
  final List<MapLink> links;

  /// 0–100 (level-weighted, like the profile), null when nothing is needed.
  final int? readiness;

  /// Competencies held that the shown projects don't need (also when hidden).
  final int otherCount;
  final bool showsOther;

  int get metCount => needs.where((n) => n.met).length;

  int get gapCount => gaps.length;

  int get pendingCount => current.where((c) => c.pending != null).length;

  /// Every node id, column by column (placeholders not included).
  Iterable<String> get nodeIds sync* {
    for (final p in projects) {
      yield p.id;
    }
    for (final n in needs) {
      yield n.id;
    }
    yield SkillMapIds.hub;
    for (final c in current) {
      yield c.id;
    }
    for (final g in gaps) {
      yield g.id;
    }
  }

  /// Changes whenever anything that is drawn changes (geometry cache key).
  String get signature => [
        profile.id,
        onlyProject?.id ?? '*',
        showsOther ? 'o' : '-',
        for (final p in projects) p.id,
        for (final n in needs) '${n.id}${n.level}',
        for (final c in current) '${c.id}${c.level ?? '_'}',
        for (final g in gaps) g.id,
        for (final l in links) '${l.id}${l.tone.index}${l.dashed ? 'd' : ''}',
      ].join('|');

  MapProject? projectNode(String nodeId) {
    for (final p in projects) {
      if (p.id == nodeId) return p;
    }
    return null;
  }

  MapNeed? needFor(String competencyId) {
    for (final n in needs) {
      if (n.competency.id == competencyId) return n;
    }
    return null;
  }

  MapCurrent? currentFor(String competencyId) {
    for (final c in current) {
      if (c.competency.id == competencyId) return c;
    }
    return null;
  }

  MapGap? gapFor(String competencyId) {
    for (final g in gaps) {
      if (g.competency.id == competencyId) return g;
    }
    return null;
  }

  /// [nodeId] and everything on a path through it – what lights up when it
  /// is hovered or tapped.
  /// * the employee: everything;
  /// * a project: its required competencies, the employee, their current
  ///   levels and gaps;
  /// * a competency (required, current or gap): the projects needing it,
  ///   the employee and its three nodes.
  Set<String> connectedTo(String nodeId) {
    if (nodeId == SkillMapIds.hub) return nodeIds.toSet();
    final result = <String>{nodeId, SkillMapIds.hub};
    final projectId = SkillMapIds.projectOf(nodeId);
    if (projectId != null) {
      for (final l in links) {
        if (l.from == nodeId) {
          final c = SkillMapIds.competencyOf(l.to);
          if (c != null) result.addAll(_competencyNodes(c));
        }
      }
      return result;
    }
    final competencyId = SkillMapIds.competencyOf(nodeId);
    if (competencyId != null) {
      result.addAll(_competencyNodes(competencyId));
      final need = SkillMapIds.need(competencyId);
      for (final l in links) {
        if (l.to == need) result.add(l.from);
      }
    }
    return result;
  }

  Iterable<String> _competencyNodes(String competencyId) sync* {
    if (needFor(competencyId) != null) yield SkillMapIds.need(competencyId);
    if (currentFor(competencyId) != null) yield SkillMapIds.current(competencyId);
    if (gapFor(competencyId) != null) yield SkillMapIds.gap(competencyId);
  }

  /// Ids of the links whose both ends are in [nodes].
  Set<String> linksAmong(Set<String> nodes) => {
        for (final l in links)
          if (nodes.contains(l.from) && nodes.contains(l.to)) l.id,
      };

  /// Builds the map for [insight]'s employee. [projectId] limits it to one
  /// of their projects (required levels and gaps are then that project's);
  /// [includeOther] adds the competencies no shown project needs.
  factory SkillMap.build(EmployeeInsight insight, {String? projectId, bool includeOther = true}) {
    final profile = insight.profile;
    final competencies = CompetencyRepository.instance;
    final approvals = ApprovalRepository.instance;
    final plans = TrainingPlanRepository.instance;
    final all = insight.projects;

    ProjectRecord? only;
    if (projectId != null) {
      for (final p in all) {
        if (p.id == projectId) only = p;
      }
    }
    final shown = only == null ? all : <ProjectRecord>[only];
    // What each project needs from the employee's role (a competency listed
    // for everyone and for the role counts once, at the higher level).
    final fits = [for (final p in shown) Insights.fit(profile, p)];

    final heldById = {for (final h in competencies.levelsFor(profile.id)) h.competency.id: h};

    // ---- required: highest level per competency across the shown projects
    final levels = <String, int>{};
    final sources = <String, List<MapSource>>{};
    final byId = <String, Competency>{};
    for (final fit in fits) {
      for (final n in fit.needs) {
        final id = n.competency.id;
        byId[id] = n.competency;
        final current = levels[id];
        if (current == null || n.requiredLevel > current) levels[id] = n.requiredLevel;
        (sources[id] ??= <MapSource>[]).add(MapSource(project: fit.project, level: n.requiredLevel, held: n.heldLevel));
      }
    }
    final needs = <MapNeed>[
      for (final entry in levels.entries)
        if (byId[entry.key] case final Competency c)
          MapNeed(
            competency: c,
            level: entry.value,
            sources: List<MapSource>.unmodifiable(
                [...?sources[entry.key]]..sort((a, b) => b.level.compareTo(a.level))),
            held: heldById[entry.key]?.level,
          ),
    ]..sort(_needOrder);

    // ---- projects: ordered by where their needs sit, so beams cross less
    final needIndex = {for (var i = 0; i < needs.length; i++) needs[i].competency.id: i};
    double centre(ProjectFit fit) {
      final indexes = <int>[
        for (final n in fit.needs)
          if (needIndex[n.competency.id] case final int i) i,
      ];
      if (indexes.isEmpty) return double.infinity;
      return indexes.reduce((a, b) => a + b) / indexes.length;
    }

    final order = {for (var i = 0; i < fits.length; i++) fits[i].project.id: i};
    final sortedFits = [...fits]..sort((a, b) {
        final byCentre = centre(a).compareTo(centre(b));
        return byCentre != 0 ? byCentre : order[a.project.id]!.compareTo(order[b.project.id]!);
      });
    final projects = [for (final f in sortedFits) MapProject(project: f.project, fit: f)];

    // ---- current: the required ones in the same order, then the others
    final current = <MapCurrent>[
      for (final n in needs)
        MapCurrent(
          competency: n.competency,
          holder: heldById[n.competency.id]?.holder,
          neededLevel: n.level,
          pending: approvals.pendingFor(profile.id, n.competency.id),
        ),
    ];
    final others = [
      for (final h in heldById.values)
        if (!levels.containsKey(h.competency.id)) h,
    ]..sort((a, b) {
        final byLevel = b.level.compareTo(a.level);
        return byLevel != 0 ? byLevel : a.competency.name.toLowerCase().compareTo(b.competency.name.toLowerCase());
      });
    if (includeOther) {
      for (final h in others) {
        current.add(MapCurrent(
          competency: h.competency,
          holder: h.holder,
          neededLevel: null,
          pending: approvals.pendingFor(profile.id, h.competency.id),
        ));
      }
    }

    // ---- gaps, in the same order as their current nodes
    final gaps = <MapGap>[
      for (final n in needs)
        if (!n.met)
          MapGap(
            competency: n.competency,
            held: n.held,
            neededLevel: n.level,
            sources: List<MapSource>.unmodifiable(
                n.sources.where((s) => s.size > 0).toList()..sort((a, b) => b.size.compareTo(a.size))),
            plan: plans.mainPlanFor(profile.id, n.competency.id),
            pending: approvals.pendingFor(profile.id, n.competency.id),
          ),
    ];

    // ---- links
    final links = <MapLink>[
      for (final p in projects)
        for (final n in p.fit.needs)
          if (levels.containsKey(n.competency.id))
            MapLink(
              from: p.id,
              to: SkillMapIds.need(n.competency.id),
              tone: n.met ? BeamTone.met : BeamTone.gap,
              stage: 0,
            ),
      for (final n in needs)
        MapLink(from: n.id, to: SkillMapIds.hub, tone: n.met ? BeamTone.met : BeamTone.gap, stage: 1),
      for (final c in current)
        MapLink(from: SkillMapIds.hub, to: c.id, tone: c.tone, stage: 2, dashed: c.holder == null),
      for (final g in gaps)
        MapLink(from: SkillMapIds.current(g.competency.id), to: g.id, tone: BeamTone.gap, stage: 3, dashed: g.held == null),
    ];

    // ---- readiness: Σ min(held + 1, required + 1) / Σ (required + 1)
    var reached = 0;
    var needed = 0;
    for (final n in needs) {
      needed += n.level + 1;
      final h = n.held;
      if (h != null) reached += h >= n.level ? n.level + 1 : h + 1;
    }

    return SkillMap._(
      profile: profile,
      roleName: RoleRepository.instance.nameOf(profile.roleId),
      allProjects: List<ProjectRecord>.unmodifiable(all),
      onlyProject: only,
      projects: List<MapProject>.unmodifiable(projects),
      needs: List<MapNeed>.unmodifiable(needs),
      current: List<MapCurrent>.unmodifiable(current),
      gaps: List<MapGap>.unmodifiable(gaps),
      links: List<MapLink>.unmodifiable(links),
      readiness: needed == 0 ? null : (reached * 100 / needed).round(),
      otherCount: others.length,
      showsOther: includeOther,
    );
  }

  /// Gaps first (biggest first), then met; by name.
  static int _needOrder(MapNeed a, MapNeed b) {
    final byRank = (a.met ? 1 : 0).compareTo(b.met ? 1 : 0);
    if (byRank != 0) return byRank;
    final bySize = b.size.compareTo(a.size);
    if (bySize != 0) return bySize;
    return a.competency.name.toLowerCase().compareTo(b.competency.name.toLowerCase());
  }
}
