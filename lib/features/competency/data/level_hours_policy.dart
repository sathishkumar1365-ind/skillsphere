// Level-up hours policy: how many hours of learning and practice an
// employee needs between two confirmed levels, per competency category.
//
//   Skill    L0 → L1  200 h      Domain   L0 → L1  100 h
//   Language L0 → L1  250 h      Tool     L0 → L1  300 h
//
// PLACEHOLDER: only the L0 → L1 numbers come from HR so far; the later
// steps are sample numbers until the real policy is shared. HRD can change
// every number in the console (Approvals › Hours policy) without a code
// change, and they live here in one place.
//
// How the hours are used
// * A Team Lead enters the hours acquired since the last confirmed level
//   when raising a level-up; the request shows them against this policy.
// * Below the policy is a WARNING for HR, not a block: HR decides.
// * A jump over several levels needs the sum of the steps (L1 → L3 =
//   L1→L2 + L2→L3). A competency that isn't held yet starts at L0, which
//   needs no hours: "not held → L2" = L0→L1 + L1→L2.
//
// Spring Boot API later:
//   GET /api/policies/level-hours            (everyone signed in)
//   PUT /api/policies/level-hours            (SUPER_ADMIN)
//   table level_hours_policy(category, from_level 0–4, hours, updated_by, updated_at)

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import 'competency_models.dart';
import 'competency_repository.dart';

class LevelHoursPolicy {
  LevelHoursPolicy._();

  static final LevelHoursPolicy instance = LevelHoursPolicy._();

  /// Hours per step, index = from level: [L0→L1, L1→L2, L2→L3, L3→L4, L4→L5].
  /// Only the first column is from HR; the rest are placeholders.
  static const Map<CompetencyCategory, List<int>> defaults = {
    CompetencyCategory.skill: [200, 280, 360, 450, 550],
    CompetencyCategory.tool: [300, 340, 400, 460, 520],
    CompetencyCategory.language: [250, 320, 400, 480, 560],
    CompetencyCategory.domain: [100, 160, 220, 300, 380],
  };

  /// Number of steps on the 0–5 scale.
  static const int steps = CompetencyLevel.max - CompetencyLevel.min;

  /// Largest number HRD may enter for one step.
  static const int maxStepHours = 5000;

  /// The policy in force. Screens rebuild when HRD changes it.
  final ValueNotifier<Map<CompetencyCategory, List<int>>> hours =
      ValueNotifier<Map<CompetencyCategory, List<int>>>(_copy(defaults));

  /// Who changed it last (null = still the defaults).
  final ValueNotifier<({String by, DateTime at})?> lastChange = ValueNotifier<({String by, DateTime at})?>(null);

  static Map<CompetencyCategory, List<int>> _copy(Map<CompetencyCategory, List<int>> source) => {
        for (final c in CompetencyCategory.values) c: List<int>.unmodifiable(source[c] ?? List<int>.filled(steps, 0)),
      };

  /// Hours to go from [fromLevel] to the next level (0 at L5 or below L0).
  int stepHours(CompetencyCategory category, int fromLevel) {
    if (fromLevel < CompetencyLevel.min || fromLevel >= CompetencyLevel.max) return 0;
    final list = hours.value[category];
    if (list == null || fromLevel >= list.length) return 0;
    return list[fromLevel];
  }

  /// Hours from [from] (null = not held yet, which starts at L0 for free)
  /// up to [to].
  int hoursBetween(CompetencyCategory category, int? from, int to) {
    var start = from ?? CompetencyLevel.min;
    if (start < CompetencyLevel.min) start = CompetencyLevel.min;
    var total = 0;
    for (var level = start; level < to && level < CompetencyLevel.max; level++) {
      total += stepHours(category, level);
    }
    return total;
  }

  /// Hours needed for the level after [level], or null at L5.
  int? hoursToNext(CompetencyCategory category, int level) =>
      level >= CompetencyLevel.max ? null : stepHours(category, level);

  /// Same as [hoursBetween] for a competency id (0 when it's unknown).
  int hoursFor(String competencyId, int? from, int to) {
    final competency = CompetencyRepository.instance.byId(competencyId);
    return competency == null ? 0 : hoursBetween(competency.category, from, to);
  }

  /// HRD changes one step. [fromLevel] 0–4.
  void setStep({
    required AppUser by,
    required CompetencyCategory category,
    required int fromLevel,
    required int value,
  }) {
    _requireHrd(by);
    if (fromLevel < CompetencyLevel.min || fromLevel >= CompetencyLevel.max) {
      throw const CompetencyException('Choose a step from L0 → L1 to L4 → L5.');
    }
    if (value < 0 || value > maxStepHours) {
      throw const CompetencyException('Enter 0 to $maxStepHours hours.');
    }
    final next = _copy(hours.value);
    final list = [...next[category]!];
    if (list[fromLevel] == value) return;
    list[fromLevel] = value;
    next[category] = List<int>.unmodifiable(list);
    hours.value = Map<CompetencyCategory, List<int>>.unmodifiable(next);
    lastChange.value = (by: by.name, at: DateTime.now());
  }

  /// Back to [defaults] (HRD).
  void reset({required AppUser by}) {
    _requireHrd(by);
    hours.value = _copy(defaults);
    lastChange.value = (by: by.name, at: DateTime.now());
  }

  bool get isDefault {
    for (final c in CompetencyCategory.values) {
      if (!listEquals(hours.value[c], defaults[c])) return false;
    }
    return true;
  }

  static void _requireHrd(AppUser by) {
    if (!by.role.canManageCompetencies) {
      throw const CompetencyException('Only the HRD team can change the hours policy.');
    }
  }
}

/// "1,250 h"
String hoursLabel(int hours) {
  final text = hours.abs().toString();
  final buffer = StringBuffer(hours < 0 ? '-' : '');
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return '$buffer h';
}
