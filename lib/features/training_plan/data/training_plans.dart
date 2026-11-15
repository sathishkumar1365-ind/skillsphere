// Training plans: how an employee plans to close a skill gap (or grow a
// competency) – the training type, course or programme, dates, hours and
// progress.
//
// Who can do what (the Spring Boot API must enforce the same rules):
// * Employee: adds, edits, updates progress and removes THEIR OWN plans.
// * Team Lead: sees the plans of their department (read-only).
// * HRD: sees everyone's plans (read-only).
//
// Spring Boot API later:
//   GET    /api/employees/{id}/training-plans          (the rules above)
//   POST   /api/employees/me/training-plans            (employee from the JWT)
//   PUT    /api/employees/me/training-plans/{planId}
//   DELETE /api/employees/me/training-plans/{planId}
//   GET    /api/training-plans?departmentId=&status=   (SUPER_ADMIN; ADMIN own dept)
//   table training_plan(id, employee_id, competency_id, current_level NULL,
//         target_level, training_type, title, provider, start_date,
//         target_date, planned_hours, completed_hours, status, link, notes,
//         created_at, updated_at) + training_plan_project(plan_id, project_id)

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_user.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/data/competency_repository.dart';
import 'training_plan_sample_data.dart';

/// Thrown when a plan can't be saved. [message] is safe to show.
class TrainingPlanException implements Exception {
  const TrainingPlanException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum TrainingType {
  onlineCourse('Online course', 'ONLINE_COURSE'),
  classroom('Classroom training', 'CLASSROOM'),
  workshop('Internal workshop', 'WORKSHOP'),
  certification('Certification', 'CERTIFICATION'),
  mentoring('Mentoring', 'MENTORING'),
  onTheJob('On-the-job practice', 'ON_THE_JOB'),
  selfStudy('Self-study', 'SELF_STUDY');

  const TrainingType(this.label, this.apiValue);

  final String label;
  final String apiValue;

  /// Example shown as a hint for the course / programme field.
  String get example => switch (this) {
        TrainingType.onlineCourse => 'e.g. Docker Mastery (Udemy)',
        TrainingType.classroom => 'e.g. AUTOSAR Classic fundamentals – 3 days',
        TrainingType.workshop => 'e.g. Kubernetes for developers (DevOps team)',
        TrainingType.certification => 'e.g. ISTQB Foundation exam',
        TrainingType.mentoring => 'e.g. Weekly sessions with Priya Raman',
        TrainingType.onTheJob => 'e.g. Own the Kafka consumer of PAY-MIG',
        TrainingType.selfStudy => 'e.g. Effective Java, chapters 1–6',
      };
}

enum PlanStatus {
  planned('Planned', 'PLANNED'),
  inProgress('In progress', 'IN_PROGRESS'),
  onHold('On hold', 'ON_HOLD'),
  completed('Completed', 'COMPLETED');

  const PlanStatus(this.label, this.apiValue);

  final String label;
  final String apiValue;

  bool get isOpen => this != PlanStatus.completed;
}

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.employeeId,
    required this.competencyId,
    required this.targetLevel,
    required this.type,
    required this.title,
    required this.startDate,
    required this.targetDate,
    required this.plannedHours,
    required this.createdAt,
    required this.updatedAt,
    this.currentLevel,
    this.provider = '',
    this.completedHours = 0,
    this.status = PlanStatus.planned,
    this.link = '',
    this.notes = '',
    this.projectIds = const [],
  });

  /// e.g. "PLN-0004".
  final String id;
  final String employeeId;
  final String competencyId;

  /// Level when the plan was made (null = not held).
  final int? currentLevel;
  final int targetLevel;
  final TrainingType type;

  /// Course, programme or activity, e.g. "Docker Mastery".
  final String title;

  /// Who gives it: Udemy, Vector Academy, the DevOps team…
  final String provider;
  final DateTime startDate;
  final DateTime targetDate;
  final int plannedHours;
  final int completedHours;
  final PlanStatus status;

  /// Course page or material (optional).
  final String link;
  final String notes;

  /// Projects whose gap this closes.
  final List<String> projectIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 0–1.
  double get progress {
    if (status == PlanStatus.completed) return 1;
    if (plannedHours <= 0) return 0;
    final p = completedHours / plannedHours;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }

  /// Open and past its target date.
  bool isOverdue([DateTime? now]) {
    final today = now ?? DateTime.now();
    return status.isOpen && DateTime(targetDate.year, targetDate.month, targetDate.day + 1).isBefore(today);
  }
}

