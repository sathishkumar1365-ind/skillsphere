import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import 'competency_models.dart';
import 'competency_sample_data.dart';

/// Thrown when a competency can't be added. [message] is safe to show.
class CompetencyException implements Exception {
  const CompetencyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Keeps the competency library and adds new competencies.
///
/// TEMPORARY: works in memory on [sampleCompetencies], so anything added is
/// gone after a page reload. Later, replace the bodies of [load] and [add]
/// with calls to the Spring Boot API; the screens keep working unchanged
/// because they only listen to [competencies].
///
/// The role check in [add] is a convenience for the UI. The real protection
/// must be in Spring Boot: POST /api/competencies only for SUPER_ADMIN.
class CompetencyRepository {
  CompetencyRepository._();

  static final CompetencyRepository instance = CompetencyRepository._();

  /// The whole library. Screens rebuild when it changes.
  final ValueNotifier<List<Competency>> competencies =
      ValueNotifier<List<Competency>>(List<Competency>.unmodifiable(sampleCompetencies));

  /// Competencies added in this session (shown with a "NEW" label).
  final Set<String> _addedThisSession = <String>{};

  bool isNew(Competency competency) => _addedThisSession.contains(competency.id);

  /// Later: GET /api/competencies.
  Future<void> load() async {}

  /// The competency with the same name (ignoring case and extra spaces).
  Competency? findByName(String name) {
    final key = Competency.keyFor(name);
    if (key.isEmpty) return null;
    for (final c in competencies.value) {
      if (c.key == key) return c;
    }
    return null;
  }

  /// Existing competencies whose names look like [name], to avoid near
  /// duplicates such as "Java" vs "Core Java".
  List<Competency> similarTo(String name, {int limit = 4}) {
    final key = Competency.keyFor(name);
    if (key.length < 2) return const [];
    final matches = competencies.value.where((c) {
      return c.key == key || c.key.contains(key) || (c.key.length >= 3 && key.contains(c.key));
    }).toList()
      ..sort((a, b) {
        // Exact match first, then shorter names.
        final exact = (b.key == key ? 1 : 0) - (a.key == key ? 1 : 0);
        return exact != 0 ? exact : a.name.length.compareTo(b.name.length);
      });
    return matches.take(limit).toList();
  }

  /// Adds a competency to the library (HRD team only).
  ///
  /// Later: POST /api/competencies with
  /// `{name, category, description, logoUrl, levels: [{level, description}]}`.
  /// The API answers 409 when the name already exists.
  Future<Competency> add({
    required AppUser by,
    required CompetencyCategory category,
    required String name,
    required String description,
    required List<String> levelDescriptions,
    String? logoUrl,
  }) async {
    _checkCanManage(by);
    final draft = _clean(CompetencyDraft(
      category: category,
      name: name,
      description: description,
      levelDescriptions: levelDescriptions,
      logoUrl: logoUrl,
    ));
    final problem = _problemWith(draft);
    if (problem != null) throw CompetencyException(problem);

    // Short pause so the button's "Adding…" state is visible, like an API call.
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final existing = findByName(draft.name);
    if (existing != null) {
      throw CompetencyException(
          '"${existing.name}" is already in the library (${existing.category.label}).');
    }
    final competency = _create(draft, id: _idFor(_highestNumber() + 1), by: by);
    _addedThisSession.add(competency.id);
    competencies.value = List<Competency>.unmodifiable([...competencies.value, competency]);
    return competency;
  }

  /// Adds many competencies at once, e.g. from an Excel or CSV file
  /// (HRD team only). Drafts whose name is already in the library, or
  /// repeats an earlier draft, are skipped. Returns the ones added.
  ///
  /// Later: POST /api/competencies/bulk with the same rules; the API should
  /// add the valid rows in one transaction and report the skipped ones.
  Future<List<Competency>> addAll({
    required AppUser by,
    required List<CompetencyDraft> drafts,
  }) async {
    _checkCanManage(by);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final taken = {for (final c in competencies.value) c.key};
    var number = _highestNumber();
    final added = <Competency>[];
    for (final raw in drafts) {
      final draft = _clean(raw);
      final key = Competency.keyFor(draft.name);
      if (_problemWith(draft) != null || taken.contains(key)) continue;
      taken.add(key);
      number++;
      added.add(_create(draft, id: _idFor(number), by: by));
    }
    if (added.isEmpty) return const [];
    _addedThisSession.addAll(added.map((c) => c.id));
    competencies.value = List<Competency>.unmodifiable([...competencies.value, ...added]);
    return added;
  }

  void _checkCanManage(AppUser by) {
    if (!by.role.canManageCompetencies) {
      throw const CompetencyException('Only the HRD team can add competencies.');
    }
  }

  static CompetencyDraft _clean(CompetencyDraft d) {
    final logo = d.logoUrl?.trim() ?? '';
    return CompetencyDraft(
      category: d.category,
      name: d.name.trim().replaceAll(RegExp(r'\s+'), ' '),
      description: d.description.trim(),
      levelDescriptions: [for (final l in d.levelDescriptions) l.trim()],
      logoUrl: logo.isEmpty ? null : logo,
    );
  }

  /// The first rule a (cleaned) draft breaks, or null when it is fine.
  static String? _problemWith(CompetencyDraft d) {
    if (d.name.isEmpty) return 'The name is missing.';
    if (d.name.length > CompetencyRules.nameMax) {
      return 'The name is longer than ${CompetencyRules.nameMax} characters.';
    }
    if (d.description.length < CompetencyRules.descriptionMin) {
      return 'The description needs at least ${CompetencyRules.descriptionMin} characters.';
    }
    if (d.description.length > CompetencyRules.descriptionMax) {
      return 'The description is longer than ${CompetencyRules.descriptionMax} characters.';
    }
    final logo = d.logoUrl;
    if (logo != null && !CompetencyRules.isValidLink(logo)) {
      return 'The logo link must start with https://';
    }
    if (d.levelDescriptions.length != CompetencyLevel.count ||
        d.levelDescriptions.any((l) => l.isEmpty)) {
      return 'Describe every level from 0 to 5.';
    }
    if (d.levelDescriptions.any((l) => l.length > CompetencyRules.levelMax)) {
      return 'A level description is longer than ${CompetencyRules.levelMax} characters.';
    }
    return null;
  }

  static Competency _create(CompetencyDraft d, {required String id, required AppUser by}) =>
      Competency(
        id: id,
        name: d.name,
        category: d.category,
        description: d.description,
        levelDescriptions: List<String>.unmodifiable(d.levelDescriptions),
        logoUrl: d.logoUrl,
        createdAt: DateTime.now(),
        createdBy: by.name,
      );

  int _highestNumber() {
    var highest = 0;
    for (final c in competencies.value) {
      final number = int.tryParse(c.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (number > highest) highest = number;
    }
    return highest;
  }

  static String _idFor(int number) => 'CMP-${number.toString().padLeft(3, '0')}';
}
