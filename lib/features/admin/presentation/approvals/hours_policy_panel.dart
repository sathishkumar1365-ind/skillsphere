import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../competency/data/competency_models.dart';
import '../../../competency/data/competency_repository.dart';
import '../../../competency/data/level_hours_policy.dart';
import '../../../competency/presentation/widgets/competency_common.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../data/admin_base.dart';
import '../widgets/admin_common.dart';

/// Opens the level-up hours policy in a 3D swing panel. HRD can edit it;
/// everyone else sees it read-only.
Future<void> showHoursPolicy({required BuildContext context, required AppUser user}) {
  return showSwingPanel<void>(
    context: context,
    title: 'Level-up hours policy',
    subtitle: 'Hours needed between two confirmed levels, per competency category.',
    width: 860,
    builder: (_) => HoursPolicyEditor(user: user),
  );
}

/// The policy as a table: one row per category, one column per step.
class HoursPolicyEditor extends StatelessWidget {
  const HoursPolicyEditor({super.key, required this.user});

  final AppUser user;

  bool get _canEdit => user.role.canManageCompetencies;

  @override
  Widget build(BuildContext context) {
    final policy = LevelHoursPolicy.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([policy.hours, policy.lastChange]),
      builder: (context, _) {
        final change = policy.lastChange.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InfoNote(
              tone: NoteTone.warning,
              icon: Icons.construction_rounded,
              text: 'Placeholder numbers: only the L0 → L1 column comes from HR so far (Skill 200, '
                  'Domain 100, Language 250, Tool 300). Replace the rest when the policy is final.',
            ),
            const SizedBox(height: 14),
            Text(
              'Team Leads enter the hours acquired since the last confirmed level with every level-up '
              'request. Below the policy is shown to HR as a warning; HR still decides. A jump over '
              'several levels needs the sum of the steps.',
              style: HomeText.body(14, height: 1.55),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: _PolicyTable(user: user, editable: _canEdit),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              change == null
                  ? 'Default policy (not changed yet).'
                  : 'Last changed by ${change.by} on ${dayMonthYear(change.at)}.',
              style: HomeText.body(12.5, color: HomeColors.muted),
            ),
            if (_canEdit) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  PillButton(
                    label: 'Reset to defaults',
                    variant: PillVariant.outline,
                    height: 44,
                    fontSize: 14,
                    onPressed: policy.isDefault
                        ? null
                        : () async {
                            final ok = await showConfirm(
                              context: context,
                              title: 'Reset the policy',
                              message: 'Put every number back to the defaults? Requests already raised keep '
                                  'the policy they were raised with.',
                              confirmLabel: 'Reset',
                            );
                            if (ok) policy.reset(by: user);
                          },
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PolicyTable extends StatelessWidget {
  const _PolicyTable({required this.user, required this.editable});

  final AppUser user;
  final bool editable;

  static const double _categoryWidth = 150;
  static const double _cellWidth = 104;

  @override
  Widget build(BuildContext context) {
    final policy = LevelHoursPolicy.instance;
    TextStyle head() => HomeText.body(11.5, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.6);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Row(
              children: [
                SizedBox(width: _categoryWidth, child: Text('CATEGORY', style: head())),
                for (var l = 0; l < LevelHoursPolicy.steps; l++)
                  SizedBox(width: _cellWidth, child: Text('L$l → L${l + 1}', style: head())),
                SizedBox(width: _cellWidth, child: Text('L0 → L5', style: head())),
              ],
            ),
          ),
          for (final category in CompetencyCategory.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: _categoryWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Align(alignment: Alignment.centerLeft, child: CategoryPill(category)),
                    ),
                  ),
                  for (var l = 0; l < LevelHoursPolicy.steps; l++)
                    SizedBox(
                      width: _cellWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _HoursCell(
                          key: ValueKey<String>('${category.name}-$l-${policy.stepHours(category, l)}'),
                          value: policy.stepHours(category, l),
                          fromHr: l == 0,
                          enabled: editable,
                          onSave: (v) {
                            try {
                              policy.setStep(by: user, category: category, fromLevel: l, value: v);
                            } on CompetencyException catch (e) {
                              showAdminMessage(context, e.message);
                            }
                          },
                        ),
                      ),
                    ),
                  SizedBox(
                    width: _cellWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        hoursLabel(policy.hoursBetween(category, 0, CompetencyLevel.max)),
                        style: HomeText.body(14, weight: FontWeight.w800, color: HomeColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One editable number; saves on Enter or when focus leaves.
class _HoursCell extends StatefulWidget {
  const _HoursCell({
    super.key,
    required this.value,
    required this.fromHr,
    required this.enabled,
    required this.onSave,
  });

  final int value;

  /// The L0 → L1 numbers came from HR (shown in ink, the rest muted).
  final bool fromHr;
  final bool enabled;
  final ValueChanged<int> onSave;

  @override
  State<_HoursCell> createState() => _HoursCellState();
}

class _HoursCellState extends State<_HoursCell> {
  late final TextEditingController _text = TextEditingController(text: '${widget.value}');
  final FocusNode _focus = FocusNode();
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (!mounted) return;
    final v = int.tryParse(_text.text.trim());
    if (v == null || v < 0 || v > LevelHoursPolicy.maxStepHours) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    if (v != widget.value) widget.onSave(v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Tooltip(
        message: widget.fromHr ? 'From HR' : 'Placeholder until the policy is final',
        child: Text(
          hoursLabel(widget.value),
          style: HomeText.body(14,
              weight: FontWeight.w700, color: widget.fromHr ? HomeColors.ink : HomeColors.muted),
        ),
      );
    }
    return Tooltip(
      message: widget.fromHr ? 'From HR' : 'Placeholder until the policy is final',
      waitDuration: const Duration(milliseconds: 600),
      child: TextField(
        controller: _text,
        focusNode: _focus,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        onSubmitted: (_) => _save(),
        style: HomeText.body(14,
            weight: widget.fromHr ? FontWeight.w800 : FontWeight.w600,
            color: widget.fromHr ? HomeColors.ink : HomeColors.body),
        decoration: adminDecoration(errorText: _invalid ? '0–${LevelHoursPolicy.maxStepHours}' : null)
            .copyWith(suffixText: 'h', contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
      ),
    );
  }
}
