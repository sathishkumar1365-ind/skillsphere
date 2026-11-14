import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../home/presentation/widgets/scroll_reveal.dart';
import '../../data/org_models.dart';

/// Status colours. Each status always ships with an icon and a label,
/// never colour alone.
class OrgColors {
  OrgColors._();

  static const good = Color(0xFF1C7A4D);
  static const goodTint = Color(0xFFE5F4EC);
}

/// A headline number with a label (KPI tile). Counts up as its section
/// is revealed and lifts in 3D on hover.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.value,
    required this.label,
    this.suffix = '',
    this.caption,
    this.dark = false,
  });

  final int value;
  final String label;
  final String suffix;
  final String? caption;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final note = caption;
    return LiftCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      color: dark ? HomeColors.ink : const Color.fromRGBO(255, 255, 255, 0.86),
      borderColor: dark ? null : const Color.fromRGBO(255, 255, 255, 0.95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CountUpText(
            value,
            suffix: suffix,
            style: HomeText.display(44,
                height: 1.0, color: dark ? HomeColors.peach : HomeColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: HomeText.body(14,
                weight: FontWeight.w600, color: dark ? HomeColors.onInk : HomeColors.body),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: HomeText.body(12.5,
                  color: dark ? HomeColors.onInkMuted : HomeColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal meter (a value against its whole) that fills as its section
/// is revealed. [value] and [marker] are fractions from 0 to 1.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    this.marker,
    this.color = HomeColors.blue,
    this.height = 8,
  });

  final double value;

  /// Optional target tick (for example "needed by projects").
  final double? marker;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final reveal = ScrollReveal.of(context);
    return SizedBox(
      height: marker == null ? height : height + 8,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) => CustomPaint(
          painter: _MeterPainter(
            value: value * reveal.value,
            marker: marker,
            color: color,
            barHeight: height,
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({
    required this.value,
    required this.marker,
    required this.color,
    required this.barHeight,
  });

  final double value;
  final double? marker;
  final Color color;
  final double barHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - barHeight) / 2;
    final radius = Radius.circular(math.min(4, barHeight / 2));
    final track = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, barHeight), radius);
    canvas.drawRRect(track, Paint()..color = HomeColors.track);

    final fill = value.clamp(0.0, 1.0).toDouble() * size.width;
    if (fill > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, top, fill, barHeight), radius),
        Paint()..color = color,
      );
    }

    final target = marker;
    if (target != null) {
      final x = target.clamp(0.0, 1.0).toDouble() * size.width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 1.5, 0, 3, size.height), const Radius.circular(2)),
        Paint()..color = HomeColors.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_MeterPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.marker != marker ||
      oldDelegate.color != color ||
      oldDelegate.barHeight != barHeight;
}

/// Small rounded label with an optional leading icon.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  factory StatusPill.employee(EmployeeStatus status) => switch (status) {
        EmployeeStatus.allocated => StatusPill(
            label: status.label,
            icon: Icons.work_outline_rounded,
            background: HomeColors.blueTint,
            foreground: HomeColors.blueDeep,
          ),
        EmployeeStatus.available => StatusPill(
            label: status.label,
            icon: Icons.check_circle_outline_rounded,
            background: OrgColors.goodTint,
            foreground: OrgColors.good,
          ),
        EmployeeStatus.onLeave => StatusPill(
            label: status.label,
            icon: Icons.beach_access_outlined,
            background: HomeColors.neutralTint,
            foreground: HomeColors.body,
          ),
      };

  factory StatusPill.project(ProjectHealth health) => switch (health) {
        ProjectHealth.onTrack => StatusPill(
            label: health.label,
            icon: Icons.check_circle_outline_rounded,
            background: OrgColors.goodTint,
            foreground: OrgColors.good,
          ),
        ProjectHealth.atRisk => StatusPill(
            label: health.label,
            icon: Icons.warning_amber_rounded,
            background: HomeColors.orangeTint,
            foreground: HomeColors.orangeText,
          ),
        ProjectHealth.staffing => StatusPill(
            label: health.label,
            icon: Icons.person_add_alt_outlined,
            background: HomeColors.blueTint,
            foreground: HomeColors.blueDeep,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final leading = icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            Icon(leading, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.body(12, weight: FontWeight.w700, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round avatar with initials.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.initials, this.size = 40});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: HomeColors.blueTint, shape: BoxShape.circle),
      child: Text(
        initials,
        style: HomeText.body(size * 0.34, weight: FontWeight.w800, color: HomeColors.blueDeep),
      ),
    );
  }
}

/// Selectable filter pill (same look as the skill filters on the Home page).
class OrgFilterPill extends StatelessWidget {
  const OrgFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? HomeColors.ink : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? HomeColors.ink : HomeColors.chipBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: HomeText.body(13.5,
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

/// White rounded panel used for charts and tables (no hover lift).
class OrgPanel extends StatelessWidget {
  const OrgPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: child,
    );
  }
}

/// Small uppercase label above a chart or panel.
class PanelTitle extends StatelessWidget {
  const PanelTitle(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            text.toUpperCase(),
            style: HomeText.body(12.5,
                weight: FontWeight.w800, color: HomeColors.ink, letterSpacing: 1.2),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub, style: HomeText.body(13.5, color: HomeColors.muted, height: 1.45)),
        ],
      ],
    );
  }
}
