import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../../core/sphere_page_route.dart';
import '../../../additional_competency/data/additional_competency_repository.dart';
import '../../../competency/data/competency_models.dart';
import '../../../competency/data/competency_repository.dart';
import '../../../competency/presentation/widgets/competency_details_panel.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../home/presentation/widgets/projects_section.dart' show MatchRing;
import '../../../home/presentation/widgets/sphere_scroll_page.dart';
import '../../../organization/data/org_models.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/approvals.dart';
import '../../data/employees.dart';
import '../../data/insights.dart';
import '../../data/job_roles.dart';
import '../../data/projects.dart';
import '../admin_console_page.dart' show ConsoleNoAccess;
import '../approvals/request_level_up_dialog.dart';
import '../onboarding/employee_form.dart';
import '../widgets/admin_common.dart';
import '../widgets/console_top_bar.dart';
import 'competency_gap_table.dart';

/// An employee's profile: who they are, their projects, the combined
/// required-vs-acquired competency table with gaps, certificates and the
/// history of profile changes and level-ups.
///
/// * HRD: any employee; Update profile (everything).
/// * Team Lead: own department; Update profile (not group, department,
///   status, not themselves) and Request level-up.
/// * Employee: their own profile, read-only.
class EmployeeProfilePage extends StatefulWidget {
  const EmployeeProfilePage({super.key, required this.user, required this.employeeId, this.onLogout});

  final AppUser user;
  final String employeeId;
  final VoidCallback? onLogout;

