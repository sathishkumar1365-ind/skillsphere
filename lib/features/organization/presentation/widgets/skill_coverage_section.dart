import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../home/presentation/widgets/scroll_reveal.dart';
import '../../data/org_models.dart';
import 'org_common.dart';

/// Skill coverage: supply vs project demand per skill (bullet bars), the
/// readiness distribution of all employees, and the verification queue.
class SkillCoverageSection extends StatelessWidget {
  const SkillCoverageSection({
    super.key,
    required this.data,
    required this.onOpenReviewQueue,
  });

  final OrgData data;
  final VoidCallback onOpenReviewQueue;

  static const double _sideWidth = 340;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 980;
        final supply = _SupplyDemandPanel(
          skills: data.skillDemandByShortage,
          compact: (wide ? width - 24 - _sideWidth : width) < 560,
        );
        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReadinessHistogram(bands: data.readinessBands, total: data.headcount),
            const SizedBox(height: 24),
            _VerificationCard(
              pending: data.pendingVerifications,
              onOpen: onOpenReviewQueue,
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'SKILL COVERAGE',
              subtitle: 'How many employees hold each skill compared with what '
                  'current projects need, and how project-ready the workforce is.',
            ),
            const SizedBox(height: 32),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: supply),
                  const SizedBox(width: 24),
                  SizedBox(width: _sideWidth, child: side),
                ],
              )
            else ...[
              supply,
              const SizedBox(height: 24),
              side,
            ],
          ],
        );
      },
    );
  }
}

// ------------------------------------------------- supply vs demand bars

class _SupplyDemandPanel extends StatelessWidget {
  const _SupplyDemandPanel({required this.skills, required this.compact});

  final List<SkillDemand> skills;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scaleMax = skills.fold<int>(1, (m, s) => math.max(m, math.max(s.holders, s.needed)));

    return OrgPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelTitle(
            'Skill supply vs project demand',
            subtitle: 'Largest shortfall first.',
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _LegendKey(kind: _LegendKind.bar, label: 'Employees with the skill'),
              _LegendKey(kind: _LegendKind.tick, label: 'Needed by projects'),
              _LegendKey(kind: _LegendKind.shortfall, label: 'Shortfall'),
            ],
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < skills.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _SupplyRow(skill: skills[i], scaleMax: scaleMax, compact: compact),
          ],
        ],
      ),
    );
  }
}

class _SupplyRow extends StatelessWidget {
  const _SupplyRow({required this.skill, required this.scaleMax, required this.compact});

  final SkillDemand skill;
  final int scaleMax;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final short = skill.shortage > 0;
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(skill.skill,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeText.body(15, weight: FontWeight.w700, color: HomeColors.ink)),
        Text('${skill.holders} have · ${skill.needed} needed',
            style: HomeText.body(12.5, color: HomeColors.muted)),
      ],
    );
    final pill = short
        ? StatusPill(
            label: 'Short by ${skill.shortage}',
            icon: Icons.warning_amber_rounded,
            background: HomeColors.orangeTint,
            foreground: HomeColors.orangeText,
          )
        : const StatusPill(
            label: 'Covered',
            icon: Icons.check_circle_outline_rounded,
            background: OrgColors.goodTint,
            foreground: OrgColors.good,
          );
    final bar = Tooltip(
      message: short
          ? '${skill.skill}: ${skill.holders} employees, ${skill.needed} needed – short by ${skill.shortage}'
          : '${skill.skill}: ${skill.holders} employees, ${skill.needed} needed – covered',
      child: _SupplyBar(
        holders: skill.holders,
        needed: skill.needed,
        scaleMax: scaleMax,
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Expanded(child: name), pill]),
          const SizedBox(height: 8),
          bar,
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 150, child: name),
        const SizedBox(width: 12),
        Expanded(child: bar),
        const SizedBox(width: 16),
        SizedBox(
          width: 118,
          child: Align(alignment: Alignment.centerLeft, child: pill),
        ),
      ],
    );
  }
}

/// Bullet bar: blue = holders, orange band = shortfall up to the ink tick
/// that marks how many are needed. Grows as the section is revealed.
class _SupplyBar extends StatelessWidget {
  const _SupplyBar({required this.holders, required this.needed, required this.scaleMax});

  final int holders;
  final int needed;
  final int scaleMax;

  @override
  Widget build(BuildContext context) {
    final reveal = ScrollReveal.of(context);
    return SizedBox(
      height: 22,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) => CustomPaint(
          painter: _SupplyPainter(
            holders: holders / scaleMax,
            needed: needed / scaleMax,
            progress: reveal.value,
          ),
        ),
      ),
    );
  }
}

