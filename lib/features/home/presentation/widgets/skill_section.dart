import 'package:flutter/material.dart';

import '../../data/home_models.dart';
import '../home_theme.dart';
import 'home_common.dart';
import 'lift_card.dart';
import 'scroll_reveal.dart';

/// "My skill profile": filterable grid of skill cards with 5-step level bars.
class SkillsSection extends StatefulWidget {
  const SkillsSection({super.key, required this.skills});

  final List<SkillItem> skills;

  @override
  State<SkillsSection> createState() => _SkillsSectionState();
}

class _SkillsSectionState extends State<SkillsSection> {
  static const _filters = <SkillKind?>[null, SkillKind.technical, SkillKind.tool, SkillKind.soft];
  static const _filterLabels = ['All', 'Technical', 'Tools', 'Soft skills'];

  SkillKind? _filter; // null = all

  @override
  Widget build(BuildContext context) {
    final visible = _filter == null
        ? widget.skills
        : widget.skills.where((s) => s.kind == _filter).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 4
            : width >= 820
                ? 3
                : width >= 540
                    ? 2
                    : 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'MY SKILL PROFILE',
              subtitle: 'Your acquired skills and current proficiency. '
                  'Verified skills were confirmed by your reporting manager.',
              trailing: Semantics(
                container: true,
                label: 'Filter skills',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _filters.length; i++)
                      _FilterPill(
                        label: _filterLabels[i],
                        selected: _filter == _filters[i],
                        onTap: () => setState(() => _filter = _filters[i]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: HomeMotion.ease,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: visible.isEmpty
                  ? Padding(
                      key: const ValueKey('empty'),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('No skills in this category yet.',
                          style: HomeText.body(15)),
                    )
                  : EqualHeightGrid(
                      key: ValueKey<SkillKind?>(_filter),
                      columns: columns,
                      children: [for (final skill in visible) _SkillCard(skill: skill)],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? HomeColors.ink : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? HomeColors.ink : HomeColors.chipBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: HomeText.body(14,
                      weight: FontWeight.w600,
                      color: selected ? Colors.white : HomeColors.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill});

  final SkillItem skill;

  static const _icons = [Icons.code_rounded, Icons.build_outlined, Icons.groups_outlined];

  @override
  Widget build(BuildContext context) {
    final levelStyle = HomeText.body(13, weight: FontWeight.w600);
    return LiftCard(
      borderColor: HomeColors.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: HomeColors.blueTint,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(_icons[skill.kind.index], size: 20, color: HomeColors.blue),
              ),
              const Spacer(),
              _VerifiedBadge(verified: skill.verified),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            skill.name,
            style: HomeText.body(18, weight: FontWeight.w700, color: HomeColors.ink),
          ),
          const SizedBox(height: 2),
          Text(skill.category, style: HomeText.body(13, color: HomeColors.muted)),
          const Spacer(),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(skill.levelName, style: levelStyle),
              const Spacer(),
              Text('${skill.level} / 5', style: levelStyle),
            ],
          ),
          const SizedBox(height: 8),
          _LevelSegments(level: skill.level),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: verified ? HomeColors.blueTint : HomeColors.neutralTint,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        verified ? 'Verified' : 'Self-assessed',
        style: HomeText.body(12,
            weight: FontWeight.w700,
            color: verified ? HomeColors.blueDeep : HomeColors.body),
      ),
    );
  }
}

/// Five segments that fill one after another as the section is revealed.
class _LevelSegments extends StatelessWidget {
  const _LevelSegments({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final reveal = ScrollReveal.of(context);
    return Semantics(
      label: 'Level $level of 5',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) {
          final filled = reveal.value * level;
          return Row(
            children: [
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: Color.lerp(HomeColors.track, HomeColors.blue,
                          (filled - i).clamp(0.0, 1.0).toDouble()),
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
