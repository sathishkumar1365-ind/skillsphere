// Shared building blocks for the HRD console: form fields, pickers, 3D
// panels and dialogs, mode switches and status notes. Same "Sky Sphere"
// look as the rest of SkillSphere (ink pills, Anton headlines, white cards).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../competency/data/competency_models.dart';
import '../../../competency/presentation/widgets/competency_common.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/smooth_wheel_scroll.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/admin_base.dart';
import '../../data/employees.dart';

// ================================================================ fields

final TextStyle adminInputStyle = HomeText.body(15, color: HomeColors.ink, height: 1.4);

InputDecoration adminDecoration({
  String? hint,
  String? helper,
  String? errorText,
  bool counter = false,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool enabled = true,
}) {
  const radius = BorderRadius.all(Radius.circular(14));
  return InputDecoration(
    hintText: hint,
    hintStyle: HomeText.body(14.5, color: HomeColors.muted),
    helperText: helper,
    helperMaxLines: 3,
    helperStyle: HomeText.body(12.5, color: HomeColors.muted),
    errorText: errorText,
    errorMaxLines: 3,
    errorStyle: HomeText.body(12.5, weight: FontWeight.w600, color: AppColors.error),
    counterText: counter ? null : '',
    counterStyle: HomeText.body(12, color: HomeColors.muted),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    enabled: enabled,
    filled: true,
    fillColor: enabled ? const Color(0xFFF4F8FC) : const Color(0xFFEEF1F5),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomeColors.cardBorder),
    ),
    disabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomeColors.cardBorder),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomeColors.ink, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.error, width: 1.5),
    ),
  );
}

/// Bold label above a field. "*" marks required fields; a lock shows when
/// the signed-in user may not change the field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(
    this.text, {
    super.key,
    this.required = false,
    this.optional = false,
    this.locked = false,
    this.lockedReason,
  });

  final String text;
  final bool required;
  final bool optional;
  final bool locked;
  final String? lockedReason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                text: text,
                children: [
                  if (required)
                    const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
                  if (optional)
                    TextSpan(
                      text: '  (optional)',
                      style: HomeText.body(12.5, weight: FontWeight.w500, color: HomeColors.muted),
                    ),
                ],
              ),
              style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink),
            ),
          ),
          if (locked) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: lockedReason ?? 'You can\'t change this',
              child: const Icon(Icons.lock_outline_rounded, size: 15, color: HomeColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// A label + field pair laid out in [FieldGrid].
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.optional = false,
    this.locked = false,
    this.lockedReason,
  });

  final String label;
  final Widget child;
  final bool required;
  final bool optional;
  final bool locked;
  final String? lockedReason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, required: required, optional: optional, locked: locked, lockedReason: lockedReason),
        child,
      ],
    );
  }
}

/// Fields in 1–3 columns depending on the available width.
class FieldGrid extends StatelessWidget {
  const FieldGrid({super.key, required this.children, this.maxColumns = 2, this.minFieldWidth = 260});

  final List<Widget> children;
  final int maxColumns;
  final double minFieldWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final width = constraints.maxWidth;
        final fit = ((width + gap) / (minFieldWidth + gap)).floor();
        var columns = fit < 1 ? 1 : (fit > maxColumns ? maxColumns : fit);
        if (children.length < columns) columns = math.max(1, children.length);
        final fieldWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 18,
          children: [for (final c in children) SizedBox(width: fieldWidth, child: c)],
        );
      },
    );
  }
}

class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(text, style: HomeText.body(12.5, weight: FontWeight.w600, color: AppColors.error)),
      ),
    );
  }
}

/// A drop-down that looks like the other fields. Values are compared with
/// == (use ids, not objects).
class AdminDropdown<T> extends StatelessWidget {
  const AdminDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.hint = 'Choose…',
    this.errorText,
    this.disabledText,
  });

  final T? value;
  final List<T> items;
  final String Function(T item) labelOf;

  /// Null disables the field.
  final ValueChanged<T>? onChanged;
  final String hint;
  final String? errorText;

  /// Shown instead of the hint while disabled with no value.
  final String? disabledText;

  @override
  Widget build(BuildContext context) {
    final current = value;
    final T? selected = current != null && items.contains(current) ? current : null;
    final change = onChanged;
    final enabled = change != null;
    return InputDecorator(
      decoration: adminDecoration(errorText: errorText, enabled: enabled).copyWith(
        contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selected,
          isExpanded: true,
          isDense: false,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          dropdownColor: Colors.white,
          menuMaxHeight: 380,
          style: adminInputStyle,
          icon: const Icon(Icons.expand_more_rounded, color: HomeColors.ink),
          hint: Text(hint,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: HomeText.body(14.5, color: HomeColors.muted)),
          disabledHint: Text(
            selected != null ? labelOf(selected) : (disabledText ?? hint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeText.body(14.5, color: selected != null ? HomeColors.body : HomeColors.muted),
          ),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(labelOf(item), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: change == null
              ? null
              : (T? v) {
                  if (v != null) change(v);
                },
        ),
      ),
    );
  }
}