/// What the form produces.
class TrainingPlanDraft {
  const TrainingPlanDraft({
    required this.competencyId,
    required this.targetLevel,
    required this.type,
    required this.title,
    required this.startDate,
    required this.targetDate,
    required this.plannedHours,
    this.provider = '',
    this.completedHours = 0,
    this.status = PlanStatus.planned,
    this.link = '',
    this.notes = '',
    this.projectIds = const [],
  });

  final String? competencyId;
  final int? targetLevel;
  final TrainingType? type;
  final String title;
  final String provider;
  final DateTime? startDate;
  final DateTime? targetDate;
  final int? plannedHours;
  final int completedHours;
  final PlanStatus status;
  final String link;
  final String notes;
  final List<String> projectIds;
}

class TrainingPlanRules {
  TrainingPlanRules._();

  static const int titleMin = 3;
  static const int titleMax = 80;
  static const int providerMax = 60;
  static const int notesMax = 300;
  static const int hoursMax = 2000;

  /// Open plans per employee.
  static const int maxOpenPlans = 20;

  /// A full http(s) link.
  static bool isValidLink(String value) => CompetencyRules.isValidLink(value);
}

class TrainingPlanRepository {
  TrainingPlanRepository._();

  static final TrainingPlanRepository instance = TrainingPlanRepository._();

  final ValueNotifier<List<TrainingPlan>> plans =
      ValueNotifier<List<TrainingPlan>>(List<TrainingPlan>.unmodifiable(sampleTrainingPlans()));

  /// Ids added in this session (shown with a "NEW" label).
  final Set<String> _addedThisSession = <String>{};

  bool isNew(String id) => _addedThisSession.contains(id);

