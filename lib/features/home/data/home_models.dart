// Data shown on the Home page.
//
// Build a [HomeData] from your Spring Boot API (for example
// GET /api/employees/me/home). [HomeData.sample] is placeholder data
// for building the UI before the backend is ready.

enum SkillKind { technical, tool, soft }

class SkillItem {
  const SkillItem({
    required this.name,
    required this.category,
    required this.kind,
    required this.level,
    this.verified = false,
  });

  final String name;

  /// Short description shown under the name, e.g. "Backend · Framework".
  final String category;
  final SkillKind kind;

  /// Proficiency from 1 (Beginner) to 5 (Expert).
  final int level;

  /// True when the reporting manager has confirmed the level.
  final bool verified;

  static const levelNames = [
    'Not rated',
    'Beginner',
    'Elementary',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  String get levelName => levelNames[level.clamp(0, 5).toInt()];
}

enum ProjectSkillStatus { met, missing, levelUp }

class ProjectSkill {
  const ProjectSkill(this.name, [this.status = ProjectSkillStatus.met]);

  final String name;
  final ProjectSkillStatus status;
}

class ProjectItem {
  const ProjectItem({
    required this.id,
    required this.name,
    required this.role,
    required this.period,
    required this.matchPercent,
    required this.skills,
  });

  final String id;
  final String name;
  final String role;
  final String period;

  /// How well the employee's skills match this project's requirements (0–100).
  final int matchPercent;
  final List<ProjectSkill> skills;
}

class SkillGap {
  const SkillGap({
    required this.skill,
    required this.project,
    required this.currentLevel,
    required this.requiredLevel,
  });

  final String skill;
  final String project;

  /// 0 means the employee does not have the skill yet.
  final int currentLevel;
  final int requiredLevel;
}

enum LearningStepStatus { inProgress, upNext, planned }

class LearningStep {
  const LearningStep({required this.title, required this.status});

  final String title;
  final LearningStepStatus status;

  static const _labels = ['In progress', 'Up next', 'Planned'];

  String get statusLabel => _labels[status.index];
}

/// A skill label orbiting the 3D globe in the hero.
class GlobeChip {
  const GlobeChip(this.label, {this.isGap = false});

  final String label;
  final bool isGap;
}

class HomeData {
  const HomeData({
    required this.firstName,
    required this.initials,
    required this.skillsAcquired,
    required this.skillsInProgress,
    required this.requiredSkillsHeld,
    required this.requiredSkillsTotal,
    required this.skills,
    required this.projects,
    required this.gaps,
    required this.learningPlan,
    this.nextReview,
    this.unreadNotifications = 0,
  });

  final String firstName;
  final String initials;

  /// Total skills on the employee's profile.
  final int skillsAcquired;
  final int skillsInProgress;

  /// Of the skills the employee's current projects require, how many they hold.
  final int requiredSkillsHeld;
  final int requiredSkillsTotal;

  final List<SkillItem> skills;
  final List<ProjectItem> projects;
  final List<SkillGap> gaps;
  final List<LearningStep> learningPlan;
  final DateTime? nextReview;
  final int unreadNotifications;

  /// A copy with some fields replaced (used to greet the signed-in user
  /// while the rest of the Home page still shows sample data).
  HomeData copyWith({String? firstName, String? initials}) => HomeData(
        firstName: firstName ?? this.firstName,
        initials: initials ?? this.initials,
        skillsAcquired: skillsAcquired,
        skillsInProgress: skillsInProgress,
        requiredSkillsHeld: requiredSkillsHeld,
        requiredSkillsTotal: requiredSkillsTotal,
        skills: skills,
        projects: projects,
        gaps: gaps,
        learningPlan: learningPlan,
        nextReview: nextReview,
        unreadNotifications: unreadNotifications,
      );

  int get readinessPercent => requiredSkillsTotal == 0
      ? 100
      : (requiredSkillsHeld * 100 / requiredSkillsTotal).round();

  int get missingRequiredSkills {
    final missing = requiredSkillsTotal - requiredSkillsHeld;
    return missing < 0 ? 0 : missing;
  }

