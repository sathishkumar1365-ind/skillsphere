import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../competency/data/competency_models.dart';
import '../../../competency/data/competency_repository.dart';
import '../../../competency/presentation/widgets/competency_common.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../data/admin_base.dart';
import '../../data/approvals.dart';
import '../../data/employees.dart';
import '../../data/insights.dart';
import '../widgets/admin_common.dart';

/// A Team Lead asks HR to raise [employee]'s level. With [row] the
/// competency (and the level its projects need) is filled in; without it
/// the TL chooses any competency from the library.
///
/// Returns the request when it was sent.
Future<LevelUpRequest?> showRequestLevelUp({
  required BuildContext context,
  required AppUser user,
  required EmployeeProfile employee,
  CompetencyRow? row,
}) {
  return showFlipDialog<LevelUpRequest>(
    context: context,
    barrierLabel: 'Close level-up request',
    builder: (context) => _RequestForm(user: user, employee: employee, row: row),
  );
}

class _RequestForm extends StatefulWidget {
  const _RequestForm({required this.user, required this.employee, required this.row});

  final AppUser user;
  final EmployeeProfile employee;
  final CompetencyRow? row;

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _note = TextEditingController();
  final _evidence = TextEditingController();
  String? _competencyId;
  int? _target;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    if (row != null) _select(row.competency.id, required: row.requiredLevel);
  }

  @override
  void dispose() {
    _note.dispose();
    _evidence.dispose();
    super.dispose();
  }

  int? get _current {
    final id = _competencyId;
    if (id == null) return null;
    return CompetencyRepository.instance.holderOf(id, widget.employee.id)?.level;
  }

  /// Highest level the employee's projects need in this competency.
  int? _requiredFor(String competencyId) {
    for (final r in Insights.of(widget.employee).rows) {
      if (r.competency.id == competencyId) return r.requiredLevel;
    }
    return null;
  }

  void _select(String id, {int? required}) {
    _competencyId = id;
    final need = required ?? _requiredFor(id);
    final current = CompetencyRepository.instance.holderOf(id, widget.employee.id)?.level;
    final next = (current ?? -1) + 1;
    _target = need != null && need > (current ?? -1) ? need : (next <= CompetencyLevel.max ? next : null);
  }

  Future<void> _send() async {
    final id = _competencyId;
    final target = _target;
    if (id == null || target == null) {
      setState(() => _error = 'Choose the competency and the new level.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final insight = Insights.of(widget.employee);
      final row = insight.rows.where((r) => r.competency.id == id).firstOrNull;
      final request = await ApprovalRepository.instance.raise(
        by: widget.user,
        employeeId: widget.employee.id,
        competencyId: id,
        toLevel: target,
        note: _note.text,
        evidence: _evidence.text,
        requiredLevel: row?.requiredLevel,
        projectIds: [for (final s in row?.sources ?? const <RequirementSource>[]) s.project.id],
      );
      if (mounted) Navigator.of(context).pop(request);
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final competencies = [...CompetencyRepository.instance.competencies.value]
      ..sort((a, b) => a.name.compareTo(b.name));
    final id = _competencyId;
    final competency = id == null ? null : CompetencyRepository.instance.byId(id);
    final current = _current;
    final required = id == null ? null : _requiredFor(id);
    final certificates = widget.employee.certificates;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('REQUEST A LEVEL-UP', style: HomeText.display(28, height: 1.05)),
            const SizedBox(height: 8),
            Text('HR approves or rejects. The level changes only after approval.',
                style: HomeText.body(14, height: 1.5)),
            const SizedBox(height: 16),
            PersonLine(profile: widget.employee),
            const SizedBox(height: 18),
            LabeledField(
              label: 'Competency',
              required: true,
              locked: widget.row != null,
              lockedReason: 'From the row you selected',
              child: widget.row != null && competency != null
                  ? Row(
                      children: [
                        CompetencyBadge.of(competency, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(competency.name,
                              style: HomeText.body(15, weight: FontWeight.w700, color: HomeColors.ink)),
                        ),
                        CategoryPill(competency.category, dense: true),
                      ],
                    )
                  : AdminDropdown<String>(
                      value: id,
                      items: [for (final c in competencies) c.id],
                      labelOf: (cid) => CompetencyRepository.instance.byId(cid)?.name ?? cid,
                      hint: 'Choose a competency',
                      onChanged: (cid) => setState(() => _select(cid)),
                    ),
            ),
            if (competency != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Fact(
                    label: 'Now',
                    value: current == null ? 'Not held' : CompetencyLevel.short(current),
                  ),
                  _Fact(
                    label: 'Projects need',
                    value: required == null ? 'Not required' : CompetencyLevel.short(required),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'New level',
                required: true,
                child: current != null && current >= CompetencyLevel.max
                    ? const InfoNote(text: 'Already at the highest level (L5 · Expert).')
                    : LevelPicker(
                        level: _target,
                        minLevel: (current ?? -1) + 1,
                        onChanged: (l) => setState(() => _target = l),
                      ),
              ),
              if (_target != null) ...[
                const SizedBox(height: 8),
                Text(competency.levelDescription(_target!),
                    style: HomeText.body(13, color: HomeColors.muted, height: 1.45)),
              ],
            ],
            const SizedBox(height: 16),
            LabeledField(
              label: 'Why (for HR)',
              required: true,
              child: TextField(
                controller: _note,
                minLines: 3,
                maxLines: 5,
                maxLength: ApprovalRules.noteMax,
                style: adminInputStyle,
                decoration: adminDecoration(
                  hint: 'What shows the new level: work done, course, review…',
                  counter: true,
                ),
              ),
            ),
            const SizedBox(height: 6),
            LabeledField(
              label: 'Proof',
              optional: true,
              child: TextField(
                controller: _evidence,
                maxLength: ApprovalRules.evidenceMax,
                style: adminInputStyle,
                decoration: adminDecoration(hint: 'Link to a certificate or work sample, or a file name'),
              ),
            ),
            if (certificates.isNotEmpty) ...[
              Text('Or pick a certificate on the profile:', style: HomeText.body(12.5, color: HomeColors.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in certificates)
                    ActionChip(
                      avatar: const Icon(Icons.attach_file_rounded, size: 16),
                      label: Text(c.name, overflow: TextOverflow.ellipsis),
                      labelStyle: HomeText.body(12.5, weight: FontWeight.w600, color: HomeColors.ink),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: HomeColors.chipBorder),
                      shape: const StadiumBorder(),
                      onPressed: () => setState(() => _evidence.text = c.name),
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              InfoNote(tone: NoteTone.error, text: _error!),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: HomeColors.ink,
                    textStyle: HomeText.body(14, weight: FontWeight.w700),
                  ),
                  child: const Text('Cancel'),
                ),
                PillButton(
                  label: _saving ? 'Sending…' : 'Send to HR',
                  height: 48,
                  fontSize: 14,
                  onPressed: _saving ? null : _send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F8FC),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Text.rich(
        TextSpan(
          text: '$label  ',
          style: HomeText.body(12, weight: FontWeight.w800, color: HomeColors.muted),
          children: [
            TextSpan(text: value, style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.ink)),
          ],
        ),
      ),
    );
  }
}