  TrainingPlan? byId(String id) {
    for (final p in plans.value) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Open plans first (in progress, planned, on hold), then completed; by
  /// target date.
  List<TrainingPlan> forEmployee(String employeeId) {
    int rank(PlanStatus s) => switch (s) {
          PlanStatus.inProgress => 0,
          PlanStatus.planned => 1,
          PlanStatus.onHold => 2,
          PlanStatus.completed => 3,
        };
    return plans.value.where((p) => p.employeeId == employeeId).toList()
      ..sort((a, b) {
        final byStatus = rank(a.status).compareTo(rank(b.status));
        return byStatus != 0 ? byStatus : a.targetDate.compareTo(b.targetDate);
      });
  }

  /// Plans of [employeeId] for [competencyId] (open ones first).
  List<TrainingPlan> forCompetency(String employeeId, String competencyId) =>
      forEmployee(employeeId).where((p) => p.competencyId == competencyId).toList();

  /// The most relevant plan for a gap: an open one, else the latest completed.
  TrainingPlan? mainPlanFor(String employeeId, String competencyId) {
    final list = forCompetency(employeeId, competencyId);
    return list.isEmpty ? null : list.first;
  }

  /// Only the employee changes their own plans.
  bool canEdit(AppUser user, String employeeId) => user.id == employeeId;

  /// The first problem with [d], or null.
  String? problemWith(TrainingPlanDraft d, {required String employeeId}) {
    final competencyId = d.competencyId;
    if (competencyId == null) return 'Choose the competency.';
    final competency = CompetencyRepository.instance.byId(competencyId);
    if (competency == null) return 'This competency is no longer in the library.';
    final target = d.targetLevel;
    if (target == null) return 'Choose the target level.';
    final current = CompetencyRepository.instance.holderOf(competencyId, employeeId)?.level;
    if (current != null && target <= current && d.status != PlanStatus.completed) {
      return 'You are already at L$current. Choose a higher target level.';
    }
    if (d.type == null) return 'Choose the training type.';
    final title = d.title.trim();
    if (title.length < TrainingPlanRules.titleMin) return 'Name the course or activity.';
    if (title.length > TrainingPlanRules.titleMax) {
      return 'Keep the name under ${TrainingPlanRules.titleMax} characters.';
    }
    if (d.provider.trim().length > TrainingPlanRules.providerMax) {
      return 'Keep the provider under ${TrainingPlanRules.providerMax} characters.';
    }
    final start = d.startDate;
    final end = d.targetDate;
    if (start == null) return 'Choose the start date.';
    if (end == null) return 'Choose the target date.';
    if (end.isBefore(start)) return 'The target date must be on or after the start date.';
    final hours = d.plannedHours;
    if (hours == null || hours < 1) return 'Enter the planned hours (at least 1).';
    if (hours > TrainingPlanRules.hoursMax) return 'Plan at most ${TrainingPlanRules.hoursMax} hours.';
    if (d.completedHours < 0 || d.completedHours > TrainingPlanRules.hoursMax) {
      return 'Hours done must be 0 to ${TrainingPlanRules.hoursMax}.';
    }
    final link = d.link.trim();
    if (link.isNotEmpty && !TrainingPlanRules.isValidLink(link)) return 'The link must start with https://';
    if (d.notes.trim().length > TrainingPlanRules.notesMax) {
      return 'Keep the notes under ${TrainingPlanRules.notesMax} characters.';
    }
    return null;
  }

  Future<TrainingPlan> add({required AppUser by, required TrainingPlanDraft draft}) async {
    _requireOwner(by, by.id);
    final problem = problemWith(draft, employeeId: by.id);
    if (problem != null) throw TrainingPlanException(problem);
    final open = plans.value.where((p) => p.employeeId == by.id && p.status.isOpen).length;
    if (open >= TrainingPlanRules.maxOpenPlans && draft.status.isOpen) {
      throw const TrainingPlanException('You have ${TrainingPlanRules.maxOpenPlans} open plans. '
          'Complete or remove one first.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    final plan = _build(
      id: _nextId(),
      employeeId: by.id,
      draft: draft,
      currentLevel: CompetencyRepository.instance.holderOf(draft.competencyId!, by.id)?.level,
      createdAt: now,
      updatedAt: now,
    );
    _addedThisSession.add(plan.id);
    plans.value = List<TrainingPlan>.unmodifiable([...plans.value, plan]);
    return plan;
  }

  Future<TrainingPlan> update({required AppUser by, required String planId, required TrainingPlanDraft draft}) async {
    final current = byId(planId);
    if (current == null) throw const TrainingPlanException('This plan no longer exists.');
    _requireOwner(by, current.employeeId);
    final problem = problemWith(draft, employeeId: current.employeeId);
    if (problem != null) throw TrainingPlanException(problem);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final updated = _build(
      id: current.id,
      employeeId: current.employeeId,
      draft: draft,
      currentLevel: current.competencyId == draft.competencyId
          ? current.currentLevel
          : CompetencyRepository.instance.holderOf(draft.competencyId!, current.employeeId)?.level,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    plans.value = List<TrainingPlan>.unmodifiable([
      for (final p in plans.value) p.id == planId ? updated : p,
    ]);
    return updated;
  }

  /// Quick status change from the plan card.
  Future<void> setStatus({required AppUser by, required String planId, required PlanStatus status}) async {
    final current = byId(planId);
    if (current == null) throw const TrainingPlanException('This plan no longer exists.');
    _requireOwner(by, current.employeeId);
    final completedHours = status == PlanStatus.completed && current.completedHours < current.plannedHours
        ? current.plannedHours
        : current.completedHours;
    await update(
      by: by,
      planId: planId,
      draft: TrainingPlanDraft(
        competencyId: current.competencyId,
        targetLevel: current.targetLevel,
        type: current.type,
        title: current.title,
        provider: current.provider,
        startDate: current.startDate,
        targetDate: current.targetDate,
        plannedHours: current.plannedHours,
        completedHours: completedHours,
        status: status,
        link: current.link,
        notes: current.notes,
        projectIds: current.projectIds,
      ),
    );
  }

  Future<void> remove({required AppUser by, required String planId}) async {
    final current = byId(planId);
    if (current == null) return;
    _requireOwner(by, current.employeeId);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    plans.value = List<TrainingPlan>.unmodifiable(plans.value.where((p) => p.id != planId));
  }

  /// Puts a removed plan back (Undo).
  void restore({required AppUser by, required TrainingPlan plan}) {
    _requireOwner(by, plan.employeeId);
    if (byId(plan.id) != null) return;
    plans.value = List<TrainingPlan>.unmodifiable([...plans.value, plan]);
  }

  void _requireOwner(AppUser by, String employeeId) {
    if (!canEdit(by, employeeId)) {
      throw const TrainingPlanException('Only the employee can change their own training plan.');
    }
  }

  String _nextId() {
    var highest = 0;
    for (final p in plans.value) {
      final n = int.tryParse(p.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > highest) highest = n;
    }
    return 'PLN-${(highest + 1).toString().padLeft(4, '0')}';
  }

  static TrainingPlan _build({
    required String id,
    required String employeeId,
    required TrainingPlanDraft draft,
    required int? currentLevel,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) =>
      TrainingPlan(
        id: id,
        employeeId: employeeId,
        competencyId: draft.competencyId!,
        currentLevel: currentLevel,
        targetLevel: draft.targetLevel!,
        type: draft.type!,
        title: draft.title.trim().replaceAll(RegExp(r'\s+'), ' '),
        provider: draft.provider.trim(),
        startDate: draft.startDate!,
        targetDate: draft.targetDate!,
        plannedHours: draft.plannedHours!,
        completedHours: draft.completedHours,
        status: draft.status,
        link: draft.link.trim(),
        notes: draft.notes.trim(),
        projectIds: List<String>.unmodifiable(draft.projectIds),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
