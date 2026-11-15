import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../competency/data/competency_models.dart';
import '../../../competency/data/competency_repository.dart';
import '../../../competency/presentation/widgets/competency_common.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../home/presentation/widgets/projects_section.dart' show MatchRing;
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/admin_import.dart';
import '../../data/employees.dart';
import '../../data/insights.dart';
import '../../data/job_roles.dart';
import '../../data/org_structure.dart';
import '../../data/projects.dart';
import '../widgets/admin_common.dart';
import '../widgets/bulk_import_panel.dart';
import 'project_form.dart';

enum _Mode { list, add, bulk }

/// Console › Projects: all projects with their team and required
/// competencies; add one, edit one, or import many from Excel/CSV.
class ProjectsView extends StatefulWidget {
  const ProjectsView({super.key, required this.user, required this.onOpenEmployee});

  final AppUser user;
  final ValueChanged<String> onOpenEmployee;

  @override
  State<ProjectsView> createState() => _ProjectsViewState();
}

class _ProjectsViewState extends State<ProjectsView> {
  _Mode _mode = _Mode.list;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  ProjectStatus? _status;
  String? _departmentId;
  String? _spotlightId;

  late final BulkImportConfig<ProjectDraft> _importConfig = BulkImportConfig<ProjectDraft>(
    title: 'Bulk import projects',
    subtitle: 'Add many projects from Excel or CSV, with required competencies and team members.',
    templateAsset: ProjectImporter.templateAsset,
    templateFileName: ProjectImporter.templateFileName,
    templateDescription: 'Project columns, drop-downs for Department and Status, two examples and '
        'an Instructions sheet explaining the requirement format.',
    columnsHelp: 'Project Code · Project Name · Customer · Department · Project Manager (employee ID) · '
        'Start Date · End Date (YYYY-MM-DD) · Status · Planned Team Size · Description · Required '
        'Competencies ("Java:4@Software Developer; Jira:2") · Team Members ("EMP-1002; EMP-1003").',
    singular: 'project',
    plural: 'projects',
    parse: (bytes, fileName) => ProjectImporter.parse(bytes, fileName: fileName),
    commit: (drafts) async => (await ProjectRepository.instance
            .addAll(by: widget.user, drafts: drafts, source: RecordSource.bulkImport))
        .length,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _added(ProjectRecord p) {
    setState(() {
      _mode = _Mode.list;
      _spotlightId = p.id;
    });
    showAdminMessage(context, '${p.name} (${p.code}) added.',
        action: SnackBarAction(label: 'Open', onPressed: () => _openDetails(p)));
  }

  void _imported(int count) {
    setState(() => _mode = _Mode.list);
    showAdminMessage(context, '$count ${count == 1 ? 'project' : 'projects'} imported. They are marked NEW.');
  }

  Future<void> _edit(ProjectRecord p) async {
    final saved = await showSwingPanel<ProjectRecord>(
      context: context,
      title: 'Edit project',
      subtitle: '${p.name} · ${p.code}',
      width: 900,
      builder: (panelContext) => ProjectForm(
        user: widget.user,
        project: p,
        onSaved: (x) => Navigator.of(panelContext).pop(x),
        onCancel: () => Navigator.of(panelContext).pop(),
      ),
    );
    if (saved != null && mounted) showAdminMessage(context, '${saved.name} saved.');
  }

  Future<void> _openDetails(ProjectRecord p) {
    return showSwingPanel<void>(
      context: context,
      title: p.name,
      subtitle: '${p.code} · ${p.period}',
      width: 820,
      builder: (panelContext) => _ProjectDetails(
        projectId: p.id,
        onEdit: () {
          Navigator.of(panelContext).pop();
          _edit(p);
        },
        onOpenEmployee: (id) {
          Navigator.of(panelContext).pop();
          widget.onOpenEmployee(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'PROJECTS',
          subtitle: 'Projects employees are onboarded to, with the competencies each one needs (per role) '
              'and its team. Gap tables on profiles are built from these.',
        ),
        const SizedBox(height: 24),
        ModeSwitch<_Mode>(
          selected: _mode,
          onChanged: (m) => setState(() => _mode = m),
          options: const [
            ModeOption(_Mode.list, 'All projects', Icons.view_module_outlined),
            ModeOption(_Mode.add, 'Add project', Icons.add_box_outlined),
            ModeOption(_Mode.bulk, 'Bulk import', Icons.upload_file_rounded),
          ],
        ),
        const SizedBox(height: 20),
        FlipWhenShown(visible: _mode == _Mode.list, child: _list()),
        FlipWhenShown(
          visible: _mode == _Mode.add,
          child: ProjectForm(user: widget.user, onSaved: _added),
        ),
        FlipWhenShown(
          visible: _mode == _Mode.bulk,
          child: BulkImportPanel<ProjectDraft>(config: _importConfig, onImported: _imported),
        ),
      ],
    );
  }

  Widget _list() {
    final structure = OrgStructureRepository.instance;
    return ListenableBuilder(
      listenable: Insights.listenable,
      builder: (context, _) {
        final repo = ProjectRepository.instance;
        final all = repo.projects.value;
        final query = _query.trim().toLowerCase();
        final list = all.where((p) {
          if (_status != null && p.status != _status) return false;
          if (_departmentId != null && p.departmentId != _departmentId) return false;
          if (query.isNotEmpty && !'${p.searchText} ${structure.departmentName(p.departmentId)}'.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        }).toList()
          ..sort((a, b) {
            final aNew = repo.isNew(a.id) ? 0 : 1;
            final bNew = repo.isNew(b.id) ? 0 : 1;
            if (aNew != bNew) return aNew.compareTo(bNew);
            return b.startDate.compareTo(a.startDate);
          });
        final width = MediaQuery.sizeOf(context).width;
        final active = all.where((p) => p.status == ProjectStatus.active).length;
        final planned = all.where((p) => p.status == ProjectStatus.planned).length;
        final people = {for (final p in all.where((p) => p.status != ProjectStatus.completed)) ...p.memberIds}.length;
        final staffing = all
            .where((p) => p.status != ProjectStatus.completed)
            .fold<int>(0, (s, p) => s + math.max(0, p.plannedTeamSize - p.memberIds.length));
        final departments = [...structure.departments.value]..sort((a, b) => a.name.compareTo(b.name));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EqualHeightGrid(
              columns: width >= 900 ? 4 : 2,
              spacing: 14,
              runSpacing: 14,
              children: [
                KpiCard(value: active, label: 'Active projects'),
                KpiCard(value: planned, label: 'Planned'),
                KpiCard(value: people, label: 'People on projects'),
                KpiCard(value: staffing, label: 'Open seats', caption: 'Planned size − members', dark: true),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width < 560 ? width - 40 : 300,
                  child: AdminSearchField(
                    controller: _search,
                    hint: 'Search code, name, customer…',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AdminDropdown<String>(
                    value: _departmentId ?? '',
                    items: ['', for (final d in departments) d.id],
                    labelOf: (id) => id.isEmpty ? 'All departments' : structure.departmentName(id),
                    onChanged: (id) => setState(() => _departmentId = id.isEmpty ? null : id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ChoicePills<String>(
              options: ['', for (final s in ProjectStatus.values) s.name],
              selected: _status?.name ?? '',
              labelOf: (n) => n.isEmpty ? 'All statuses' : ProjectStatus.values.byName(n).label,
              onSelected: (n) => setState(() => _status = n.isEmpty ? null : ProjectStatus.values.byName(n)),
            ),
            const SizedBox(height: 18),
            if (list.isEmpty)
              const EmptyState(title: 'No projects match', icon: Icons.work_off_outlined)
            else
              EqualHeightGrid(
                columns: width >= 1240 ? 2 : 1,
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (final p in list)
                    TurnIn(
                      key: ValueKey<String>('prj-${p.id}'),
                      play: repo.isNew(p.id) || p.id == _spotlightId,
                      child: _ProjectCard(
                        project: p,
                        isNew: repo.isNew(p.id),
                        onOpen: () => _openDetails(p),
                        onEdit: () => _edit(p),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.isNew, required this.onOpen, required this.onEdit});

  final ProjectRecord project;
  final bool isNew;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = project;
    final structure = OrgStructureRepository.instance;
    final manager = EmployeeRepository.instance.byId(p.managerId);
    final members = p.memberIds.length;
    final planned = math.max(p.plannedTeamSize, members);
    final missing = Insights.projectMissing(p);
    final match = Insights.projectMatch(p);

    return LiftCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: Padding(
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
                              StatusPill(label: p.code, background: HomeColors.neutralTint, foreground: HomeColors.ink),
                              ProjectStatusPill(status: p.status),
                              if (isNew) const NewLabel(),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(p.name, style: HomeText.body(19, weight: FontWeight.w800, color: HomeColors.ink)),
                          const SizedBox(height: 4),
                          Text(
                            [
                              structure.departmentName(p.departmentId),
                              if (p.customer.isNotEmpty) p.customer,
                              p.period,
                            ].join(' · '),
                            style: HomeText.body(13, color: HomeColors.muted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: 'How well the team covers the required levels',
                      child: MatchRing(percent: members == 0 ? 0 : match, size: 74),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: MeterBar(value: planned == 0 ? 0 : members / planned)),
                    const SizedBox(width: 10),
                    Text('$members / $planned people',
                        style: HomeText.body(12.5, weight: FontWeight.w700, color: HomeColors.ink)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${p.requirements.length} requirements · PM ${manager?.name ?? '—'}',
                  style: HomeText.body(12.5, color: HomeColors.muted),
                ),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Text('Not covered:',
                          style: HomeText.body(12.5, weight: FontWeight.w700, color: HomeColors.orangeText)),
                      for (final c in missing.take(4))
                        StatusPill(
                          label: c.name,
                          icon: Icons.north_east_rounded,
                          background: HomeColors.orangeTint,
                          foreground: HomeColors.orangeText,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  children: [
                    TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Details'),
                      style: TextButton.styleFrom(
                        foregroundColor: HomeColors.blue,
                        textStyle: HomeText.body(13, weight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: HomeColors.ink,
                        textStyle: HomeText.body(13, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProjectStatusPill extends StatelessWidget {
  const ProjectStatusPill({super.key, required this.status});

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

/// Requirements by role and the team with their match for this project.
class _ProjectDetails extends StatelessWidget {
  const _ProjectDetails({required this.projectId, required this.onEdit, required this.onOpenEmployee});

  final String projectId;
  final VoidCallback onEdit;
  final ValueChanged<String> onOpenEmployee;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Insights.listenable,
      builder: (context, _) {
        final p = ProjectRepository.instance.byId(projectId);
        if (p == null) return const EmptyState(title: 'This project no longer exists');
        final structure = OrgStructureRepository.instance;
        final employees = EmployeeRepository.instance;
        final competencies = CompetencyRepository.instance;
        final roles = RoleRepository.instance;
        final byRole = <String, List<ProjectRequirement>>{};
        for (final r in p.requirements) {
          (byRole[r.roleId ?? ''] ??= <ProjectRequirement>[]).add(r);
        }
        final roleKeys = byRole.keys.toList()
          ..sort((a, b) => a.isEmpty ? -1 : (b.isEmpty ? 1 : roles.nameOf(a).compareTo(roles.nameOf(b))));
        final members = [
          for (final id in p.memberIds)
            if (employees.byId(id) case final EmployeeProfile e) e,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldGrid(
              maxColumns: 3,
              minFieldWidth: 180,
              children: [
                DetailItem(label: 'Department', value: structure.departmentName(p.departmentId), icon: Icons.apartment_rounded),
                DetailItem(label: 'Group', value: structure.groupNameOfDepartment(p.departmentId), icon: Icons.account_tree_outlined),
                DetailItem(label: 'Customer', value: p.customer, icon: Icons.handshake_outlined),
                DetailItem(label: 'Project manager', value: employees.byId(p.managerId)?.name ?? '—', icon: Icons.person_outline_rounded),
                DetailItem(label: 'Dates', value: p.dateRange, icon: Icons.date_range_outlined),
                DetailItem(label: 'Status', value: p.status.label, icon: Icons.flag_outlined),
              ],
            ),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(p.description, style: HomeText.body(14.5, height: 1.55)),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: PillButton(label: 'Edit project', variant: PillVariant.outline, height: 44, fontSize: 14, onPressed: onEdit),
            ),
            const SizedBox(height: 22),
            const PanelTitle('Required competencies', subtitle: 'Per role; "Everyone" applies to the whole team.'),
            const SizedBox(height: 12),
            if (p.requirements.isEmpty)
              Text('None yet. Add them in Edit project.', style: HomeText.body(13.5, color: HomeColors.muted))
            else
              for (final key in roleKeys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OrgPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(key.isEmpty ? 'EVERYONE' : roles.nameOf(key).toUpperCase(),
                            style: HomeText.body(12, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 1)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final r in byRole[key]!)
                              if (competencies.byId(r.competencyId) case final Competency c)
                                Container(
                                  padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                                    border: Border.all(color: HomeColors.cardBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CompetencyBadge.of(c, size: 26),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(c.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.ink)),
                                      ),
                                      const SizedBox(width: 8),
                                      LevelPill(r.level),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 18),
            PanelTitle('Team · ${members.length} of ${math.max(p.plannedTeamSize, members.length)}',
                subtitle: 'Each person\'s match with what this project needs from their role.'),
            const SizedBox(height: 12),
            if (members.isEmpty)
              Text('No one on the team yet.', style: HomeText.body(13.5, color: HomeColors.muted))
            else
              for (final e in members)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MemberRow(project: p, profile: e, onOpen: () => onOpenEmployee(e.id)),
                ),
          ],
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.project, required this.profile, required this.onOpen});

  final ProjectRecord project;
  final EmployeeProfile profile;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final competencies = CompetencyRepository.instance;
    final needs = project.requirementsFor(profile.roleId);
    var reached = 0;
    var needed = 0;
    var gaps = 0;
    for (final r in needs) {
      needed += r.level + 1;
      final held = competencies.holderOf(r.competencyId, profile.id);
      if (held == null || held.level < r.level) gaps++;
      if (held != null) reached += held.level >= r.level ? r.level + 1 : held.level + 1;
    }
    final match = needed == 0 ? null : (reached * 100 / needed).round();
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        side: const BorderSide(color: HomeColors.cardBorder),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: PersonLine(
            profile: profile,
            detail: '${RoleRepository.instance.nameOf(profile.roleId)} · '
                '${needs.isEmpty ? 'nothing specific' : '$gaps ${gaps == 1 ? 'gap' : 'gaps'}'}',
            trailing: match == null
                ? null
                : Text('$match%', style: HomeText.body(14, weight: FontWeight.w800, color: HomeColors.ink)),
          ),
        ),
      ),
    );
  }
}
