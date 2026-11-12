import 'package:flutter/material.dart';

import '../../data/home_models.dart';
import '../home_theme.dart';
import 'home_common.dart';
import 'lift_card.dart';
import 'scroll_reveal.dart';

/// "Skill gaps to close": current vs required level per gap, plus the
/// employee's learning plan and next skill review.
class GapsSection extends StatelessWidget {
  const GapsSection({
    super.key,
    required this.gaps,
    required this.learningPlan,
    required this.nextReview,
    required this.onFindCourse,
    required this.onOpenLearningPlan,
  });

  final List<SkillGap> gaps;
  final List<LearningStep> learningPlan;
  final DateTime? nextReview;
  final ValueChanged<SkillGap> onFindCourse;
  final VoidCallback onOpenLearningPlan;

  static const double _planWidth = 340;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 960;
        final listWidth = wide ? width - 24 - _planWidth : width;

        final list = _GapList(
          gaps: gaps,
          compact: listWidth < 600,
          onFindCourse: onFindCourse,
        );
        final plan = _LearningPlanCard(
          steps: learningPlan,
          nextReview: nextReview,
          onOpen: onOpenLearningPlan,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'SKILL GAPS TO CLOSE',
              subtitle: 'Where your level is below what a project needs. '
                  'Blue is your level; the orange band is what the project requires.',
            ),
            const SizedBox(height: 32),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: list),
                  const SizedBox(width: 24),
                  SizedBox(width: _planWidth, child: plan),
                ],
              )
            else ...[
              list,
              const SizedBox(height: 24),
              plan,
            ],
          ],
        );
      },
    );
  }
}

class _GapList extends StatelessWidget {
  const _GapList({required this.gaps, required this.compact, required this.onFindCourse});

  final List<SkillGap> gaps;
  final bool compact;
  final ValueChanged<SkillGap> onFindCourse;

  @override
  Widget build(BuildContext context) {
    if (gaps.isEmpty) {
      return Text(
        'No gaps: you meet every requirement of your current projects.',
        style: HomeText.body(15),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < gaps.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _GapRow(gap: gaps[i], compact: compact, onFindCourse: () => onFindCourse(gaps[i])),
        ],
      ],
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap, required this.compact, required this.onFindCourse});

  final SkillGap gap;
  final bool compact;
  final VoidCallback onFindCourse;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(gap.skill, style: HomeText.body(17, weight: FontWeight.w700, color: HomeColors.ink)),
        const SizedBox(height: 2),
        Text('For ${gap.project}', style: HomeText.body(13, color: HomeColors.muted)),
      ],
    );
    final bar = _GapBar(currentLevel: gap.currentLevel, requiredLevel: gap.requiredLevel);
    final button = PillButton(
      label: 'Find a course',
      onPressed: onFindCourse,
      variant: PillVariant.outline,
      height: 44,
      fontSize: 13,
      horizontalPadding: 16,
    );

    return LiftCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      radius: 20,
      borderColor: HomeColors.cardBorder,
      liftBy: 6,
      tiltDegrees: 5,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 14),
                bar,
                const SizedBox(height: 14),
                button,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 11, child: title),
                const SizedBox(width: 20),
                Expanded(flex: 14, child: bar),
                const SizedBox(width: 20),
                button,
              ],
            ),
    );
  }
}

/// Track with the required level (orange band) and the current level (blue)
/// on top. Both grow from the left as the section is revealed.
class _GapBar extends StatelessWidget {
  const _GapBar({required this.currentLevel, required this.requiredLevel});

  final int currentLevel;
  final int requiredLevel;

  @override
  Widget build(BuildContext context) {
    final reveal = ScrollReveal.of(context);
    return Semantics(
      label: 'Your level $currentLevel of 5. Project needs $requiredLevel of 5.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 10,
            child: AnimatedBuilder(
              animation: reveal,
              builder: (context, _) {
                final t = reveal.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: HomeColors.gapTrack,
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (requiredLevel / 5 * t).clamp(0.0, 1.0).toDouble(),
                      child: Container(
                        alignment: Alignment.centerRight,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                          color: HomeColors.orangeBand,
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                        child: Container(width: 3, color: HomeColors.orange),
                      ),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (currentLevel / 5 * t).clamp(0.0, 1.0).toDouble(),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: HomeColors.blue,
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You $currentLevel / 5 · Needed $requiredLevel / 5',
            style: HomeText.body(12, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LearningPlanCard extends StatelessWidget {
  const _LearningPlanCard({required this.steps, required this.nextReview, required this.onOpen});

  final List<LearningStep> steps;
  final DateTime? nextReview;
  final VoidCallback onOpen;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final review = nextReview;
    final reviewText = review == null
        ? 'not scheduled yet'
        : '${review.day} ${_months[review.month - 1]} ${review.year}';

    return LiftCard(
      color: HomeColors.ink,
      radius: 28,
      padding: const EdgeInsets.all(30),
      liftBy: 6,
      tiltDegrees: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'MY LEARNING PLAN',
              style: HomeText.display(32, color: Colors.white, height: 1.0),
            ),
          ),
          const SizedBox(height: 22),
          if (steps.isEmpty)
            Text('No courses planned yet.', style: HomeText.body(14, color: HomeColors.onInkMuted))
          else
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              _PlanStep(number: i + 1, step: steps[i]),
            ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.08),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Text.rich(
              TextSpan(
                text: 'Next skill review with your manager: ',
                children: [
                  TextSpan(
                    text: reviewText,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
              style: HomeText.body(14, color: HomeColors.onInk, height: 1.5),
            ),
          ),
          const SizedBox(height: 22),
          PillButton(label: 'Open learning plan', onPressed: onOpen, variant: PillVariant.light),
        ],
      ),
    );
  }
}

class _PlanStep extends StatelessWidget {
  const _PlanStep({required this.number, required this.step});

  final int number;
  final LearningStep step;

  @override
  Widget build(BuildContext context) {
    final planned = step.status == LearningStepStatus.planned;
    final Color fill = step.status == LearningStepStatus.inProgress
        ? HomeColors.peach
        : (planned ? Colors.transparent : Colors.white);
    final Color textColor = planned ? Colors.white : HomeColors.ink;
    final Border? border =
        planned ? Border.all(color: HomeColors.onInkMuted, width: 1.5) : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: border),
          child: Text(
            '$number',
            style: HomeText.body(14, weight: FontWeight.w800, color: textColor),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step.title,
                  style: HomeText.body(15, weight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 2),
              Text(step.statusLabel,
                  style: HomeText.body(13, color: HomeColors.onInkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
