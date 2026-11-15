import 'package:flutter/material.dart';

import '../../../home/presentation/widgets/home_common.dart';
import '../../data/org_models.dart';
import 'employee_directory.dart';
import 'org_common.dart';

/// "My Team" on the Home page – shown ONLY to Team Leads (Admin role).
///
/// Lists the employees of the Team Lead's own department. The page only
/// builds this section for that role, so End Users never receive it.
/// (When the API exists, the server must also enforce this: the department
/// comes from the signed-in user's token, not from the app.)
class TeamSection extends StatelessWidget {
  const TeamSection({
    super.key,
    required this.department,
    required this.members,
    required this.onOpenEmployee,
    this.onOpenDirectory,
    this.onOpenReports,
  });

  final String department;
  final List<EmployeeRecord> members;
  final ValueChanged<EmployeeRecord> onOpenEmployee;

  /// Opens the full team directory page (profiles, filters, gaps, bulk
  /// project allocation).
  final VoidCallback? onOpenDirectory;

  /// Opens the team's dashboards & reports (own department only).
  final VoidCallback? onOpenReports;

  @override
  Widget build(BuildContext context) {
    final count = members.length;
    final avgReadiness = count == 0
        ? 0
        : (members.fold(0, (sum, e) => sum + e.readiness) / count).round();
    final openGaps = members.fold(0, (sum, e) => sum + e.gapCount);
    final available = members.where((e) => e.status == EmployeeStatus.available).length;
    final directory = onOpenDirectory;
    final reports = onOpenReports;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : (width >= 480 ? 2 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'MY TEAM',
          subtitle: '$department · $count people. Their skills, readiness, gaps and projects. '
              'Only Team Leads and HRD can see this. Open a person for their full '
              'profile, project allocation and level-up requests; allocate several '
              'people at once from the team directory.',
          trailing: directory == null && reports == null
              ? null
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (reports != null) PillButton(label: 'Team dashboards & reports', onPressed: reports),
                    if (directory != null)
                      PillButton(
                        label: 'Open team directory',
                        variant: PillVariant.outline,
                        onPressed: directory,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 32),
        EqualHeightGrid(
          columns: columns,
          spacing: 16,
          runSpacing: 16,
          children: [
            KpiCard(value: count, label: 'Team members'),
            KpiCard(value: avgReadiness, suffix: '%', label: 'Average readiness'),
            KpiCard(value: available, label: 'Available to staff', caption: 'Not on a project'),
            KpiCard(value: openGaps, label: 'Open skill gaps', dark: true),
          ],
        ),
        const SizedBox(height: 28),
        EmployeeDirectory(
          employees: members,
          showDepartment: false,
          onOpenEmployee: onOpenEmployee,
        ),
      ],
    );
  }
}