/// A row of selectable pills for a short list of options.
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T? selected;
  final String Function(T option) labelOf;

  /// Null makes the pills read-only.
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final select = onSelected;
    return Opacity(
      opacity: select == null ? 0.6 : 1,
      child: IgnorePointer(
        ignoring: select == null,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              OrgFilterPill(
                label: labelOf(o),
                selected: o == selected,
                onTap: () => select?.call(o),
              ),
          ],
        ),
      ),
    );
  }
}

/// A date shown like a field; tap to pick.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Choose a date',
    this.errorText,
    this.firstDate,
    this.lastDate,
    this.clearable = false,
  });

  final DateTime? value;

  /// Null disables the field.
  final ValueChanged<DateTime?>? onChanged;
  final String hint;
  final String? errorText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool clearable;

  Future<void> _pick(BuildContext context) async {
    final change = onChanged;
    if (change == null) return;
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 30);
    final last = lastDate ?? DateTime(now.year + 10);
    var initial = value ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) change(picked);
  }

  @override
  Widget build(BuildContext context) {
    final date = value;
    final enabled = onChanged != null;
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InputDecorator(
        decoration: adminDecoration(
          errorText: errorText,
          enabled: enabled,
          suffixIcon: clearable && date != null && enabled
              ? IconButton(
                  tooltip: 'Clear date',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => onChanged?.call(null),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18, color: HomeColors.ink),
        ),
        child: Text(
          date == null ? hint : dayMonthYear(date),
          style: date == null ? HomeText.body(14.5, color: HomeColors.muted) : adminInputStyle,
        ),
      ),
    );
  }
}

// =========================================================== level picker

/// Level 0–5 as six raised blocks. Levels below [minLevel] are disabled
/// (e.g. a Team Lead can only ask for a higher level).
class LevelPicker extends StatelessWidget {
  const LevelPicker({
    super.key,
    required this.level,
    required this.onChanged,
    this.minLevel = 0,
    this.compact = false,
  });

  final int? level;
  final ValueChanged<int>? onChanged;
  final int minLevel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final current = level;
    final size = compact ? 30.0 : 36.0;
    return Semantics(
      label: current == null ? 'Level not set' : 'Level $current, ${CompetencyLevel.name(current)}',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var l = CompetencyLevel.min; l <= CompetencyLevel.max; l++)
            _LevelBlock(
              level: l,
              size: size,
              selected: current == l,
              filled: current != null && l <= current,
              enabled: onChanged != null && l >= minLevel,
              onTap: () => onChanged?.call(l),
            ),
          if (!compact && current != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(CompetencyLevel.name(current),
                  style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.ink)),
            ),
        ],
      ),
    );
  }
}

