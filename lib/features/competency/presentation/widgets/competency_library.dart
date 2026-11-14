import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/competency_models.dart';
import 'competency_common.dart';

enum _SortBy {
  name('Name (A–Z)'),
  mostEmployees('Most employees'),
  recent('Recently added');

  const _SortBy(this.label);
  final String label;
}

/// The current competencies: search, category filter, sort, and a grid of
/// cards. Selecting a card calls [onOpen].
class CompetencyLibrary extends StatefulWidget {
  const CompetencyLibrary({
    super.key,
    required this.competencies,
    required this.onOpen,
    required this.isNew,
    this.spotlightId,
  });

  final List<Competency> competencies;
  final ValueChanged<Competency> onOpen;

  /// True for competencies added in this session ("NEW" label).
  final bool Function(Competency) isNew;

  /// When this changes to a competency's id (after it was just added), the
  /// filters are cleared so it is visible, and its card flips in.
  final String? spotlightId;

  @override
  State<CompetencyLibrary> createState() => _CompetencyLibraryState();
}

class _CompetencyLibraryState extends State<CompetencyLibrary> {
  static const _pageSize = 12;

  final TextEditingController _search = TextEditingController();
  String _query = '';
  CompetencyCategory? _category; // null = all
  _SortBy _sort = _SortBy.name;
  int _limit = _pageSize;

  /// Cards that already played their "just added" animation.
  final Set<String> _flipped = <String>{};

  @override
  void didUpdateWidget(CompetencyLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    final spotlight = widget.spotlightId;
    if (spotlight != null && spotlight != oldWidget.spotlightId) {
      // Make sure the new competency is on screen.
      _query = '';
      _category = null;
      // Clearing the text notifies listeners, so do it after this build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search.clear();
      });
      final index = _sorted(widget.competencies).indexWhere((c) => c.id == spotlight);
      if (index >= _limit) _limit = index + 1;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Competency> _sorted(List<Competency> list) {
    final sorted = [...list];
    switch (_sort) {
      case _SortBy.name:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortBy.mostEmployees:
        sorted.sort((a, b) {
          final byCount = b.holderCount.compareTo(a.holderCount);
          return byCount != 0 ? byCount : a.name.compareTo(b.name);
        });
      case _SortBy.recent:
        sorted.sort((a, b) {
          final byDate = b.createdAt.compareTo(a.createdAt);
          return byDate != 0 ? byDate : b.id.compareTo(a.id);
        });
    }
    return sorted;
  }

  List<Competency> get _filtered {
    final query = _query.trim().toLowerCase();
    return _sorted(widget.competencies.where((c) {
      if (_category != null && c.category != _category) return false;
      return query.isEmpty || c.searchText.contains(query);
    }).toList());
  }

  void _setFilter(VoidCallback change) => setState(() {
        change();
        _limit = _pageSize;
      });

