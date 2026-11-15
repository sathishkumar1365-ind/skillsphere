import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../additional_competency/data/additional_competency.dart';
import '../../../additional_competency/data/additional_competency_repository.dart';
import '../../../competency/data/competency_models.dart';
import '../../../competency/data/competency_repository.dart';
import '../../../competency/presentation/widgets/competency_common.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/approvals.dart';
import '../../data/employees.dart';
import '../../data/job_roles.dart';
import '../../data/locations.dart';
import '../../data/org_structure.dart';
import '../../data/projects.dart';
import '../widgets/admin_common.dart';

const String _otherCity = '__other__';

/// The employee form: onboarding a new employee (HRD) or updating a
/// profile (HRD, or a Team Lead for their own department).
///
/// Team Leads can't change group, department or status, and the skill
/// levels they raise or add are sent to HR as level-up requests instead of
/// being saved directly.
class EmployeeForm extends StatefulWidget {
  const EmployeeForm({
    super.key,
    required this.user,
    required this.onSaved,
    this.employee,
    this.onCancel,
  });

  final AppUser user;

  /// Null = onboard a new employee.
  final EmployeeProfile? employee;

  /// Called with the saved profile.
  final ValueChanged<EmployeeProfile> onSaved;
  final VoidCallback? onCancel;

  @override
  State<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<EmployeeForm> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _designation = TextEditingController();
  final _intro = TextEditingController();
  final _otherCityText = TextEditingController();
  final _changeNote = TextEditingController();
  final _levelNote = TextEditingController();

  Gender? _gender;
  EmploymentStatus _status = EmploymentStatus.active;
  String? _groupId;
  String? _departmentId;
  String? _managerId;
  String? _managerName;
  String? _roleId;
  String? _country;
  String? _state;
  String? _city;
  final List<CertificateFile> _certificates = [];

  /// Competency id → level, in the order they were added.
  final Map<String, int> _levels = {};

  /// Levels when the form opened (edit mode).
  Map<String, int> _originalLevels = const {};
  final List<String> _additional = [];
  Set<String> _projectIds = {};
  Set<String> _originalProjectIds = const {};

  ChangeReason _reason = ChangeReason.correction;
  DateTime _effective = dateOnly(DateTime.now());

  bool _submitted = false;
  bool _saving = false;
  bool _pickingFiles = false;

  EmployeeRepository get _employees => EmployeeRepository.instance;
  OrgStructureRepository get _structure => OrgStructureRepository.instance;

  bool get _isEdit => widget.employee != null;

  /// HRD may change everything; a Team Lead not group/department/status.
  bool get _canPlace => _employees.canChangePlacement(widget.user);

  /// Team Lead: level changes become approval requests.
  bool get _levelsNeedApproval => _isEdit && !widget.user.role.canManageOrganization;

  @override
  void initState() {
    super.initState();
    _load(widget.employee);
  }

  void _load(EmployeeProfile? e) {
    if (e == null) return;
    _id.text = e.id;
    _name.text = e.name;
    _email.text = e.email;
    _designation.text = e.designation;
    _intro.text = e.intro;
    _gender = e.gender;
    _status = e.status;
    _departmentId = e.departmentId;
    _groupId = _structure.departmentById(e.departmentId)?.groupId;
    _managerId = e.managerId;
    _managerName = e.managerName;
    _roleId = e.roleId;
    final country = LocationCatalog.matchCountry(e.location.country);
    _country = country;
    if (country != null) {
      final state = LocationCatalog.matchState(country, e.location.state);
      _state = state;
      if (state != null && e.location.city.isNotEmpty) {
        final city = LocationCatalog.matchCity(country, state, e.location.city);
        if (city != null) {
          _city = city;
        } else {
          _city = _otherCity;
          _otherCityText.text = e.location.city;
        }
      }
    }
    _certificates.addAll(e.certificates);
    for (final held in CompetencyRepository.instance.levelsFor(e.id)) {
      _levels[held.competency.id] = held.level;
    }
    _originalLevels = Map<String, int>.unmodifiable(_levels);
    _projectIds = {for (final p in ProjectRepository.instance.forEmployee(e.id)) p.id};
    _originalProjectIds = Set<String>.unmodifiable(_projectIds);
  }

