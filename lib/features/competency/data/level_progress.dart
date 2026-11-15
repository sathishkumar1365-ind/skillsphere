// Level history of each acquired competency: every time a level is
// confirmed (approved level-up, HRD change, onboarding) one record is kept
// with the hours acquired since the previous confirmation.
//
// * "Hours since confirmed" = the hours a Team Lead entered with the
//   level-up request, i.e. what was acquired between the previous
//   confirmed level and this one.
// * "Last confirmed" = date of the latest confirmation (set when HR
//   approves a level-up).
// * "Total hours" = sum of the hours of every record from the starting
//   point (the first level recorded in SkillSphere) onwards.
//
// Spring Boot API later:
//   GET /api/employees/{id}/competencies/{competencyId}/history
//   table employee_competency_history(id, employee_id, competency_id,
//         from_level NULL, to_level, hours, source, confirmed_on,
//         confirmed_by, request_id NULL)
//   employee_competency.last_confirmed_on / total_hours can be kept in step
//   by the approve transaction (or computed in a view).

import 'package:flutter/foundation.dart';

import 'level_progress_sample_data.dart';

/// How a level got onto the profile.
enum LevelChangeSource {
  /// First level recorded in SkillSphere, confirmed by HR (sample data and
  /// the move from the old system).
  starting('Starting level', confirms: true),

  /// Entered by HRD when onboarding the employee.
  onboarding('Onboarded', confirms: true),

  /// A Team Lead's level-up request approved by HR.
  approval('Level-up approved', confirms: true),

  /// Changed directly by HRD (Update profile).
  hrd('Set by HRD', confirms: true),

  /// Declared by the employee, not confirmed yet.
  selfAssessed('Self-assessed', confirms: false);

  const LevelChangeSource(this.label, {required this.confirms});

  final String label;

  /// False for self-assessed levels: they don't set "Last confirmed".
  final bool confirms;

  String get apiValue => switch (this) {
        LevelChangeSource.starting => 'STARTING',
        LevelChangeSource.onboarding => 'ONBOARDING',
        LevelChangeSource.approval => 'APPROVAL',
        LevelChangeSource.hrd => 'HRD',
        LevelChangeSource.selfAssessed => 'SELF_ASSESSED',
      };
}

/// One confirmed (or self-assessed) level of one competency.
class LevelConfirmation {
  const LevelConfirmation({
    required this.id,
    required this.employeeId,
    required this.competencyId,
    required this.toLevel,
    required this.hours,
    required this.confirmedOn,
    required this.confirmedBy,
    required this.source,
    this.fromLevel,
    this.requestId,
  });

  /// e.g. "LVC-00042".
  final String id;
  final String employeeId;
  final String competencyId;

  /// Level before (null = not held).
  final int? fromLevel;
  final int toLevel;

  /// Hours acquired since the previous confirmation (entered by the TL).
  final int hours;
  final DateTime confirmedOn;

  /// Who approved / set it.
  final String confirmedBy;
  final LevelChangeSource source;

  /// The level-up request this came from, e.g. "APR-0004".
  final String? requestId;

  bool get confirms => source.confirms;

  /// "L2 → L3", "New → L2", "L2" (starting point).
  String get stepLabel {
    final from = fromLevel;
    if (source == LevelChangeSource.starting || source == LevelChangeSource.selfAssessed) {
      return 'L$toLevel';
    }
    if (from == null) return 'New → L$toLevel';
    if (from == toLevel) return 'L$toLevel confirmed';
    return 'L$from → L$toLevel';
  }
}

/// Everything known about how one employee got to their level.
class LevelProgress {
  const LevelProgress(this.history);

  /// Oldest first.
  final List<LevelConfirmation> history;

  bool get isEmpty => history.isEmpty;

  /// The latest record that confirms a level.
  LevelConfirmation? get lastConfirmation {
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i].confirms) return history[i];
    }
    return null;
  }

  DateTime? get lastConfirmedOn => lastConfirmation?.confirmedOn;

  /// Hours acquired between the previous confirmation and the last one.
  int? get hoursAtLastConfirmation => lastConfirmation?.hours;

  /// Sum from the starting point.
  int get totalHours => history.fold<int>(0, (sum, r) => sum + r.hours);

  /// First record (the starting point of the level-ups).
  LevelConfirmation? get start => history.isEmpty ? null : history.first;

  /// Level-ups after the starting point.
  int get levelUps => history.where((r) => r.source == LevelChangeSource.approval).length;
}

class LevelProgressRepository {
  LevelProgressRepository._();

  static final LevelProgressRepository instance = LevelProgressRepository._();

  /// Every record, in the order they were added.
  final ValueNotifier<List<LevelConfirmation>> confirmations =
      ValueNotifier<List<LevelConfirmation>>(List<LevelConfirmation>.unmodifiable(sampleLevelConfirmations()));

  List<LevelConfirmation>? _indexed;
  Map<String, List<LevelConfirmation>> _byKey = const {};

  static String _key(String employeeId, String competencyId) => '$employeeId|$competencyId';

  void _reindex() {
    final list = confirmations.value;
    if (identical(list, _indexed)) return;
    final map = <String, List<LevelConfirmation>>{};
    for (final r in list) {
      (map[_key(r.employeeId, r.competencyId)] ??= <LevelConfirmation>[]).add(r);
    }
    for (final entries in map.values) {
      entries.sort((a, b) {
        final byDate = a.confirmedOn.compareTo(b.confirmedOn);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    }
    _byKey = map;
    _indexed = list;
  }

  /// History of [employeeId] in [competencyId], oldest first.
  List<LevelConfirmation> historyFor(String employeeId, String competencyId) {
    _reindex();
    return List<LevelConfirmation>.unmodifiable(_byKey[_key(employeeId, competencyId)] ?? const []);
  }

  LevelProgress progressOf(String employeeId, String competencyId) =>
      LevelProgress(historyFor(employeeId, competencyId));

  /// Adds one record. Called by CompetencyRepository.setLevels, so every
  /// level change (approval, HRD edit, onboarding) is kept.
  LevelConfirmation record({
    required String employeeId,
    required String competencyId,
    required int? fromLevel,
    required int toLevel,
    required int hours,
    required LevelChangeSource source,
    required String by,
    String? requestId,
    DateTime? on,
  }) {
    var highest = 0;
    for (final r in confirmations.value) {
      final n = int.tryParse(r.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > highest) highest = n;
    }
    final entry = LevelConfirmation(
      id: 'LVC-${(highest + 1).toString().padLeft(5, '0')}',
      employeeId: employeeId,
      competencyId: competencyId,
      fromLevel: fromLevel,
      toLevel: toLevel,
      hours: hours < 0 ? 0 : hours,
      confirmedOn: on ?? DateTime.now(),
      confirmedBy: by,
      source: source,
      requestId: requestId,
    );
    confirmations.value = List<LevelConfirmation>.unmodifiable([...confirmations.value, entry]);
    return entry;
  }
}
