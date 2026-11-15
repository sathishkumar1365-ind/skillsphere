// Dashboards & Reports › Skill maps: pick a person (HRD: anyone active in
// the organisation; Team Lead: their own department only – the same scope
// as every other report) and see their skill map with animated beams.
// The people with the biggest gaps are one click away.

import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../admin/data/employees.dart';
import '../../admin/data/insights.dart';
import '../../admin/presentation/widgets/admin_common.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/presentation/widgets/competency_details_panel.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../organization/data/org_models.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../../reports/data/report_engine.dart';
import 'skill_beam_map.dart';

class SkillMapExplorer extends StatefulWidget {
  const SkillMapExplorer({super.key, required this.user, required this.onOpenEmployee});

  final AppUser user;

  /// Opens a profile (only called for people in the viewer's scope).
  final ValueChanged<String> onOpenEmployee;

  @override
  State<SkillMapExplorer> createState() => _SkillMapExplorerState();
}

class _SkillMapExplorerState extends State<SkillMapExplorer> {
  String? _employeeId;

  void _openCompetency(Competency competency) {
    showCompetencyDetails(
      context,
      competency: competency,
      employeesById: {for (final r in Insights.records(includeInactive: true)) r.id: r},
      onOpenEmployee: (EmployeeRecord e) {
        final target = EmployeeRepository.instance.byId(e.id);
        if (target == null || !EmployeeRepository.instance.canView(widget.user, target)) {
          showAdminMessage(context, 'You can only open profiles in your own department.');
          return;
        }
        widget.onOpenEmployee(e.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = ReportScope.of(widget.user);
    return ListenableBuilder(
      listenable: Insights.listenable,
      builder: (context, _) {
        final people = EmployeeRepository.instance.employees.value
            .where((e) => e.isActive && scope.includesDepartment(e.departmentId))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        if (people.isEmpty) {
          return const EmptyState(
            title: 'Nobody to show',
            message: 'There are no active employees in your scope yet.',
            icon: Icons.person_search_outlined,
          );
        }
        final insights = {for (final e in people) e.id: Insights.of(e)};
        // Biggest gaps first, then the least ready.
        final ranked = [...people]..sort((a, b) {
            final ia = insights[a.id]!;
            final ib = insights[b.id]!;
            final byGaps = ib.gapCount.compareTo(ia.gapCount);
            if (byGaps != 0) return byGaps;
            final byReady = (ia.readiness ?? 101).compareTo(ib.readiness ?? 101);
            return byReady != 0 ? byReady : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        EmployeeProfile selected = ranked.first;
        for (final e in people) {
          if (e.id == _employeeId) selected = e;
        }
        final insight = insights[selected.id]!;

        String detail(EmployeeProfile e) {
          final i = insights[e.id]!;
          final ready = i.readiness;
          return '${e.id} · ${i.gapCount} ${i.gapCount == 1 ? 'gap' : 'gaps'}'
              '${ready == null ? ' · no project needs' : ' · $ready% ready'}';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OrgPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelTitle(
                    'Whose skill map?',
                    subtitle: scope.isOrganisation
                        ? 'Anyone active in the organisation. Projects, what they need, the levels held and '
                            'the gaps – joined by animated beams.'
                        : 'People in the ${widget.user.department} department only. Projects, what they need, '
                            'the levels held and the gaps – joined by animated beams.',
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: EmployeeSearchBox(
                        options: people,
                        hint: 'Search name or employee ID…',
                        detailOf: detail,
                        onPicked: (e) => setState(() => _employeeId = e.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('BIGGEST GAPS',
                      style: HomeText.body(11, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in ranked.take(8))
                        _PersonChip(
                          profile: e,
                          gaps: insights[e.id]!.gapCount,
                          selected: e.id == selected.id,
                          onTap: () => setState(() => _employeeId = e.id),
                        ),
                      if (ranked.take(8).every((e) => e.id != selected.id))
                        _PersonChip(
                          profile: selected,
                          gaps: insight.gapCount,
                          selected: true,
                          onTap: () {},
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TurnIn(
              replayKey: selected.id,
              child: SkillBeamMap(
                key: ValueKey<String>(selected.id),
                insight: insight,
                own: selected.id == widget.user.id,
                onOpenProfile: () => widget.onOpenEmployee(selected.id),
                onOpenCompetency: _openCompetency,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.profile, required this.gaps, required this.selected, required this.onTap});

  final EmployeeProfile profile;
  final int gaps;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : HomeColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '${profile.name}, $gaps ${gaps == 1 ? 'gap' : 'gaps'}',
      excludeSemantics: true,
      child: HoverRaise(
        child: Material(
          color: selected ? HomeColors.ink : Colors.white,
          shape: StadiumBorder(side: BorderSide(color: selected ? HomeColors.ink : HomeColors.chipBorder)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InitialsAvatar(initials: profile.initials, size: 30),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text(profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HomeText.body(13.5, weight: FontWeight.w700, color: fg)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: gaps == 0
                          ? (selected ? const Color.fromRGBO(255, 255, 255, 0.18) : HomeColors.neutralTint)
                          : (selected ? HomeColors.orange : HomeColors.orangeTint),
                      borderRadius: const BorderRadius.all(Radius.circular(999)),
                    ),
                    child: Text(
                      gaps == 0 ? 'no gaps' : '−$gaps',
                      style: HomeText.body(11.5,
                          weight: FontWeight.w800,
                          color: gaps == 0 ? fg : (selected ? Colors.white : HomeColors.orangeText)),
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