class _LevelBlock extends StatefulWidget {
  const _LevelBlock({
    required this.level,
    required this.size,
    required this.selected,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  final int level;
  final double size;
  final bool selected;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_LevelBlock> createState() => _LevelBlockState();
}

class _LevelBlockState extends State<_LevelBlock> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.level;
    final color = widget.filled ? levelBlockColor(l) : Colors.white;
    final text = widget.filled ? levelBlockText(l) : (widget.enabled ? HomeColors.ink : HomeColors.muted);
    final lift = widget.selected ? 1.0 : (_hover && widget.enabled ? 0.6 : 0.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Tooltip(
      message: 'L$l · ${CompetencyLevel.name(l)}',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: lift),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
            curve: HomeMotion.ease,
            builder: (context, t, child) {
              final matrix = t == 0
                  ? Matrix4.identity()
                  : (Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
                    ..multiply(Matrix4.translationValues(0, -4 * t, 0))
                    ..multiply(Matrix4.rotationX(-0.35 * t)));
              return Transform(
                alignment: Alignment.bottomCenter,
                transform: matrix,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.enabled ? color : const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(widget.size * 0.3),
                    border: Border.all(
                      color: widget.selected
                          ? HomeColors.ink
                          : (widget.filled ? Colors.transparent : HomeColors.chipBorder),
                      width: widget.selected ? 2 : 1,
                    ),
                    boxShadow: t == 0
                        ? null
                        : [
                            BoxShadow(
                              color: Color.fromRGBO(15, 27, 45, 0.30 * t),
                              blurRadius: 12,
                              spreadRadius: -4,
                              offset: Offset(0, 6 * t),
                            ),
                          ],
                  ),
                  child: Text('$l', style: HomeText.body(widget.size * 0.4, weight: FontWeight.w800, color: text)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ========================================================== layout bits

/// A white panel with a numbered 3D badge, title and subtitle.
class StepPanel extends StatelessWidget {
  const StepPanel({
    super.key,
    required this.title,
    required this.child,
    this.number,
    this.icon,
    this.subtitle,
    this.trailing,
  });

  final int? number;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final extra = trailing;
    return OrgPanel(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BadgeTile(number: number, icon: icon),
              const SizedBox(width: 14),
              Expanded(child: PanelTitle(title, subtitle: subtitle)),
              if (extra != null) ...[const SizedBox(width: 12), extra],
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({this.number, this.icon});

  final int? number;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C7BE8), HomeColors.ink],
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(15, 27, 45, 0.35),
            blurRadius: 14,
            spreadRadius: -6,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: glyph != null
          ? Icon(glyph, color: Colors.white, size: 20)
          : Text('${number ?? ''}', style: HomeText.display(20, color: Colors.white, height: 1)),
    );
  }
}

/// One option of a [ModeSwitch].
class ModeOption<T> {
  const ModeOption(this.value, this.label, this.icon, {this.badge});

  final T value;
  final String label;
  final IconData icon;

  /// Small count shown next to the label (e.g. pending items).
  final int? badge;
}

const double _modePadding = 4;
const double _modeBorder = 1;

/// Pill switch with a sliding ink highlight (2–5 options).
class ModeSwitch<T> extends StatelessWidget {
  const ModeSwitch({super.key, required this.options, required this.selected, required this.onChanged});

  final List<ModeOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final index = math.max(0, options.indexWhere((o) => o.value == selected));
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(0.0, math.min(constraints.maxWidth, 180.0 * options.length));
        // Inner width = width minus the 4px padding AND the 1px border on
        // each side (the border was missed before: 2px overflow). Never
        // negative, however narrow the window gets.
        const inset = _modePadding + _modeBorder;
        final optionWidth = math.max(0.0, (width - inset * 2) / options.length);
        final showIcons = optionWidth >= 128;
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: width,
            height: 52,
            padding: const EdgeInsets.all(_modePadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              border: Border.all(color: HomeColors.chipBorder, width: _modeBorder),
            ),
            // expand + stretch: every option fills the pill's full height,
            // so its label is centred vertically (a loose Stack let the row
            // shrink to the text height and sit at the top).
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedPositioned(
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 380),
                  curve: HomeMotion.ease,
                  left: optionWidth * index,
                  top: 0,
                  bottom: 0,
                  width: optionWidth,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: HomeColors.ink,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final o in options)
                      SizedBox(
                        width: optionWidth,
                        child: _ModeButton(
                          option: o,
                          selected: o.value == selected,
                          showIcon: showIcons,
                          onTap: () => onChanged(o.value),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeButton<T> extends StatelessWidget {
  const _ModeButton({required this.option, required this.selected, required this.showIcon, required this.onTap});

  final ModeOption<T> option;
  final bool selected;
  final bool showIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : HomeColors.ink;
    final badge = option.badge;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showIcon) ...[
                  Icon(option.icon, size: 18, color: color),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: HomeText.body(13.5, weight: FontWeight.w700, color: color),
                    child: Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (badge != null && badge > 0) ...[
                  const SizedBox(width: 6),
                  CountBadge(count: badge, inverted: selected),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded count, orange (needs attention).
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.inverted = false});

  final int count;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: inverted ? Colors.white : HomeColors.orange,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: HomeText.body(11.5, weight: FontWeight.w800, color: inverted ? HomeColors.orangeText : Colors.white),
      ),
    );
  }
}

