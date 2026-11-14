import 'package:flutter/material.dart';

import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/scroll_reveal.dart';
import '../../../home/presentation/widgets/skill_globe.dart';
import '../../data/org_models.dart';
import 'org_common.dart';

/// Super Admin hero: greeting, organisation summary, the 3D globe showing
/// average readiness with strong skills and shortages orbiting, and the
/// headline numbers.
class OrgOverviewSection extends StatelessWidget {
  const OrgOverviewSection({
    super.key,
    required this.data,
    required this.firstName,
    required this.onViewEmployees,
    required this.onViewShortages,
  });

  final OrgData data;
  final String firstName;
  final VoidCallback onViewEmployees;
  final VoidCallback onViewShortages;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 980;
        final titleSize = width >= 980 ? 88.0 : (width >= 600 ? 72.0 : 52.0);

        final intro = ScrollReveal(
          offset: 40,
          tiltDegrees: 10,
          child: _Intro(
            data: data,
            firstName: firstName,
            titleSize: titleSize,
            onViewEmployees: onViewEmployees,
            onViewShortages: onViewShortages,
          ),
        );
        final globe = Center(
          child: SkillGlobe(
            readinessPercent: data.avgReadiness,
            chips: data.globeChips,
            caption: 'ORG READY',
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                children: [
                  Expanded(flex: 21, child: intro),
                  const SizedBox(width: 24),
                  Expanded(flex: 20, child: globe),
                ],
              )
            else ...[
              intro,
              const SizedBox(height: 8),
              globe,
            ],
            const SizedBox(height: 28),
            ScrollReveal(
              offset: 40,
              delay: const Duration(milliseconds: 150),
              child: _KpiGrid(data: data, width: width),
            ),
          ],
        );
      },
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({
    required this.data,
    required this.firstName,
    required this.titleSize,
    required this.onViewEmployees,
    required this.onViewShortages,
  });

  final OrgData data;
  final String firstName;
  final double titleSize;
  final VoidCallback onViewEmployees;
  final VoidCallback onViewShortages;

  @override
  Widget build(BuildContext context) {
    final shortSkills = data.skillDemand.where((s) => s.shortage > 0).length;
    final summary = '${data.headcount} employees across ${data.departmentCount} departments '
        'are ${data.avgReadiness}% project-ready on average. ${data.openGaps} skill gaps '
        'are open, and $shortSkills skills are short of what current projects need.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Color.fromRGBO(255, 255, 255, 0.75),
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          child: Text(
            'ORGANIZATION OVERVIEW · HRD',
            style: HomeText.body(12,
                weight: FontWeight.w700, color: HomeColors.blue, letterSpacing: 1.7),
          ),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text('HELLO, ${firstName.toUpperCase()}.', style: HomeText.display(titleSize)),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Text(summary, style: HomeText.body(18, height: 1.6)),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            PillButton(label: 'View all employees', onPressed: onViewEmployees),
            PillButton(
              label: 'See skill shortages',
              onPressed: onViewShortages,
              variant: PillVariant.outline,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _LegendDot(color: HomeColors.blue, label: 'Strong skill across the org'),
            _LegendDot(color: HomeColors.orange, label: 'Short of project demand'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: HomeText.body(13)),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data, required this.width});

  final OrgData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final columns = width >= 900 ? 3 : (width >= 480 ? 2 : 1);
    return EqualHeightGrid(
      columns: columns,
      spacing: 16,
      runSpacing: 16,
      children: [
        KpiCard(
          value: data.headcount,
          label: 'Employees',
          caption: 'Across ${data.departmentCount} departments',
        ),
        KpiCard(
          value: data.avgReadiness,
          suffix: '%',
          label: 'Average project readiness',
          caption: 'Required skills held vs needed',
        ),
        KpiCard(
          value: data.projects.length,
          label: 'Active projects',
          caption: '${data.projects.where((p) => p.health != ProjectHealth.onTrack).length} need attention',
        ),
        KpiCard(
          value: data.availableCount,
          label: 'Available to staff',
          caption: 'Not on a project right now',
        ),
        KpiCard(
          value: data.pendingVerifications,
          label: 'Skills awaiting verification',
          caption: 'Waiting for Team Lead review',
        ),
        KpiCard(
          value: data.openGaps,
          label: 'Open skill gaps',
          caption: 'Across all employees',
          dark: true,
        ),
      ],
    );
  }
}
