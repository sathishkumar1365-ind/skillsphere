// Level-up approvals. A Team Lead asks HR to raise a team member's level in
// a competency (usually to close a skill gap for a project), with a note and
// optional proof. HR approves (the level changes and is marked verified) or
// rejects with a reason.
//
// Spring Boot API later:
//   POST /api/approvals/level-ups               (ADMIN; employee must be in the TL's department)
//   GET  /api/approvals/level-ups?status=&departmentId=&q=   (SUPER_ADMIN)
//   POST /api/approvals/level-ups/{id}/approve  (SUPER_ADMIN) {comment}
//   POST /api/approvals/level-ups/{id}/reject   (SUPER_ADMIN) {reason}
// Approving must update employee_competency in the same transaction.

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/data/competency_repository.dart';
import 'admin_base.dart';
import 'admin_sample_data.dart';
import 'employees.dart';

enum ApprovalStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const ApprovalStatus(this.label);
  final String label;
}

class LevelUpRequest {
  const LevelUpRequest({
    required this.id,
    required this.employeeId,
    required this.competencyId,
    required this.toLevel,
    required this.raisedById,
    required this.raisedByName,
    required this.raisedAt,
    required this.note,
    this.fromLevel,
    this.requiredLevel,
    this.projectIds = const [],
    this.evidence = '',
    this.status = ApprovalStatus.pending,
    this.decidedByName,
    this.decidedAt,
    this.decisionNote = '',
  });

  /// e.g. "APR-0007".
  final String id;
  final String employeeId;
  final String competencyId;

  /// Level when the request was raised (null = not held yet).
  final int? fromLevel;
  final int toLevel;

  /// Highest level the employee's projects need, if any.
  final int? requiredLevel;

  /// Projects that need this competency (context for HR).
  final List<String> projectIds;

  /// Why the TL thinks the level is reached.
  final String note;

  /// Proof: a link, or the name of a certificate on the profile.
  final String evidence;
  final String raisedById;
  final String raisedByName;
  final DateTime raisedAt;
  final ApprovalStatus status;
  final String? decidedByName;
  final DateTime? decidedAt;

  /// Approval comment or rejection reason.
  final String decisionNote;

  bool get isNewSkill => fromLevel == null;
  bool get isPending => status == ApprovalStatus.pending;

  /// Steps up the scale: L1 → L3 is 2.
  int get jump => toLevel - (fromLevel ?? -1);

  LevelUpRequest decide({
    required ApprovalStatus status,
    required String by,
    required String note,
  }) =>
      LevelUpRequest(
        id: id,
        employeeId: employeeId,
        competencyId: competencyId,
        toLevel: toLevel,
        raisedById: raisedById,
        raisedByName: raisedByName,
        raisedAt: raisedAt,
        note: this.note,
        fromLevel: fromLevel,
        requiredLevel: requiredLevel,
        projectIds: projectIds,
        evidence: evidence,
        status: status,
        decidedByName: by,
        decidedAt: DateTime.now(),
        decisionNote: note,
      );
}

class ApprovalRules {
  ApprovalRules._();

  static const int noteMin = 10;
  static const int noteMax = 300;
  static const int evidenceMax = 200;
  static const int reasonMin = 5;
  static const int reasonMax = 300;
}

class ApprovalRepository {
  ApprovalRepository._();

  static final ApprovalRepository instance = ApprovalRepository._();

  /// Newest first.
  final ValueNotifier<List<LevelUpRequest>> requests =
      ValueNotifier<List<LevelUpRequest>>(List<LevelUpRequest>.unmodifiable(sampleLevelUpRequests()));

  List<LevelUpRequest> get pending => requests.value.where((r) => r.isPending).toList();

  int get pendingCount => requests.value.where((r) => r.isPending).length;

  LevelUpRequest? pendingFor(String employeeId, String competencyId) {
    for (final r in requests.value) {
      if (r.isPending && r.employeeId == employeeId && r.competencyId == competencyId) return r;
    }
    return null;
  }

  List<LevelUpRequest> forEmployee(String employeeId) =>
      requests.value.where((r) => r.employeeId == employeeId).toList()
        ..sort((a, b) => b.raisedAt.compareTo(a.raisedAt));

