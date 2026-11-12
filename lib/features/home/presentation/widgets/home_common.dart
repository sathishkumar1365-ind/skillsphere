import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../home_theme.dart';
import 'scroll_reveal.dart';

/// The SkillSphere globe mark (a circle crossed by two ellipses).
class SphereMark extends StatelessWidget {
  const SphereMark({super.key, this.size = 30, this.color = HomeColors.ink});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SphereMarkPainter(color));
  }
}

class _SphereMarkPainter extends CustomPainter {
  _SphereMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 32;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * unit;
    canvas.drawCircle(center, 13 * unit, paint);
    canvas.drawOval(
        Rect.fromCenter(center: center, width: 26 * unit, height: 10 * unit), paint);
    canvas.drawOval(
        Rect.fromCenter(center: center, width: 10 * unit, height: 26 * unit), paint);
  }

  @override
  bool shouldRepaint(_SphereMarkPainter oldDelegate) => oldDelegate.color != color;
}

/// Section title (Anton) with a short explanation, and optional controls
/// on the right that wrap underneath on narrow screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 600;
    final heading = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: HomeText.display(narrow ? 38 : 48, height: 1.0)),
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: HomeText.body(16, height: 1.6)),
        ],
      ),
    );
    final extra = trailing;
    if (extra == null) return heading;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 20,
      runSpacing: 20,
      children: [heading, extra],
    );
  }
}

/// Lays children out in [columns] equal-width columns where every card in a
/// row gets the height of the tallest one.
///
/// Children must not contain a LayoutBuilder (it can't report its height
/// in advance).
class EqualHeightGrid extends StatelessWidget {
  const EqualHeightGrid({
    super.key,
    required this.columns,
    required this.children,
    this.spacing = 20,
    this.runSpacing = 20,
  });

  final int columns;
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final perRow = math.max(1, columns);
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += perRow) {
      final cells = <Widget>[];
      for (var c = 0; c < perRow; c++) {
        if (c > 0) cells.add(SizedBox(width: spacing));
        final index = start + c;
        cells.add(Expanded(
          child: index < children.length ? children[index] : const SizedBox.shrink(),
        ));
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing));
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// Raises its child by a couple of pixels with a soft shadow on hover.
class HoverRaise extends StatefulWidget {
  const HoverRaise({super.key, required this.child, this.distance = 2});

  final Widget child;
  final double distance;

  @override
  State<HoverRaise> createState() => _HoverRaiseState();
}

class _HoverRaiseState extends State<HoverRaise> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -widget.distance : 0, 0),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          boxShadow: _hovered
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(15, 27, 45, 0.45),
                    blurRadius: 20,
                    spreadRadius: -10,
                    offset: Offset(0, 10),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: widget.child,
      ),
    );
  }
}

enum PillVariant {
  /// Ink-black with white text (like the login's Sign In button).
  primary,

  /// White with an ink outline.
  outline,

  /// White with ink text, for dark backgrounds.
  light,
}

/// Rounded "pill" button used across the Home page.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillVariant.primary,
    this.height = 52,
    this.fontSize = 15,
    this.horizontalPadding = 26,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillVariant variant;
  final double height;
  final double fontSize;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder();
    final padding = EdgeInsets.symmetric(horizontal: horizontalPadding);
    final minimumSize = Size(0, height);
    final textStyle = HomeText.body(fontSize, weight: FontWeight.w700);

    final Widget button;
    if (variant == PillVariant.outline) {
      button = OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: HomeColors.ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: HomeColors.ink, width: 1.5),
          shape: shape,
          padding: padding,
          minimumSize: minimumSize,
          textStyle: textStyle,
        ),
        child: Text(label),
      );
    } else {
      final primary = variant == PillVariant.primary;
      button = ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary ? HomeColors.ink : Colors.white,
          foregroundColor: primary ? Colors.white : HomeColors.ink,
          shape: shape,
          padding: padding,
          minimumSize: minimumSize,
          textStyle: textStyle,
        ),
        child: Text(label),
      );
    }
    return HoverRaise(child: button);
  }
}

/// A rounded outline drawn in dashes (used for skill-gap chips).
class DashedOutline extends StatelessWidget {
  const DashedOutline({
    super.key,
    required this.child,
    required this.color,
    this.radius = 999,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final r = math.min(radius, math.min(rect.width, rect.height) / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}

/// A number that counts up from 0 as its section is revealed.
class CountUpText extends StatelessWidget {
  const CountUpText(this.value, {super.key, required this.style, this.suffix = ''});

  final int value;
  final TextStyle style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final reveal = ScrollReveal.of(context);
    return Semantics(
      label: '$value$suffix',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) =>
            Text('${(value * reveal.value).round()}$suffix', style: style),
      ),
    );
  }
}