/// "NEW" label for items added in this session.
class NewLabel extends StatelessWidget {
  const NewLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: const BoxDecoration(
        color: HomeColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Text('NEW', style: HomeText.body(10.5, weight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
    );
  }
}

enum NoteTone { info, warning, success, error }

/// A tinted note with an icon (never colour alone).
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text, this.tone = NoteTone.info, this.icon, this.action});

  final String text;
  final NoteTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color border, Color foreground, IconData defaultIcon) = switch (tone) {
      NoteTone.info => (HomeColors.blueTint, const Color(0xFFC9DBF6), HomeColors.blueDeep, Icons.info_outline_rounded),
      NoteTone.warning => (HomeColors.orangeTint, HomeColors.orangeBand, HomeColors.orangeText, Icons.warning_amber_rounded),
      NoteTone.success => (OrgColors.goodTint, const Color(0xFFBFE3CF), OrgColors.good, Icons.check_circle_outline_rounded),
      NoteTone.error => (const Color(0xFFFDECEC), const Color(0xFFF5C2C3), const Color(0xFFB4232A), Icons.error_outline_rounded),
    };
    final extra = action;
    return Semantics(
      liveRegion: tone == NoteTone.error || tone == NoteTone.success,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, size: 19, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: HomeText.body(13.5, color: HomeColors.ink, height: 1.45)),
                  if (extra != null) ...[const SizedBox(height: 8), extra],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty list message.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon = Icons.inbox_outlined});

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final body = message;
    return OrgPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Icon(icon, size: 34, color: HomeColors.muted),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center,
              style: HomeText.body(16, weight: FontWeight.w700, color: HomeColors.ink)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: HomeText.body(14, color: HomeColors.muted, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// Small "label: value" pair used in detail grids.
class DetailItem extends StatelessWidget {
  const DetailItem({super.key, required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (glyph != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(glyph, size: 18, color: HomeColors.muted),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: HomeText.body(11, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.9)),
              const SizedBox(height: 3),
              Text(value.isEmpty ? '—' : value,
                  style: HomeText.body(14.5, weight: FontWeight.w600, color: HomeColors.ink, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}

void showAdminMessage(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, action: action));
}

/// Small search box (rounded, with clear button).
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search…',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return CompetencySearchField(
      controller: controller,
      hint: hint,
      onChanged: onChanged,
      onClear: () {
        controller.clear();
        onChanged('');
      },
    );
  }
}

// ======================================================= people pickers

/// Avatar + name + one line of detail.
class PersonLine extends StatelessWidget {
  const PersonLine({super.key, required this.profile, this.detail, this.size = 36, this.trailing});

  final EmployeeProfile profile;
  final String? detail;
  final double size;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final extra = trailing;
    return Row(
      children: [
        InitialsAvatar(initials: profile.initials, size: size),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink)),
              Text(detail ?? '${profile.id} · ${profile.designation}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.body(12.5, color: HomeColors.muted)),
            ],
          ),
        ),
        if (extra != null) ...[const SizedBox(width: 8), extra],
      ],
    );
  }
}

/// Search box that suggests employees; [onPicked] gets the chosen one.
class EmployeeSearchBox extends StatefulWidget {
  const EmployeeSearchBox({
    super.key,
    required this.options,
    required this.onPicked,
    this.hint = 'Search name or employee ID…',
    this.errorText,
    this.detailOf,
  });

  final List<EmployeeProfile> options;
  final ValueChanged<EmployeeProfile> onPicked;
  final String hint;
  final String? errorText;
  final String Function(EmployeeProfile e)? detailOf;

  @override
  State<EmployeeSearchBox> createState() => _EmployeeSearchBoxState();
}

