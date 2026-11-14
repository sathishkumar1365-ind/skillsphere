// Competencies: the skills, tools, languages and domains employees are
// rated on, each with a Level 0–5 guide.
//
// Spring Boot API later (see CHANGES-competencies.md for the full contract):
//   GET  /api/competencies                 – library (everyone signed in)
//   GET  /api/competencies/{id}/employees  – who holds it, at which level
//   POST /api/competencies                 – add one (SUPER_ADMIN / HRD only)

/// The four kinds of competency.
enum CompetencyCategory {
  skill(label: 'Skill', plural: 'Skills', apiValue: 'SKILL', example: 'Project Management'),
  tool(label: 'Tool', plural: 'Tools', apiValue: 'TOOL', example: 'Jira'),
  language(label: 'Language', plural: 'Languages', apiValue: 'LANGUAGE', example: 'Java'),
  domain(label: 'Domain', plural: 'Domains', apiValue: 'DOMAIN', example: 'Atlassian');

  const CompetencyCategory({
    required this.label,
    required this.plural,
    required this.apiValue,
    required this.example,
  });

  /// "Language"
  final String label;

  /// "Languages"
  final String plural;

  /// Value stored in PostgreSQL / sent by the API, e.g. "LANGUAGE".
  final String apiValue;

  /// Shown as a hint in the Add form, e.g. "Java".
  final String example;

  static CompetencyCategory fromApi(String value) => CompetencyCategory.values.firstWhere(
        (c) => c.apiValue == value.toUpperCase(),
        orElse: () => CompetencyCategory.skill,
      );
}

/// The organisation-wide proficiency scale. Every competency uses the same
/// six levels (0–5) so "Level 3" means the same thing everywhere; what each
/// level means for a particular competency is in its own level guide.
class CompetencyLevel {
  CompetencyLevel._();

  static const int min = 0;
  static const int max = 5;
  static const int count = 6;

  static const names = [
    'Beginner', // 0
    'Elementary', // 1
    'Intermediate', // 2
    'Proficient', // 3
    'Advanced', // 4
    'Expert', // 5
  ];

  static String name(int level) => names[level.clamp(min, max).toInt()];

  /// "L3 · Proficient"
  static String short(int level) => 'L$level · ${name(level)}';

  /// Generic wording HRD can start from and then make specific.
  static const standardDescriptions = [
    'Knows the basic concepts and terms; needs guidance for every task.',
    'Does simple tasks with some help; understands the common use cases.',
    'Works independently on routine tasks and follows standard practices.',
    'Handles complex tasks independently and reviews the work of others.',
    'Designs solutions, solves unusual problems and mentors the team.',
    'Recognised authority who sets standards and guides the organisation.',
  ];
}

/// One employee's rating in a competency.
class CompetencyHolder {
  const CompetencyHolder(this.employeeId, this.level, {this.verified = true});

  /// Matches EmployeeRecord.id, e.g. "EMP-1002".
  final String employeeId;

  /// 0–5 on the [CompetencyLevel] scale.
  final int level;

  /// True when the Team Lead has confirmed the level (otherwise self-assessed).
  final bool verified;
}

class Competency {
  const Competency({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.levelDescriptions,
    required this.createdAt,
    required this.createdBy,
    this.logoUrl,
    this.holders = const [],
  });

  /// e.g. "CMP-001".
  final String id;
  final String name;
  final CompetencyCategory category;

  /// One or two sentences: what it is and where it's used.
  final String description;

  /// Exactly [CompetencyLevel.count] entries; index = level (0–5).
  final List<String> levelDescriptions;

  /// Optional link to a logo image. A lettered badge is shown without one.
  final String? logoUrl;

  final List<CompetencyHolder> holders;
  final DateTime createdAt;
  final String createdBy;

  int get holderCount => holders.length;

  int get verifiedCount => holders.where((h) => h.verified).length;

  /// Holders at Level 4 or 5.
  int get advancedCount => holders.where((h) => h.level >= 4).length;

  /// Number of holders at each level, index = level.
  List<int> get levelCounts {
    final counts = List<int>.filled(CompetencyLevel.count, 0);
    for (final h in holders) {
      counts[h.level.clamp(CompetencyLevel.min, CompetencyLevel.max).toInt()]++;
    }
    return counts;
  }

  String levelDescription(int level) =>
      level >= 0 && level < levelDescriptions.length ? levelDescriptions[level] : '';

  bool get hasLogo => (logoUrl ?? '').trim().isNotEmpty;

  /// Letters for the badge when there is no logo:
  /// "Project Management" → "PM", "Java" → "Ja", "SQL" → "SQL".
  String get monogram => monogramFor(name);

  static String monogramFor(String name) {
    final words = name
        .split(RegExp(r'[\s/&+\-]+'))
        .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9#]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first;
    // Short acronyms stay as they are: "SQL", "UX Research" → "UX", "C#".
    if (first.length >= 2 && first.length <= 3 && first == first.toUpperCase()) {
      return first;
    }
    if (words.length == 1) {
      return first.length == 1
          ? first.toUpperCase()
          : first[0].toUpperCase() + first[1].toLowerCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// Case- and space-insensitive key used to stop duplicates.
  static String keyFor(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String get key => keyFor(name);

  /// Text the library search looks in.
  String get searchText => '$id $name ${category.label} $description'.toLowerCase();
}
