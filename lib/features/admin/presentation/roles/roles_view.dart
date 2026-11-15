import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/admin_import.dart';
import '../../data/employees.dart';
import '../../data/job_roles.dart';
import '../../data/projects.dart';
import '../widgets/admin_common.dart';
import '../widgets/bulk_import_panel.dart';

enum _Mode { one, bulk }

/// Console › Roles: project roles (Software Developer, Test Engineer…).
/// Add one or import many; deactivate roles no longer used.
class RolesView extends StatefulWidget {
  const RolesView({super.key, required this.user});

  final AppUser user;

  @override
  State<RolesView> createState() => _RolesViewState();
}

class _RolesViewState extends State<RolesView> {
  _Mode _mode = _Mode.one;
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _description = TextEditingController();
  final _search = TextEditingController();
  String _query = '';
  bool _saving = false;
  String? _error;
  String? _spotlightId;

  late final BulkImportConfig<RoleDraft> _importConfig = BulkImportConfig<RoleDraft>(
    title: 'Bulk import roles',
    subtitle: 'Add many roles from Excel or CSV.',
    templateAsset: RoleImporter.templateAsset,
    templateFileName: RoleImporter.templateFileName,
    templateDescription: 'Role Name, Role Code and Description columns with automotive examples.',
    columnsHelp: 'Role Name · Role Code (optional, made from the name when empty) · Description.',
    singular: 'role',
    plural: 'roles',
    parse: (bytes, fileName) => RoleImporter.parse(bytes, fileName: fileName),
    commit: (drafts) async =>
        (await RoleRepository.instance.addAll(by: widget.user, drafts: drafts, source: RecordSource.bulkImport))
            .length,
  );

  @override
  void dispose() {
    for (final c in [_name, _code, _description, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final role = await RoleRepository.instance.add(
        by: widget.user,
        draft: RoleDraft(name: _name.text, code: _code.text, description: _description.text),
      );
      if (!mounted) return;
      _name.clear();
      _code.clear();
      _description.clear();
      setState(() => _spotlightId = role.id);
      showAdminMessage(context, '${role.name} (${role.code}) added.');
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final addPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModeSwitch<_Mode>(
          selected: _mode,
          onChanged: (m) => setState(() => _mode = m),
          options: const [
            ModeOption(_Mode.one, 'Add one', Icons.edit_note_rounded),
            ModeOption(_Mode.bulk, 'Import Excel / CSV', Icons.upload_file_rounded),
          ],
        ),
        const SizedBox(height: 14),
        FlipWhenShown(
          visible: _mode == _Mode.one,
          child: StepPanel(
            icon: Icons.badge_outlined,
            title: 'Add a role',
            subtitle: 'The role someone plays on a project. Projects can require competencies per role.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledField(
                  label: 'Role name',
                  required: true,
                  child: TextField(
                    controller: _name,
                    style: adminInputStyle,
                    maxLength: RoleRules.nameMax,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() => _error = null),
                    decoration: adminDecoration(hint: 'e.g. AUTOSAR Integrator'),
                  ),
                ),
                LabeledField(
                  label: 'Code',
                  optional: true,
                  child: TextField(
                    controller: _code,
                    style: adminInputStyle,
                    maxLength: RoleRules.codeMax,
                    textCapitalization: TextCapitalization.characters,
                    decoration: adminDecoration(hint: 'e.g. AI (made from the name when empty)'),
                  ),
                ),
                LabeledField(
                  label: 'Description',
                  optional: true,
                  child: TextField(
                    controller: _description,
                    style: adminInputStyle,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: RoleRules.descriptionMax,
                    decoration: adminDecoration(hint: 'What people in this role do', counter: true),
                  ),
                ),
                if (_error != null) ...[
                  InfoNote(tone: NoteTone.error, text: _error!),
                  const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: PillButton(label: _saving ? 'Adding…' : 'Add role', onPressed: _saving ? null : _add),
                ),
              ],
            ),
          ),
        ),
        FlipWhenShown(
          visible: _mode == _Mode.bulk,
          child: BulkImportPanel<RoleDraft>(
            config: _importConfig,
            onImported: (n) => showAdminMessage(context, '$n ${n == 1 ? 'role' : 'roles'} imported. They are marked NEW.'),
          ),
        ),
      ],
    );

    final list = _RoleList(
      user: widget.user,
      query: _query,
      spotlightId: _spotlightId,
      search: AdminSearchField(
        controller: _search,
        hint: 'Search roles…',
        onChanged: (v) => setState(() => _query = v),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'ROLES',
          subtitle: 'Project roles employees are given. Different from designation (job title) and from '
              'the app access levels. More role settings will follow.',
        ),
        const SizedBox(height: 24),
        if (width >= 1320)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 400, child: addPanel),
              const SizedBox(width: 22),
              Expanded(child: list),
            ],
          )
        else ...[
          addPanel,
          const SizedBox(height: 22),
          list,
        ],
      ],
    );
  }
}

