import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/sphere_page_route.dart';
import '../../additional_competency/presentation/my_additional_section.dart';
import '../../admin/data/employees.dart';
import '../../admin/data/insights.dart';
import '../../admin/presentation/employees/all_employees_view.dart';
import '../../admin/presentation/employees/employee_gaps_panel.dart';
import '../../admin/presentation/employees/employee_profile_page.dart';
import '../../admin/presentation/widgets/admin_common.dart';
import '../../organization/data/org_models.dart';
import '../../organization/presentation/widgets/team_section.dart';
import '../../reports/presentation/reports_view.dart';
import '../../training_plan/data/training_plans.dart';
import '../../training_plan/presentation/training_plan_form.dart';
import '../../training_plan/presentation/training_plan_section.dart';
import '../data/home_models.dart';
import 'widgets/hero_section.dart';
import 'widgets/home_common.dart';
import 'widgets/home_nav_bar.dart';
import 'widgets/projects_section.dart';
import 'widgets/skill_section.dart';
import 'widgets/sphere_scroll_page.dart';

/// SkillSphere Home page — design Option A "Sky Sphere".
///
/// Used by End Users and Team Leads (Admin). For a Team Lead, pass their
/// department's employees in [team]: a "My Team" link and section appear.
/// For End Users [team] is ignored, so the section is never built.
///
/// Live (from the console data): the hero's readiness, gaps and "in
/// progress" numbers, Skill Gaps (table + chart) and My Plan (training
/// plans). My Skills and Projects still show [data] (sample).
///
/// Any callback left null shows a small "not connected yet" message.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    this.data = HomeData.sample,
    this.team = const [],
    this.onLogout,
    this.onUpdateSkills,
    this.onOpenProject,
    this.onFindCourse,
    this.onOpenLearningPlan,
    this.onOpenEmployee,
    this.onSearch,
    this.onNotifications,
    this.onProfile,
  });

  final AppUser user;
  final HomeData data;

  /// Employees of the Team Lead's department (Admin role only). Leave it
  /// empty to show the live team from the HRD console data.
  final List<EmployeeRecord> team;

  final VoidCallback? onLogout;
  final VoidCallback? onUpdateSkills;
  final ValueChanged<ProjectItem>? onOpenProject;
  /// Not used since Skill Gaps and My Plan are live; kept so existing
  /// callers keep compiling.
  final ValueChanged<SkillGap>? onFindCourse;
  final VoidCallback? onOpenLearningPlan;
  final ValueChanged<EmployeeRecord>? onOpenEmployee;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  /// Opens the Home page with SkillSphere's 3D page transition.
  static Route<void> route({
    required AppUser user,
    HomeData data = HomeData.sample,
    List<EmployeeRecord> team = const [],
    VoidCallback? onLogout,
  }) =>
      SpherePageRoute<void>(
        builder: (_) => HomePage(user: user, data: data, team: team, onLogout: onLogout),
      );

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<SphereScrollPageState> _page = GlobalKey<SphereScrollPageState>();

  // Section order on this page.
  static const int _gapsIndex = 3;
  static const int _planIndex = 4;
  static const int _teamIndex = 6;

  /// Team Leads get the extra "My Team" section; End Users never do.
  bool get _showTeam => widget.user.role == UserRole.admin;

  void _notConnected(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$what is not connected yet'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _scrollTo(int index) => _page.currentState?.scrollToSection(index);

  void _openProfile(String employeeId) {
    Navigator.of(context).push(EmployeeProfilePage.route(
      user: widget.user,
      employeeId: employeeId,
      onLogout: widget.onLogout,
    ));
  }

  void _openTeamDirectory() {
    Navigator.of(context).push(AllEmployeesPage.route(user: widget.user, onLogout: widget.onLogout));
  }

  void _openTeamReports() {
    Navigator.of(context).push(TeamReportsPage.route(user: widget.user, onLogout: widget.onLogout));
  }

  Future<void> _planFor(EmployeeProfile profile, GapEntry gap) async {
    final saved = await showTrainingPlanForm(context: context, user: widget.user, employee: profile, gap: gap);
    if (saved != null && mounted) {
      showAdminMessage(context, 'Added to your training plan: ${saved.title}.');
      _scrollTo(_planIndex);
    }
  }

  /// [base] with the signed-in employee's live readiness, gaps and plans.
  HomeData _live(HomeData base) {
    final profile = EmployeeRepository.instance.byId(widget.user.id);
    if (profile == null) return base;
    final insight = Insights.of(profile);
    final inProgress = TrainingPlanRepository.instance
        .forEmployee(profile.id)
        .where((p) => p.status == PlanStatus.inProgress)
        .length;
    return base.copyWith(
      skillsAcquired: insight.acquiredCount,
      skillsInProgress: inProgress,
      requiredSkillsHeld: insight.metCount,
      requiredSkillsTotal: insight.requiredCount,
      readiness: insight.readiness,
      gaps: [
        for (final r in insight.rows)
          if (r.state.isGap)
            SkillGap(
              skill: r.competency.name,
              project: r.sources.isEmpty ? '—' : r.sources.first.project.name,
              // SkillGap counts 1–5 with 0 = not held; the library uses 0–5.
              currentLevel: (r.acquiredLevel ?? -1) + 1,
              requiredLevel: (r.requiredLevel ?? 0) + 1,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final user = widget.user;

    final sections = <SphereSection>[
      SphereSection(
        label: 'Home',
        child: ListenableBuilder(
          listenable: Insights.listenable,
          builder: (context, _) => HeroSection(
            data: _live(data),
            onUpdateSkills: widget.onUpdateSkills ?? () => _notConnected('Update my skills'),
            onSeeGaps: () => _scrollTo(_gapsIndex),
            onViewTeam: _showTeam ? () => _scrollTo(_teamIndex) : null,
          ),
        ),
      ),
      SphereSection(
        label: 'My Skills',
        child: SkillsSection(skills: data.skills),
      ),
      SphereSection(
        label: 'Projects',
        child: ProjectsSection(
          projects: data.projects,
          onOpenProject:
              widget.onOpenProject ?? (ProjectItem project) => _notConnected('Project details'),
        ),
      ),
      SphereSection(
        label: 'Skill Gaps',
        child: _MyGapsSection(
          user: user,
          onPlan: _planFor,
          onOpenPlans: () => _scrollTo(_planIndex),
        ),
      ),
      SphereSection(
        label: 'My Plan',
        child: TrainingPlanSection(viewer: user, employeeId: user.id),
      ),
      SphereSection(
        label: 'Additional',
        child: MyAdditionalSection(user: user),
      ),
      if (_showTeam)
        SphereSection(
          label: 'My Team',
          child: _showTeam && widget.team.isEmpty
              // Live: follows profile updates, moves and onboarding.
              ? ListenableBuilder(
                  listenable: Insights.listenable,
                  builder: (context, _) => TeamSection(
                    department: user.department,
                    members: Insights.records().where((e) => e.department == user.department).toList(),
                    onOpenEmployee:
                        widget.onOpenEmployee ?? (EmployeeRecord e) => _openProfile(e.id),
                    onOpenDirectory: _openTeamDirectory,
                    onOpenReports: _openTeamReports,
                  ),
                )
              : TeamSection(
                  department: user.department,
                  members: widget.team,
                  onOpenEmployee: widget.onOpenEmployee ?? (EmployeeRecord e) => _openProfile(e.id),
                  onOpenDirectory: _openTeamDirectory,
                  onOpenReports: _openTeamReports,
                ),
        ),
    ];

    return SphereScrollPage(
      key: _page,
      sections: sections,
      navBarBuilder: (context, active, onSelect) => HomeNavBar(
        links: [for (final s in sections) s.label],
        activeIndex: active,
        onSelect: onSelect,
        user: user,
        unreadNotifications: data.unreadNotifications,
        onSearch: widget.onSearch ?? () => _notConnected('Search'),
        onNotifications: widget.onNotifications ?? () => _notConnected('Notifications'),
        onProfile: widget.onProfile ?? () => _openProfile(user.id),
        onLogout: widget.onLogout ?? () => _notConnected('Log out'),
      ),
    );
  }
}


/// The signed-in employee's gaps (live): one table + one chart, with
/// "Plan training" on every gap.
class _MyGapsSection extends StatelessWidget {
  const _MyGapsSection({required this.user, required this.onPlan, required this.onOpenPlans});

  final AppUser user;
  final void Function(EmployeeProfile profile, GapEntry gap) onPlan;
  final VoidCallback onOpenPlans;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Insights.listenable,
      builder: (context, _) {
        final profile = EmployeeRepository.instance.byId(user.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'SKILL GAPS TO CLOSE',
              subtitle: 'Your current level vs the level each of your projects needs: one row per project '
                  'that reports the gap (−1, −2, −3…). Plan the training for a gap from its row.',
            ),
            const SizedBox(height: 32),
            if (profile == null)
              const EmptyState(
                title: 'Profile not found',
                message: 'Ask HR to onboard you in SkillSphere.',
                icon: Icons.person_off_outlined,
              )
            else
              EmployeeGapsPanel(
                insight: Insights.of(profile),
                onPlan: (gap) => onPlan(profile, gap),
                onOpenPlans: onOpenPlans,
              ),
          ],
        );
      },
    );
  }
}
