import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/app_user.dart';
import '../../../competency/data/competency_models.dart';
import '../../../competency/data/competency_repository.dart';
import '../../../competency/presentation/widgets/competency_common.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/approvals.dart';
import '../../data/employees.dart';
import '../../data/job_roles.dart';
import '../../data/org_structure.dart';
import '../../data/projects.dart';
import '../widgets/admin_common.dart';

enum _StatusFilter {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  all('All');

  const _StatusFilter(this.label);
  final String label;

  bool matches(LevelUpRequest r) => switch (this) {
        _StatusFilter.pending => r.status == ApprovalStatus.pending,
        _StatusFilter.approved => r.status == ApprovalStatus.approved,
        _StatusFilter.rejected => r.status == ApprovalStatus.rejected,
        _StatusFilter.all => true,
      };
}

/// Console › Approvals: level-ups raised by Team Leads to close skill gaps.
/// HR approves (the level changes and is marked verified) or rejects with
/// a reason; approved and rejected ones stay filterable.
class ApprovalsView extends StatefulWidget {
  const ApprovalsView({super.key, required this.user, required this.onOpenEmployee});

  final AppUser user;
  final ValueChanged<String> onOpenEmployee;

  @override
  State<ApprovalsView> createState() => _ApprovalsViewState();
}

class _ApprovalsViewState extends State<ApprovalsView> {
  static const _pageSize = 15;

  final TextEditingController _search = TextEditingController();
  String _query = '';
  _StatusFilter _status = _StatusFilter.pending;
  String? _departmentId;
  final Set<String> _selected = {};
  final Set<String> _busy = {};
  bool _bulkBusy = false;
  int _limit = _pageSize;

  ApprovalRepository get _approvals => ApprovalRepository.instance;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _competencyName(LevelUpRequest r) =>
      CompetencyRepository.instance.byId(r.competencyId)?.name ?? r.competencyId;