  /// A Team Lead asks HR to raise [employeeId]'s level in [competencyId]
  /// to [toLevel].
  Future<LevelUpRequest> raise({
    required AppUser by,
    required String employeeId,
    required String competencyId,
    required int toLevel,
    required String note,
    String evidence = '',
    int? requiredLevel,
    List<String> projectIds = const [],
  }) async {
    final employees = EmployeeRepository.instance;
    final employee = employees.byId(employeeId);
    if (employee == null) throw const AdminException('This employee no longer exists.');
    if (!employees.canRequestLevelUp(by, employee)) {
      throw const AdminException('Only the Team Lead of this department can request a level-up.');
    }
    final competency = CompetencyRepository.instance.byId(competencyId);
    if (competency == null) throw const AdminException('This competency is no longer in the library.');
    final current = CompetencyRepository.instance.holderOf(competencyId, employeeId)?.level;
    if (toLevel < CompetencyLevel.min || toLevel > CompetencyLevel.max) {
      throw const AdminException('Choose a level from 0 to 5.');
    }
    if (current != null && toLevel <= current) {
      throw AdminException('${employee.firstName} is already at L$current. Choose a higher level.');
    }
    final cleanNote = note.trim();
    if (cleanNote.length < ApprovalRules.noteMin) {
      throw const AdminException('Tell HR why (at least ${ApprovalRules.noteMin} characters).');
    }
    if (cleanNote.length > ApprovalRules.noteMax) {
      throw const AdminException('Keep the note under ${ApprovalRules.noteMax} characters.');
    }
    if (evidence.trim().length > ApprovalRules.evidenceMax) {
      throw const AdminException('Keep the proof under ${ApprovalRules.evidenceMax} characters.');
    }
    final existing = pendingFor(employeeId, competencyId);
    if (existing != null) {
      throw AdminException('A request for ${competency.name} '
          '(→ L${existing.toLevel}) is already waiting for HR.');
    }
    await apiPause(450);
    final request = LevelUpRequest(
      id: nextId('APR-', requests.value.map((r) => r.id), width: 4),
      employeeId: employeeId,
      competencyId: competencyId,
      fromLevel: current,
      toLevel: toLevel,
      requiredLevel: requiredLevel,
      projectIds: List<String>.unmodifiable(projectIds),
      note: cleanNote,
      evidence: evidence.trim(),
      raisedById: by.id,
      raisedByName: by.name,
      raisedAt: DateTime.now(),
    );
    requests.value = List<LevelUpRequest>.unmodifiable([request, ...requests.value]);
    return request;
  }

  /// HR approves: the employee's level becomes [LevelUpRequest.toLevel]
  /// (verified). Several requests can be approved at once.
  Future<int> approve({
    required AppUser by,
    required List<LevelUpRequest> items,
    String comment = '',
  }) async {
    requireHrd(by, 'approve level-ups');
    final ids = {for (final r in items) if (r.isPending) r.id};
    if (ids.isEmpty) return 0;
    await apiPause(450);
    var count = 0;
    final next = <LevelUpRequest>[];
    for (final r in requests.value) {
      if (!ids.contains(r.id) || !r.isPending) {
        next.add(r);
        continue;
      }
      final current = CompetencyRepository.instance.holderOf(r.competencyId, r.employeeId)?.level;
      // Never lower a level that HRD has raised further in the meantime.
      final level = current != null && current > r.toLevel ? current : r.toLevel;
      if (CompetencyRepository.instance.byId(r.competencyId) != null) {
        CompetencyRepository.instance.setLevels(
          by: by,
          employeeId: r.employeeId,
          levels: {r.competencyId: level},
        );
      }
      next.add(r.decide(status: ApprovalStatus.approved, by: by.name, note: comment.trim()));
      count++;
    }
    requests.value = List<LevelUpRequest>.unmodifiable(next);
    return count;
  }

  /// HR rejects with a [reason] the Team Lead will see.
  Future<void> reject({
    required AppUser by,
    required LevelUpRequest request,
    required String reason,
  }) async {
    requireHrd(by, 'reject level-ups');
    final clean = reason.trim();
    if (clean.length < ApprovalRules.reasonMin) {
      throw const AdminException('Give the Team Lead a short reason.');
    }
    if (clean.length > ApprovalRules.reasonMax) {
      throw const AdminException('Keep the reason under ${ApprovalRules.reasonMax} characters.');
    }
    await apiPause(350);
    requests.value = List<LevelUpRequest>.unmodifiable([
      for (final r in requests.value)
        r.id == request.id && r.isPending
            ? r.decide(status: ApprovalStatus.rejected, by: by.name, note: clean)
            : r,
    ]);
  }
}