  static Route<void> route({required AppUser user, required String employeeId, VoidCallback? onLogout}) =>
      SpherePageRoute<void>(
        builder: (_) => EmployeeProfilePage(user: user, employeeId: employeeId, onLogout: onLogout),
      );

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage> {
  final GlobalKey<SphereScrollPageState> _page = GlobalKey<SphereScrollPageState>();

  EmployeeRepository get _employees => EmployeeRepository.instance;

  void _back() => Navigator.of(context).maybePop();

  Future<void> _update(EmployeeProfile profile) async {
    final user = widget.user;
    final saved = await showSwingPanel<EmployeeProfile>(
      context: context,
      title: 'Update profile',
      subtitle: '${profile.name} · ${profile.id}'
          '${user.role.canManageOrganization ? '' : ' · group, department and status are managed by HRD'}',
      width: 900,
      builder: (panelContext) => EmployeeForm(
        user: user,
        employee: profile,
        onSaved: (p) => Navigator.of(panelContext).pop(p),
        onCancel: () => Navigator.of(panelContext).pop(),
      ),
    );
    if (saved == null || !mounted) return;
    showAdminMessage(
      context,
      user.role.canManageOrganization
          ? 'Profile saved.'
          : 'Profile saved. Any level changes are waiting for HR approval.',
    );
  }

  Future<void> _request(EmployeeProfile profile, [CompetencyRow? row]) async {
    final request = await showRequestLevelUp(context: context, user: widget.user, employee: profile, row: row);
    if (request == null || !mounted) return;
    final name = CompetencyRepository.instance.byId(request.competencyId)?.name ?? 'the competency';
    showAdminMessage(context, 'Sent to HR: $name → L${request.toLevel} for ${profile.firstName}.');
  }

  void _openCompetency(Competency competency) {
    showCompetencyDetails(
      context,
      competency: competency,
      employeesById: {for (final r in Insights.records(includeInactive: true)) r.id: r},
      onOpenEmployee: (EmployeeRecord e) {
        if (e.id == widget.employeeId) return;
        final target = _employees.byId(e.id);
        if (target == null || !_employees.canView(widget.user, target)) {
          showAdminMessage(context, 'You can only open profiles in your own department.');
          return;
        }
        Navigator.of(context).push(EmployeeProfilePage.route(
          user: widget.user,
          employeeId: e.id,
          onLogout: widget.onLogout,
        ));
      },
    );
  }

  Future<void> _download(CertificateFile file) async {
    final bytes = file.bytes;
    if (bytes == null) return;
    try {
      final FileSaveLocation? location =
          kIsWeb ? const FileSaveLocation('') : await getSaveLocation(suggestedName: file.name);
      if (location == null) return;
      await XFile.fromData(bytes, name: file.name, mimeType: file.mimeType).saveTo(location.path);
    } catch (e) {
      if (mounted) showAdminMessage(context, 'Could not save ${file.name}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Insights.listenable,
      builder: (context, _) {
        final profile = _employees.byId(widget.employeeId);
        if (profile == null) {
          return ConsoleNoAccess(onBack: _back, message: 'This employee no longer exists.');
        }
        final user = widget.user;
        if (!_employees.canView(user, profile)) {
          return ConsoleNoAccess(
            onBack: _back,
            message: 'You can only view profiles of your own department.',
          );
        }
        final insight = Insights.of(profile);
        final canEdit = _employees.canEdit(user, profile);
        final canRequest = _employees.canRequestLevelUp(user, profile);

        final sections = <SphereSection>[
          SphereSection(
            label: 'Profile',
            child: _Hero(
              profile: profile,
              insight: insight,
              onUpdate: canEdit ? () => _update(profile) : null,
              onRequest: canRequest ? () => _request(profile) : null,
              onSeeGaps: () => _page.currentState?.scrollToSection(1),
            ),
          ),
          SphereSection(
            label: 'Competencies',
            child: _CompetenciesSection(
              insight: insight,
              canRequest: canRequest,
              isHrd: user.role.canManageOrganization,
              onRequest: (row) => _request(profile, row),
              onOpenCompetency: _openCompetency,
            ),
          ),
          SphereSection(label: 'Projects', child: _ProjectsSection(insight: insight)),
          SphereSection(
            label: 'Certificates',
            child: _CertificatesSection(profile: profile, onDownload: _download),
          ),
          SphereSection(label: 'History', child: _HistorySection(profile: profile)),
        ];

        return SphereScrollPage(
          key: _page,
          sections: sections,
          navBarBuilder: (context, active, onSelect) => ConsoleTopBar(
            title: profile.id == user.id ? 'My profile' : 'Employee profile',
            user: user,
            onBack: _back,
            onLogout: widget.onLogout,
            links: [for (final s in sections) s.label],
            activeIndex: active,
            onSelect: onSelect,
          ),
        );
      },
    );
  }
}

// ================================================================= hero

class _Hero extends StatelessWidget {
  const _Hero({
    required this.profile,
    required this.insight,
    required this.onUpdate,
    required this.onRequest,
    required this.onSeeGaps,
  });

  final EmployeeProfile profile;
  final EmployeeInsight insight;
  final VoidCallback? onUpdate;
  final VoidCallback? onRequest;
  final VoidCallback onSeeGaps;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final identity = TurnIn(child: _IdentityCard(profile: profile, onUpdate: onUpdate, onRequest: onRequest));
    final readiness = TurnIn(
      delay: const Duration(milliseconds: 160),
      child: _ReadinessCard(insight: insight, onSeeGaps: onSeeGaps),
    );
    if (width < 980) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [identity, const SizedBox(height: 18), readiness],
      );
    }
    // No IntrinsicHeight here: the identity card's field grid uses a
    // LayoutBuilder, which can't report intrinsic heights.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 62, child: identity),
        const SizedBox(width: 20),
        Expanded(flex: 38, child: readiness),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.onUpdate, required this.onRequest});

  final EmployeeProfile profile;
  final VoidCallback? onUpdate;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final employees = EmployeeRepository.instance;
    final update = onUpdate;
    final request = onRequest;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return LiftCard(
      padding: EdgeInsets.all(narrow ? 20 : 28),
      liftBy: 6,
      tiltDegrees: 3,
      color: const Color.fromRGBO(255, 255, 255, 0.95),
      borderColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(initials: profile.initials, size: narrow ? 64 : 84),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name.toUpperCase(), style: HomeText.display(narrow ? 32 : 44, height: 1.0)),
                    const SizedBox(height: 6),
                    Text(profile.designation.isEmpty ? 'Designation not set' : profile.designation,
                        style: HomeText.body(16, weight: FontWeight.w600, color: HomeColors.body)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusPill(
                          label: profile.id,
                          icon: Icons.badge_outlined,
                          background: HomeColors.neutralTint,
                          foreground: HomeColors.ink,
                        ),
                        profile.isActive
                            ? const StatusPill(
                                label: 'Active',
                                icon: Icons.check_circle_outline_rounded,
                                background: OrgColors.goodTint,
                                foreground: OrgColors.good,
                              )
                            : const StatusPill(
                                label: 'Inactive',
                                icon: Icons.person_off_outlined,
                                background: HomeColors.neutralTint,
                                foreground: HomeColors.body,
                              ),
                        StatusPill(
                          label: RoleRepository.instance.nameOf(profile.roleId),
                          icon: Icons.work_outline_rounded,
                          background: HomeColors.blueTint,
                          foreground: HomeColors.blueDeep,
                        ),
                        if (profile.onLeave)
                          const StatusPill(
                            label: 'On leave',
                            icon: Icons.beach_access_outlined,
                            background: HomeColors.neutralTint,
                            foreground: HomeColors.body,
                          ),
                        if (employees.isNew(profile.id)) const NewLabel(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.intro.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(profile.intro, style: HomeText.body(15, height: 1.6)),
          ],
          const SizedBox(height: 20),
          FieldGrid(
            maxColumns: 3,
            minFieldWidth: 190,
            children: [
              DetailItem(label: 'Group', value: employees.groupNameOf(profile), icon: Icons.account_tree_outlined),
              DetailItem(label: 'Department', value: employees.departmentNameOf(profile), icon: Icons.apartment_rounded),
              DetailItem(label: 'Reporting manager', value: employees.managerLabel(profile), icon: Icons.supervisor_account_outlined),
              DetailItem(label: 'Location', value: profile.location.label, icon: Icons.place_outlined),
              DetailItem(label: 'Work email', value: profile.email, icon: Icons.alternate_email_rounded),
              DetailItem(label: 'Gender', value: profile.gender.label, icon: Icons.person_outline_rounded),
              DetailItem(label: 'Onboarded', value: dayMonthYear(profile.onboardedAt), icon: Icons.event_outlined),
              DetailItem(label: 'Source', value: profile.source.label, icon: Icons.inventory_2_outlined),
              if (profile.crowdUsername != null)
                DetailItem(label: 'Crowd user', value: profile.crowdUsername!, icon: Icons.hub_outlined),
            ],
          ),
          if (!profile.isComplete) ...[
            const SizedBox(height: 18),
            InfoNote(
              tone: NoteTone.warning,
              text: 'Profile incomplete: ${profile.missingFields.join(', ')} '
                  '${profile.missingFields.length == 1 ? 'is' : 'are'} missing.',
            ),
          ],
          if (update != null || request != null) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (update != null) PillButton(label: 'Update profile', onPressed: update),
                if (request != null)
                  PillButton(label: 'Request level-up', variant: PillVariant.outline, onPressed: request),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Initials on a raised 3D disc.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C7BE8), HomeColors.ink],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(15, 27, 45, 0.35),
            blurRadius: size * 0.35,
            spreadRadius: -size * 0.12,
            offset: Offset(0, size * 0.16),
          ),
        ],
      ),
      child: Text(initials, style: HomeText.display(size * 0.38, color: Colors.white, height: 1)),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.insight, required this.onSeeGaps});

  final EmployeeInsight insight;
  final VoidCallback onSeeGaps;

  @override
  Widget build(BuildContext context) {
    final readiness = insight.readiness;
    return LiftCard(
      padding: const EdgeInsets.all(26),
      liftBy: 6,
      tiltDegrees: 4,
      color: const Color.fromRGBO(255, 255, 255, 0.95),
      borderColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const PanelTitle('Project readiness',
              subtitle: 'Share of the levels their projects need that they have reached.'),
          const SizedBox(height: 18),
          Row(
            children: [
              if (readiness != null)
                MatchRing(percent: readiness, size: 112)
              else
                Container(
                  width: 112,
                  height: 112,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: HomeColors.track, width: 8),
                  ),
                  child: Text('No\nproject',
                      textAlign: TextAlign.center,
                      style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.muted)),
                ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Stat(value: insight.requiredCount, label: 'required by projects'),
                    _Stat(value: insight.metCount, label: 'met'),
                    _Stat(value: insight.gapCount, label: insight.gapCount == 1 ? 'gap' : 'gaps', highlight: true),
                    _Stat(value: insight.pendingCount, label: 'waiting for HR'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: '${insight.acquiredCount} acquired',
                icon: Icons.school_outlined,
                background: HomeColors.blueTint,
                foreground: HomeColors.blueDeep,
              ),
              StatusPill(
                label: '${insight.additionalCount} additional',
                icon: Icons.auto_awesome_outlined,
                background: const Color(0xFFFFF4F6),
                foreground: const Color(0xFF8C1D3A),
              ),
              StatusPill(
                label: '${insight.projects.length} ${insight.projects.length == 1 ? 'project' : 'projects'}',
                icon: Icons.work_outline_rounded,
                background: HomeColors.neutralTint,
                foreground: HomeColors.ink,
              ),
            ],
          ),
          const SizedBox(height: 18),
          PillButton(
            label: insight.gapCount > 0 ? 'See the gaps' : 'See competencies',
            variant: PillVariant.outline,
            height: 46,
            fontSize: 14,
            onPressed: onSeeGaps,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.highlight = false});

  final int value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final orange = highlight && value > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 40,
            child: Text('$value',
                style: HomeText.display(26, height: 1.1, color: orange ? HomeColors.orange : HomeColors.ink)),
          ),
          Flexible(
            child: Text(label,
                style: HomeText.body(13.5,
                    weight: FontWeight.w600, color: orange ? HomeColors.orangeText : HomeColors.body)),
          ),
        ],
      ),
    );
  }
}

