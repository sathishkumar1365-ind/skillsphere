import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/home_models.dart';
import '../home_theme.dart';
import 'home_common.dart';
import 'lift_card.dart';
import 'scroll_reveal.dart';

/// "My projects": one card per onboarded project with its skill-match ring
/// and the skills it requires (held ones in blue, gaps dashed orange).
class ProjectsSection extends StatelessWidget {
  const ProjectsSection({super.key, required this.projects, required this.onOpenProject});

  final List<ProjectItem> projects;
  final ValueChanged<ProjectItem> onOpenProject;

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
              title: 'MY PROJECTS',
              subtitle: 'The skills each onboarded project needs, matched against your profile.',
            ),
            const SizedBox(height: 32),
            if (projects.isEmpty)
              Text("You haven't been onboarded to a project yet.", style: HomeText.body(15))
            else
              EqualHeightGrid(
                columns: columns,
                spacing: 24,
                runSpacing: 24,
                children: [
                  for (final project in projects)
                    _ProjectCard(project: project, onOpen: () => onOpenProject(project)),
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

  final ProjectItem project;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      project.name,
                      style: HomeText.body(20, weight: FontWeight.w700, color: HomeColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${project.role} · ${project.period}',
                      style: HomeText.body(14, color: HomeColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              MatchRing(percent: project.matchPercent),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final skill in project.skills) _ProjectSkillChip(skill: skill)],
          ),
          const SizedBox(height: 20),
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

class _ProjectSkillChip extends StatelessWidget {
  const _ProjectSkillChip({required this.skill});

  final ProjectSkill skill;

  @override
  Widget build(BuildContext context) {
    final met = skill.status == ProjectSkillStatus.met;
    final prefix = met ? '✓ ' : (skill.status == ProjectSkillStatus.levelUp ? '↑ ' : '+ ');
    final semantic = met
        ? '${skill.name}, you have this skill'
        : skill.status == ProjectSkillStatus.levelUp
            ? '${skill.name}, level up needed'
            : '${skill.name}, skill gap';

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: met ? HomeColors.blueTint : HomeColors.orangeTint,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        '$prefix${skill.name}',
        style: HomeText.body(13,
            weight: FontWeight.w600, color: met ? HomeColors.blueDeep : HomeColors.orangeText),
      ),
    );

    return Semantics(
      label: semantic,
      excludeSemantics: true,
      child: met ? chip : DashedOutline(color: HomeColors.orange, child: chip),
    );
  }
}

/// Circular skill-match gauge; sweeps and counts up as its section reveals.
class MatchRing extends StatelessWidget {
  const MatchRing({super.key, required this.percent, this.size = 78});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reveal = ScrollReveal.of(context);
    return Semantics(
      label: 'Skill match $percent percent',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) {
          final shown = percent * reveal.value;
          return SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(shown / 100),
              child: Center(
                child: Text(
                  '${shown.round()}%',
                  style: HomeText.body(17, weight: FontWeight.w800, color: HomeColors.ink),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = HomeColors.track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    final value = math.min(1.0, math.max(0.0, progress));
    if (value <= 0) return;
    final fill = Paint()
      ..color = HomeColors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.progress != progress;
}
