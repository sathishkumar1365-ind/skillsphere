import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/sphere_page_route.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../home/presentation/widgets/home_nav_bar.dart';
import '../../home/presentation/widgets/sphere_scroll_page.dart';
import '../data/org_models.dart';
import 'widgets/departments_section.dart';
import 'widgets/employee_directory.dart';
import 'widgets/org_overview_section.dart';
import 'widgets/org_projects_section.dart';
import 'widgets/skill_coverage_section.dart';

/// Overall Dashboard – the Super Admin (HRD) landing page.
///
/// One scrolling page (same Sky Sphere look as the Home page) with
/// organisation-wide data: overview, departments, skill coverage, projects
/// and the full employee directory. The nav bar jumps between sections.
class OrgDashboardPage extends StatefulWidget {
  const OrgDashboardPage({
    super.key,
    required this.user,
    this.data = OrgData.sample,
    this.onLogout,
    this.onOpenEmployee,
    this.onOpenProject,
    this.onOpenReviewQueue,
    this.onSearch,
    this.onNotifications,
    this.onProfile,
  });

  final AppUser user;
  final OrgData data;
  final VoidCallback? onLogout;
  final ValueChanged<EmployeeRecord>? onOpenEmployee;
  final ValueChanged<OrgProject>? onOpenProject;
  final VoidCallback? onOpenReviewQueue;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  /// Opens the dashboard with SkillSphere's 3D page transition.
  static Route<void> route({
    required AppUser user,
    OrgData data = OrgData.sample,
    VoidCallback? onLogout,
  }) =>
      SpherePageRoute<void>(
        builder: (_) => OrgDashboardPage(user: user, data: data, onLogout: onLogout),
      );

  @override
  State<OrgDashboardPage> createState() => _OrgDashboardPageState();
}

class _OrgDashboardPageState extends State<OrgDashboardPage> {
  final GlobalKey<SphereScrollPageState> _page = GlobalKey<SphereScrollPageState>();

  // Section order on this page.
  static const int _skillsIndex = 2;
  static const int _employeesIndex = 4;

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
    final user = widget.user;
    // Safety net: only Super Admins may see organisation-wide data.
    if (!user.role.canViewOrganization) {
      return _NoAccess(onLogout: widget.onLogout);
    }
    final data = widget.data;

    final sections = <SphereSection>[
      SphereSection(
        label: 'Overview',
        child: OrgOverviewSection(
          data: data,
          firstName: user.firstName,
          onViewEmployees: () => _scrollTo(_employeesIndex),
          onViewShortages: () => _scrollTo(_skillsIndex),
        ),
      ),
      SphereSection(
        label: 'Departments',
        child: DepartmentsSection(departments: data.departments),
      ),
      SphereSection(
        label: 'Skills',
        child: SkillCoverageSection(
          data: data,
          onOpenReviewQueue:
              widget.onOpenReviewQueue ?? () => _notConnected('Review queue'),
        ),
      ),
      SphereSection(
        label: 'Projects',
        child: OrgProjectsSection(
          projects: data.projects,
          onOpenProject: widget.onOpenProject ??
              (OrgProject project) => _notConnected('Project details'),
        ),
      ),
      SphereSection(
        label: 'Employees',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'ALL EMPLOYEES',
              subtitle: 'Every employee across all departments with their readiness, '
                  'skills and gaps. Search, filter by department or sort.',
            ),
            const SizedBox(height: 32),
            EmployeeDirectory(
              employees: data.employees,
              departments: data.departmentNames,
              onOpenEmployee: widget.onOpenEmployee ??
                  (EmployeeRecord e) => _notConnected('Employee profile'),
            ),
          ],
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
        unreadNotifications: data.pendingVerifications > 0 ? 1 : 0,
        onSearch: widget.onSearch ?? () => _notConnected('Search'),
        onNotifications: widget.onNotifications ?? () => _notConnected('Notifications'),
        onProfile: widget.onProfile ?? () => _notConnected('Profile'),
        onLogout: widget.onLogout ?? () => _notConnected('Log out'),
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.onLogout});

  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: HomeColors.skyGradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('NO ACCESS', style: HomeText.display(48)),
                const SizedBox(height: 12),
                Text('The Overall Dashboard is only available to the HRD team.',
                    textAlign: TextAlign.center, style: HomeText.body(16)),
                const SizedBox(height: 24),
                PillButton(label: 'Back to sign in', onPressed: onLogout),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
