import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/admin_import.dart';
import '../../data/employees.dart';
import '../console_section.dart';
import '../widgets/admin_common.dart';
import '../widgets/bulk_import_panel.dart';
import 'crowd_panel.dart';
import 'employee_form.dart';

enum _Mode { single, bulk, crowd }

/// Console › Employee Onboarding: add one employee with the form, many from
/// an Excel/CSV file, or synchronise from Atlassian Crowd.
class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    required this.user,
    required this.onOpenEmployee,
    required this.onNavigate,
  });

  final AppUser user;
  final ValueChanged<String> onOpenEmployee;
  final ValueChanged<ConsoleSection> onNavigate;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  _Mode _mode = _Mode.single;
  EmployeeProfile? _justAdded;

  late final BulkImportConfig<EmployeeDraft> _importConfig = BulkImportConfig<EmployeeDraft>(
    title: 'Bulk import employees',
    subtitle: 'Onboard many employees from Excel or CSV. Each row is checked with the same '
        'rules as the form.',
    templateAsset: EmployeeImporter.templateAsset,
    templateFileName: EmployeeImporter.templateFileName,
    templateDescription: 'Columns in the right order, drop-downs for Gender, Status, Group, '
        'Department, Role and Country, examples, a Lists sheet and an Instructions sheet.',
    columnsHelp: 'Employee ID · Full Name · Work Email · Gender · Status · Group · Department · '
        'Reporting Manager (ID) · Designation · Role · Country · State · City · Acquired Skills '
        '("Java:3; Python:2") · Additional Skills ("Poster Design; Video Editing") · Short Intro. '
        'Certificates are attached later on each profile.',
    singular: 'employee',
    plural: 'employees',
    parse: (bytes, fileName) => EmployeeImporter.parse(bytes, fileName: fileName),
    commit: (drafts) async =>
        (await EmployeeRepository.instance.onboardAll(by: widget.user, drafts: drafts)).length,
  );

  void _onboarded(EmployeeProfile profile) {
    setState(() => _justAdded = profile);
    showAdminMessage(
      context,
      '${profile.name} (${profile.id}) is onboarded.',
      action: SnackBarAction(label: 'View profile', onPressed: () => widget.onOpenEmployee(profile.id)),
    );
  }

  void _imported(int count) {
    showAdminMessage(
      context,
      '$count ${count == 1 ? 'employee' : 'employees'} onboarded. They are marked NEW in All Employees.',
      action: SnackBarAction(label: 'View', onPressed: () => widget.onNavigate(ConsoleSection.employees)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final added = _justAdded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'EMPLOYEE ONBOARDING',
          subtitle: ConsoleSection.onboarding.blurb,
        ),
        const SizedBox(height: 24),
        ModeSwitch<_Mode>(
          selected: _mode,
          onChanged: (m) => setState(() => _mode = m),
          options: const [
            ModeOption(_Mode.single, 'Add employee', Icons.person_add_alt_1_rounded),
            ModeOption(_Mode.bulk, 'Bulk import', Icons.upload_file_rounded),
            ModeOption(_Mode.crowd, 'Crowd sync', Icons.sync_rounded),
          ],
        ),
        const SizedBox(height: 20),
        if (added != null && _mode == _Mode.single) ...[
          TurnIn(
            replayKey: added.id,
            child: _SuccessCard(
              profile: added,
              onView: () => widget.onOpenEmployee(added.id),
              onDismiss: () => setState(() => _justAdded = null),
            ),
          ),
          const SizedBox(height: 18),
        ],
        FlipWhenShown(
          visible: _mode == _Mode.single,
          child: EmployeeForm(user: widget.user, onSaved: _onboarded),
        ),
        FlipWhenShown(
          visible: _mode == _Mode.bulk,
          child: BulkImportPanel<EmployeeDraft>(config: _importConfig, onImported: _imported),
        ),
        FlipWhenShown(
          visible: _mode == _Mode.crowd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CrowdConnectionPanel(user: widget.user),
              const SizedBox(height: 18),
              CrowdUsersPanel(user: widget.user, onOpenEmployee: widget.onOpenEmployee),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _RecentlyOnboarded(onOpen: widget.onOpenEmployee),
      ],
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.profile, required this.onView, required this.onDismiss});

  final EmployeeProfile profile;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final employees = EmployeeRepository.instance;
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${profile.name.toUpperCase()} IS ON BOARD',
            style: HomeText.display(narrow ? 20 : 24, color: Colors.white, height: 1.05)),
        const SizedBox(height: 4),
        Text(
          '${profile.id} · ${profile.designation} · ${employees.departmentNameOf(profile)} '
          '(${employees.groupNameOf(profile)})',
          style: HomeText.body(13.5, color: HomeColors.onInkMuted),
        ),
      ],
    );
    final view = PillButton(
      label: 'View profile',
      variant: PillVariant.light,
      height: 44,
      fontSize: 14,
      onPressed: onView,
    );
    final dismiss = IconButton(
      tooltip: 'Dismiss',
      icon: const Icon(Icons.close_rounded, color: HomeColors.onInkMuted),
      onPressed: onDismiss,
    );
    final tick = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Color.fromRGBO(255, 255, 255, 0.14), shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, color: HomeColors.peach, size: 26),
    );
    return LiftCard(
      color: HomeColors.ink,
      padding: const EdgeInsets.fromLTRB(22, 20, 14, 20),
      // Phones: the button goes under the text instead of squeezing it.
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [tick, const SizedBox(width: 12), Expanded(child: text), dismiss],
                ),
                const SizedBox(height: 12),
                view,
              ],
            )
          : Row(
              children: [
                tick,
                const SizedBox(width: 16),
                Expanded(child: text),
                const SizedBox(width: 10),
                view,
                dismiss,
              ],
            ),
    );
  }
}

/// The newest profiles (this session first), as small cards.
class _RecentlyOnboarded extends StatelessWidget {
  const _RecentlyOnboarded({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final employees = EmployeeRepository.instance;
    return ListenableBuilder(
      listenable: employees.employees,
      builder: (context, _) {
        final recent = [...employees.employees.value]..sort((a, b) => b.onboardedAt.compareTo(a.onboardedAt));
        final shown = recent.take(6).toList();
        final width = MediaQuery.sizeOf(context).width;
        final columns = width >= 1300 ? 3 : (width >= 720 ? 2 : 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelTitle('Recently onboarded', subtitle: 'Newest profiles first. Select one to open it.'),
            const SizedBox(height: 14),
            EqualHeightGrid(
              columns: columns,
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final e in shown)
                  TurnIn(
                    key: ValueKey<String>('recent-${e.id}'),
                    play: employees.isNew(e.id),
                    child: _RecentCard(profile: e, onOpen: () => onOpen(e.id)),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.profile, required this.onOpen});

  final EmployeeProfile profile;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final employees = EmployeeRepository.instance;
    final isNew = employees.isNew(profile.id);
    return LiftCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PersonLine(
                  profile: profile,
                  detail: '${profile.id} · ${employees.departmentNameOf(profile)}',
                  trailing: isNew ? const NewLabel() : null,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SourcePill(profile.source),
                    if (!profile.isComplete)
                      StatusPill(
                        label: 'Missing: ${profile.missingFields.join(', ')}',
                        icon: Icons.edit_note_rounded,
                        background: HomeColors.orangeTint,
                        foreground: HomeColors.orangeText,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Onboarded ${relativeDays(profile.onboardedAt)}',
                    style: HomeText.body(12.5, color: HomeColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
