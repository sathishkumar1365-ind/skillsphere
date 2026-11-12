import 'package:flutter/material.dart';

import '../../data/home_models.dart';
import '../home_theme.dart';
import 'home_common.dart';
import 'lift_card.dart';
import 'scroll_reveal.dart';
import 'skill_globe.dart';

/// Greeting, readiness summary and the 3D skill globe, followed by the
/// four headline numbers.
class HeroSection extends StatelessWidget {
  const HeroSection({
    super.key,
    required this.data,
    required this.onUpdateSkills,
    required this.onSeeGaps,
  });

  final HomeData data;
  final VoidCallback onUpdateSkills;
  final VoidCallback onSeeGaps;

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
            titleSize: titleSize,
            onUpdateSkills: onUpdateSkills,
            onSeeGaps: onSeeGaps,
          ),
        );
        final globe = Center(
          child: SkillGlobe(
            readinessPercent: data.readinessPercent,
            chips: data.globeChips,
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
              child: _StatsRow(data: data, width: width),
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
    required this.titleSize,
    required this.onUpdateSkills,
    required this.onSeeGaps,
  });

  final HomeData data;
  final double titleSize;
  final VoidCallback onUpdateSkills;
  final VoidCallback onSeeGaps;

  @override
  Widget build(BuildContext context) {
    final missing = data.missingRequiredSkills;
    final summary = missing == 0
        ? 'You hold every skill your current projects need. Keep them sharp.'
        : 'You hold ${data.requiredSkillsHeld} of the ${data.requiredSkillsTotal} '
            'skills your current projects need. Close the remaining $missing '
            'to be fully project-ready.';

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
            'COMPETENCY SNAPSHOT',
            style: HomeText.body(12,
                weight: FontWeight.w700, color: HomeColors.blue, letterSpacing: 1.7),
          ),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            'WELCOME BACK, ${data.firstName.toUpperCase()}.',
            style: HomeText.display(titleSize),
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(summary, style: HomeText.body(18, height: 1.6)),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            PillButton(label: 'Update my skills', onPressed: onUpdateSkills),
            PillButton(
              label: 'See my skill gaps',
              onPressed: onSeeGaps,
              variant: PillVariant.outline,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _LegendDot(color: HomeColors.blue, label: 'Acquired skill'),
            _LegendDot(color: HomeColors.orange, label: 'Gap to close'),
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

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data, required this.width});

  final HomeData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final columns = width >= 900 ? 4 : (width >= 480 ? 2 : 1);
    return EqualHeightGrid(
      columns: columns,
      spacing: 16,
      runSpacing: 16,
      children: [
        _StatCard(value: data.skillsAcquired, label: 'Skills acquired'),
        _StatCard(value: data.skillsInProgress, label: 'Skills in progress'),
        _StatCard(value: data.projects.length, label: 'Onboarded projects'),
        _StatCard(value: data.gaps.length, label: 'Skill gaps to close', dark: true),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, this.dark = false});

  final int value;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return LiftCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      color: dark ? HomeColors.ink : const Color.fromRGBO(255, 255, 255, 0.82),
      borderColor: dark ? null : const Color.fromRGBO(255, 255, 255, 0.95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CountUpText(
            value,
            style: HomeText.display(44,
                height: 1.0, color: dark ? HomeColors.peach : HomeColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: HomeText.body(14,
                weight: FontWeight.w600, color: dark ? HomeColors.onInk : HomeColors.body),
          ),
        ],
      ),
    );
  }
}
