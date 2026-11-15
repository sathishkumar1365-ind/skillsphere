import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/crowd.dart';
import '../../data/org_structure.dart';
import '../widgets/admin_common.dart';

/// Connection settings for Atlassian Crowd (shared by Onboarding and
/// Groups & Departments).
class CrowdConnectionPanel extends StatefulWidget {
  const CrowdConnectionPanel({super.key, required this.user});

  final AppUser user;

  @override
  State<CrowdConnectionPanel> createState() => _CrowdConnectionPanelState();
}

class _CrowdConnectionPanelState extends State<CrowdConnectionPanel> {
  final _url = TextEditingController();
  final _app = TextEditingController();
  final _password = TextEditingController();
  final _group = TextEditingController(text: 'mobis-employees');
  final _attribute = TextEditingController(text: 'employeeNumber');
  final _groupPrefix = TextEditingController(text: 'grp-');
  final _departmentPrefix = TextEditingController(text: 'dept-');
  CrowdSchedule _schedule = CrowdSchedule.manual;
  bool _deactivate = true;
  bool _busy = false;
  bool _editing = true;
  String? _error;

  CrowdService get _crowd => CrowdService.instance;

  @override
  void initState() {
    super.initState();
    final saved = _crowd.settings.value;
    if (saved != null) {
      _fill(saved);
      _editing = false;
    }
  }

  void _fill(CrowdSettings s) {
    _url.text = s.serverUrl;
    _app.text = s.applicationName;
    _group.text = s.userGroup;
    _attribute.text = s.employeeIdAttribute;
    _groupPrefix.text = s.groupPrefix;
    _departmentPrefix.text = s.departmentPrefix;
    _schedule = s.schedule;
    _deactivate = s.deactivateDisabled;
  }

  @override
  void dispose() {
    for (final c in [_url, _app, _password, _group, _attribute, _groupPrefix, _departmentPrefix]) {
      c.dispose();
    }
    super.dispose();
  }

