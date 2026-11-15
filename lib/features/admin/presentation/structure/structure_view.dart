import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/admin_import.dart';
import '../../data/crowd.dart';
import '../../data/employees.dart';
import '../../data/org_structure.dart';
import '../../data/projects.dart';
import '../onboarding/crowd_panel.dart';
import '../widgets/admin_common.dart';
import '../widgets/bulk_import_panel.dart';

enum _Mode { structure, add, bulk, crowd }

/// Console › Groups & Departments: the organisation structure (groups and
/// the departments inside them), add new ones, import from Excel/CSV or
/// synchronise from Crowd, and move a department to another group.
class StructureView extends StatefulWidget {
  const StructureView({super.key, required this.user, required this.onOpenEmployee});

  final AppUser user;
  final ValueChanged<String> onOpenEmployee;

  @override
  State<StructureView> createState() => _StructureViewState();
}

class _StructureViewState extends State<StructureView> {
  _Mode _mode = _Mode.structure;

  late final BulkImportConfig<StructureDraft> _importConfig = BulkImportConfig<StructureDraft>(
    title: 'Bulk import groups & departments',
    subtitle: 'One row per department (with its group). A group that doesn\'t exist yet is created.',
    templateAsset: StructureImporter.templateAsset,
    templateFileName: StructureImporter.templateFileName,
    templateDescription: 'Group, codes, Department, Department Head and descriptions, with '
        'automotive examples and an Instructions sheet.',
    columnsHelp: 'Group · Group Code · Group Description · Department · Department Code · '
        'Department Head (employee ID) · Department Description. Leave Department empty to add only a group.',
    singular: 'row',
    plural: 'rows',
    parse: (bytes, fileName) => StructureImporter.parse(bytes, fileName: fileName),
    commit: (drafts) async {
      final result = await OrgStructureRepository.instance
          .addAll(by: widget.user, drafts: drafts, source: RecordSource.bulkImport);
      return result.groups.length + result.departments.length;
    },
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'GROUPS & DEPARTMENTS',
          subtitle: 'Business groups and the departments inside them. Every employee belongs to one '
              'department; moving a department to another group moves its people too (logged in '
              'Profile Changes).',
        ),
        const SizedBox(height: 24),
        ModeSwitch<_Mode>(
          selected: _mode,
          onChanged: (m) => setState(() => _mode = m),
          options: const [
            ModeOption(_Mode.structure, 'Structure', Icons.account_tree_outlined),
            ModeOption(_Mode.add, 'Add new', Icons.add_box_outlined),
            ModeOption(_Mode.bulk, 'Bulk import', Icons.upload_file_rounded),
            ModeOption(_Mode.crowd, 'Crowd sync', Icons.sync_rounded),
          ],
        ),
        const SizedBox(height: 20),
        FlipWhenShown(
          visible: _mode == _Mode.structure,
          child: _StructureList(user: widget.user, onOpenEmployee: widget.onOpenEmployee),
        ),
        FlipWhenShown(
          visible: _mode == _Mode.add,
          child: _AddForms(
            user: widget.user,
            onAdded: (text) {
              showAdminMessage(context, text);
            },
          ),
        ),
        FlipWhenShown(
          visible: _mode == _Mode.bulk,
          child: BulkImportPanel<StructureDraft>(
            config: _importConfig,
            onImported: (n) {
              setState(() => _mode = _Mode.structure);
              showAdminMessage(context, '$n groups/departments added. They are marked NEW.');
            },
          ),
        ),
        FlipWhenShown(
          visible: _mode == _Mode.crowd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CrowdConnectionPanel(user: widget.user),
              const SizedBox(height: 18),
              _CrowdGroupsPanel(
                user: widget.user,
                onDone: (text) {
                  setState(() => _mode = _Mode.structure);
                  showAdminMessage(context, text);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================ structure

class _StructureList extends StatelessWidget {
  const _StructureList({required this.user, required this.onOpenEmployee});

  final AppUser user;
  final ValueChanged<String> onOpenEmployee;

  @override
  Widget build(BuildContext context) {
    final structure = OrgStructureRepository.instance;
    final employees = EmployeeRepository.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        structure.groups,
        structure.departments,
        employees.employees,
        ProjectRepository.instance.projects,
      ]),
      builder: (context, _) {
        final groups = [...structure.groups.value]..sort((a, b) {
            final aNew = structure.isNew(a.id) ? 0 : 1;
            final bNew = structure.isNew(b.id) ? 0 : 1;
            return aNew != bNew ? aNew.compareTo(bNew) : a.name.compareTo(b.name);
          });
        final width = MediaQuery.sizeOf(context).width;
        final departmentCount = structure.departments.value.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EqualHeightGrid(
              columns: width >= 900 ? 3 : 1,
              spacing: 14,
              runSpacing: 14,
              children: [
                KpiCard(value: groups.length, label: 'Groups'),
                KpiCard(value: departmentCount, label: 'Departments'),
                KpiCard(value: employees.active.length, label: 'Active employees', dark: true),
              ],
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < groups.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: TurnIn(
                  key: ValueKey<String>('grp-${groups[i].id}'),
                  delay: Duration(milliseconds: (i < 6 ? i : 6) * 70),
                  child: _GroupCard(group: groups[i], user: user, onOpenEmployee: onOpenEmployee),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.user, required this.onOpenEmployee});

  final OrgGroup group;
  final AppUser user;
  final ValueChanged<String> onOpenEmployee;

  @override
  Widget build(BuildContext context) {
    final structure = OrgStructureRepository.instance;
    final employees = EmployeeRepository.instance;
    final departments = structure.departmentsIn(group.id);
    final people = departments.fold<int>(0, (s, d) => s + employees.inDepartment(d.id).length);
    return LiftCard(
      padding: const EdgeInsets.all(22),
      liftBy: 5,
      tiltDegrees: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3C7BE8), HomeColors.ink],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color.fromRGBO(15, 27, 45, 0.3), blurRadius: 14, spreadRadius: -6, offset: Offset(0, 7)),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(group.code, style: HomeText.display(20, color: Colors.white, height: 1)),
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
                          child: Text(group.name.toUpperCase(),
                              overflow: TextOverflow.ellipsis, style: HomeText.display(26, height: 1.05)),
                        ),
                        if (structure.isNew(group.id)) ...[const SizedBox(width: 8), const NewLabel()],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${departments.length} ${departments.length == 1 ? 'department' : 'departments'} · '
                      '$people ${people == 1 ? 'person' : 'people'}'
                      '${group.crowdGroup == null ? '' : ' · Crowd: ${group.crowdGroup}'}',
                      style: HomeText.body(13, color: HomeColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (group.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(group.description, style: HomeText.body(14, height: 1.5)),
          ],
          const SizedBox(height: 14),
          if (departments.isEmpty)
            Text('No departments yet. Add one under Add new.', style: HomeText.body(13.5, color: HomeColors.muted))
          else
            for (final d in departments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DepartmentRow(department: d, user: user, onOpenEmployee: onOpenEmployee),
              ),
        ],
      ),
    );
  }
}