class _EmployeeSearchBoxState extends State<EmployeeSearchBox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Iterable<EmployeeProfile> _search(TextEditingValue value) {
    final q = value.text.trim().toLowerCase();
    final list = widget.options;
    if (q.isEmpty) return list.take(8);
    return list
        .where((e) => '${e.id} ${e.name} ${e.designation} ${e.email}'.toLowerCase().contains(q))
        .take(12);
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<EmployeeProfile>(
      textEditingController: _controller,
      focusNode: _focus,
      optionsBuilder: _search,
      displayStringForOption: (e) => e.name,
      onSelected: (e) {
        widget.onPicked(e);
        // Ready for the next search (multi-select) or replaced by a chip.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _controller.clear();
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        style: adminInputStyle,
        onSubmitted: (_) => onSubmitted(),
        decoration: adminDecoration(
          hint: widget.hint,
          errorText: widget.errorText,
          prefixIcon: const Icon(Icons.person_search_outlined, color: HomeColors.muted),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: Colors.white,
            elevation: 10,
            shadowColor: const Color.fromRGBO(15, 27, 45, 0.25),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: [
                  for (final e in options)
                    InkWell(
                      onTap: () => onSelected(e),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: PersonLine(profile: e, size: 32, detail: widget.detailOf?.call(e)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Picks one employee (shows a chip once chosen).
class EmployeePickerField extends StatelessWidget {
  const EmployeePickerField({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.hint = 'Search name or employee ID…',
    this.errorText,
    this.emptyLabel,
  });

  final List<EmployeeProfile> options;
  final EmployeeProfile? selected;

  /// Null makes the field read-only.
  final ValueChanged<String?>? onChanged;
  final String hint;
  final String? errorText;

  /// Shown read-only when nothing is selected (e.g. "Delivery Head").
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final person = selected;
    final change = onChanged;
    if (person != null || change == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
            decoration: BoxDecoration(
              color: change == null ? const Color(0xFFEEF1F5) : const Color(0xFFF4F8FC),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: errorText == null ? HomeColors.cardBorder : AppColors.error),
            ),
            child: person == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text(emptyLabel ?? '—', style: adminInputStyle),
                  )
                : PersonLine(
                    profile: person,
                    size: 32,
                    trailing: change == null
                        ? null
                        : IconButton(
                            tooltip: 'Change',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => change(null),
                          ),
                  ),
          ),
          if (errorText != null) FieldError(errorText!),
        ],
      );
    }
    return EmployeeSearchBox(
      options: options,
      hint: emptyLabel == null ? hint : '$hint (now: $emptyLabel)',
      errorText: errorText,
      onPicked: (e) => change(e.id),
    );
  }
}

/// Picks several employees (chips + search).
class EmployeeMultiPicker extends StatelessWidget {
  const EmployeeMultiPicker({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
    this.hint = 'Add people: search name or ID…',
    this.lookup,
  });

  final List<EmployeeProfile> options;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  final String hint;

  /// Finds a selected employee by id (defaults to [options]).
  final EmployeeProfile? Function(String id)? lookup;

  @override
  Widget build(BuildContext context) {
    EmployeeProfile? find(String id) {
      final custom = lookup;
      if (custom != null) return custom(id);
      for (final e in options) {
        if (e.id == id) return e;
      }
      return null;
    }

    final remaining = options.where((e) => !selectedIds.contains(e.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmployeeSearchBox(
          options: remaining,
          hint: hint,
          onPicked: (e) => onChanged([...selectedIds, e.id]),
        ),
        if (selectedIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in selectedIds)
                InputChip(
                  avatar: CircleAvatar(
                    backgroundColor: HomeColors.blueTint,
                    child: Text(find(id)?.initials ?? '?',
                        style: HomeText.body(10, weight: FontWeight.w800, color: HomeColors.blueDeep)),
                  ),
                  label: Text(find(id)?.name ?? id),
                  labelStyle: HomeText.body(13, weight: FontWeight.w600, color: HomeColors.ink),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: HomeColors.chipBorder),
                  shape: const StadiumBorder(),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted: () => onChanged(selectedIds.where((x) => x != id).toList()),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ========================================================= 3D animation

/// Keeps [child] (and its state) in the tree; when it becomes visible it
/// turns in around its vertical axis like a card being flipped over.
class FlipWhenShown extends StatefulWidget {
  const FlipWhenShown({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<FlipWhenShown> createState() => _FlipWhenShownState();
}

class _FlipWhenShownState extends State<FlipWhenShown> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );

  @override
  void didUpdateWidget(FlipWhenShown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget.visible,
      maintainState: true,
      child: FadeTransition(
        opacity: _controller,
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            final remaining = 1 - Curves.easeOutCubic.transform(_controller.value);
            final matrix = remaining == 0
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..multiply(Matrix4.rotationY(-math.pi / 2.4 * remaining)));
            return Transform(alignment: Alignment.center, transform: matrix, child: child);
          },
        ),
      ),
    );
  }
}

/// Plays a 3D entrance (rise + tip forward) the first time it is built
/// with [play] true, and again each time [replayKey] changes.
class TurnIn extends StatefulWidget {
  const TurnIn({
    super.key,
    required this.child,
    this.play = true,
    this.replayKey,
    this.delay = Duration.zero,
    this.fromSide = false,
  });

