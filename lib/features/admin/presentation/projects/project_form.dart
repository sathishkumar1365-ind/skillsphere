import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../competency/data/competency_models.dart';
import '../../../competency/data/competency_repository.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../data/admin_base.dart';
import '../../data/employees.dart';
import '../../data/job_roles.dart';
import '../../data/org_structure.dart';
import '../../data/projects.dart';
import '../widgets/admin_common.dart';

/// One editable requirement row.
class _Requirement {
  _Requirement({this.competencyId, this.level = 2, this.roleId});

  String? competencyId;
  int level;

  /// '' = everyone on the project.
  String? roleId;
}

/// Add or edit a project (HRD): basics, required competencies (optionally
/// per role) and team members. More project fields will follow.
class ProjectForm extends StatefulWidget {
  const ProjectForm({super.key, required this.user, required this.onSaved, this.project, this.onCancel});

  final AppUser user;

  /// Null = add a new project.
  final ProjectRecord? project;
  final ValueChanged<ProjectRecord> onSaved;
  final VoidCallback? onCancel;

  @override
  State<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<ProjectForm> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _customer = TextEditingController();
  final _description = TextEditingController();
  final _team = TextEditingController();
  String? _departmentId;
  String? _managerId;
  DateTime? _start;
  DateTime? _end;
  ProjectStatus _status = ProjectStatus.planned;
  final List<_Requirement> _requirements = [];
  List<String> _members = [];
  bool _saving = false;
  bool _submitted = false;

