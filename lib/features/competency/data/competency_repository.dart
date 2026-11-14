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
    if (!by.role.canManageCompetencies) {
      throw const CompetencyException('Only the HRD team can add competencies.');
    }
    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final levels = levelDescriptions.map((d) => d.trim()).toList();
    if (cleanName.isEmpty || description.trim().isEmpty) {
      throw const CompetencyException('Name and description are required.');
    }
    if (levels.length != CompetencyLevel.count || levels.any((d) => d.isEmpty)) {
      throw const CompetencyException('Describe every level from 0 to 5.');
    }

    // Short pause so the button's "Adding…" state is visible, like an API call.
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final existing = findByName(cleanName);
    if (existing != null) {
      throw CompetencyException(
          '"${existing.name}" is already in the library (${existing.category.label}).');
    }

    final logo = logoUrl?.trim();
    final competency = Competency(
      id: _nextId(),
      name: cleanName,
      category: category,
      description: description.trim(),
      levelDescriptions: List<String>.unmodifiable(levels),
      logoUrl: (logo == null || logo.isEmpty) ? null : logo,
      createdAt: DateTime.now(),
      createdBy: by.name,
    );
    _addedThisSession.add(competency.id);
    competencies.value =
        List<Competency>.unmodifiable([...competencies.value, competency]);
    return competency;
  }

  String _nextId() {
    var highest = 0;
    for (final c in competencies.value) {
      final number = int.tryParse(c.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (number > highest) highest = number;
    }
    return 'CMP-${(highest + 1).toString().padLeft(3, '0')}';
  }
}