class _SupplyPainter extends CustomPainter {
  _SupplyPainter({required this.holders, required this.needed, required this.progress});

  final double holders;
  final double needed;
  final double progress;

  static const double _barHeight = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4) return;
    final top = (size.height - _barHeight) / 2;
    const radius = Radius.circular(4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, top, size.width, _barHeight), radius),
      Paint()..color = HomeColors.gapTrack,
    );

    final have = holders * progress * size.width;
    final need = needed * size.width;

    if (needed > holders) {
      // Shortfall band between what we have and what is needed.
      final bandStart = have;
      final bandEnd = have + (need - holders * size.width) * progress;
      if (bandEnd > bandStart) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(bandStart, top, bandEnd, top + _barHeight), radius),
          Paint()..color = HomeColors.orangeBand,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(bandStart, top, bandEnd, top + _barHeight).deflate(0.75),
              radius),
          Paint()
            ..color = HomeColors.orange
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    if (have > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, top, have, _barHeight), radius),
        Paint()..color = HomeColors.blue,
      );
    }

    // "Needed" tick, fades in with the reveal.
    final x = need.clamp(1.5, size.width - 1.5).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.5, 0, 3, size.height), const Radius.circular(2)),
      Paint()..color = HomeColors.ink.withValues(alpha: progress),
    );
  }

  @override
  bool shouldRepaint(_SupplyPainter oldDelegate) =>
      oldDelegate.holders != holders ||
      oldDelegate.needed != needed ||
      oldDelegate.progress != progress;
}

enum _LegendKind { bar, tick, shortfall }

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.kind, required this.label});

  final _LegendKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Widget swatch = switch (kind) {
      _LegendKind.bar => Container(
          width: 18,
          height: 10,
          decoration: const BoxDecoration(
            color: HomeColors.blue,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
      _LegendKind.tick => Container(
          width: 3,
          height: 16,
          decoration: const BoxDecoration(
            color: HomeColors.ink,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      _LegendKind.shortfall => Container(
          width: 18,
          height: 10,
          decoration: BoxDecoration(
            color: HomeColors.orangeBand,
            border: Border.all(color: HomeColors.orange, width: 1.5),
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
        ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 8),
        Text(label, style: HomeText.body(13)),
      ],
    );
  }
}

// ------------------------------------------------- readiness histogram

/// Employees per readiness band, in the bands' natural order, one hue.
class _ReadinessHistogram extends StatelessWidget {
  const _ReadinessHistogram({required this.bands, required this.total});

  final List<int> bands;
  final int total;

  static const double _plotHeight = 150;

  @override
  Widget build(BuildContext context) {
    final reveal = ScrollReveal.of(context);
    final largest = bands.fold<int>(1, math.max);
    const labels = OrgData.readinessBandLabels;

    return OrgPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitle('Readiness distribution', subtitle: '$total employees by project readiness'),
          const SizedBox(height: 20),
          SizedBox(
            height: _plotHeight + 26,
            child: AnimatedBuilder(
              animation: reveal,
              builder: (context, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < bands.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: Tooltip(
                        message: '${labels[i]} ready: ${bands[i]} '
                            '${bands[i] == 1 ? 'employee' : 'employees'}',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${bands[i]}',
                                style: HomeText.body(14,
                                    weight: FontWeight.w800, color: HomeColors.ink)),
                            const SizedBox(height: 6),
                            Container(
                              height: math.max(
                                  4.0, _plotHeight * bands[i] / largest * reveal.value),
                              decoration: const BoxDecoration(
                                color: HomeColors.blue,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: HomeColors.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Text(labels[i],
                      textAlign: TextAlign.center,
                      style: HomeText.body(12, weight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------- verification queue

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.pending, required this.onOpen});

  final int pending;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return LiftCard(
      color: HomeColors.ink,
      radius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VERIFICATION QUEUE',
            style: HomeText.body(12.5,
                weight: FontWeight.w800, color: HomeColors.onInkMuted, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          CountUpText(pending,
              style: HomeText.display(48, height: 1.0, color: HomeColors.peach)),
          const SizedBox(height: 8),
          Text(
            'Skill updates waiting for a Team Lead to verify the level.',
            style: HomeText.body(14, color: HomeColors.onInk, height: 1.5),
          ),
          const SizedBox(height: 18),
          PillButton(
            label: 'Open review queue',
            onPressed: onOpen,
            variant: PillVariant.light,
            height: 46,
          ),
        ],
      ),
    );
  }
}
