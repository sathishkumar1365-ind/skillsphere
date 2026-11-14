import 'package:flutter/material.dart';

import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../data/org_models.dart';
import 'org_common.dart';

/// Departments: one card per department (lead, headcount, average
/// readiness meter, open gaps) plus headcount ranked as bars.
class DepartmentsSection extends StatelessWidget {
  const DepartmentsSection({super.key, required this.departments});

  final List<DepartmentSummary> departments;

  static const double _sideWidth = 340;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 980;
        final gridWidth = wide ? width - 24 - _sideWidth : width;
        final columns = gridWidth >= 600 ? 2 : 1;

        final grid = EqualHeightGrid(
          columns: columns,
          spacing: 16,
          runSpacing: 16,
          children: [for (final d in departments) _DepartmentCard(department: d)],
        );
        final headcount = _HeadcountPanel(departments: departments);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'DEPARTMENTS',
              subtitle: 'Headcount, average project readiness and open skill gaps '
                  'for every department.',
            ),
            const SizedBox(height: 32),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: grid),
                  const SizedBox(width: 24),
                  SizedBox(width: _sideWidth, child: headcount),
                ],
              )
            else ...[
              headcount,
              const SizedBox(height: 24),
              grid,
            ],
          ],
        );
      },
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department});

  final DepartmentSummary department;

  @override
  Widget build(BuildContext context) {
    final d = department;
    final small = HomeText.body(13, color: HomeColors.muted);
    return LiftCard(
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
                    Text(d.name,
                        style: HomeText.body(18, weight: FontWeight.w700, color: HomeColors.ink)),
                    const SizedBox(height: 2),
                    Text('Lead · ${d.lead}', style: small),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CountUpText(d.headcount, style: HomeText.display(36, height: 1.0)),
                  Text(d.headcount == 1 ? 'person' : 'people', style: small),
                ],
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Average readiness', style: HomeText.body(13, weight: FontWeight.w600)),
              const Spacer(),
              Text('${d.avgReadiness}%',
                  style: HomeText.body(14, weight: FontWeight.w800, color: HomeColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: '${d.name}: ${d.avgReadiness}% average project readiness',
            child: MeterBar(value: d.avgReadiness / 100),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: '${d.openGaps} open gaps',
                icon: Icons.trending_up_rounded,
                background: HomeColors.orangeTint,
                foreground: HomeColors.orangeText,
              ),
              StatusPill(
                label: '${d.available} available',
                icon: Icons.check_circle_outline_rounded,
                background: OrgColors.goodTint,
                foreground: OrgColors.good,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Headcount per department as ranked horizontal bars (one hue, largest
/// first), each with its number printed beside it.
class _HeadcountPanel extends StatelessWidget {
  const _HeadcountPanel({required this.departments});

  final List<DepartmentSummary> departments;

  @override
  Widget build(BuildContext context) {
    final ranked = [...departments]..sort((a, b) => b.headcount.compareTo(a.headcount));
    final total = departments.fold(0, (sum, d) => sum + d.headcount);
    final largest = ranked.isEmpty || ranked.first.headcount == 0 ? 1 : ranked.first.headcount;

    return OrgPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitle('Headcount by department', subtitle: '$total employees, largest first'),
          const SizedBox(height: 20),
          for (var i = 0; i < ranked.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Tooltip(
              message: '${ranked[i].name}: ${ranked[i].headcount} people '
                  '(${total == 0 ? 0 : (ranked[i].headcount * 100 / total).round()}%)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(ranked[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(13.5,
                                weight: FontWeight.w600, color: HomeColors.ink)),
                      ),
                      Text('${ranked[i].headcount}',
                          style: HomeText.body(13.5,
                              weight: FontWeight.w800, color: HomeColors.ink)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  MeterBar(value: ranked[i].headcount / largest, height: 10),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
