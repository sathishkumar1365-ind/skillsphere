import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/data/competency_repository.dart';
import 'additional_competency.dart';
import 'additional_competency_sample_data.dart' show sampleAdditionalCompetencies;

/// Thrown when an additional competency can't be added or removed.
class AdditionalCompetencyException implements Exception {
  const AdditionalCompetencyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A name in use across the organisation and how many employees list it.
class AdditionalNameCount {
  const AdditionalNameCount(this.name, this.count);

  final String name;
  final int count;
}

/// Everyone's Additional Competencies.
///
/// TEMPORARY: in memory on [sampleAdditionalCompetencies], so changes are
/// gone after a reload. Replace the bodies of [add] and [remove] with API
/// calls later; the screens only listen to [entries].
///
/// The API must take the employee from the JWT (never from the request) so
/// people can only change their own list.
class AdditionalCompetencyRepository {
  AdditionalCompetencyRepository._();

  static final AdditionalCompetencyRepository instance = AdditionalCompetencyRepository._();

  final ValueNotifier<List<AdditionalCompetency>> entries =
      ValueNotifier<List<AdditionalCompetency>>(
          List<AdditionalCompetency>.unmodifiable(sampleAdditionalCompetencies));

  /// One employee's list, newest first.
  List<AdditionalCompetency> forEmployee(String employeeId) =>
      entries.value.where((e) => e.employeeId == employeeId).toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  /// Names in use, most common first.
  List<AdditionalNameCount> get nameCounts {
    final counts = <String, int>{};
    final display = <String, String>{};
    for (final e in entries.value) {
      counts[e.key] = (counts[e.key] ?? 0) + 1;
      display.putIfAbsent(e.key, () => e.name);
    }
    final list = [
      for (final key in counts.keys) AdditionalNameCount(display[key]!, counts[key]!),
    ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
    return list;
  }

  /// Names to offer while [employeeId] types [typed]: names colleagues use
  /// plus the standard suggestions, without the ones they already have.
  List<String> suggestionsFor(String typed, {required String employeeId, int limit = 8}) {
    final own = {for (final e in forEmployee(employeeId)) e.key};
    final query = AdditionalCompetency.keyFor(typed);
    final seen = <String>{};
    final result = <String>[];
    void offer(String name) {
      final key = AdditionalCompetency.keyFor(name);
      if (own.contains(key) || !seen.add(key)) return;
      if (query.isNotEmpty && (!key.contains(query) || key == query)) return;
      result.add(name);
    }

    for (final n in nameCounts) {
      offer(n.name);
    }
    for (final s in AdditionalCompetencyRules.suggestions) {
      offer(s);
    }
    return result.take(limit).toList();
  }

  /// Adds to the signed-in user's own list.
  Future<AdditionalCompetency> add({
    required AppUser by,
    required String name,
    String? note,
    String? link,
  }) async {
    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final cleanNote = note?.trim() ?? '';
    final cleanLink = link?.trim() ?? '';
    if (cleanName.isEmpty) {
      throw const AdditionalCompetencyException('Enter a name.');
    }
    if (cleanName.length > AdditionalCompetencyRules.nameMax) {
      throw const AdditionalCompetencyException(
          'Keep the name under ${AdditionalCompetencyRules.nameMax} characters.');
    }
    if (cleanNote.length > AdditionalCompetencyRules.noteMax) {
      throw const AdditionalCompetencyException(
          'Keep the note under ${AdditionalCompetencyRules.noteMax} characters.');
    }
    if (cleanLink.isNotEmpty && !CompetencyRules.isValidLink(cleanLink)) {
      throw const AdditionalCompetencyException('Enter a full link starting with https://');
    }
    final problem = nameProblem(cleanName, employeeId: by.id);
    if (problem != null) throw AdditionalCompetencyException(problem);
    if (forEmployee(by.id).length >= AdditionalCompetencyRules.maxPerEmployee) {
      throw const AdditionalCompetencyException(
          'You can list up to ${AdditionalCompetencyRules.maxPerEmployee} additional competencies.');
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));

    final entry = AdditionalCompetency(
      id: _nextId(),
      employeeId: by.id,
      // Reuse the spelling colleagues already use ("poster design" → "Poster Design").
      name: _existingSpelling(cleanName) ?? cleanName,
      note: cleanNote.isEmpty ? null : cleanNote,
      link: cleanLink.isEmpty ? null : cleanLink,
      addedAt: DateTime.now(),
    );
    entries.value = List<AdditionalCompetency>.unmodifiable([...entries.value, entry]);
    return entry;
  }