  final Widget child;
  final bool play;
  final Object? replayKey;
  final Duration delay;

  /// Swing in around the vertical axis instead of tipping forward.
  final bool fromSide;

  @override
  State<TurnIn> createState() => _TurnInState();
}

class _TurnInState extends State<TurnIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
    value: widget.play ? 0 : 1,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && widget.play) {
      _started = true;
      _start();
    }
  }

  @override
  void didUpdateWidget(TurnIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replayKey != oldWidget.replayKey && widget.play) {
      _controller.value = 0;
      _start();
    }
  }

  void _start() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward(from: 0);
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final remaining = 1 - HomeMotion.ease.transform(_controller.value);
          final matrix = remaining == 0
              ? Matrix4.identity()
              : widget.fromSide
                  ? (Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..multiply(Matrix4.translationValues(60 * remaining, 0, 0))
                    ..multiply(Matrix4.rotationY(-0.45 * remaining)))
                  : (Matrix4.identity()
                    ..setEntry(3, 2, 0.0011)
                    ..multiply(Matrix4.translationValues(0, 40 * remaining, 0))
                    ..multiply(Matrix4.rotationX(-0.24 * remaining)));
          return Transform(
            alignment: widget.fromSide ? Alignment.centerLeft : Alignment.center,
            transform: matrix,
            child: child,
          );
        },
      ),
    );
  }
}

// ======================================================= minimum width

/// Lays [child] out at least [minWidth] wide. In a narrower window (e.g.
/// the browser's Inspect panel docked over the page) the content scrolls
/// sideways instead of being squeezed below what it can lay out – no
/// overflow stripes and no negative sizes.
///
/// The widget tree is the same at every width, so the content keeps its
/// state when the window crosses [minWidth]. Don't put it around content
/// that uses ScrollReveal (it would find this scroll view instead of the
/// page's).
class MinWidthBox extends StatelessWidget {
  const MinWidthBox({super.key, required this.child, this.minWidth = 320});

  final Widget child;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    // Widgets inside that size themselves from the window width
    // (MediaQuery) see at least [minWidth] too, so their sums can't go
    // negative either. Same data as the window when it is wide enough.
    final media = MediaQuery.of(context);
    final screen = media.size;
    final data = screen.width >= minWidth ? media : media.copyWith(size: Size(minWidth, screen.height));
    return MediaQuery(
      data: data,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final bounded = available.isFinite;
          final fits = !bounded || available >= minWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            // Wide enough: not scrollable (and doesn't take drags or wheel).
            physics: fits ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
            child: SizedBox(width: bounded ? math.max(minWidth, available) : minWidth, child: child),
          );
        },
      ),
    );
  }
}

// ===================================================== panels & dialogs

/// Opens [builder]'s content in a panel hinged on the right edge of the
/// screen that swings in toward the viewer (full screen on phones).
/// Returns what the panel pops with.
Future<T?> showSwingPanel<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  double width = 720,
  required Widget Function(BuildContext context) builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close $title',
    barrierColor: const Color.fromRGBO(15, 27, 45, 0.38),
    transitionDuration: const Duration(milliseconds: 650),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _SwingPanel(title: title, subtitle: subtitle, width: width, builder: builder),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      return FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final eased = animation.status == AnimationStatus.reverse
                ? Curves.easeInCubic.transform(animation.value)
                : HomeMotion.ease.transform(animation.value);
            final remaining = 1 - eased;
            final matrix = remaining == 0
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..multiply(Matrix4.translationValues(140 * remaining, 0, 0))
                  ..multiply(Matrix4.rotationY(0.55 * remaining)));
            return Transform(alignment: Alignment.centerRight, transform: matrix, child: child);
          },
        ),
      );
    },
  );
}

class _SwingPanel extends StatefulWidget {
  const _SwingPanel({required this.title, required this.subtitle, required this.width, required this.builder});

  final String title;
  final String? subtitle;
  final double width;
  final Widget Function(BuildContext context) builder;

  @override
  State<_SwingPanel> createState() => _SwingPanelState();
}