  /// Up to 5 strongest skills (blue) mixed with up to 3 gaps (orange).
  List<GlobeChip> get globeChips {
    final held = [...skills]..sort((a, b) => b.level.compareTo(a.level));
    final acquired = held.take(5).map((s) => GlobeChip(s.name)).toList();
    final missing =
        gaps.take(3).map((g) => GlobeChip(g.skill, isGap: true)).toList();
    final result = <GlobeChip>[];
    var a = 0, g = 0;
    for (var i = 0; i < acquired.length + missing.length; i++) {
      final takeGap = g < missing.length && (a >= acquired.length || i % 3 == 1);
      result.add(takeGap ? missing[g++] : acquired[a++]);
    }
    return result;
  }

  /// Placeholder data matching the approved design.
  static const HomeData sample = HomeData(
    firstName: 'Sathish',
    initials: 'SA',
    skillsAcquired: 18,
    skillsInProgress: 4,
    requiredSkillsHeld: 18,
    requiredSkillsTotal: 24,
    unreadNotifications: 2,
    skills: [
      SkillItem(name: 'Java', category: 'Backend · Language', kind: SkillKind.technical, level: 5, verified: true),
      SkillItem(name: 'Spring Boot', category: 'Backend · Framework', kind: SkillKind.technical, level: 4, verified: true),
      SkillItem(name: 'Flutter', category: 'Mobile & Web · Framework', kind: SkillKind.technical, level: 4, verified: true),
      SkillItem(name: 'Dart', category: 'Mobile & Web · Language', kind: SkillKind.technical, level: 4),
      SkillItem(name: 'PostgreSQL', category: 'Data · Database', kind: SkillKind.tool, level: 3, verified: true),
      SkillItem(name: 'REST API Design', category: 'Architecture', kind: SkillKind.technical, level: 4, verified: true),
      SkillItem(name: 'Docker', category: 'DevOps · Tool', kind: SkillKind.tool, level: 2),
      SkillItem(name: 'Agile / Scrum', category: 'Process · Soft skill', kind: SkillKind.soft, level: 3, verified: true),
    ],
    projects: [
      ProjectItem(
        id: 'talent-hub',
        name: 'Talent Hub Revamp',
        role: 'Flutter Developer',
        period: 'Since Aug 2026',
        matchPercent: 92,
        skills: [
          ProjectSkill('Flutter'),
          ProjectSkill('Dart'),
          ProjectSkill('REST APIs'),
          ProjectSkill('Firebase', ProjectSkillStatus.missing),
        ],
      ),
      ProjectItem(
        id: 'payments-api',
        name: 'Payments API Migration',
        role: 'Backend Developer',
        period: 'Since Jun 2026',
        matchPercent: 70,
        skills: [
          ProjectSkill('Java'),
          ProjectSkill('Spring Boot'),
          ProjectSkill('PostgreSQL'),
          ProjectSkill('Kafka', ProjectSkillStatus.missing),
          ProjectSkill('Kubernetes', ProjectSkillStatus.missing),
        ],
      ),
      ProjectItem(
        id: 'analytics',
        name: 'Analytics Platform',
        role: 'Full-stack Developer',
        period: 'Starts Jan 2027',
        matchPercent: 55,
        skills: [
          ProjectSkill('PostgreSQL'),
          ProjectSkill('Java'),
          ProjectSkill('Docker', ProjectSkillStatus.levelUp),
          ProjectSkill('AWS', ProjectSkillStatus.missing),
          ProjectSkill('Terraform', ProjectSkillStatus.missing),
        ],
      ),
    ],
    gaps: [
      SkillGap(skill: 'Kubernetes', project: 'Payments API Migration', currentLevel: 0, requiredLevel: 3),
      SkillGap(skill: 'Kafka', project: 'Payments API Migration', currentLevel: 1, requiredLevel: 3),
      SkillGap(skill: 'AWS', project: 'Analytics Platform', currentLevel: 0, requiredLevel: 3),
      SkillGap(skill: 'Docker', project: 'Analytics Platform', currentLevel: 2, requiredLevel: 3),
      SkillGap(skill: 'Terraform', project: 'Analytics Platform', currentLevel: 0, requiredLevel: 2),
      SkillGap(skill: 'Firebase', project: 'Talent Hub Revamp', currentLevel: 1, requiredLevel: 3),
    ],
    learningPlan: [
      LearningStep(title: 'Docker in practice', status: LearningStepStatus.inProgress),
      LearningStep(title: 'Kafka fundamentals', status: LearningStepStatus.upNext),
      LearningStep(title: 'Kubernetes for developers', status: LearningStepStatus.planned),
    ],
  );
}