  bool get _isEdit => widget.project != null;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    if (p != null) {
      _code.text = p.code;
      _name.text = p.name;
      _customer.text = p.customer;
      _description.text = p.description;
      _team.text = p.plannedTeamSize == 0 ? '' : '${p.plannedTeamSize}';
      _departmentId = p.departmentId;
      _managerId = p.managerId;
      _start = p.startDate;
      _end = p.endDate;
      _status = p.status;
      _requirements.addAll([
        for (final r in p.requirements) _Requirement(competencyId: r.competencyId, level: r.level, roleId: r.roleId ?? ''),
      ]);
      _members = [...p.memberIds];
    }
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _customer, _description, _team]) {
      c.dispose();
    }
    super.dispose();
  }

  ProjectDraft _draft() => ProjectDraft(
        code: _code.text.trim(),
        name: _name.text,
        departmentId: _departmentId ?? '',
        startDate: _start ?? DateTime.now(),
        status: _status,
        customer: _customer.text,
        managerId: _managerId,
        endDate: _end,
        description: _description.text,
        plannedTeamSize: int.tryParse(_team.text.trim()) ?? 0,
        requirements: [
          for (final r in _requirements)
            if (r.competencyId != null)
              ProjectRequirement(r.competencyId!, r.level, roleId: (r.roleId ?? '').isEmpty ? null : r.roleId),
        ],
        memberIds: _members,
      );

  Map<String, String> get _errors {
    final e = <String, String>{};
    if (_code.text.trim().isEmpty) e['code'] = 'Enter a code.';
    if (cleanText(_name.text).isEmpty) e['name'] = 'Enter the name.';
    if (_departmentId == null) e['department'] = 'Choose the owning department.';
    if (_start == null) e['start'] = 'Choose the start date.';
    final team = _team.text.trim();
    if (team.isNotEmpty && (int.tryParse(team) == null || int.parse(team) < 0)) e['team'] = 'Enter a whole number.';
    if (_requirements.any((r) => r.competencyId == null)) e['requirements'] = 'Choose a competency in every row (or remove it).';
    if (e.isEmpty) {
      final problem = ProjectRepository.instance.problemWith(_draft(), exceptId: widget.project?.id);
      if (problem != null) e['form'] = problem;
    }
    return e;
  }

  Future<void> _save() async {
    final errors = _errors;
    setState(() => _submitted = true);
    if (errors.isNotEmpty) {
      showAdminMessage(context, errors['form'] ?? 'Please fix the highlighted fields.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ProjectRepository.instance;
      final saved = _isEdit
          ? await repo.update(by: widget.user, projectId: widget.project!.id, draft: _draft())
          : await repo.add(by: widget.user, draft: _draft());
      if (!mounted) return;
      if (!_isEdit) _clear();
      widget.onSaved(saved);
    } on AdminException catch (e) {
      if (mounted) showAdminMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clear() {
    for (final c in [_code, _name, _customer, _description, _team]) {
      c.clear();
    }
    setState(() {
      _departmentId = null;
      _managerId = null;
      _start = null;
      _end = null;
      _status = ProjectStatus.planned;
      _requirements.clear();
      _members = [];
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final errors = _submitted ? _errors : const <String, String>{};
    final structure = OrgStructureRepository.instance;
    final employees = EmployeeRepository.instance;
    final departments = [...structure.departments.value]
      ..sort((a, b) => structure.groupNameOfDepartment(a.id).compareTo(structure.groupNameOfDepartment(b.id)));
    final active = [...employees.active]..sort((a, b) => a.name.compareTo(b.name));
    final competencies = [...CompetencyRepository.instance.competencies.value]..sort((a, b) => a.name.compareTo(b.name));
    final roles = RoleRepository.instance.active;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepPanel(
          number: 1,
          title: 'Project details',
          child: FieldGrid(
            children: [
              LabeledField(
                label: 'Project code',
                required: true,
                child: TextField(
                  controller: _code,
                  style: adminInputStyle,
                  maxLength: ProjectRules.codeMax,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  decoration: adminDecoration(hint: 'e.g. BMS-VAL-27', errorText: errors['code']),
                ),
              ),
              LabeledField(
                label: 'Project name',
                required: true,
                child: TextField(
                  controller: _name,
                  style: adminInputStyle,
                  maxLength: ProjectRules.nameMax,
                  onChanged: (_) => setState(() {}),
                  decoration: adminDecoration(hint: 'e.g. EV BMS Validation', errorText: errors['name']),
                ),
              ),
              LabeledField(
                label: 'Customer / programme',
                optional: true,
                child: TextField(
                  controller: _customer,
                  style: adminInputStyle,
                  maxLength: ProjectRules.customerMax,
                  decoration: adminDecoration(hint: 'e.g. EV Programme'),
                ),
              ),
              LabeledField(
                label: 'Owning department',
                required: true,
                child: AdminDropdown<String>(
                  value: _departmentId,
                  items: [for (final d in departments) d.id],
                  labelOf: (id) => '${structure.departmentName(id)} · ${structure.groupNameOfDepartment(id)}',
                  hint: 'Choose a department',
                  errorText: errors['department'],
                  onChanged: (id) => setState(() => _departmentId = id),
                ),
              ),
              LabeledField(
                label: 'Project manager',
                optional: true,
                child: EmployeePickerField(
                  options: active,
                  selected: employees.byId(_managerId),
                  onChanged: (id) => setState(() => _managerId = id),
                ),
              ),
              LabeledField(
                label: 'Planned team size',
                optional: true,
                child: TextField(
                  controller: _team,
                  style: adminInputStyle,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: adminDecoration(hint: 'e.g. 8', errorText: errors['team']),
                ),
              ),
              LabeledField(
                label: 'Start date',
                required: true,
                child: DateField(
                  value: _start,
                  errorText: errors['start'],
                  onChanged: (d) => setState(() => _start = d),
                ),
              ),
              LabeledField(
                label: 'End date',
                optional: true,
                child: DateField(
                  value: _end,
                  clearable: true,
                  firstDate: _start,
                  onChanged: (d) => setState(() => _end = d),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StepPanel(
          number: 2,
          title: 'Status & description',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChoicePills<ProjectStatus>(
                options: ProjectStatus.values,
                selected: _status,
                labelOf: (s) => s.label,
                onSelected: (s) => setState(() => _status = s),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                maxLength: ProjectRules.descriptionMax,
                style: adminInputStyle,
                decoration: adminDecoration(hint: 'What the project delivers', counter: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StepPanel(
          number: 3,
          title: 'Required competencies',
          subtitle: 'The level each competency is needed at. Pick a role to require it only from people '
              'in that role; "Everyone" applies to the whole team.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _requirements.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RequirementRow(
                    key: ObjectKey(_requirements[i]),
                    requirement: _requirements[i],
                    competencies: competencies,
                    roles: roles,
                    onChanged: () => setState(() {}),
                    onRemove: () => setState(() => _requirements.removeAt(i)),
                  ),
                ),
              if (errors['requirements'] != null) FieldError(errors['requirements']!),
              Align(
                alignment: Alignment.centerLeft,
                child: PillButton(
                  label: '+ Add requirement',
                  variant: PillVariant.outline,
                  height: 42,
                  fontSize: 13.5,
                  horizontalPadding: 18,
                  onPressed: () => setState(() => _requirements.add(_Requirement(roleId: ''))),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StepPanel(
          number: 4,
          title: 'Team members',
          subtitle: 'People on the project. Their gap tables use this project\'s requirements.',
          child: EmployeeMultiPicker(
            options: active,
            selectedIds: _members,
            lookup: employees.byId,
            onChanged: (ids) => setState(() => _members = ids),
          ),
        ),
        if (errors['form'] != null) ...[
          const SizedBox(height: 14),
          InfoNote(tone: NoteTone.error, text: errors['form']!),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            PillButton(
              label: _saving ? 'Saving…' : (_isEdit ? 'Save project' : 'Add project'),
              onPressed: _saving ? null : _save,
            ),
            PillButton(
              label: _isEdit ? 'Cancel' : 'Clear form',
              variant: PillVariant.outline,
              onPressed: _saving ? null : (_isEdit ? widget.onCancel : _clear),
            ),
          ],
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    super.key,
    required this.requirement,
    required this.competencies,
    required this.roles,
    required this.onChanged,
    required this.onRemove,
  });

  final _Requirement requirement;
  final List<Competency> competencies;
  final List<JobRole> roles;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final r = requirement;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: AdminDropdown<String>(
                    value: r.competencyId,
                    items: [for (final c in competencies) c.id],
                    labelOf: (id) => CompetencyRepository.instance.byId(id)?.name ?? id,
                    hint: 'Competency',
                    onChanged: (id) {
                      r.competencyId = id;
                      onChanged();
                    },
                  ),
                ),
                LevelPicker(
                  level: r.level,
                  compact: true,
                  onChanged: (l) {
                    r.level = l;
                    onChanged();
                  },
                ),
                SizedBox(
                  width: 210,
                  child: AdminDropdown<String>(
                    value: r.roleId ?? '',
                    items: ['', for (final role in roles) role.id, if ((r.roleId ?? '').isNotEmpty && !roles.any((x) => x.id == r.roleId)) r.roleId!],
                    labelOf: (id) => id.isEmpty ? 'Everyone' : RoleRepository.instance.nameOf(id),
                    onChanged: (id) {
                      r.roleId = id;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove requirement',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