  CrowdSettings get _draft => CrowdSettings(
        serverUrl: _url.text,
        applicationName: _app.text,
        passwordSaved: _crowd.settings.value?.passwordSaved ?? false,
        userGroup: _group.text,
        employeeIdAttribute: _attribute.text,
        groupPrefix: _groupPrefix.text,
        departmentPrefix: _departmentPrefix.text,
        schedule: _schedule,
        deactivateDisabled: _deactivate,
      );

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _crowd.testConnection(by: widget.user, draft: _draft, password: _password.text);
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _crowd.save(by: widget.user, draft: _draft, password: _password.text);
      _password.clear();
      if (!mounted) return;
      setState(() => _editing = false);
      showAdminMessage(context, 'Crowd connection saved.');
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_crowd.settings, _crowd.lastTest]),
      builder: (context, _) {
        final saved = _crowd.settings.value;
        final tested = _crowd.lastTest.value;
        return StepPanel(
          icon: Icons.hub_outlined,
          title: 'Atlassian Crowd connection',
          subtitle: 'Synchronise employees and groups from your Crowd directory.',
          trailing: saved == null
              ? const StatusPill(
                  label: 'Not connected',
                  icon: Icons.link_off_rounded,
                  background: HomeColors.neutralTint,
                  foreground: HomeColors.body,
                )
              : const StatusPill(
                  label: 'Connected',
                  icon: Icons.link_rounded,
                  background: OrgColors.goodTint,
                  foreground: OrgColors.good,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InfoNote(
                icon: Icons.shield_outlined,
                text: 'The SkillSphere server talks to Crowd (REST API, application name and '
                    'password); the browser never does. The password is stored encrypted on the '
                    'server and is never shown again. Until the server is ready, this screen uses '
                    'a sample Crowd directory.',
              ),
              const SizedBox(height: 16),
              if (saved != null && !_editing) ...[
                FieldGrid(
                  children: [
                    DetailItem(label: 'Crowd server', value: saved.serverUrl, icon: Icons.dns_outlined),
                    DetailItem(label: 'Application', value: saved.applicationName, icon: Icons.apps_rounded),
                    DetailItem(label: 'Employees group', value: saved.userGroup, icon: Icons.groups_outlined),
                    DetailItem(label: 'Employee ID attribute', value: saved.employeeIdAttribute, icon: Icons.badge_outlined),
                    DetailItem(
                      label: 'Group / department prefixes',
                      value: '${saved.groupPrefix}…  /  ${saved.departmentPrefix}…',
                      icon: Icons.account_tree_outlined,
                    ),
                    DetailItem(label: 'Automatic sync', value: saved.schedule.label, icon: Icons.schedule_rounded),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    PillButton(
                      label: 'Edit connection',
                      variant: PillVariant.outline,
                      height: 44,
                      fontSize: 14,
                      onPressed: () => setState(() => _editing = true),
                    ),
                    PillButton(
                      label: _busy ? 'Testing…' : 'Test connection',
                      height: 44,
                      fontSize: 14,
                      onPressed: _busy ? null : _test,
                    ),
                  ],
                ),
              ] else ...[
                FieldGrid(
                  children: [
                    LabeledField(
                      label: 'Crowd server address',
                      required: true,
                      child: TextField(
                        controller: _url,
                        style: adminInputStyle,
                        keyboardType: TextInputType.url,
                        decoration: adminDecoration(hint: 'https://crowd.company.com/crowd'),
                      ),
                    ),
                    LabeledField(
                      label: 'Application name',
                      required: true,
                      child: TextField(
                        controller: _app,
                        style: adminInputStyle,
                        decoration: adminDecoration(hint: 'skillsphere'),
                      ),
                    ),
                    LabeledField(
                      label: 'Application password',
                      required: saved == null,
                      child: TextField(
                        controller: _password,
                        obscureText: true,
                        style: adminInputStyle,
                        decoration: adminDecoration(
                          hint: saved?.passwordSaved ?? false ? 'Saved – leave empty to keep' : 'From Crowd › Applications',
                        ),
                      ),
                    ),
                    LabeledField(
                      label: 'Employees group in Crowd',
                      required: true,
                      child: TextField(
                        controller: _group,
                        style: adminInputStyle,
                        decoration: adminDecoration(hint: 'mobis-employees'),
                      ),
                    ),
                    LabeledField(
                      label: 'Employee ID attribute',
                      required: true,
                      child: TextField(
                        controller: _attribute,
                        style: adminInputStyle,
                        decoration: adminDecoration(hint: 'employeeNumber'),
                      ),
                    ),
                    LabeledField(
                      label: 'Prefixes: groups / departments',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _groupPrefix,
                              style: adminInputStyle,
                              decoration: adminDecoration(hint: 'grp-'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _departmentPrefix,
                              style: adminInputStyle,
                              decoration: adminDecoration(hint: 'dept-'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const FieldLabel('Automatic sync (runs on the server)'),
                ChoicePills<CrowdSchedule>(
                  options: CrowdSchedule.values,
                  selected: _schedule,
                  labelOf: (s) => s.label,
                  onSelected: (s) => setState(() => _schedule = s),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _deactivate,
                  onChanged: (v) => setState(() => _deactivate = v),
                  title: Text('Deactivate employees whose Crowd account is disabled',
                      style: HomeText.body(14, weight: FontWeight.w600, color: HomeColors.ink)),
                  subtitle: Text('They become Inactive in SkillSphere; their history stays.',
                      style: HomeText.body(12.5, color: HomeColors.muted)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    PillButton(
                      label: _busy ? 'Working…' : 'Save connection',
                      height: 46,
                      fontSize: 14,
                      onPressed: _busy ? null : _save,
                    ),
                    PillButton(
                      label: 'Test connection',
                      variant: PillVariant.outline,
                      height: 46,
                      fontSize: 14,
                      onPressed: _busy ? null : _test,
                    ),
                    if (saved != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _fill(saved);
                                  _password.clear();
                                  _editing = false;
                                  _error = null;
                                }),
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                InfoNote(tone: NoteTone.error, text: _error!),
              ] else if (tested != null) ...[
                const SizedBox(height: 14),
                InfoNote(tone: NoteTone.success, text: tested),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Synchronise employees from Crowd: preview, choose, apply.
class CrowdUsersPanel extends StatefulWidget {
  const CrowdUsersPanel({super.key, required this.user, required this.onOpenEmployee});

  final AppUser user;
  final ValueChanged<String> onOpenEmployee;

  @override
  State<CrowdUsersPanel> createState() => _CrowdUsersPanelState();
}

class _CrowdUsersPanelState extends State<CrowdUsersPanel> {
  List<CrowdUserChange>? _changes;
  final Set<String> _selected = {};
  final Map<String, String> _departmentFor = {};
  bool _busy = false;
  String? _error;

  CrowdService get _crowd => CrowdService.instance;

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final changes = await _crowd.previewUsers(by: widget.user);
      if (!mounted) return;
      setState(() {
        _changes = changes;
        _departmentFor.clear();
        _selected
          ..clear()
          ..addAll(changes
              .where((c) => c.kind != CrowdChangeKind.added || c.departmentId != null)
              .map((c) => c.key));
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
    final chosen = changes.where((c) => _selected.contains(c.key)).toList();
    final missing = chosen.where((c) =>
        c.kind == CrowdChangeKind.added && c.departmentId == null && !_departmentFor.containsKey(c.user.username));
    if (missing.isNotEmpty) {
      showAdminMessage(context, 'Choose a department for ${missing.first.user.displayName}.');
      return;
    }
    setState(() => _busy = true);
    try {
      final summary = await _crowd.applyUsers(by: widget.user, selected: chosen, departmentFor: _departmentFor);
      if (!mounted) return;
      setState(() => _changes = null);
      showAdminMessage(context, 'Crowd sync: $summary.');
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_crowd.settings, _crowd.history, OrgStructureRepository.instance.departments]),
      builder: (context, _) {
        final configured = _crowd.isConfigured;
        final changes = _changes;
        final history = _crowd.history.value.where((h) => h.usersSync).toList();
        return StepPanel(
          icon: Icons.sync_rounded,
          title: 'Synchronise employees',
          subtitle: 'New Crowd users are onboarded (HRD completes role and gender later), changed '
              'names/emails are updated and disabled accounts are deactivated.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!configured)
                const InfoNote(text: 'Save the Crowd connection above first.')
              else ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    PillButton(
                      label: _busy && changes == null ? 'Checking Crowd…' : 'Check Crowd for changes',
                      height: 46,
                      fontSize: 14,
                      onPressed: _busy ? null : _check,
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  InfoNote(tone: NoteTone.error, text: _error!),
                ],
                if (changes != null) ...[
                  const SizedBox(height: 16),
                  if (changes.isEmpty)
                    const InfoNote(tone: NoteTone.success, text: 'Everything is in sync with Crowd.')
                  else
                    TurnIn(
                      replayKey: changes,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final kind in CrowdChangeKind.values)
                            if (changes.any((c) => c.kind == kind)) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 6, bottom: 8),
                                child: Text(
                                  '${kind.label} · ${changes.where((c) => c.kind == kind).length}'.toUpperCase(),
                                  style: HomeText.body(12, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 1),
                                ),
                              ),
                              for (final c in changes.where((c) => c.kind == kind))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ChangeTile(
                                    change: c,
                                    selected: _selected.contains(c.key),
                                    departmentId: _departmentFor[c.user.username] ?? c.departmentId,
                                    onSelected: (v) => setState(() {
                                      if (v) {
                                        _selected.add(c.key);
                                      } else {
                                        _selected.remove(c.key);
                                      }
                                    }),
                                    onDepartment: (id) => setState(() {
                                      _departmentFor[c.user.username] = id;
                                      _selected.add(c.key);
                                    }),
                                  ),
                                ),
                            ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              PillButton(
                                label: _busy
                                    ? 'Applying…'
                                    : 'Apply ${_selected.length} ${_selected.length == 1 ? 'change' : 'changes'}',
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
                      ),
                    ),
                ],
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 20),
                const FieldLabel('Recent synchronisations'),
                for (final h in history.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 18, color: HomeColors.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${dayMonthYear(h.at)} · ${h.summary} · by ${h.by}',
                              style: HomeText.body(13, color: HomeColors.body)),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ChangeTile extends StatelessWidget {
  const _ChangeTile({
    required this.change,
    required this.selected,
    required this.departmentId,
    required this.onSelected,
    required this.onDepartment,
  });

  final CrowdUserChange change;
  final bool selected;
  final String? departmentId;
  final ValueChanged<bool> onSelected;
  final ValueChanged<String> onDepartment;

  @override
  Widget build(BuildContext context) {
    final u = change.user;
    final structure = OrgStructureRepository.instance;
    final departments = [...structure.departments.value]..sort((a, b) => a.name.compareTo(b.name));
    final (IconData icon, Color tint, Color fg) = switch (change.kind) {
      CrowdChangeKind.added => (Icons.person_add_alt_1_rounded, OrgColors.goodTint, OrgColors.good),
      CrowdChangeKind.updated => (Icons.edit_note_rounded, HomeColors.blueTint, HomeColors.blueDeep),
      CrowdChangeKind.disabled => (Icons.person_off_outlined, HomeColors.orangeTint, HomeColors.orangeText),
    };
    final details = switch (change.kind) {
      CrowdChangeKind.added => [
          '${u.employeeNumber} · ${u.email}',
          [if (u.title.isNotEmpty) u.title, if (u.city.isNotEmpty) '${u.city}, ${u.country}'].join(' · '),
        ],
      CrowdChangeKind.updated => change.differences,
      CrowdChangeKind.disabled => ['Disabled in Crowd → will become Inactive (${change.employee?.id ?? ''})'],
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: selected ? HomeColors.ink : HomeColors.cardBorder, width: selected ? 1.5 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            onChanged: (v) => onSelected(v ?? false),
            activeColor: HomeColors.ink,
          ),
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 6, right: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, borderRadius: const BorderRadius.all(Radius.circular(10))),
            child: Icon(icon, size: 18, color: fg),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.displayName, style: HomeText.body(14.5, weight: FontWeight.w700, color: HomeColors.ink)),
                  for (final d in details.where((d) => d.isNotEmpty))
                    Text(d, style: HomeText.body(12.5, color: HomeColors.muted, height: 1.45)),
                  if (change.kind == CrowdChangeKind.added) ...[
                    const SizedBox(height: 8),
                    if (change.departmentId != null)
                      Text(
                        'Department from Crowd group: ${structure.departmentName(change.departmentId)}',
                        style: HomeText.body(12.5, weight: FontWeight.w600, color: OrgColors.good),
                      )
                    else ...[
                      Text(
                        'No department matches the Crowd group "${u.groups.where((g) => g != 'mobis-employees').join(', ')}". '
                        'Choose one (or add it under Groups & Departments › Crowd sync):',
                        style: HomeText.body(12.5, weight: FontWeight.w600, color: HomeColors.orangeText, height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 320,
                        child: AdminDropdown<String>(
                          value: departmentId,
                          items: [for (final d in departments) d.id],
                          labelOf: (id) =>
                              '${structure.departmentName(id)} · ${structure.groupNameOfDepartment(id)}',
                          hint: 'Choose a department',
                          onChanged: onDepartment,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