  /// HRD adds names to a new employee's list while onboarding them (from the
  /// onboarding form or a bulk import). Names the employee already has, or
  /// that are in the competency library, are skipped. Returns those added.
  ///
  /// Later: POST /api/employees/{id}/additional-competencies (SUPER_ADMIN).
  List<AdditionalCompetency> addForEmployee({
    required AppUser by,
    required String employeeId,
    required List<String> names,
  }) {
    if (!by.role.canManageOrganization) {
      throw const AdditionalCompetencyException(
          'Only the HRD team can add competencies for another employee.');
    }
    final added = <AdditionalCompetency>[];
    final taken = {for (final e in forEmployee(employeeId)) e.key};
    var number = _highestNumber();
    for (final raw in names) {
      final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      final key = AdditionalCompetency.keyFor(name);
      if (name.isEmpty ||
          name.length > AdditionalCompetencyRules.nameMax ||
          taken.contains(key) ||
          CompetencyRepository.instance.findByName(name) != null ||
          taken.length >= AdditionalCompetencyRules.maxPerEmployee) {
        continue;
      }
      taken.add(key);
      number++;
      added.add(AdditionalCompetency(
        id: 'ADD-${number.toString().padLeft(3, '0')}',
        employeeId: employeeId,
        name: _existingSpelling(name) ?? name,
        addedAt: DateTime.now(),
      ));
    }
    if (added.isNotEmpty) {
      entries.value = List<AdditionalCompetency>.unmodifiable([...entries.value, ...added]);
    }
    return added;
  }

  int _highestNumber() {
    var highest = 0;
    for (final e in entries.value) {
      final n = int.tryParse(e.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > highest) highest = n;
    }
    return highest;
  }

  /// Removes one of the signed-in user's own entries.
  Future<void> remove(AdditionalCompetency entry, {required AppUser by}) async {
    if (entry.employeeId != by.id) {
      throw const AdditionalCompetencyException('You can only remove your own entries.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    entries.value = List<AdditionalCompetency>.unmodifiable(
        entries.value.where((e) => e.id != entry.id));
  }

  /// Why [name] can't be added for [employeeId], or null when it can.
  String? nameProblem(String name, {required String employeeId}) {
    final key = AdditionalCompetency.keyFor(name);
    if (key.isEmpty) return null;
    if (forEmployee(employeeId).any((e) => e.key == key)) {
      return 'You already listed "${name.trim()}".';
    }
    final core = CompetencyRepository.instance.findByName(name);
    if (core != null) {
      return '"${core.name}" is in the company competency library '
          '(${core.category.label}), so it isn\'t an additional competency.';
    }
    return null;
  }

  String? _existingSpelling(String name) {
    final key = AdditionalCompetency.keyFor(name);
    for (final e in entries.value) {
      if (e.key == key) return e.name;
    }
    for (final s in AdditionalCompetencyRules.suggestions) {
      if (AdditionalCompetency.keyFor(s) == key) return s;
    }
    return null;
  }

  String _nextId() {
    var highest = 0;
    for (final e in entries.value) {
      final n = int.tryParse(e.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > highest) highest = n;
    }
    return 'ADD-${(highest + 1).toString().padLeft(3, '0')}';
  }
}