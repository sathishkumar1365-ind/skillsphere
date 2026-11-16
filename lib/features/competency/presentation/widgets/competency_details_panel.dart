import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/smooth_wheel_scroll.dart';
import '../../../organization/data/org_models.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/competency_models.dart';
import 'competency_common.dart';

/// An employee who holds a competency, with their rating.
class CompetencyHolderView {
  const CompetencyHolderView(this.employee, this.holder);

  final EmployeeRecord employee;
  final CompetencyHolder holder;

  int get level => holder.level;
  bool get verified => holder.verified;
}

/// Opens the details of [competency] in a panel that swings in from the
/// right in 3D. The page behind (and anything typed in the Add form) stays
/// as it is; close with the X, Esc or a click outside.
Future<void> showCompetencyDetails(
  BuildContext context, {
  required Competency competency,
  required Map<String, EmployeeRecord> employeesById,
  ValueChanged<EmployeeRecord>? onOpenEmployee,
}) {
  final holders = <CompetencyHolderView>[
    for (final h in competency.holders)
      if (employeesById[h.employeeId] case final employee?) CompetencyHolderView(employee, h),
  ]..sort((a, b) {
      final byLevel = b.level.compareTo(a.level);
      return byLevel != 0 ? byLevel : a.employee.name.compareTo(b.employee.name);
    });

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close ${competency.name} details',
    barrierColor: const Color.fromRGBO(15, 27, 45, 0.38),
    transitionDuration: const Duration(milliseconds: 700),
    pageBuilder: (context, animation, secondaryAnimation) => _DetailsSheet(
      competency: competency,
      holders: holders,
      onOpenEmployee: onOpenEmployee,
    ),
    transitionBuilder: _swingIn,
  );
}

/// The panel is hinged on the right edge of the screen and swings open
/// toward the viewer (3D rotation around the vertical axis) while sliding
/// and fading in.
Widget _swingIn(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return FadeTransition(opacity: animation, child: child);
  }
  // The widget structure stays the same for the whole transition (only the
  // matrix changes), so the panel's state is never rebuilt from scratch.
  return FadeTransition(
    opacity: animation,
    child: AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        // Long soft landing when opening, quick exit when closing.
        final eased = animation.status == AnimationStatus.reverse
            ? Curves.easeInCubic.transform(value)
            : HomeMotion.ease.transform(value);
        final remaining = 1 - eased;
        // Identity when open: Flutter then skips the transform layer.
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
}

class _DetailsSheet extends StatefulWidget {
  const _DetailsSheet({
    required this.competency,
    required this.holders,
    required this.onOpenEmployee,
  });

  final Competency competency;
  final List<CompetencyHolderView> holders;
  final ValueChanged<EmployeeRecord>? onOpenEmployee;

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();

  /// Drives the staggered entrance of the content blocks.
  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  /// Level the employee list is filtered to (null = all levels).
  int? _levelFilter;

