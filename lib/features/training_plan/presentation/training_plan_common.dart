import 'package:flutter/material.dart';

import '../../home/presentation/home_theme.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../data/training_plans.dart';

IconData trainingTypeIcon(TrainingType type) => switch (type) {
      TrainingType.onlineCourse => Icons.laptop_chromebook_rounded,
      TrainingType.classroom => Icons.cast_for_education_rounded,
      TrainingType.workshop => Icons.groups_2_outlined,
      TrainingType.certification => Icons.workspace_premium_outlined,
      TrainingType.mentoring => Icons.handshake_outlined,
      TrainingType.onTheJob => Icons.engineering_outlined,
      TrainingType.selfStudy => Icons.menu_book_rounded,
    };

/// Status with an icon and a label (never colour alone).
class PlanStatusPill extends StatelessWidget {
  const PlanStatusPill({super.key, required this.status});

  final PlanStatus status;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color bg, Color fg) = switch (status) {
      PlanStatus.planned => (Icons.event_outlined, HomeColors.blueTint, HomeColors.blueDeep),
      PlanStatus.inProgress => (Icons.play_circle_outline_rounded, HomeColors.blueTint, HomeColors.blueDeep),
      PlanStatus.onHold => (Icons.pause_circle_outline_rounded, HomeColors.neutralTint, HomeColors.body),
      PlanStatus.completed => (Icons.task_alt_rounded, OrgColors.goodTint, OrgColors.good),
    };
    return StatusPill(label: status.label, icon: icon, background: bg, foreground: fg);
  }
}

/// The training type as a raised 3D tile: lifts and tips forward when hovered
/// or chosen.
class TrainingTypeChip extends StatefulWidget {
  const TrainingTypeChip({super.key, required this.type, required this.selected, required this.onTap});

  final TrainingType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<TrainingTypeChip> createState() => _TrainingTypeChipState();
}

class _TrainingTypeChipState extends State<TrainingTypeChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final lift = selected ? 1.0 : (_hover ? 0.6 : 0.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: widget.type.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: lift),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
            curve: HomeMotion.ease,
            builder: (context, t, child) {
              // Identity at rest, so nothing is re-laid out while idle.
              final matrix = t == 0
                  ? Matrix4.identity()
                  : (Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
                    ..multiply(Matrix4.translationValues(0, -3 * t, 0))
                    ..multiply(Matrix4.rotationX(-0.28 * t)));
              return Transform(
                alignment: Alignment.bottomCenter,
                transform: matrix,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
                  decoration: BoxDecoration(
                    color: selected ? HomeColors.ink : Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    border: Border.all(color: selected ? HomeColors.ink : HomeColors.chipBorder),
                    boxShadow: t == 0
                        ? null
                        : [
                            BoxShadow(
                              color: Color.fromRGBO(15, 27, 45, 0.28 * t),
                              blurRadius: 14,
                              spreadRadius: -6,
                              offset: Offset(0, 7 * t),
                            ),
                          ],
                  ),
                  child: child,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trainingTypeIcon(widget.type), size: 18, color: selected ? Colors.white : HomeColors.blue),
                const SizedBox(width: 8),
                Text(widget.type.label,
                    style: HomeText.body(13.5, weight: FontWeight.w700, color: selected ? Colors.white : HomeColors.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
