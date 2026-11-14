import 'package:flutter/material.dart';

import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../home/presentation/widgets/projects_section.dart' show MatchRing;
import '../../data/org_models.dart';
import 'org_common.dart';

/// Every active project: health, team skill match, staffing and the skills
/// the team is still missing.
class OrgProjectsSection extends StatelessWidget {
  const OrgProjectsSection({super.key, required this.projects, required this.onOpenProject});

  final List<OrgProject> projects;
  final ValueChanged<OrgProject> onOpenProject;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000 ? 3 : (width >= 680 ? 2 : 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'PROJECTS',
              subtitle: 'Staffing and team skill match for every active project, '
                  'with the skills each team still needs.',
            ),
            const SizedBox(height: 32),
            if (projects.isEmpty)
              Text('No active projects.', style: HomeText.body(15))
            else
              EqualHeightGrid(
                columns: columns,
                spacing: 24,
                runSpacing: 24,
                children: [
                  for (final p in projects)
                    _ProjectCard(project: p, onOpen: () => onOpenProject(p)),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onOpen});

  final OrgProject project;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = project;
    final open = p.needed - p.members;
    return LiftCard(
      padding: const EdgeInsets.all(26),
      radius: 26,
      borderColor: HomeColors.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: HomeText.body(20, weight: FontWeight.w700, color: HomeColors.ink)),
                    const SizedBox(height: 4),
                    Text('${p.department} · ${p.period}',
                        style: HomeText.body(14, color: HomeColors.muted)),
                    const SizedBox(height: 10),
                    StatusPill.project(p.health),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              MatchRing(percent: p.matchPercent),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Team staffed', style: HomeText.body(13, weight: FontWeight.w600)),
              const Spacer(),
              Text('${p.members} of ${p.needed}',
                  style: HomeText.body(14, weight: FontWeight.w800, color: HomeColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: open > 0
                ? '${p.members} of ${p.needed} people onboarded – $open open'
                : 'Fully staffed',
            child: MeterBar(value: p.needed == 0 ? 1 : p.members / p.needed),
          ),
          const SizedBox(height: 18),
          if (p.missingSkills.isEmpty)
            Text('No missing skills.', style: HomeText.body(13.5))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in p.missingSkills)
                  Semantics(
                    label: '$skill, missing in the team',
                    excludeSemantics: true,
                    child: DashedOutline(
                      color: HomeColors.orange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: const BoxDecoration(
                          color: HomeColors.orangeTint,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text('+ $skill',
                            style: HomeText.body(13,
                                weight: FontWeight.w600, color: HomeColors.orangeText)),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          const Spacer(),
          TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              foregroundColor: HomeColors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 44),
              textStyle: HomeText.body(14, weight: FontWeight.w700),
            ),
            child: const Text('View project →'),
          ),
        ],
      ),
    );
  }
}
