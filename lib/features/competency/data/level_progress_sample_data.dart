// Placeholder level histories for the sample employees, so "Last
// confirmed", "Hours since confirmed" and "Total hours" have something to
// show before the Spring Boot API exists.
//
// Built from the sample holders (competency_sample_data.dart): every
// verified holder gets a starting level and 0–3 approved level-ups with
// hours close to the policy; self-assessed holders only have their
// self-assessed level. The same input always gives the same history.
//
// The five APPROVED sample requests in admin_sample_data.dart
// (APR-0001 … APR-0005) are reproduced exactly – keep them in step.

import 'competency_sample_data.dart';
import 'level_hours_policy.dart';
import 'level_progress.dart';

const _hrd = 'Anitha Joseph';

/// Approved sample level-ups (same as admin_sample_data.dart).
const List<({String request, String employee, String competency, int? from, int to, int hours, int y, int m, int d})>
    _approved = [
  (request: 'APR-0001', employee: 'EMP-1008', competency: 'CMP-003', from: 2, to: 3, hours: 430, y: 2026, m: 9, d: 24),
  (request: 'APR-0002', employee: 'EMP-1014', competency: 'CMP-009', from: 2, to: 3, hours: 415, y: 2026, m: 10, d: 3),
  (request: 'APR-0003', employee: 'EMP-1011', competency: 'CMP-011', from: null, to: 2, hours: 500, y: 2026, m: 10, d: 9),
  (request: 'APR-0004', employee: 'EMP-1012', competency: 'CMP-002', from: null, to: 2, hours: 540, y: 2026, m: 10, d: 15),
  (request: 'APR-0005', employee: 'EMP-1020', competency: 'CMP-006', from: null, to: 2, hours: 600, y: 2026, m: 10, d: 21),
];

/// Small deterministic hash (no dart:math Random, so the data never changes).
int _seed(String a, String b) {
  var h = 7;
  for (final unit in '$a/$b'.codeUnits) {
    h = (h * 31 + unit) & 0x7fffffff;
  }
  return h;
}

int _roundTo5(num value) => ((value / 5).round() * 5).toInt();

List<LevelConfirmation> sampleLevelConfirmations() {
  final list = <LevelConfirmation>[];
  var number = 0;
  void add({
    required String employee,
    required String competency,
    required int? from,
    required int to,
    required int hours,
    required DateTime on,
    required LevelChangeSource source,
    String? request,
  }) {
    list.add(LevelConfirmation(
      id: 'LVC-${(++number).toString().padLeft(5, '0')}',
      employeeId: employee,
      competencyId: competency,
      fromLevel: from,
      toLevel: to,
      hours: hours,
      confirmedOn: on,
      confirmedBy: _hrd,
      source: source,
      requestId: request,
    ));
  }

  final approvedByKey = {for (final a in _approved) '${a.employee}|${a.competency}': a};

  for (final competency in sampleCompetencies) {
    final steps = LevelHoursPolicy.defaults[competency.category]!;
    for (final holder in competency.holders) {
      final seed = _seed(holder.employeeId, competency.id);

      if (!holder.verified) {
        add(
          employee: holder.employeeId,
          competency: competency.id,
          from: null,
          to: holder.level,
          hours: 0,
          on: DateTime(2026, 1 + seed % 9, 1 + seed % 27),
          source: LevelChangeSource.selfAssessed,
        );
        continue;
      }

      final known = approvedByKey['${holder.employeeId}|${competency.id}'];
      // Generated part ends at [topLevel] on [lastDate].
      final topLevel = known == null ? holder.level : known.from;
      final lastDate = known == null
          ? DateTime(2026, 10, 20).subtract(Duration(days: seed % 420))
          : DateTime(known.y, known.m, known.d).subtract(Duration(days: 120 + seed % 90));

      if (topLevel != null) {
        final ups = topLevel < seed % 4 ? topLevel : seed % 4;
        final startLevel = topLevel - ups;
        // Dates from the last step backwards.
        final dates = <DateTime>[lastDate];
        for (var i = 1; i <= ups; i++) {
          dates.add(dates.last.subtract(Duration(days: 110 + (seed >> i) % 160)));
        }
        final startDate = dates.last.subtract(Duration(days: ups == 0 ? 0 : 60 + seed % 90));
        add(
          employee: holder.employeeId,
          competency: competency.id,
          from: null,
          to: startLevel,
          hours: 0,
          on: startDate,
          source: LevelChangeSource.starting,
        );
        for (var i = 0; i < ups; i++) {
          final from = startLevel + i;
          final policy = steps[from];
          final factor = 85 + (seed >> (i + 3)) % 50; // 85–134 % of the policy
          add(
            employee: holder.employeeId,
            competency: competency.id,
            from: from,
            to: from + 1,
            hours: _roundTo5(policy * factor / 100),
            on: dates[ups - 1 - i],
            source: LevelChangeSource.approval,
          );
        }
      }

      if (known != null) {
        add(
          employee: holder.employeeId,
          competency: competency.id,
          from: known.from,
          to: known.to,
          hours: known.hours,
          on: DateTime(known.y, known.m, known.d),
          source: LevelChangeSource.approval,
          request: known.request,
        );
      }
    }
  }
  return list;
}
