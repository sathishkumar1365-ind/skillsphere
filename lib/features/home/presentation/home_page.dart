import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/sphere_page_route.dart';
import '../../organization/data/org_models.dart';
import '../../organization/presentation/widgets/team_section.dart';
import '../data/home_models.dart';
import 'widgets/gaps_section.dart';
import 'widgets/hero_section.dart';
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

  /// Employees of the Team Lead's department (Admin role only).
  final List<EmployeeRecord> team;

  final VoidCallback? onLogout;
  final VoidCallback? onUpdateSkills;
  final ValueChanged<ProjectItem>? onOpenProject;
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
  static const int _teamIndex = 4;

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

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final user = widget.user;

    final sections = <SphereSection>[
      SphereSection(
        label: 'Home',
        child: HeroSection(
          data: data,
          onUpdateSkills: widget.onUpdateSkills ?? () => _notConnected('Update my skills'),
          onSeeGaps: () => _scrollTo(_gapsIndex),
          onViewTeam: _showTeam ? () => _scrollTo(_teamIndex) : null,
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
        child: GapsSection(
          gaps: data.gaps,
          learningPlan: data.learningPlan,
          nextReview: data.nextReview,
          onFindCourse: widget.onFindCourse ?? (SkillGap gap) => _notConnected('Course search'),
          onOpenLearningPlan:
              widget.onOpenLearningPlan ?? () => _notConnected('Learning plan'),
        ),
      ),
      if (_showTeam)
        SphereSection(
          label: 'My Team',
          child: TeamSection(
            department: user.department,
            members: widget.team,
            onOpenEmployee: widget.onOpenEmployee ??
                (EmployeeRecord e) => _notConnected('Employee profile'),
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
        onProfile: widget.onProfile ?? () => _notConnected('Profile'),
        onLogout: widget.onLogout ?? () => _notConnected('Log out'),
      ),
    );
  }
}