  Future<void> _approve(LevelUpRequest r) async {
    setState(() => _busy.add(r.id));
    try {
      await _approvals.approve(by: widget.user, items: [r]);
      if (!mounted) return;
      _selected.remove(r.id);
      showAdminMessage(
        context,
        'Approved: ${EmployeeRepository.instance.nameOf(r.employeeId)} is now L${r.toLevel} in ${_competencyName(r)}.',
      );
    } on AdminException catch (e) {
      if (mounted) showAdminMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _reject(LevelUpRequest r) async {
    final reason = await showTextPrompt(
      context: context,
      title: 'Reject level-up',
      message: '${EmployeeRepository.instance.nameOf(r.employeeId)} · ${_competencyName(r)} → L${r.toLevel}. '
          '${r.raisedByName} will see your reason.',
      hint: 'e.g. Please add the course certificate, or request one level at a time.',
      confirmLabel: 'Reject',
      minLength: ApprovalRules.reasonMin,
      maxLength: ApprovalRules.reasonMax,
      destructive: true,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy.add(r.id));
    try {
      await _approvals.reject(by: widget.user, request: r, reason: reason);
      if (!mounted) return;
      _selected.remove(r.id);
      showAdminMessage(context, 'Rejected. ${r.raisedByName} can raise it again later.');
    } on AdminException catch (e) {
      if (mounted) showAdminMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _approveSelected(List<LevelUpRequest> visiblePending) async {
    final items = visiblePending.where((r) => _selected.contains(r.id)).toList();
    if (items.isEmpty) return;
    final ok = await showConfirm(
      context: context,
      title: 'Approve ${items.length}',
      message: 'Approve ${items.length} level-ups? Each employee\'s level changes now and is marked verified.',
      confirmLabel: 'Approve all',
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    try {
      final count = await _approvals.approve(by: widget.user, items: items);
      if (!mounted) return;
      setState(_selected.clear);
      showAdminMessage(context, '$count level-ups approved.');
    } on AdminException catch (e) {
      if (mounted) showAdminMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = EmployeeRepository.instance;
    final structure = OrgStructureRepository.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _approvals.requests,
        employees.employees,
        CompetencyRepository.instance.competencies,
      ]),
      builder: (context, _) {
        final now = DateTime.now();
        final all = _approvals.requests.value;
        final pending = all.where((r) => r.isPending).toList();
        final monthAgo = now.subtract(const Duration(days: 30));
        final approvedMonth = all
            .where((r) => r.status == ApprovalStatus.approved && (r.decidedAt?.isAfter(monthAgo) ?? false))
            .length;
        final rejectedMonth = all
            .where((r) => r.status == ApprovalStatus.rejected && (r.decidedAt?.isAfter(monthAgo) ?? false))
            .length;
        final avgWait = pending.isEmpty
            ? 0
            : (pending.fold<int>(0, (s, r) => s + now.difference(r.raisedAt).inDays) / pending.length).round();

        final query = _query.trim().toLowerCase();
        final list = all.where((r) {
          if (!_status.matches(r)) return false;
          final e = employees.byId(r.employeeId);
          if (_departmentId != null && e?.departmentId != _departmentId) return false;
          if (query.isNotEmpty) {
            final text = '${r.employeeId} ${e?.name ?? ''} ${_competencyName(r)} ${r.raisedByName} ${r.note}'
                .toLowerCase();
            if (!text.contains(query)) return false;
          }
          return true;
        }).toList()
          ..sort((a, b) => _status == _StatusFilter.pending
              ? a.raisedAt.compareTo(b.raisedAt) // oldest waiting first
              : (b.decidedAt ?? b.raisedAt).compareTo(a.decidedAt ?? a.raisedAt));
        final shown = list.take(_limit).toList();
        final visiblePending = shown.where((r) => r.isPending).toList();
        _selected.removeWhere((id) => !visiblePending.any((r) => r.id == id));
        final width = MediaQuery.sizeOf(context).width;
        final counts = {
          for (final f in _StatusFilter.values) f: all.where(f.matches).length,
        };
        final departments = [...structure.departments.value]..sort((a, b) => a.name.compareTo(b.name));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'APPROVALS',
              subtitle: 'Level-ups that close skill gaps, raised by Team Leads. Approving changes the '
                  'employee\'s level right away (marked verified); rejecting sends your reason back.',
            ),
            const SizedBox(height: 24),
            EqualHeightGrid(
              columns: width >= 900 ? 4 : 2,
              spacing: 14,
              runSpacing: 14,
              children: [
                KpiCard(value: pending.length, label: 'Waiting for you', dark: true),
                KpiCard(value: approvedMonth, label: 'Approved', caption: 'Last 30 days'),
                KpiCard(value: rejectedMonth, label: 'Rejected', caption: 'Last 30 days'),
                KpiCard(value: avgWait, label: 'Days waiting', caption: 'Average for pending'),
              ],
            ),
            const SizedBox(height: 22),
            ModeSwitch<_StatusFilter>(
              selected: _status,
              onChanged: (s) => setState(() {
                _status = s;
                _limit = _pageSize;
                _selected.clear();
              }),
              options: [
                ModeOption(_StatusFilter.pending, 'Pending', Icons.hourglass_top_rounded,
                    badge: counts[_StatusFilter.pending]),
                const ModeOption(_StatusFilter.approved, 'Approved', Icons.check_circle_outline_rounded),
                const ModeOption(_StatusFilter.rejected, 'Rejected', Icons.cancel_outlined),
                const ModeOption(_StatusFilter.all, 'All', Icons.list_alt_rounded),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width < 560 ? width - 40 : 320,
                  child: AdminSearchField(
                    controller: _search,
                    hint: 'Search employee, competency, Team Lead…',
                    onChanged: (v) => setState(() {
                      _query = v;
                      _limit = _pageSize;
                    }),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AdminDropdown<String>(
                    value: _departmentId ?? '',
                    items: ['', for (final d in departments) d.id],
                    labelOf: (id) => id.isEmpty ? 'All departments' : structure.departmentName(id),
                    onChanged: (id) => setState(() {
                      _departmentId = id.isEmpty ? null : id;
                      _limit = _pageSize;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${counts[_StatusFilter.approved]} approved · ${counts[_StatusFilter.rejected]} rejected · '
              '${counts[_StatusFilter.pending]} pending in total · showing ${shown.length} of ${list.length}',
              style: HomeText.body(13.5, weight: FontWeight.w600, color: HomeColors.muted),
            ),
            if (visiblePending.length > 1) ...[
              const SizedBox(height: 12),
              _BulkBar(
                total: visiblePending.length,
                selected: _selected.length,
                busy: _bulkBusy,
                onSelectAll: (all) => setState(() {
                  if (all) {
                    _selected.addAll(visiblePending.map((r) => r.id));
                  } else {
                    _selected.clear();
                  }
                }),
                onApprove: () => _approveSelected(visiblePending),
              ),
            ],
            const SizedBox(height: 14),
            if (list.isEmpty)
              EmptyState(
                title: _status == _StatusFilter.pending ? 'Nothing waiting' : 'Nothing here',
                message: _status == _StatusFilter.pending
                    ? 'All level-up requests are decided. Team Leads raise new ones from team members\' profiles.'
                    : 'Try another filter.',
                icon: Icons.task_alt_rounded,
              )
            else
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TurnIn(
                    key: ValueKey<String>('apr-${shown[i].id}-${shown[i].status.name}'),
                    delay: Duration(milliseconds: math.min(i, 6) * 60),
                    child: _RequestCard(
                      request: shown[i],
                      selected: _selected.contains(shown[i].id),
                      busy: _busy.contains(shown[i].id) || _bulkBusy,
                      onSelected: shown[i].isPending
                          ? (v) => setState(() => v ? _selected.add(shown[i].id) : _selected.remove(shown[i].id))
                          : null,
                      onApprove: () => _approve(shown[i]),
                      onReject: () => _reject(shown[i]),
                      onOpenEmployee: () => widget.onOpenEmployee(shown[i].employeeId),
                    ),
                  ),
                ),
            if (list.length > shown.length)
              Center(
                child: PillButton(
                  label: 'Show more (${list.length - shown.length} left)',
                  variant: PillVariant.outline,
                  height: 46,
                  fontSize: 14,
                  onPressed: () => setState(() => _limit += _pageSize),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.total,
    required this.selected,
    required this.busy,
    required this.onSelectAll,
    required this.onApprove,
  });

  final int total;
  final int selected;
  final bool busy;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final all = selected == total;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: HomeColors.chipBorder),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected == 0 ? false : (all ? true : null),
            tristate: true,
            activeColor: HomeColors.ink,
            onChanged: (_) => onSelectAll(!all),
          ),
          Expanded(
            child: Text(
              selected == 0 ? 'Select requests to approve several at once' : '$selected of $total selected',
              style: HomeText.body(13.5, weight: FontWeight.w600, color: HomeColors.ink),
            ),
          ),
          PillButton(
            label: busy ? 'Approving…' : 'Approve selected',
            height: 40,
            fontSize: 13.5,
            horizontalPadding: 18,
            onPressed: busy || selected == 0 ? null : onApprove,
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.selected,
    required this.busy,
    required this.onSelected,
    required this.onApprove,
    required this.onReject,
    required this.onOpenEmployee,
  });

  final LevelUpRequest request;
  final bool selected;
  final bool busy;
  final ValueChanged<bool>? onSelected;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onOpenEmployee;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final employees = EmployeeRepository.instance;
    final competency = CompetencyRepository.instance.byId(r.competencyId);
    final employee = employees.byId(r.employeeId);
    final current = CompetencyRepository.instance.holderOf(r.competencyId, r.employeeId)?.level;
    final changedSince = r.isPending && current != r.fromLevel;
    final select = onSelected;
    final projects = [
      for (final id in r.projectIds)
        if (ProjectRepository.instance.byId(id) case final ProjectRecord p) p,
    ];

    return LiftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 18),
      liftBy: 4,
      tiltDegrees: 3,
      color: selected ? const Color(0xFFF2F7FE) : Colors.white,
      borderColor: selected ? HomeColors.ink : HomeColors.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (select != null)
                Checkbox(value: selected, activeColor: HomeColors.ink, onChanged: (v) => select(v ?? false))
              else
                const SizedBox(width: 6),
              Expanded(
                child: employee == null
                    ? Text(r.employeeId, style: HomeText.body(14, weight: FontWeight.w700))
                    : InkWell(
                        onTap: onOpenEmployee,
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        child: PersonLine(
                          profile: employee,
                          detail: '${employee.id} · ${employees.departmentNameOf(employee)} · '
                              '${RoleRepository.instance.nameOf(employee.roleId)}',
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: r.status),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (competency != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CompetencyBadge.of(competency, size: 40),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(competency.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: HomeText.body(16, weight: FontWeight.w800, color: HomeColors.ink)),
                            CategoryPill(competency.category, dense: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                _LevelJump(from: r.fromLevel, to: r.toLevel),
                if (r.requiredLevel != null)
                  StatusPill(
                    label: 'Projects need L${r.requiredLevel}',
                    icon: Icons.flag_outlined,
                    background: HomeColors.blueTint,
                    foreground: HomeColors.blueDeep,
                  ),
                for (final p in projects)
                  Tooltip(
                    message: p.name,
                    child: StatusPill(label: p.code, background: HomeColors.neutralTint, foreground: HomeColors.ink),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF7FAFE),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('“${r.note}”', style: HomeText.body(14, color: HomeColors.ink, height: 1.5)),
                const SizedBox(height: 6),
                Text('${r.raisedByName} (Team Lead) · ${dayMonthYear(r.raisedAt)} · ${relativeDays(r.raisedAt)}',
                    style: HomeText.body(12.5, color: HomeColors.muted)),
                if (r.evidence.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Evidence(text: r.evidence),
                ],
              ],
            ),
          ),
          if (r.isPending && r.jump > 1) ...[
            const SizedBox(height: 10),
            InfoNote(
              tone: NoteTone.warning,
              text: 'Skips ${r.jump - 1} ${r.jump - 1 == 1 ? 'level' : 'levels'} '
                  '(${r.isNewSkill ? 'new skill straight to' : 'L${r.fromLevel} →'} L${r.toLevel}).',
            ),
          ],
          if (changedSince) ...[
            const SizedBox(height: 10),
            InfoNote(
              text: 'The level changed since this was raised: now '
                  '${current == null ? 'not held' : 'L$current'}. Approving sets L${r.toLevel} '
                  '(never lower than the current level).',
            ),
          ],
          if (!r.isPending) ...[
            const SizedBox(height: 12),
            Text(
              '${r.status.label} by ${r.decidedByName ?? 'HR'}'
              '${r.decidedAt == null ? '' : ' on ${dayMonthYear(r.decidedAt!)}'}'
              '${r.decisionNote.isEmpty ? '' : ': “${r.decisionNote}”'}',
              style: HomeText.body(13, weight: FontWeight.w600, color: HomeColors.body, height: 1.45),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                PillButton(
                  label: busy ? 'Working…' : 'Approve',
                  height: 44,
                  fontSize: 14,
                  onPressed: busy ? null : onApprove,
                ),
                PillButton(
                  label: 'Reject',
                  variant: PillVariant.outline,
                  height: 44,
                  fontSize: 14,
                  onPressed: busy ? null : onReject,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelJump extends StatelessWidget {
  const _LevelJump({required this.from, required this.to});

  final int? from;
  final int to;

  @override
  Widget build(BuildContext context) {
    final start = from;
    // Wrap (not Row) so the arrow and new level move down on tiny screens.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (start == null)
          const StatusPill(label: 'Not held', background: HomeColors.neutralTint, foreground: HomeColors.body)
        else
          LevelPill(start),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, size: 18, color: HomeColors.ink),
        ),
        LevelPill(to),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color bg, Color fg) = switch (status) {
      ApprovalStatus.pending => (Icons.hourglass_top_rounded, HomeColors.orangeTint, HomeColors.orangeText),
      ApprovalStatus.approved => (Icons.check_circle_outline_rounded, OrgColors.goodTint, OrgColors.good),
      ApprovalStatus.rejected => (Icons.cancel_outlined, const Color(0xFFFDECEC), const Color(0xFFB4232A)),
    };
    return StatusPill(label: status.label, icon: icon, background: bg, foreground: fg);
  }
}

/// Proof: a link opens in a new tab; anything else is shown as a file name.
class _Evidence extends StatelessWidget {
  const _Evidence({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isLink = CompetencyRules.isValidLink(text);
    return Row(
      children: [
        Icon(isLink ? Icons.link_rounded : Icons.attach_file_rounded, size: 16, color: HomeColors.blue),
        const SizedBox(width: 6),
        Flexible(
          child: isLink
              ? InkWell(
                  onTap: () => launchUrl(Uri.parse(text), webOnlyWindowName: '_blank'),
                  child: Text(text,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.blue)
                          .copyWith(decoration: TextDecoration.underline)),
                )
              : Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.ink)),
        ),
      ],
    );
  }
}
