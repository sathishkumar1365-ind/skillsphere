import 'package:flutter/material.dart';

import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/scroll_reveal.dart';
import '../../data/competency_models.dart';

/// Icon and colours for each competency category. Colour is never the only
/// signal: every badge and pill also shows the category's icon or name.
class CategoryStyle {
  const CategoryStyle({
    required this.icon,
    required this.tint,
    required this.foreground,
    required this.light,
    required this.dark,
  });

  final IconData icon;

  /// Pill background and text colour.
  final Color tint;
  final Color foreground;

  /// Gradient of the lettered badge.
  final Color light;
  final Color dark;

  static CategoryStyle of(CompetencyCategory category) => switch (category) {
        CompetencyCategory.skill => const CategoryStyle(
            icon: Icons.lightbulb_outline_rounded,
            tint: HomeColors.blueTint,
            foreground: HomeColors.blueDeep,
            light: Color(0xFF3C7BE8),
            dark: HomeColors.blueDeep,
          ),
        CompetencyCategory.tool => const CategoryStyle(
            icon: Icons.handyman_outlined,
            tint: Color(0xFFE2F3F1),
            foreground: Color(0xFF0B5F57),
            light: Color(0xFF1C9A8E),
            dark: Color(0xFF0B5F57),
          ),
        CompetencyCategory.language => const CategoryStyle(
            icon: Icons.code_rounded,
            tint: Color(0xFFEEEAFD),
            foreground: Color(0xFF4128A3),
            light: Color(0xFF7657E0),
            dark: Color(0xFF4128A3),
          ),
        CompetencyCategory.domain => const CategoryStyle(
            icon: Icons.business_center_outlined,
            tint: HomeColors.neutralTint,
            foreground: HomeColors.ink,
            light: Color(0xFF4A5D78),
            dark: HomeColors.ink,
          ),
      };
}

/// The competency's logo, or a lettered 3D tile when there is no logo (or
/// the logo link can't be loaded).
class CompetencyBadge extends StatelessWidget {
  const CompetencyBadge({
    super.key,
    required this.name,
    required this.category,
    this.logoUrl,
    this.size = 48,
  });

  CompetencyBadge.of(Competency competency, {Key? key, double size = 48})
      : this(
          key: key,
          name: competency.name,
          category: competency.category,
          logoUrl: competency.logoUrl,
          size: size,
        );

  final String name;
  final CompetencyCategory category;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final link = logoUrl?.trim() ?? '';
    final radius = BorderRadius.circular(size * 0.28);
    final monogram = _Monogram(name: name, category: category, size: size, radius: radius);
    if (link.isEmpty) return monogram;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: HomeColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 27, 45, 0.16),
            blurRadius: 14,
            spreadRadius: -6,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Image.network(
        link,
        fit: BoxFit.contain,
        // Many logo hosts don't send CORS headers; on the web this falls
        // back to a plain <img> element so the logo still shows.
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        semanticLabel: '$name logo',
        errorBuilder: (context, error, stackTrace) => FittedBox(child: monogram),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({
    required this.name,
    required this.category,
    required this.size,
    required this.radius,
  });

  final String name;
  final CompetencyCategory category;
  final double size;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category);
    final letters = Competency.monogramFor(name.isEmpty ? '?' : name);
    return Semantics(
      label: '$name, ${category.label}',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: radius,
          // Light-to-dark gradient plus a soft coloured drop shadow make the
          // tile read as a raised 3D block.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [style.light, style.dark],
          ),
          boxShadow: [
            BoxShadow(
              color: style.dark.withValues(alpha: 0.35),
              blurRadius: size * 0.3,
              spreadRadius: -size * 0.12,
              offset: Offset(0, size * 0.14),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              letters,
              style: HomeText.display(size * 0.42, color: Colors.white, height: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}

/// "</> Language" style label.
class CategoryPill extends StatelessWidget {
  const CategoryPill(this.category, {super.key, this.dense = false});

  final CompetencyCategory category;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: dense ? 13 : 14, color: style.foreground),
          const SizedBox(width: 5),
          Text(
            category.label,
            style: HomeText.body(dense ? 11.5 : 12,
                weight: FontWeight.w700, color: style.foreground),
          ),
        ],
      ),
    );
  }
}

/// "L3 · Proficient"
class LevelPill extends StatelessWidget {
  const LevelPill(this.level, {super.key});

  final int level;

  @override
  Widget build(BuildContext context) {
    final strong = level >= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: strong ? HomeColors.ink : HomeColors.blueTint,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        CompetencyLevel.short(level),
        maxLines: 1,
        style: HomeText.body(12,
            weight: FontWeight.w700, color: strong ? Colors.white : HomeColors.blueDeep),
      ),
    );
  }
}

/// Six segments (Level 0–5). Level N fills N+1 segments, so a Level 0
/// Beginner still shows a first step. Fills as the section is revealed.
class LevelSteps extends StatelessWidget {
  const LevelSteps({super.key, required this.level, this.height = 6, this.gap = 3});

  final int level;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final reveal = ScrollReveal.of(context);
    return Semantics(
      label: 'Level $level of ${CompetencyLevel.max}',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) {
          final filled = reveal.value * (level + 1);
          return Row(
            children: [
              for (var i = 0; i < CompetencyLevel.count; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: Color.lerp(HomeColors.track, HomeColors.blue,
                          (filled - i).clamp(0.0, 1.0).toDouble()),
                      borderRadius: BorderRadius.circular(height / 2),
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

/// Colour of a level's number block: light for Level 0, deep blue for 5.
Color levelBlockColor(int level) =>
    Color.lerp(HomeColors.blueTint, HomeColors.blueDeep, level / CompetencyLevel.max)!;

Color levelBlockText(int level) => level >= 2 ? Colors.white : HomeColors.blueDeep;

/// Rounded search field used by the competency library.
class CompetencySearchField extends StatelessWidget {
  const CompetencySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hint = 'Search competencies…',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hint;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(999)),
      borderSide: BorderSide(color: HomeColors.chipBorder),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: HomeText.body(15, color: HomeColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: HomeText.body(15, color: HomeColors.muted),
        prefixIcon: const Icon(Icons.search_rounded, color: HomeColors.muted),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                ),
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: HomeColors.ink, width: 1.5),
        ),
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "14 Nov 2026"
String formatDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';