  @override
  void dispose() {
    for (final c in [_id, _name, _email, _designation, _intro, _otherCityText, _changeNote, _levelNote]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch() {
    if (_submitted) setState(() {});
  }

  // ------------------------------------------------------- validation

  /// Field key → problem. Shown under each field after the first submit.
  Map<String, String> get _errors {
    final errors = <String, String>{};
    if (!_isEdit) {
      final idIssue = _employees.idProblem(_id.text);
      if (idIssue != null) errors['id'] = idIssue;
    }
    final name = cleanText(_name.text);
    if (name.isEmpty) {
      errors['name'] = 'Enter the full name.';
    } else if (name.length > EmployeeRules.nameMax) {
      errors['name'] = 'Keep it under ${EmployeeRules.nameMax} characters.';
    }
    final emailIssue = _employees.emailProblem(_email.text, exceptId: widget.employee?.id);
    if (emailIssue != null) errors['email'] = emailIssue;
    if (_gender == null) errors['gender'] = 'Choose an option.';
    if (_groupId == null) errors['group'] = 'Choose the group.';
    if (_departmentId == null) errors['department'] = 'Choose the department.';
    final designation = _designation.text.trim();
    if (designation.isEmpty) {
      errors['designation'] = 'Enter the designation (job title).';
    } else if (designation.length > EmployeeRules.designationMax) {
      errors['designation'] = 'Keep it under ${EmployeeRules.designationMax} characters.';
    }
    if (_roleId == null) errors['role'] = 'Choose the role.';
    if (_country == null) errors['country'] = 'Choose the country.';
    if (_city == _otherCity && _otherCityText.text.trim().isEmpty) errors['city'] = 'Type the city.';
    if (_intro.text.trim().length > EmployeeRules.introMax) {
      errors['intro'] = 'Keep it under ${EmployeeRules.introMax} characters.';
    }
    if (_levelsNeedApproval && _levelChanges.isNotEmpty && _levelNote.text.trim().length < ApprovalRules.noteMin) {
      errors['levelNote'] = 'Tell HR why (at least ${ApprovalRules.noteMin} characters).';
    }
    return errors;
  }

  String? _error(String key, Map<String, String> errors) => _submitted ? errors[key] : null;

  /// Live problems shown while typing (taken ID or email).
  String? _liveError(String key, Map<String, String> errors) {
    if (_submitted) return errors[key];
    final text = key == 'id' ? _id.text : _email.text;
    final problem = errors[key];
    if (text.trim().isEmpty || problem == null) return null;
    return problem.contains('belongs to') || problem.contains('used by') ? problem : null;
  }

  /// Competencies whose level is new or raised compared to when the form
  /// opened (edit mode).
  Map<String, int> get _levelChanges => {
        for (final entry in _levels.entries)
          if ((_originalLevels[entry.key] ?? -1) < entry.value) entry.key: entry.value,
      };

  bool get _placementChanged {
    final e = widget.employee;
    if (e == null) return false;
    return e.departmentId != _departmentId ||
        e.managerId != _managerId ||
        e.designation.trim() != _designation.text.trim() ||
        e.roleId != _roleId ||
        e.status != _status;
  }

  EmployeeLocation get _location => EmployeeLocation(
        country: _country ?? '',
        state: _state ?? '',
        city: _city == _otherCity ? cleanText(_otherCityText.text) : (_city ?? ''),
      );

  EmployeeDraft _draft() => EmployeeDraft(
        id: _isEdit ? widget.employee!.id : _id.text.trim(),
        name: _name.text,
        email: _email.text,
        gender: _gender ?? Gender.undisclosed,
        status: _status,
        departmentId: _departmentId ?? '',
        designation: _designation.text,
        roleId: _roleId,
        managerId: _managerId,
        managerName: _managerId == null ? _managerName : null,
        location: _location,
        intro: _intro.text,
        certificates: List<CertificateFile>.of(_certificates),
        acquired: [for (final e in _levels.entries) AcquiredLevel(e.key, e.value)],
        additional: List<String>.of(_additional),
      );

  // ------------------------------------------------------------- save

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final errors = _errors;
    setState(() => _submitted = true);
    if (errors.isNotEmpty) {
      showAdminMessage(context, 'Please fix the ${errors.length} highlighted '
          '${errors.length == 1 ? 'field' : 'fields'}.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = _isEdit ? await _saveEdit() : await _employees.onboard(by: widget.user, draft: _draft());
      if (!mounted) return;
      if (!_isEdit) _clear();
      widget.onSaved(saved);
    } on AdminException catch (e) {
      if (mounted) showAdminMessage(context, e.message);
    } on CompetencyException catch (e) {
      if (mounted) showAdminMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<EmployeeProfile> _saveEdit() async {
    final employee = widget.employee!;
    final user = widget.user;
    final saved = await _employees.update(
      by: user,
      employeeId: employee.id,
      draft: _draft(),
      reason: _reason,
      effectiveDate: _effective,
      note: _changeNote.text,
    );

    // Skill levels: HRD saves directly, a Team Lead asks HR.
    if (user.role.canManageOrganization) {
      final changes = <String, int?>{
        for (final entry in _levels.entries)
          if (_originalLevels[entry.key] != entry.value) entry.key: entry.value,
        for (final id in _originalLevels.keys)
          if (!_levels.containsKey(id)) id: null,
      };
      CompetencyRepository.instance.setLevels(by: user, employeeId: employee.id, levels: changes);
    } else {
      final requests = ApprovalRepository.instance;
      for (final entry in _levelChanges.entries) {
        if (requests.pendingFor(employee.id, entry.key) != null) continue;
        await requests.raise(
          by: user,
          employeeId: employee.id,
          competencyId: entry.key,
          toLevel: entry.value,
          note: _levelNote.text,
          projectIds: _projectIds.toList(),
        );
      }
    }

    if (_projectIds.length != _originalProjectIds.length || !_projectIds.containsAll(_originalProjectIds)) {
      ProjectRepository.instance
          .setEmployeeProjects(by: user, employeeId: employee.id, projectIds: _projectIds);
    }
    return saved;
  }

  void _clear() {
    for (final c in [_id, _name, _email, _designation, _intro, _otherCityText, _changeNote, _levelNote]) {
      c.clear();
    }
    setState(() {
      _gender = null;
      _status = EmploymentStatus.active;
      _groupId = null;
      _departmentId = null;
      _managerId = null;
      _managerName = null;
      _roleId = null;
      _country = null;
      _state = null;
      _city = null;
      _certificates.clear();
      _levels.clear();
      _additional.clear();
      _submitted = false;
    });
  }

  Future<void> _pickFiles() async {
    final room = EmployeeRules.maxCertificates - _certificates.length;
    if (room <= 0) {
      showAdminMessage(context, 'Up to ${EmployeeRules.maxCertificates} files can be attached.');
      return;
    }
    setState(() => _pickingFiles = true);
    try {
      // No type groups = any file type (PDF, image, Word…).
      final files = await openFiles();
      if (!mounted || files.isEmpty) return;
      final added = <CertificateFile>[];
      final skipped = <String>[];
      for (final file in files.take(room)) {
        final size = await file.length();
        if (size > EmployeeRules.maxCertificateBytes) {
          skipped.add(file.name);
          continue;
        }
        final bytes = await file.readAsBytes();
        added.add(CertificateFile(
          id: 'CRT-${DateTime.now().microsecondsSinceEpoch}-${added.length}',
          name: file.name,
          sizeBytes: size,
          addedAt: DateTime.now(),
          bytes: bytes,
          mimeType: file.mimeType,
        ));
      }
      if (!mounted) return;
      setState(() => _certificates.addAll(added));
      if (skipped.isNotEmpty) {
        showAdminMessage(context, '${skipped.join(', ')}: larger than '
            '${fileSizeLabel(EmployeeRules.maxCertificateBytes)}, not attached.');
      } else if (files.length > room) {
        showAdminMessage(context, 'Only $room more files could be attached '
            '(limit ${EmployeeRules.maxCertificates}).');
      }
    } catch (e) {
      if (mounted) showAdminMessage(context, 'Could not open the files: $e');
    } finally {
      if (mounted) setState(() => _pickingFiles = false);
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final errors = _errors;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _structure.groups,
        _structure.departments,
        RoleRepository.instance.roles,
        _employees.employees,
        CompetencyRepository.instance.competencies,
      ]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _details(errors),
          const SizedBox(height: 18),
          _organisation(errors),
          const SizedBox(height: 18),
          _locationPanel(errors),
          const SizedBox(height: 18),
          _skills(errors),
          if (_isEdit) ...[
            const SizedBox(height: 18),
            _projects(),
          ],
          const SizedBox(height: 18),
          _proofAndIntro(errors),
          if (_isEdit && _placementChanged) ...[
            const SizedBox(height: 18),
            TurnIn(child: _reasonPanel()),
          ],
          const SizedBox(height: 22),
          if (_submitted && errors.isNotEmpty) ...[
            InfoNote(
              tone: NoteTone.error,
              text: 'Please fix ${errors.length} ${errors.length == 1 ? 'field' : 'fields'}: '
                  '${errors.values.take(3).join(' ')}${errors.length > 3 ? ' …' : ''}',
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PillButton(
                label: _saving
                    ? (_isEdit ? 'Saving…' : 'Onboarding…')
                    : (_isEdit ? 'Save changes' : 'Onboard employee'),
                onPressed: _saving ? null : _submit,
              ),
              PillButton(
                label: _isEdit ? 'Cancel' : 'Clear form',
                variant: PillVariant.outline,
                onPressed: _saving ? null : (_isEdit ? widget.onCancel : _clear),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _details(Map<String, String> errors) {
    final locked = _isEdit;
    return StepPanel(
      number: 1,
      title: 'Employee details',
      subtitle: _isEdit ? 'The employee ID can\'t be changed.' : 'Who is joining.',
      child: FieldGrid(
        children: [
          LabeledField(
            label: 'Employee ID',
            required: true,
            locked: locked,
            lockedReason: 'The employee ID is fixed once onboarded',
            child: TextField(
              controller: _id,
              enabled: !locked,
              style: adminInputStyle,
              maxLength: EmployeeRules.idMax,
              onChanged: (_) => setState(() {}),
              decoration: adminDecoration(
                hint: 'e.g. ${_employees.suggestNextId()}',
                errorText: _liveError('id', errors),
                enabled: !locked,
                suffixIcon: locked
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: TextButton(
                          onPressed: () => setState(() => _id.text = _employees.suggestNextId()),
                          style: TextButton.styleFrom(
                            foregroundColor: HomeColors.blue,
                            textStyle: HomeText.body(12.5, weight: FontWeight.w700),
                          ),
                          child: const Text('Next free ID'),
                        ),
                      ),
              ),
            ),
          ),
          LabeledField(
            label: 'Full name',
            required: true,
            child: TextField(
              controller: _name,
              style: adminInputStyle,
              maxLength: EmployeeRules.nameMax,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _touch(),
              decoration: adminDecoration(hint: 'e.g. Kiran Kumar', errorText: _error('name', errors)),
            ),
          ),
          LabeledField(
            label: 'Work email',
            required: true,
            child: TextField(
              controller: _email,
              style: adminInputStyle,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              decoration: adminDecoration(hint: 'name@company.com', errorText: _liveError('email', errors)),
            ),
          ),
          LabeledField(
            label: 'Gender',
            required: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChoicePills<Gender>(
                  options: Gender.values,
                  selected: _gender,
                  labelOf: (g) => g.label,
                  onSelected: (g) => setState(() => _gender = g),
                ),
                if (_error('gender', errors) case final message?) FieldError(message),
              ],
            ),
          ),
          LabeledField(
            label: 'Status',
            required: true,
            locked: !_canPlace,
            lockedReason: 'Only the HRD team can change the status',
            child: ChoicePills<EmploymentStatus>(
              options: EmploymentStatus.values,
              selected: _status,
              labelOf: (s) => s.label,
              onSelected: _canPlace ? (s) => setState(() => _status = s) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _organisation(Map<String, String> errors) {
    final groups = [..._structure.groups.value]..sort((a, b) => a.name.compareTo(b.name));
    final departments = _groupId == null ? const <OrgDepartment>[] : _structure.departmentsIn(_groupId!);
    final roles = RoleRepository.instance.active;
    // Keep a now-inactive role visible when editing.
    final currentRole = RoleRepository.instance.byId(_roleId);
    final roleIds = [
      for (final r in roles) r.id,
      if (currentRole != null && !currentRole.active) currentRole.id,
    ];
    final selfId = widget.employee?.id;
    final managers = _employees.active.where((e) => e.id != selfId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final manager = _employees.byId(_managerId);
    final lockReason = 'Only the HRD team can move people between groups and departments';

    return StepPanel(
      number: 2,
      title: 'Organisation',
      subtitle: 'Where they sit and who they report to.',
      child: FieldGrid(
        children: [
          LabeledField(
            label: 'Group',
            required: true,
            locked: !_canPlace,
            lockedReason: lockReason,
            child: AdminDropdown<String>(
              value: _groupId,
              items: [for (final g in groups) g.id],
              labelOf: (id) => _structure.groupById(id)?.name ?? id,
              hint: 'Choose a group',
              errorText: _error('group', errors),
              onChanged: _canPlace
                  ? (id) => setState(() {
                        _groupId = id;
                        if (_structure.departmentById(_departmentId)?.groupId != id) _departmentId = null;
                      })
                  : null,
            ),
          ),
          LabeledField(
            label: 'Department',
            required: true,
            locked: !_canPlace,
            lockedReason: lockReason,
            child: AdminDropdown<String>(
              value: _departmentId,
              items: [for (final d in departments) d.id],
              labelOf: (id) => _structure.departmentById(id)?.name ?? id,
              hint: 'Choose a department',
              disabledText: _groupId == null ? 'Choose a group first' : null,
              errorText: _error('department', errors),
              onChanged: _canPlace && _groupId != null ? (id) => setState(() => _departmentId = id) : null,
            ),
          ),
          LabeledField(
            label: 'Reporting manager',
            optional: true,
            child: EmployeePickerField(
              options: managers,
              selected: manager,
              emptyLabel: _managerId == null ? _managerName : null,
              onChanged: (id) => setState(() {
                _managerId = id;
                if (id != null) _managerName = null;
              }),
            ),
          ),
          LabeledField(
            label: 'Designation',
            required: true,
            child: _SuggestField(
              controller: _designation,
              suggestions: _employees.designations,
              hint: 'e.g. Senior Software Engineer',
              errorText: _error('designation', errors),
              onChanged: _touch,
            ),
          ),
          LabeledField(
            label: 'Role',
            required: true,
            child: AdminDropdown<String>(
              value: _roleId,
              items: roleIds,
              labelOf: (id) => RoleRepository.instance.nameOf(id),
              hint: 'Choose the project role',
              errorText: _error('role', errors),
              onChanged: (id) => setState(() => _roleId = id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationPanel(Map<String, String> errors) {
    final country = _country;
    final state = _state;
    final states = country == null ? const <String>[] : LocationCatalog.statesOf(country);
    final cities = country == null || state == null ? const <String>[] : LocationCatalog.citiesOf(country, state);
    return StepPanel(
      number: 3,
      title: 'Employee location',
      subtitle: 'Country, then one of its major states and cities.',
      child: FieldGrid(
        maxColumns: 3,
        minFieldWidth: 200,
        children: [
          LabeledField(
            label: 'Country',
            required: true,
            child: AdminDropdown<String>(
              value: _country,
              items: LocationCatalog.countries,
              labelOf: (c) => c,
              hint: 'Choose a country',
              errorText: _error('country', errors),
              onChanged: (c) => setState(() {
                if (c != _country) {
                  _state = null;
                  _city = null;
                }
                _country = c;
              }),
            ),
          ),
          LabeledField(
            label: 'State / province',
            optional: true,
            child: AdminDropdown<String>(
              value: _state,
              items: states,
              labelOf: (s) => s,
              hint: 'Choose a state',
              disabledText: 'Choose a country first',
              onChanged: country == null
                  ? null
                  : (s) => setState(() {
                        if (s != _state) _city = null;
                        _state = s;
                      }),
            ),
          ),
          LabeledField(
            label: 'City',
            optional: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminDropdown<String>(
                  value: _city,
                  items: [...cities, if (state != null) _otherCity],
                  labelOf: (c) => c == _otherCity ? 'Other city…' : c,
                  hint: 'Choose a city',
                  disabledText: 'Choose a state first',
                  onChanged: state == null ? null : (c) => setState(() => _city = c),
                ),
                if (_city == _otherCity) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _otherCityText,
                    style: adminInputStyle,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => _touch(),
                    decoration: adminDecoration(hint: 'Type the city', errorText: _error('city', errors)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skills(Map<String, String> errors) {
    final competencies = CompetencyRepository.instance;
    final pending = {
      if (widget.employee != null)
        for (final r in ApprovalRepository.instance.forEmployee(widget.employee!.id))
          if (r.isPending) r.competencyId: r,
    };
    final changes = _levelChanges;
    return StepPanel(
      number: 4,
      title: 'Competencies',
      subtitle: _levelsNeedApproval
          ? 'You can add skills and raise levels. Your changes go to HR for approval; '
              'levels can\'t be lowered here.'
          : 'Acquired skills from the competency library with their level (0–5)'
              '${_isEdit ? '.' : ', and optional additional skills.'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Acquired skills'),
          _CompetencySearch(
            exclude: _levels.keys.toSet(),
            onPicked: (c) => setState(() => _levels[c.id] = _levelsNeedApproval ? 1 : 2),
          ),
          const SizedBox(height: 12),
          if (_levels.isEmpty)
            Text('No skills added yet. Search the library above.',
                style: HomeText.body(13.5, color: HomeColors.muted))
          else
            for (final entry in _levels.entries)
              if (competencies.byId(entry.key) case final Competency competency)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AcquiredRow(
                    key: ValueKey<String>('acq-${entry.key}'),
                    competency: competency,
                    level: entry.value,
                    original: _originalLevels[entry.key],
                    pending: pending[entry.key],
                    needsApproval: _levelsNeedApproval,
                    onLevel: (l) => setState(() => _levels[entry.key] = l),
                    onRemove: _levelsNeedApproval && _originalLevels.containsKey(entry.key)
                        ? null
                        : () => setState(() => _levels.remove(entry.key)),
                  ),
                ),
          if (_levelsNeedApproval && changes.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoNote(
              tone: NoteTone.warning,
              icon: Icons.outbox_outlined,
              text: '${changes.length} level ${changes.length == 1 ? 'change' : 'changes'} will be '
                  'sent to HR for approval when you save. The profile keeps the current '
                  'levels until HR approves.',
            ),
            const SizedBox(height: 10),
            LabeledField(
              label: 'Note for HR',
              required: true,
              child: TextField(
                controller: _levelNote,
                minLines: 2,
                maxLines: 4,
                maxLength: ApprovalRules.noteMax,
                style: adminInputStyle,
                onChanged: (_) => _touch(),
                decoration: adminDecoration(
                  hint: 'What shows they reached these levels (projects, courses, reviews)?',
                  errorText: _error('levelNote', errors),
                  counter: true,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (!_isEdit)
            _AdditionalInput(
              names: _additional,
              onChanged: (names) => setState(() {
                _additional
                  ..clear()
                  ..addAll(names);
              }),
            )
          else
            _AdditionalReadOnly(employeeId: widget.employee!.id),
        ],
      ),
    );
  }

  Widget _projects() {
    final projects = ProjectRepository.instance.projects.value
        .where((p) => p.status != ProjectStatus.completed)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return StepPanel(
      number: 5,
      title: 'Projects',
      subtitle: 'Projects this employee works on. Their required competencies feed the gap table.',
      child: projects.isEmpty
          ? Text('No open projects yet.', style: HomeText.body(13.5, color: HomeColors.muted))
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in projects)
                  OrgFilterPill(
                    label: '${_projectIds.contains(p.id) ? '✓ ' : ''}${p.name} · ${p.code}',
                    selected: _projectIds.contains(p.id),
                    onTap: () => setState(() {
                      final next = {..._projectIds};
                      if (!next.remove(p.id)) next.add(p.id);
                      _projectIds = next;
                    }),
                  ),
              ],
            ),
    );
  }

  Widget _proofAndIntro(Map<String, String> errors) {
    return StepPanel(
      number: _isEdit ? 6 : 5,
      title: 'Certificate proofs & intro',
      subtitle: 'Attach any file type (up to ${EmployeeRules.maxCertificates} files, '
          '${fileSizeLabel(EmployeeRules.maxCertificateBytes)} each) and a short introduction.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Certificate proofs', optional: true),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PillButton(
                label: _pickingFiles ? 'Opening…' : 'Attach files',
                variant: PillVariant.outline,
                height: 44,
                fontSize: 14,
                horizontalPadding: 20,
                onPressed: _pickingFiles ? null : _pickFiles,
              ),
              Text('${_certificates.length} of ${EmployeeRules.maxCertificates} attached',
                  style: HomeText.body(12.5, color: HomeColors.muted)),
            ],
          ),
          if (_certificates.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final file in _certificates)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TurnIn(
                  key: ValueKey<String>(file.id),
                  child: CertificateTile(
                    file: file,
                    onRemove: () => setState(() => _certificates.remove(file)),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 18),
          LabeledField(
            label: 'Short intro',
            optional: true,
            child: TextField(
              controller: _intro,
              minLines: 3,
              maxLines: 6,
              maxLength: EmployeeRules.introMax,
              style: adminInputStyle,
              onChanged: (_) => _touch(),
              decoration: adminDecoration(
                hint: 'Background, strengths, what they will work on…',
                errorText: _error('intro', errors),
                counter: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonPanel() {
    return StepPanel(
      icon: Icons.history_rounded,
      title: 'Why is this changing?',
      subtitle: 'Changes to group, department, manager, designation, role or status are '
          'logged in Profile Changes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoicePills<ChangeReason>(
            options: ChangeReason.selectable,
            selected: _reason,
            labelOf: (r) => r.label,
            onSelected: (r) => setState(() => _reason = r),
          ),
          const SizedBox(height: 16),
          FieldGrid(
            children: [
              LabeledField(
                label: 'Effective from',
                required: true,
                child: DateField(
                  value: _effective,
                  onChanged: (d) => setState(() => _effective = d ?? _effective),
                ),
              ),
              LabeledField(
                label: 'Note',
                optional: true,
                child: TextField(
                  controller: _changeNote,
                  style: adminInputStyle,
                  maxLength: 160,
                  decoration: adminDecoration(hint: 'e.g. Q1 2027 re-org'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- pieces

/// A text field that suggests values as you type (e.g. designations).
class _SuggestField extends StatefulWidget {
  const _SuggestField({
    required this.controller,
    required this.suggestions,
    required this.hint,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String hint;
  final String? errorText;
  final VoidCallback onChanged;

  @override
  State<_SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<_SuggestField> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return widget.suggestions.where((s) => s.toLowerCase().contains(q) && s.toLowerCase() != q).take(8);
      },
      onSelected: (_) => widget.onChanged(),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        style: adminInputStyle,
        textCapitalization: TextCapitalization.words,
        maxLength: EmployeeRules.designationMax,
        onChanged: (_) => widget.onChanged(),
        decoration: adminDecoration(hint: widget.hint, errorText: widget.errorText),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.white,
          elevation: 8,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260, maxWidth: 380),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              children: [
                for (final o in options)
                  InkWell(
                    onTap: () => onSelected(o),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      child: Text(o, style: adminInputStyle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Search box over the competency library.
class _CompetencySearch extends StatefulWidget {
  const _CompetencySearch({required this.exclude, required this.onPicked});

  final Set<String> exclude;
  final ValueChanged<Competency> onPicked;

  @override
  State<_CompetencySearch> createState() => _CompetencySearchState();
}

class _CompetencySearchState extends State<_CompetencySearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Competency>(
      textEditingController: _controller,
      focusNode: _focus,
      displayStringForOption: (c) => c.name,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        final list = CompetencyRepository.instance.competencies.value
            .where((c) => !widget.exclude.contains(c.id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        if (q.isEmpty) return list.take(10);
        return list.where((c) => c.searchText.contains(q)).take(12);
      },
      onSelected: (c) {
        widget.onPicked(c);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _controller.clear();
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        style: adminInputStyle,
        onSubmitted: (_) => onSubmitted(),
        decoration: adminDecoration(
          hint: 'Search the competency library (Java, AUTOSAR, Jira…)',
          prefixIcon: const Icon(Icons.add_circle_outline_rounded, color: HomeColors.muted),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: Colors.white,
            elevation: 10,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: [
                  for (final c in options)
                    InkWell(
                      onTap: () => onSelected(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            CompetencyBadge.of(c, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink)),
                            ),
                            CategoryPill(c.category, dense: true),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AcquiredRow extends StatelessWidget {
  const _AcquiredRow({
    super.key,
    required this.competency,
    required this.level,
    required this.original,
    required this.pending,
    required this.needsApproval,
    required this.onLevel,
    required this.onRemove,
  });

  final Competency competency;
  final int level;
  final int? original;
  final LevelUpRequest? pending;
  final bool needsApproval;
  final ValueChanged<int> onLevel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final waiting = pending;
    final changed = (original ?? -1) < level && needsApproval;
    final remove = onRemove;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        final picker = waiting != null && needsApproval
            ? StatusPill(
                label: 'Waiting for HR: L${waiting.fromLevel ?? '–'} → L${waiting.toLevel}',
                icon: Icons.hourglass_top_rounded,
                background: HomeColors.orangeTint,
                foreground: HomeColors.orangeText,
              )
            : LevelPicker(
                level: level,
                compact: narrow,
                minLevel: needsApproval ? (original ?? 0) : 0,
                onChanged: onLevel,
              );
        final title = Row(
          children: [
            CompetencyBadge.of(competency, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(competency.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.body(14.5, weight: FontWeight.w700, color: HomeColors.ink)),
                  Text(
                    changed
                        ? (original == null ? 'New · will be sent to HR' : 'L$original → L$level · will be sent to HR')
                        : '${competency.category.label} · ${CompetencyLevel.short(level)}',
                    style: HomeText.body(12.5,
                        weight: changed ? FontWeight.w700 : FontWeight.w400,
                        color: changed ? HomeColors.orangeText : HomeColors.muted),
                  ),
                ],
              ),
            ),
            if (remove != null)
              IconButton(
                tooltip: 'Remove ${competency.name}',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: remove,
              ),
          ],
        );
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: changed ? HomeColors.orangeBand : HomeColors.cardBorder),
          ),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 8), picker],
                )
              : Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 10),
                    picker,
                  ],
                ),
        );
      },
    );
  }
}

/// Optional self-declared skills for a new employee.
class _AdditionalInput extends StatefulWidget {
  const _AdditionalInput({required this.names, required this.onChanged});

  final List<String> names;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_AdditionalInput> createState() => _AdditionalInputState();
}

class _AdditionalInputState extends State<_AdditionalInput> {
  final TextEditingController _text = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String? _check(String name) {
    final clean = cleanText(name);
    if (clean.isEmpty) return null;
    if (clean.length > AdditionalCompetencyRules.nameMax) {
      return 'Keep it under ${AdditionalCompetencyRules.nameMax} characters.';
    }
    if (widget.names.any((n) => AdditionalCompetency.keyFor(n) == AdditionalCompetency.keyFor(clean))) {
      return '"$clean" is already added.';
    }
    final core = CompetencyRepository.instance.findByName(clean);
    if (core != null) return '"${core.name}" is in the competency library: add it above with a level.';
    if (widget.names.length >= AdditionalCompetencyRules.maxPerEmployee) {
      return 'Up to ${AdditionalCompetencyRules.maxPerEmployee} additional skills.';
    }
    return null;
  }

  void _add(String name) {
    final clean = cleanText(name);
    final problem = _check(clean);
    if (clean.isEmpty) return;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    _text.clear();
    setState(() => _problem = null);
    widget.onChanged([...widget.names, clean]);
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = AdditionalCompetencyRepository.instance
        .suggestionsFor(_text.text, employeeId: '')
        .where((s) => !widget.names.any((n) => AdditionalCompetency.keyFor(n) == AdditionalCompetency.keyFor(s)))
        .take(8)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Additional skills', optional: true),
        Text('Things they are good at outside the library, e.g. Poster Design or Public Speaking. '
            'No levels; the employee can change these later on their Home page.',
            style: HomeText.body(12.5, color: HomeColors.muted, height: 1.45)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                style: adminInputStyle,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() => _problem = null),
                onSubmitted: _add,
                decoration: adminDecoration(hint: 'Type a skill and press Enter', errorText: _problem),
              ),
            ),
            const SizedBox(width: 8),
            PillButton(
              label: 'Add',
              height: 48,
              fontSize: 14,
              horizontalPadding: 20,
              onPressed: () => _add(_text.text),
            ),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text('+ $s'),
                  labelStyle: HomeText.body(12.5, weight: FontWeight.w600, color: HomeColors.ink),
                  backgroundColor: const Color(0xFFFFF4F6),
                  side: const BorderSide(color: Color(0xFFF3C6D0)),
                  shape: const StadiumBorder(),
                  onPressed: () => _add(s),
                ),
            ],
          ),
        ],
        if (widget.names.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in widget.names)
                DashedOutline(
                  color: const Color(0xFFD9496B),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(n,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HomeText.body(13, weight: FontWeight.w700, color: const Color(0xFF8C1D3A))),
                        ),
                        IconButton(
                          tooltip: 'Remove $n',
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF8C1D3A)),
                          onPressed: () => widget.onChanged(widget.names.where((x) => x != n).toList()),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AdditionalReadOnly extends StatelessWidget {
  const _AdditionalReadOnly({required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final entries = AdditionalCompetencyRepository.instance.forEmployee(employeeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Additional skills'),
        Text(
          entries.isEmpty
              ? 'None listed. Employees add these themselves on their Home page.'
              : 'Self-declared by the employee on their Home page (not editable here).',
          style: HomeText.body(12.5, color: HomeColors.muted),
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in entries)
                DashedOutline(
                  color: const Color(0xFFD9496B),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(e.name,
                        style: HomeText.body(13, weight: FontWeight.w700, color: const Color(0xFF8C1D3A))),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A certificate file: type icon, name, size and remove/download.
class CertificateTile extends StatelessWidget {
  const CertificateTile({super.key, required this.file, this.onRemove, this.onDownload});

  final CertificateFile file;
  final VoidCallback? onRemove;
  final VoidCallback? onDownload;

  static IconData iconFor(String extension) => switch (extension) {
        'pdf' => Icons.picture_as_pdf_outlined,
        'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'heic' => Icons.image_outlined,
        'doc' || 'docx' || 'odt' || 'rtf' || 'txt' => Icons.description_outlined,
        'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
        'zip' || 'rar' || '7z' => Icons.folder_zip_outlined,
        _ => Icons.insert_drive_file_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final remove = onRemove;
    final download = onDownload;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: HomeColors.blueTint,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Icon(iconFor(file.extension), color: HomeColors.blueDeep, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink)),
                Text(
                  '${file.extension.isEmpty ? 'File' : file.extension.toUpperCase()} · ${file.sizeLabel} · '
                  'added ${dayMonthYear(file.addedAt)}',
                  style: HomeText.body(12.5, color: HomeColors.muted),
                ),
              ],
            ),
          ),
          if (download != null)
            IconButton(
              tooltip: file.canDownload ? 'Download ${file.name}' : 'Stored on the server (download later)',
              icon: const Icon(Icons.download_rounded, size: 20),
              onPressed: file.canDownload ? download : null,
            ),
          if (remove != null)
            IconButton(
              tooltip: 'Remove ${file.name}',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: remove,
            ),
        ],
      ),
    );
  }
}