// ========================================================= competencies

class _CompetenciesSection extends StatelessWidget {
  const _CompetenciesSection({
    required this.insight,
    required this.canRequest,
    required this.isHrd,
    required this.onRequest,
    required this.onOpenCompetency,
  });

  final EmployeeInsight insight;
  final bool canRequest;
  final bool isHrd;
  final ValueChanged<CompetencyRow> onRequest;
  final ValueChanged<Competency> onOpenCompetency;

  @override
  Widget build(BuildContext context) {
    final additional = AdditionalCompetencyRepository.instance.forEmployee(insight.profile.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'COMPETENCIES & GAPS',
          subtitle: 'What ${insight.profile.firstName}\'s projects need from a '
              '${RoleRepository.instance.nameOf(insight.profile.roleId)} next to what they have. '
              'A competency several projects need is one row with the highest level.'
              '${canRequest ? ' Ask HR for a level-up on any gap.' : ''}'
              '${isHrd ? ' HRD changes levels in Update profile.' : ''}',
        ),
        const SizedBox(height: 26),
        CompetencyGapTable(
          insight: insight,
          onRequest: canRequest ? onRequest : null,
          onOpenCompetency: onOpenCompetency,
        ),
        const SizedBox(height: 24),
        OrgPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PanelTitle('Additional skills',
                  subtitle: 'Self-declared, outside the competency library. No levels.'),
              const SizedBox(height: 12),
              if (additional.isEmpty)
                Text('None listed.', style: HomeText.body(13.5, color: HomeColors.muted))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in additional)
                      Tooltip(
                        message: a.note ?? 'Self-declared',
                        child: DashedOutline(
                          color: const Color(0xFFD9496B),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            child: Text(a.name,
                                style: HomeText.body(13, weight: FontWeight.w700, color: const Color(0xFF8C1D3A))),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================= projects

class _ProjectsSection extends StatelessWidget {
  const _ProjectsSection({required this.insight});

  final EmployeeInsight insight;

  @override
  Widget build(BuildContext context) {
    final projects = insight.projects;
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'PROJECTS',
          subtitle: 'Projects ${insight.profile.firstName} is on, and what each one needs from their role.',
        ),
        const SizedBox(height: 26),
        if (projects.isEmpty)
          const EmptyState(
            title: 'Not on a project yet',
            message: 'HRD or the Team Lead adds projects in Update profile.',
            icon: Icons.work_off_outlined,
          )
        else
          EqualHeightGrid(
            columns: width >= 980 ? 2 : 1,
            spacing: 18,
            runSpacing: 18,
            children: [for (final p in projects) _ProjectCard(project: p, profile: insight.profile)],
          ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.profile});

  final ProjectRecord project;
  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final competencies = CompetencyRepository.instance;
    final employees = EmployeeRepository.instance;
    final needs = project.requirementsFor(profile.roleId);
    var reached = 0;
    var needed = 0;
    for (final r in needs) {
      needed += r.level + 1;
      final held = competencies.holderOf(r.competencyId, profile.id);
      if (held != null) reached += held.level >= r.level ? r.level + 1 : held.level + 1;
    }
    final match = needed == 0 ? 100 : (reached * 100 / needed).round();
    final manager = employees.byId(project.managerId);

    return LiftCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusPill(
                          label: project.code,
                          background: HomeColors.neutralTint,
                          foreground: HomeColors.ink,
                        ),
                        _ProjectStatusPill(status: project.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(project.name, style: HomeText.body(19, weight: FontWeight.w800, color: HomeColors.ink)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (project.customer.isNotEmpty) project.customer,
                        project.period,
                        if (manager != null) 'PM ${manager.name}',
                      ].join(' · '),
                      style: HomeText.body(13, color: HomeColors.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MatchRing(percent: match, size: 70),
            ],
          ),
          const SizedBox(height: 16),
          Text('NEEDS FROM A ${RoleRepository.instance.nameOf(profile.roleId).toUpperCase()}',
              style: HomeText.body(11, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.9)),
          const SizedBox(height: 8),
          if (needs.isEmpty)
            Text('Nothing specific for this role.', style: HomeText.body(13, color: HomeColors.muted))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in needs)
                  if (competencies.byId(r.competencyId) case final Competency c)
                    _NeedChip(
                      name: c.name,
                      level: r.level,
                      held: competencies.holderOf(c.id, profile.id)?.level,
                    ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NeedChip extends StatelessWidget {
  const _NeedChip({required this.name, required this.level, required this.held});

  final String name;
  final int level;
  final int? held;

  @override
  Widget build(BuildContext context) {
    final have = held;
    final met = have != null && have >= level;
    return Tooltip(
      message: have == null ? 'Not acquired yet (needs L$level)' : 'Has L$have, needs L$level',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: met ? OrgColors.goodTint : HomeColors.orangeTint,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(met ? Icons.check_rounded : Icons.north_east_rounded,
                size: 14, color: met ? OrgColors.good : HomeColors.orangeText),
            const SizedBox(width: 4),
            Flexible(
              child: Text('$name L$level',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.body(12, weight: FontWeight.w700, color: met ? OrgColors.good : HomeColors.orangeText)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectStatusPill extends StatelessWidget {
  const _ProjectStatusPill({required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color bg, Color fg) = switch (status) {
      ProjectStatus.planned => (Icons.event_outlined, HomeColors.blueTint, HomeColors.blueDeep),
      ProjectStatus.active => (Icons.play_circle_outline_rounded, OrgColors.goodTint, OrgColors.good),
      ProjectStatus.onHold => (Icons.pause_circle_outline_rounded, HomeColors.orangeTint, HomeColors.orangeText),
      ProjectStatus.completed => (Icons.task_alt_rounded, HomeColors.neutralTint, HomeColors.body),
    };
    return StatusPill(label: status.label, icon: icon, background: bg, foreground: fg);
  }
}

// ========================================================= certificates

class _CertificatesSection extends StatelessWidget {
  const _CertificatesSection({required this.profile, required this.onDownload});

  final EmployeeProfile profile;
  final ValueChanged<CertificateFile> onDownload;

  @override
  Widget build(BuildContext context) {
    final files = profile.certificates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'CERTIFICATES',
          subtitle: 'Certificate proofs attached to the profile. Files added in this session can be '
              'downloaded; stored files download once the server is connected.',
        ),
        const SizedBox(height: 26),
        if (files.isEmpty)
          const EmptyState(
            title: 'No certificates attached',
            message: 'Attach them in Update profile.',
            icon: Icons.workspace_premium_outlined,
          )
        else
          for (final f in files)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CertificateTile(file: f, onDownload: () => onDownload(f)),
            ),
      ],
    );
  }
}

// ============================================================== history

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.profile});

  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final changes = EmployeeRepository.instance.changesFor(profile.id);
    final requests = ApprovalRepository.instance.forEmployee(profile.id);
    final width = MediaQuery.sizeOf(context).width;
    final changesPanel = OrgPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelTitle('Profile changes', subtitle: 'Group, department, manager, designation, role, status.'),
          const SizedBox(height: 14),
          if (changes.isEmpty)
            Text('No changes since onboarding.', style: HomeText.body(13.5, color: HomeColors.muted))
          else
            for (final c in changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChangeLine(change: c),
              ),
        ],
      ),
    );
    final requestsPanel = OrgPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelTitle('Level-up requests', subtitle: 'Raised by the Team Lead, decided by HR.'),
          const SizedBox(height: 14),
          if (requests.isEmpty)
            Text('No requests yet.', style: HomeText.body(13.5, color: HomeColors.muted))
          else
            for (final r in requests)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RequestLine(request: r),
              ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'HISTORY',
          subtitle: 'Moves between groups and departments, other profile changes and level-ups.',
        ),
        const SizedBox(height: 26),
        if (width >= 980)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: changesPanel),
              const SizedBox(width: 18),
              Expanded(child: requestsPanel),
            ],
          )
        else ...[
          changesPanel,
          const SizedBox(height: 18),
          requestsPanel,
        ],
      ],
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.change});

  final ProfileChange change;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5, right: 12),
          decoration: BoxDecoration(
            color: change.field.isPlacement ? HomeColors.blue : HomeColors.chipBorder,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${change.field.label}: ${change.from} → ${change.to}',
                  style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink, height: 1.4)),
              Text(
                '${dayMonthYear(change.effectiveDate)} · ${change.reason.label}'
                '${change.note.isEmpty ? '' : ' · ${change.note}'} · by ${change.changedBy}',
                style: HomeText.body(12.5, color: HomeColors.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestLine extends StatelessWidget {
  const _RequestLine({required this.request});

  final LevelUpRequest request;

  @override
  Widget build(BuildContext context) {
    final name = CompetencyRepository.instance.byId(request.competencyId)?.name ?? request.competencyId;
    final (IconData icon, Color bg, Color fg) = switch (request.status) {
      ApprovalStatus.pending => (Icons.hourglass_top_rounded, HomeColors.orangeTint, HomeColors.orangeText),
      ApprovalStatus.approved => (Icons.check_circle_outline_rounded, OrgColors.goodTint, OrgColors.good),
      ApprovalStatus.rejected => (Icons.cancel_outlined, const Color(0xFFFDECEC), const Color(0xFFB4232A)),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$name: ${request.isNewSkill ? 'new' : 'L${request.fromLevel}'} → L${request.toLevel}',
                  style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink)),
              Text(
                'Raised ${dayMonthYear(request.raisedAt)} by ${request.raisedByName}'
                '${request.decidedAt == null ? '' : ' · ${request.status.label.toLowerCase()} ${dayMonthYear(request.decidedAt!)}'}'
                '${request.decisionNote.isEmpty ? '' : ' · "${request.decisionNote}"'}',
                style: HomeText.body(12.5, color: HomeColors.muted, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StatusPill(label: request.status.label, icon: icon, background: bg, foreground: fg),
      ],
    );
  }
}