  @override
  Widget build(BuildContext context) {
    final all = widget.competencies;
    final filtered = _filtered;
    final shown = filtered.take(_limit).toList();
    final remaining = filtered.length - shown.length;

    return OrgPanel(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 620 ? 2 : 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    child: const Icon(Icons.layers_outlined, color: HomeColors.blueDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PanelTitle(
                      'Competency library',
                      subtitle: '${all.length} competencies. Select one to see its '
                          'level guide and who holds it.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: width < 560 ? width : 320,
                    child: CompetencySearchField(
                      controller: _search,
                      onChanged: (value) => _setFilter(() => _query = value),
                      onClear: () => _setFilter(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
                  ),
                  _SortMenu(
                    value: _sort,
                    onChanged: (value) => _setFilter(() => _sort = value),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Semantics(
                container: true,
                label: 'Filter by category',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OrgFilterPill(
                      label: 'All · ${all.length}',
                      selected: _category == null,
                      onTap: () => _setFilter(() => _category = null),
                    ),
                    for (final category in CompetencyCategory.values)
                      OrgFilterPill(
                        label: '${category.plural} · '
                            '${all.where((c) => c.category == category).length}',
                        selected: _category == category,
                        onTap: () => _setFilter(() => _category = category),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Showing ${shown.length} of ${filtered.length}'
                  '${filtered.length == all.length ? '' : ' (${all.length} in total)'}',
                  style: HomeText.body(13.5, weight: FontWeight.w600, color: HomeColors.muted),
                ),
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F8FC),
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                  child: Text(
                    _query.trim().isEmpty
                        ? 'No competencies in this category yet.'
                        : 'No competency matches "${_query.trim()}". '
                            'Try another word or category.',
                    style: HomeText.body(14.5),
                  ),
                )
              else
                EqualHeightGrid(
                  columns: columns,
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final c in shown)
                      _maybeFlipIn(
                        c,
                        _CompetencyCard(
                          competency: c,
                          isNew: widget.isNew(c),
                          onTap: () => widget.onOpen(c),
                        ),
                      ),
                  ],
                ),
              if (remaining > 0) ...[
                const SizedBox(height: 18),
                Center(
                  child: PillButton(
                    label: 'Show ${math.min(remaining, _pageSize)} more',
                    variant: PillVariant.outline,
                    height: 46,
                    fontSize: 14,
                    onPressed: () => setState(() => _limit += _pageSize),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// The card of the competency that was just added flips in once.
  Widget _maybeFlipIn(Competency c, Widget card) {
    if (c.id != widget.spotlightId) return card;
    final play = !_flipped.contains(c.id);
    if (play) _flipped.add(c.id);
    return _FlipIn(key: ValueKey('flip-${c.id}'), play: play, child: card);
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final _SortBy value;
  final ValueChanged<_SortBy> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortBy>(
      tooltip: 'Sort competencies',
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 50),
      color: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      itemBuilder: (context) => [
        for (final option in _SortBy.values)
          PopupMenuItem<_SortBy>(
            value: option,
            child: Text(
              option.label,
              style: HomeText.body(14,
                  weight: option == value ? FontWeight.w800 : FontWeight.w500,
                  color: HomeColors.ink),
            ),
          ),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(color: HomeColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18, color: HomeColors.ink),
            const SizedBox(width: 8),
            Text('Sort: ${value.label}',
                style: HomeText.body(14, weight: FontWeight.w600, color: HomeColors.ink)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 18, color: HomeColors.ink),
          ],
        ),
      ),
    );
  }
}

/// One competency in the library. Lifts in 3D on hover or keyboard focus.
class _CompetencyCard extends StatelessWidget {
  const _CompetencyCard({
    required this.competency,
    required this.isNew,
    required this.onTap,
  });

  final Competency competency;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = competency;
    final count = c.holderCount;
    return Semantics(
      button: true,
      onTap: onTap,
      label: '${c.name}, ${c.category.label}, '
          '$count ${count == 1 ? 'employee' : 'employees'}. Open details',
      excludeSemantics: true,
      child: LiftCard(
        padding: EdgeInsets.zero,
        radius: 20,
        liftBy: 6,
        tiltDegrees: 6,
        color: Colors.white,
        borderColor: isNew ? HomeColors.blue : HomeColors.cardBorder,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            hoverColor: const Color.fromRGBO(31, 95, 209, 0.03),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CompetencyBadge.of(c, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HomeText.body(16.5,
                                    weight: FontWeight.w800, color: HomeColors.ink)),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                CategoryPill(c.category, dense: true),
                                if (isNew)
                                  const StatusPill(
                                    label: 'NEW',
                                    icon: Icons.auto_awesome_rounded,
                                    background: HomeColors.ink,
                                    foreground: Colors.white,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Icon(Icons.chevron_right_rounded, color: HomeColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(13.5, color: HomeColors.body, height: 1.45),
                  ),
                  const Spacer(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16, color: HomeColors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          count == 0
                              ? 'No employees yet'
                              : '$count ${count == 1 ? 'employee' : 'employees'}'
                                  ' · ${c.verifiedCount} verified',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HomeText.body(13, weight: FontWeight.w600, color: HomeColors.body),
                        ),
                      ),
                      Text('L0–5',
                          style: HomeText.body(12, weight: FontWeight.w700, color: HomeColors.muted)),
                    ],
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

/// Flips a card in around its horizontal axis (3D) the first time it is
/// built with [play] set. Otherwise shows the child as it is.
class _FlipIn extends StatefulWidget {
  const _FlipIn({super.key, required this.play, required this.child});

  final bool play;
  final Widget child;

  @override
  State<_FlipIn> createState() => _FlipInState();
}

class _FlipInState extends State<_FlipIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: widget.play ? 0.0 : 1.0,
  );
  late final CurvedAnimation _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.play) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) {
          // easeOutBack overshoots slightly past flat, which reads as a bounce.
          final remaining = 1 - _curve.value;
          // Finished: identity matrix, so Flutter skips the transform layer.
          final matrix = _controller.isCompleted
              ? Matrix4.identity()
              : (Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..multiply(Matrix4.translationValues(0, 24 * remaining, 0))
                ..multiply(Matrix4.rotationX(-math.pi / 2.2 * remaining)));
          return Transform(alignment: Alignment.center, transform: matrix, child: child);
        },
      ),
    );
  }
}