class _RoleList extends StatelessWidget {
  const _RoleList({required this.user, required this.query, required this.search, required this.spotlightId});

  final AppUser user;
  final String query;
  final Widget search;
  final String? spotlightId;

  @override
  Widget build(BuildContext context) {
    final roles = RoleRepository.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        roles.roles,
        EmployeeRepository.instance.employees,
        ProjectRepository.instance.projects,
      ]),
      builder: (context, _) {
        final q = query.trim().toLowerCase();
        final list = roles.roles.value
            .where((r) => q.isEmpty || '${r.name} ${r.code} ${r.description}'.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) {
            final aNew = roles.isNew(a.id) ? 0 : 1;
            final bNew = roles.isNew(b.id) ? 0 : 1;
            return aNew != bNew ? aNew.compareTo(bNew) : a.name.compareTo(b.name);
          });
        final employees = EmployeeRepository.instance.employees.value;
        final projects = ProjectRepository.instance.projects.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 12),
            Text('${list.length} of ${roles.roles.value.length} roles · ${roles.active.length} active',
                style: HomeText.body(13.5, weight: FontWeight.w600, color: HomeColors.muted)),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const EmptyState(title: 'No roles match', icon: Icons.badge_outlined)
            else
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TurnIn(
                    key: ValueKey<String>('role-${r.id}'),
                    play: roles.isNew(r.id) || r.id == spotlightId,
                    child: _RoleTile(
                      role: r,
                      isNew: roles.isNew(r.id),
                      people: employees.where((e) => e.roleId == r.id && e.isActive).length,
                      projects: projects.where((p) => p.requirements.any((x) => x.roleId == r.id)).length,
                      onActive: (v) {
                        try {
                          roles.setActive(by: user, roleId: r.id, active: v);
                        } on AdminException catch (e) {
                          showAdminMessage(context, e.message);
                        }
                      },
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.role,
    required this.isNew,
    required this.people,
    required this.projects,
    required this.onActive,
  });

  final JobRole role;
  final bool isNew;
  final int people;
  final int projects;
  final ValueChanged<bool> onActive;

  @override
  Widget build(BuildContext context) {
    return OrgPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      color: role.active ? Colors.white : const Color(0xFFF6F8FB),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: role.active
                    ? const [Color(0xFF3C7BE8), HomeColors.ink]
                    : const [Color(0xFFB8C2D0), Color(0xFF8592A6)],
              ),
              boxShadow: const [
                BoxShadow(color: Color.fromRGBO(15, 27, 45, 0.25), blurRadius: 12, spreadRadius: -5, offset: Offset(0, 6)),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(role.code, style: HomeText.display(18, color: Colors.white, height: 1)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(role.name,
                          overflow: TextOverflow.ellipsis,
                          style: HomeText.body(15, weight: FontWeight.w800, color: HomeColors.ink)),
                    ),
                    if (isNew) ...[const SizedBox(width: 8), const NewLabel()],
                    if (!role.active) ...[
                      const SizedBox(width: 8),
                      const StatusPill(label: 'Inactive', background: HomeColors.neutralTint, foreground: HomeColors.body),
                    ],
                  ],
                ),
                if (role.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(role.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: HomeText.body(13, color: HomeColors.body)),
                ],
                const SizedBox(height: 4),
                Text('$people ${people == 1 ? 'employee' : 'employees'} · used in $projects '
                    '${projects == 1 ? 'project' : 'projects'} · ${role.source.label}',
                    style: HomeText.body(12, color: HomeColors.muted)),
              ],
            ),
          ),
          Tooltip(
            message: role.active ? 'Active – can be given to employees' : 'Inactive – kept for history',
            child: Switch(value: role.active, onChanged: onActive),
          ),
        ],
      ),
    );
  }
}