  @override
  void initState() {
    super.initState();
    // Starts just after the panel begins swinging in.
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _entrance.value = 1;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  void _toggleLevel(int level) =>
      setState(() => _levelFilter = _levelFilter == level ? null : level);

  void _openEmployee(EmployeeRecord employee) {
    final open = widget.onOpenEmployee;
    if (open != null) {
      open(employee);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Employee profile is not connected yet'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fullScreen = size.width < 640;
    final panelWidth = fullScreen ? size.width : math.min(620.0, size.width * 0.92);
    final c = widget.competency;

    final sheet = Material(
      color: const Color(0xFFF7FBFE),
      clipBehavior: Clip.antiAlias,
      borderRadius: fullScreen
          ? BorderRadius.zero
          : const BorderRadius.horizontal(left: Radius.circular(28)),
      elevation: 0,
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(onClose: _close),
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(fullScreen ? 18 : 28, 8, fullScreen ? 18 : 28, 36),
                  child: SmoothWheelScroll(
                    controller: _scroll,
                    child: _content(c, panelWidth - (fullScreen ? 36 : 56)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: true,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: panelWidth,
            height: size.height,
            decoration: BoxDecoration(
              borderRadius: fullScreen
                  ? null
                  : const BorderRadius.horizontal(left: Radius.circular(28)),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(15, 27, 45, 0.30),
                  blurRadius: 60,
                  spreadRadius: -12,
                  offset: Offset(-20, 0),
                ),
              ],
            ),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              label: '${c.name} details',
              explicitChildNodes: true,
              child: sheet,
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(Competency c, double width) {
    final narrow = width < 440;
    final counts = c.levelCounts;
    final maxCount = counts.fold<int>(1, math.max);
    final filter = _levelFilter;
    final visible = filter == null
        ? widget.holders
        : widget.holders.where((h) => h.level == filter).toList();

    var block = 0;
    Widget stagger(Widget child) => _Stagger(animation: _entrance, index: block++, child: child);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stagger(_Header(competency: c, narrow: narrow, entrance: _entrance)),
        const SizedBox(height: 18),
        stagger(Text(c.description, style: HomeText.body(16, height: 1.6))),
        const SizedBox(height: 22),
        stagger(_Stats(competency: c, entrance: _entrance)),
        const SizedBox(height: 30),
        stagger(PanelTitle(
          'Level guide',
          subtitle: 'What each level means for ${c.name}, and how many employees '
              'are at it. Select a level to filter the list below.',
        )),
        const SizedBox(height: 14),
        for (var level = 0; level < CompetencyLevel.count; level++) ...[
          if (level > 0) const SizedBox(height: 10),
          stagger(_LevelRow(
            level: level,
            description: c.levelDescription(level),
            count: counts[level],
            maxCount: maxCount,
            selected: filter == level,
            compact: narrow,
            onTap: () => _toggleLevel(level),
          )),
        ],
        const SizedBox(height: 30),
        stagger(Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: PanelTitle(
                'Employees with ${c.name} · ${c.holderCount}',
                subtitle: filter == null
                    ? 'Highest level first.'
                    : 'Showing ${visible.length} at ${CompetencyLevel.short(filter)}.',
              ),
            ),
            if (filter != null)
              TextButton(
                onPressed: () => setState(() => _levelFilter = null),
                style: TextButton.styleFrom(
                  foregroundColor: HomeColors.blue,
                  textStyle: HomeText.body(13.5, weight: FontWeight.w700),
                ),
                child: const Text('Show all levels'),
              ),
          ],
        )),
        const SizedBox(height: 12),
        if (widget.holders.isEmpty)
          stagger(_EmptyNote(
            title: 'No employees have ${c.name} yet.',
            body: 'Employees add it to their profile and pick their level from this '
                'guide; their Team Lead then verifies it.',
          ))
        else if (visible.isEmpty)
          _EmptyNote(
            title: 'Nobody is at ${CompetencyLevel.short(filter ?? 0)} yet.',
            body: 'Choose another level, or show all levels.',
          )
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: HomeMotion.ease,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, alignment: Alignment.topLeft, child: child),
            ),
            child: Column(
              key: ValueKey(filter),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  stagger(_HolderTile(
                    view: visible[i],
                    onTap: () => _openEmployee(visible[i].employee),
                  )),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------- top bar

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 14, 6),
      child: Row(
        children: [
          Text(
            'COMPETENCY DETAILS',
            style: HomeText.body(12,
                weight: FontWeight.w800, color: HomeColors.blue, letterSpacing: 1.6),
          ),
          const Spacer(),
          Tooltip(
            message: 'Close (Esc)',
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(side: BorderSide(color: HomeColors.divider)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onClose,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.close_rounded, size: 20, color: HomeColors.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({required this.competency, required this.narrow, required this.entrance});

  final Competency competency;
  final bool narrow;
  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    final c = competency;
    // The badge turns in like a coin: from edge-on to facing the viewer
    // (3D turn around its vertical axis), with a small bounce.
    final badge = AnimatedBuilder(
      animation: entrance,
      builder: (context, child) {
        final local = (entrance.value / 0.45).clamp(0.0, 1.0).toDouble();
        final remaining = local >= 1 ? 0.0 : 1 - Curves.easeOutBack.transform(local);
        return Transform(
          alignment: Alignment.center,
          transform: remaining == 0
              ? Matrix4.identity()
              : (Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..multiply(Matrix4.rotationY(math.pi * 0.5 * remaining))),
          child: child,
        );
      },
      child: CompetencyBadge.of(c, size: narrow ? 72 : 88),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CategoryPill(c.category),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(c.name.toUpperCase(),
              style: HomeText.display(narrow ? 34 : 42, height: 1.02)),
        ),
        const SizedBox(height: 8),
        Text(
          '${c.id} · Added ${formatDate(c.createdAt)} by ${c.createdBy}',
          style: HomeText.body(13, color: HomeColors.muted),
        ),
      ],
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [badge, const SizedBox(height: 16), info],
      );
    }
    return Row(
      children: [
        badge,
        const SizedBox(width: 22),
        Expanded(child: info),
      ],
    );
  }
}

// ----------------------------------------------------------------- stats

class _Stats extends StatelessWidget {
  const _Stats({required this.competency, required this.entrance});