class _DepartmentRow extends StatelessWidget {
  const _DepartmentRow({required this.department, required this.user, required this.onOpenEmployee});

  final OrgDepartment department;
  final AppUser user;
  final ValueChanged<String> onOpenEmployee;

  Future<void> _move(BuildContext context) async {
    final moved = await showSwingPanel<int>(
      context: context,
      title: 'Move department',
      subtitle: '${department.name} and everyone in it move to another group.',
      width: 640,
      builder: (panelContext) => _MoveDepartmentForm(
        user: user,
        department: department,
        onDone: (n) => Navigator.of(panelContext).pop(n),
      ),
    );
    if (moved != null && context.mounted) {
      showAdminMessage(context, '${department.name} moved. $moved group ${moved == 1 ? 'change' : 'changes'} logged.');
    }
  }

  Future<void> _setHead(BuildContext context) async {
    final employees = EmployeeRepository.instance;
    final candidates = [...employees.active]..sort((a, b) => a.name.compareTo(b.name));
    final picked = await showSwingPanel<String>(
      context: context,
      title: 'Department head',
      subtitle: department.name,
      width: 560,
      builder: (panelContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Search the person who leads ${department.name}.', style: HomeText.body(14, height: 1.5)),
          const SizedBox(height: 12),
          EmployeeSearchBox(
            options: candidates,
            onPicked: (e) => Navigator.of(panelContext).pop(e.id),
            detailOf: (e) => '${e.id} · ${employees.departmentNameOf(e)}',
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    try {
      OrgStructureRepository.instance.setHead(by: user, departmentId: department.id, employeeId: picked);
      showAdminMessage(context, '${employees.nameOf(picked)} now heads ${department.name}.');
    } on AdminException catch (e) {
      showAdminMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final structure = OrgStructureRepository.instance;
    final employees = EmployeeRepository.instance;
    final head = employees.byId(department.headId);
    final people = employees.inDepartment(department.id).length;
    final projects = ProjectRepository.instance.projects.value.where((p) => p.departmentId == department.id).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: Row(
                    children: [
                      const Icon(Icons.apartment_rounded, size: 18, color: HomeColors.blueDeep),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(department.name,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(14.5, weight: FontWeight.w800, color: HomeColors.ink)),
                      ),
                      const SizedBox(width: 6),
                      Text(department.code, style: HomeText.body(12, weight: FontWeight.w700, color: HomeColors.muted)),
                      if (structure.isNew(department.id)) ...[const SizedBox(width: 6), const NewLabel()],
                    ],
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: head == null
                      ? Text('No head set', style: HomeText.body(13, weight: FontWeight.w600, color: HomeColors.orangeText))
                      : InkWell(
                          onTap: () => onOpenEmployee(head.id),
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                          child: PersonLine(profile: head, size: 28, detail: 'Head · ${head.designation}'),
                        ),
                ),
                Text('$people people · $projects ${projects == 1 ? 'project' : 'projects'}',
                    style: HomeText.body(13, color: HomeColors.body)),
              ],
            ),
          ),
          PopupMenuButton<int>(
            tooltip: 'Department actions',
            color: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            onSelected: (v) => v == 0 ? _move(context) : _setHead(context),
            itemBuilder: (context) => const [
              PopupMenuItem<int>(value: 0, child: Text('Move to another group…')),
              PopupMenuItem<int>(value: 1, child: Text('Change department head…')),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }
}

class _MoveDepartmentForm extends StatefulWidget {
  const _MoveDepartmentForm({required this.user, required this.department, required this.onDone});

  final AppUser user;
  final OrgDepartment department;
  final ValueChanged<int> onDone;

  @override
  State<_MoveDepartmentForm> createState() => _MoveDepartmentFormState();
}

class _MoveDepartmentFormState extends State<_MoveDepartmentForm> {
  final _note = TextEditingController();
  String? _groupId;
  ChangeReason _reason = ChangeReason.reorg;
  DateTime _effective = dateOnly(DateTime.now());
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _move() async {
    final target = _groupId;
    if (target == null) {
      setState(() => _error = 'Choose the new group.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final count = await OrgStructureRepository.instance.moveDepartment(
        by: widget.user,
        departmentId: widget.department.id,
        toGroupId: target,
        reason: _reason,
        effectiveDate: _effective,
        note: _note.text,
      );
      if (mounted) widget.onDone(count);
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final structure = OrgStructureRepository.instance;
    final current = structure.groupOfDepartment(widget.department.id);
    final groups = structure.groups.value.where((g) => g.id != current?.id).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final people = EmployeeRepository.instance.inDepartment(widget.department.id, activeOnly: false).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoNote(text: 'Now in ${current?.name ?? '—'}. $people ${people == 1 ? 'person' : 'people'} will get a '
            'group change in their history.'),
        const SizedBox(height: 16),
        LabeledField(
          label: 'New group',
          required: true,
          child: AdminDropdown<String>(
            value: _groupId,
            items: [for (final g in groups) g.id],
            labelOf: (id) => structure.groupById(id)?.name ?? id,
            hint: 'Choose a group',
            onChanged: (id) => setState(() => _groupId = id),
          ),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Reason'),
        ChoicePills<ChangeReason>(
          options: ChangeReason.selectable,
          selected: _reason,
          labelOf: (r) => r.label,
          onSelected: (r) => setState(() => _reason = r),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Effective from',
          required: true,
          child: DateField(value: _effective, onChanged: (d) => setState(() => _effective = d ?? _effective)),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Note',
          optional: true,
          child: TextField(
            controller: _note,
            style: adminInputStyle,
            maxLength: 160,
            decoration: adminDecoration(hint: 'e.g. Q1 2027 re-org'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          InfoNote(tone: NoteTone.error, text: _error!),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PillButton(label: _saving ? 'Moving…' : 'Move department', onPressed: _saving ? null : _move),
            PillButton(
              label: 'Cancel',
              variant: PillVariant.outline,
              onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }
}

// ================================================================= add

class _AddForms extends StatefulWidget {
  const _AddForms({required this.user, required this.onAdded});

  final AppUser user;
  final ValueChanged<String> onAdded;

  @override
  State<_AddForms> createState() => _AddFormsState();
}

class _AddFormsState extends State<_AddForms> {
  final _groupName = TextEditingController();
  final _groupCode = TextEditingController();
  final _groupDescription = TextEditingController();
  final _departmentName = TextEditingController();
  final _departmentCode = TextEditingController();
  final _departmentDescription = TextEditingController();
  String? _groupId;
  String? _headId;
  bool _savingGroup = false;
  bool _savingDepartment = false;
  String? _groupError;
  String? _departmentError;

  @override
  void dispose() {
    for (final c in [
      _groupName,
      _groupCode,
      _groupDescription,
      _departmentName,
      _departmentCode,
      _departmentDescription,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addGroup() async {
    setState(() {
      _savingGroup = true;
      _groupError = null;
    });
    try {
      final g = await OrgStructureRepository.instance.addGroup(
        by: widget.user,
        name: _groupName.text,
        // Empty = a free code is made from the name.
        code: _groupCode.text,
        description: _groupDescription.text,
      );
      if (!mounted) return;
      _groupName.clear();
      _groupCode.clear();
      _groupDescription.clear();
      setState(() => _groupId = g.id);
      widget.onAdded('Group ${g.name} (${g.code}) added. Add its departments next.');
    } on AdminException catch (e) {
      if (mounted) setState(() => _groupError = e.message);
    } finally {
      if (mounted) setState(() => _savingGroup = false);
    }
  }

  Future<void> _addDepartment() async {
    final groupId = _groupId;
    if (groupId == null) {
      setState(() => _departmentError = 'Choose the group first.');
      return;
    }
    setState(() {
      _savingDepartment = true;
      _departmentError = null;
    });
    try {
      final d = await OrgStructureRepository.instance.addDepartment(
        by: widget.user,
        groupId: groupId,
        name: _departmentName.text,
        code: _departmentCode.text,
        headId: _headId,
        description: _departmentDescription.text,
      );
      if (!mounted) return;
      _departmentName.clear();
      _departmentCode.clear();
      _departmentDescription.clear();
      setState(() => _headId = null);
      widget.onAdded('Department ${d.name} added to ${OrgStructureRepository.instance.groupById(groupId)?.name}.');
    } on AdminException catch (e) {
      if (mounted) setState(() => _departmentError = e.message);
    } finally {
      if (mounted) setState(() => _savingDepartment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([OrgStructureRepository.instance.groups, OrgStructureRepository.instance.departments]),
      builder: (context, _) {
        final structure = OrgStructureRepository.instance;
        final employees = EmployeeRepository.instance;
        final groups = [...structure.groups.value]..sort((a, b) => a.name.compareTo(b.name));
        final active = [...employees.active]..sort((a, b) => a.name.compareTo(b.name));
        final groupPanel = StepPanel(
          icon: Icons.account_tree_outlined,
          title: 'New group',
          subtitle: 'A business group, e.g. Vehicle Software.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Group name',
                required: true,
                child: TextField(
                  controller: _groupName,
                  style: adminInputStyle,
                  maxLength: StructureRules.nameMax,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => _groupError = null),
                  decoration: adminDecoration(hint: 'e.g. Vehicle Software'),
                ),
              ),
              LabeledField(
                label: 'Code',
                optional: true,
                child: TextField(
                  controller: _groupCode,
                  style: adminInputStyle,
                  maxLength: StructureRules.codeMax,
                  textCapitalization: TextCapitalization.characters,
                  decoration: adminDecoration(
                    hint: _groupName.text.trim().isEmpty
                        ? 'Made from the name when empty'
                        : 'Suggested: ${StructureRules.suggestCode(_groupName.text)}',
                  ),
                ),
              ),
              LabeledField(
                label: 'Description',
                optional: true,
                child: TextField(
                  controller: _groupDescription,
                  style: adminInputStyle,
                  maxLength: StructureRules.descriptionMax,
                  decoration: adminDecoration(hint: 'What the group covers'),
                ),
              ),
              if (_groupError != null) ...[
                InfoNote(tone: NoteTone.error, text: _groupError!),
                const SizedBox(height: 12),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: PillButton(label: _savingGroup ? 'Adding…' : 'Add group', onPressed: _savingGroup ? null : _addGroup),
              ),
            ],
          ),
        );
        final departmentPanel = StepPanel(
          icon: Icons.apartment_rounded,
          title: 'New department',
          subtitle: 'Inside a group, e.g. Functional Safety in Vehicle Software.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Group',
                required: true,
                child: AdminDropdown<String>(
                  value: _groupId,
                  items: [for (final g in groups) g.id],
                  labelOf: (id) => structure.groupById(id)?.name ?? id,
                  hint: 'Choose a group',
                  onChanged: (id) => setState(() => _groupId = id),
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Department name',
                required: true,
                child: TextField(
                  controller: _departmentName,
                  style: adminInputStyle,
                  maxLength: StructureRules.nameMax,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => _departmentError = null),
                  decoration: adminDecoration(hint: 'e.g. Functional Safety'),
                ),
              ),
              LabeledField(
                label: 'Code',
                optional: true,
                child: TextField(
                  controller: _departmentCode,
                  style: adminInputStyle,
                  maxLength: StructureRules.codeMax,
                  textCapitalization: TextCapitalization.characters,
                  decoration: adminDecoration(
                    hint: _departmentName.text.trim().isEmpty
                        ? 'Made from the name when empty'
                        : 'Suggested: ${StructureRules.suggestCode(_departmentName.text)}',
                  ),
                ),
              ),
              LabeledField(
                label: 'Department head',
                optional: true,
                child: EmployeePickerField(
                  options: active,
                  selected: employees.byId(_headId),
                  onChanged: (id) => setState(() => _headId = id),
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Description',
                optional: true,
                child: TextField(
                  controller: _departmentDescription,
                  style: adminInputStyle,
                  maxLength: StructureRules.descriptionMax,
                  decoration: adminDecoration(hint: 'What the department does'),
                ),
              ),
              if (_departmentError != null) ...[
                InfoNote(tone: NoteTone.error, text: _departmentError!),
                const SizedBox(height: 12),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: PillButton(
                  label: _savingDepartment ? 'Adding…' : 'Add department',
                  onPressed: _savingDepartment ? null : _addDepartment,
                ),
              ),
            ],
          ),
        );
        return LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 900
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: groupPanel),
                    const SizedBox(width: 18),
                    Expanded(child: departmentPanel),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [groupPanel, const SizedBox(height: 18), departmentPanel],
                ),
        );
      },
    );
  }
}

// =========================================================== Crowd sync

class _CrowdGroupsPanel extends StatefulWidget {
  const _CrowdGroupsPanel({required this.user, required this.onDone});

  final AppUser user;
  final ValueChanged<String> onDone;

  @override
  State<_CrowdGroupsPanel> createState() => _CrowdGroupsPanelState();
}

class _CrowdGroupsPanelState extends State<_CrowdGroupsPanel> {
  List<CrowdGroupChange>? _changes;
  final Set<String> _selected = {};
  bool _busy = false;
  String? _error;

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final changes = await CrowdService.instance.previewGroups(by: widget.user);
      if (!mounted) return;
      setState(() {
        _changes = changes;
        _selected
          ..clear()
          ..addAll(changes.map((c) => c.group.name));
      });
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final changes = _changes;
    if (changes == null) return;
    setState(() => _busy = true);
    try {
      final chosen = changes.where((c) => _selected.contains(c.group.name)).toList();
      final result = await CrowdService.instance.applyGroups(by: widget.user, selected: chosen);
      if (!mounted) return;
      setState(() => _changes = null);
      widget.onDone(result.isEmpty
          ? 'Nothing was added.'
          : '${result.groups.length} groups and ${result.departments.length} departments added from Crowd.');
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CrowdService.instance.settings,
      builder: (context, _) {
        final configured = CrowdService.instance.isConfigured;
        final changes = _changes;
        return StepPanel(
          icon: Icons.sync_rounded,
          title: 'Synchronise groups & departments',
          subtitle: 'Crowd groups named with the group prefix (grp-…) become groups; those with the '
              'department prefix (dept-…) become departments inside the group they are nested in.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!configured)
                const InfoNote(text: 'Save the Crowd connection above first.')
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: PillButton(
                    label: _busy && changes == null ? 'Checking Crowd…' : 'Check Crowd groups',
                    height: 46,
                    fontSize: 14,
                    onPressed: _busy ? null : _check,
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                InfoNote(tone: NoteTone.error, text: _error!),
              ],
              if (changes != null) ...[
                const SizedBox(height: 16),
                if (changes.isEmpty)
                  const InfoNote(tone: NoteTone.success, text: 'All Crowd groups are already in SkillSphere.')
                else ...[
                  for (final c in changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TurnIn(
                        key: ValueKey<String>('crowd-${c.group.name}'),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.all(Radius.circular(14)),
                            border: Border.all(color: HomeColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _selected.contains(c.group.name),
                                activeColor: HomeColors.ink,
                                onChanged: (v) => setState(() {
                                  if (v ?? false) {
                                    _selected.add(c.group.name);
                                  } else {
                                    _selected.remove(c.group.name);
                                  }
                                }),
                              ),
                              Icon(c.isDepartment ? Icons.apartment_rounded : Icons.account_tree_outlined,
                                  size: 20, color: HomeColors.blueDeep),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.isDepartment
                                          ? '${c.parentDisplayName ?? '(no parent group)'} › ${c.displayName}'
                                          : c.displayName,
                                      style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink),
                                    ),
                                    Text(
                                      '${c.isDepartment ? 'New department' : 'New group'} · Crowd group ${c.group.name}'
                                      ' · ${c.group.members} members',
                                      style: HomeText.body(12.5, color: HomeColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      PillButton(
                        label: _busy ? 'Adding…' : 'Add ${_selected.length} selected',
                        onPressed: _busy || _selected.isEmpty ? null : _apply,
                      ),
                      PillButton(
                        label: 'Cancel',
                        variant: PillVariant.outline,
                        onPressed: _busy ? null : () => setState(() => _changes = null),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