class _SwingPanelState extends State<_SwingPanel> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final full = size.width < 640;
    final panelWidth = full ? size.width : math.min(widget.width, size.width - 48);
    final sub = widget.subtitle;
    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: full ? EdgeInsets.zero : const EdgeInsets.fromLTRB(0, 16, 16, 16),
          child: Material(
            color: const Color(0xFFF7FBFE),
            elevation: 24,
            shadowColor: const Color.fromRGBO(15, 27, 45, 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(full ? 0 : 28)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: panelWidth,
              height: full ? size.height : size.height - 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 18, 12, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: HomeColors.cardBorder)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(widget.title.toUpperCase(),
                                    style: HomeText.display(full ? 26 : 30, height: 1.05)),
                              ),
                              if (sub != null) ...[
                                const SizedBox(height: 6),
                                Text(sub, style: HomeText.body(13.5, color: HomeColors.muted, height: 1.45)),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(full ? 16 : 24, 20, full ? 16 : 24, 32),
                        child: SmoothWheelScroll(
                          controller: _scroll,
                          child: MinWidthBox(child: widget.builder(context)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dialog that flips up into place (3D).
Future<T?> showFlipDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  String barrierLabel = 'Close',
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: const Color.fromRGBO(15, 27, 45, 0.42),
    transitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: Colors.white,
              elevation: 20,
              shadowColor: const Color.fromRGBO(15, 27, 45, 0.4),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(26))),
              clipBehavior: Clip.antiAlias,
              child: builder(context),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      return FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final remaining = 1 - Curves.easeOutBack.transform(animation.value);
            final matrix = animation.value == 1
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..multiply(Matrix4.translationValues(0, 30 * remaining, 0))
                  ..multiply(Matrix4.rotationX(-0.9 * remaining)));
            return Transform(alignment: Alignment.center, transform: matrix, child: child);
          },
        ),
      );
    },
  );
}

/// "Are you sure?" with a flip-in dialog. Returns true when confirmed.
Future<bool> showConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showFlipDialog<bool>(
    context: context,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(), style: HomeText.display(28, height: 1.05)),
          const SizedBox(height: 10),
          Text(message, style: HomeText.body(14.5, height: 1.5)),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: HomeColors.ink,
                  textStyle: HomeText.body(14, weight: FontWeight.w700),
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: destructive ? const Color(0xFFB4232A) : HomeColors.ink,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  textStyle: HomeText.body(14, weight: FontWeight.w700),
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Asks for a short text (e.g. a rejection reason). Returns null on cancel.
Future<String?> showTextPrompt({
  required BuildContext context,
  required String title,
  required String message,
  required String hint,
  String confirmLabel = 'Save',
  int minLength = 1,
  int maxLength = 300,
  bool destructive = false,
}) {
  return showFlipDialog<String>(
    context: context,
    builder: (context) => _TextPrompt(
      title: title,
      message: message,
      hint: hint,
      confirmLabel: confirmLabel,
      minLength: minLength,
      maxLength: maxLength,
      destructive: destructive,
    ),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.message,
    required this.hint,
    required this.confirmLabel,
    required this.minLength,
    required this.maxLength,
    required this.destructive,
  });

  final String title;
  final String message;
  final String hint;
  final String confirmLabel;
  final int minLength;
  final int maxLength;
  final bool destructive;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  final TextEditingController _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _text.text.trim();
    if (value.length < widget.minLength) {
      setState(() => _error = 'Write at least ${widget.minLength} characters.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title.toUpperCase(), style: HomeText.display(28, height: 1.05)),
          const SizedBox(height: 10),
          Text(widget.message, style: HomeText.body(14.5, height: 1.5)),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            maxLength: widget.maxLength,
            style: adminInputStyle,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: adminDecoration(hint: widget.hint, errorText: _error, counter: true),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: HomeColors.ink,
                  textStyle: HomeText.body(14, weight: FontWeight.w700),
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.destructive ? const Color(0xFFB4232A) : HomeColors.ink,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  textStyle: HomeText.body(14, weight: FontWeight.w700),
                ),
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Added manually", "Bulk import", "Crowd sync" pill.
class SourcePill extends StatelessWidget {
  const SourcePill(this.source, {super.key});

  final RecordSource source;

  @override
  Widget build(BuildContext context) {
    final icon = switch (source) {
      RecordSource.existing => Icons.inventory_2_outlined,
      RecordSource.manual => Icons.edit_outlined,
      RecordSource.bulkImport => Icons.upload_file_outlined,
      RecordSource.crowd => Icons.sync_rounded,
    };
    return StatusPill(
      label: source.label,
      icon: icon,
      background: HomeColors.neutralTint,
      foreground: HomeColors.body,
    );
  }
}