  final Competency competency;
  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    final c = competency;
    return Row(
      children: [
        Expanded(
          child: _StatTile(value: c.holderCount, label: 'Employees', entrance: entrance),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(value: c.verifiedCount, label: 'Verified', entrance: entrance),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: c.advancedCount,
            label: 'At Level 4–5',
            entrance: entrance,
            dark: true,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.entrance,
    this.dark = false,
  });

  final int value;
  final String label;
  final Animation<double> entrance;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: dark ? HomeColors.ink : Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: dark ? null : Border.all(color: HomeColors.cardBorder),
      ),
      child: Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: entrance,
              builder: (context, _) {
                final t = const Interval(0.15, 0.6, curve: Curves.easeOutCubic)
                    .transform(entrance.value);
                return Text(
                  '${(value * t).round()}',
                  style: HomeText.display(32,
                      height: 1.0, color: dark ? HomeColors.peach : HomeColors.ink),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.body(12.5,
                  weight: FontWeight.w600, color: dark ? HomeColors.onInk : HomeColors.body),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- level guide

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.description,
    required this.count,
    required this.maxCount,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final int level;
  final String description;
  final int count;
  final int maxCount;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = CompetencyLevel.name(level);
    final people = '$count ${count == 1 ? 'employee' : 'employees'}';

    final countBlock = SizedBox(
      width: compact ? 64 : 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$count', style: HomeText.body(17, weight: FontWeight.w800, color: HomeColors.ink)),
          Text(
            compact ? (count == 1 ? 'person' : 'people') : (count == 1 ? 'employee' : 'employees'),
            style: HomeText.body(11.5, color: HomeColors.muted),
          ),
          const SizedBox(height: 6),
          MeterBar(value: count / maxCount, height: 5),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      onTap: onTap,
      label: 'Level $level, $name. $description. $people. '
          '${selected ? 'Showing only this level' : 'Show only this level'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: HomeMotion.ease,
        decoration: BoxDecoration(
          color: selected ? HomeColors.blueTint : Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(
            color: selected ? HomeColors.ink : HomeColors.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: levelBlockColor(level),
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Text('$level',
                        style: HomeText.display(24, color: levelBlockText(level), height: 1.0)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEVEL $level · ${name.toUpperCase()}',
                          style: HomeText.body(11.5,
                              weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(description,
                            style: HomeText.body(14.5, color: HomeColors.ink, height: 1.45)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  countBlock,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- employees

class _HolderTile extends StatelessWidget {
  const _HolderTile({required this.view, required this.onTap});

  final CompetencyHolderView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = view.employee;
    final person = Row(
      children: [
        InitialsAvatar(initials: e.initials, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.body(15, weight: FontWeight.w700, color: HomeColors.ink)),
              const SizedBox(height: 2),
              Text('${e.id} · ${e.designation}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.body(12.5, color: HomeColors.muted)),
              Text(e.department,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.body(12.5, color: HomeColors.muted)),
            ],
          ),
        ),
      ],
    );
    final verification = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          view.verified ? Icons.verified_outlined : Icons.person_outline_rounded,
          size: 14,
          color: view.verified ? HomeColors.blueDeep : HomeColors.muted,
        ),
        const SizedBox(width: 4),
        Text(
          view.verified ? 'Verified' : 'Self-assessed',
          style: HomeText.body(11.5,
              weight: FontWeight.w700,
              color: view.verified ? HomeColors.blueDeep : HomeColors.muted),
        ),
      ],
    );

    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: HomeColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Phones: the level goes under the person instead of beside.
              if (constraints.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    person,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        LevelPill(view.level),
                        const Spacer(),
                        verification,
                      ],
                    ),
                    const SizedBox(height: 8),
                    LevelSteps(level: view.level, height: 5),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: person),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        LevelPill(view.level),
                        const SizedBox(height: 8),
                        LevelSteps(level: view.level, height: 5),
                        const SizedBox(height: 6),
                        verification,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_search_outlined, color: HomeColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: HomeText.body(15, weight: FontWeight.w700, color: HomeColors.ink)),
                const SizedBox(height: 4),
                Text(body, style: HomeText.body(13.5, color: HomeColors.body, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades and rises a block into place, a little after the one before it.
class _Stagger extends StatelessWidget {
  const _Stagger({required this.animation, required this.index, required this.child});

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = math.min(0.6, index * 0.05);
    // drive() only listens to the controller while this widget is mounted.
    final progress = animation.drive(
      CurveTween(curve: Interval(start, math.min(1.0, start + 0.4), curve: HomeMotion.ease)),
    );
    return FadeTransition(
      opacity: progress,
      child: AnimatedBuilder(
        animation: progress,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 22 * (1 - progress.value)),
          child: child,
        ),
      ),
    );
  }
}
