// The skill map card: one employee's projects, required competencies,
// current levels and gaps, joined by animated beams.
//
//   Projects → Required → (employee) → Current levels → Gaps
//
// * Hover (or keyboard focus) a node to light up everything on a path
//   through it and dim the rest; tap to keep it lit (tap again or tap the
//   background to let go). The panel underneath explains the tapped node
//   and offers its actions (competency details, plan training, request a
//   level-up, open the profile – whatever the page passes in).
// * Project pills limit the map to one project (required levels and gaps
//   are then that project's). "Skills no project needs" shows/hides the
//   held competencies the shown projects don't ask for.
// * Wide screens: five columns; narrow: tiers from top to bottom.
// * The beams only move while the map is on screen and never with reduced
//   motion (then the paths are drawn still). "Save image" downloads a PNG.
//
// Used by the employee profile (section "Skill map") and by Dashboards &
// Reports ("Skill maps").

import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../admin/data/admin_base.dart' show monthYear;
import '../../admin/data/insights.dart';
import '../../admin/presentation/projects/allocate_projects_panel.dart' show NeedChip;
import '../../admin/presentation/widgets/admin_common.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/presentation/widgets/competency_common.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../../training_plan/data/training_plans.dart';
import '../data/skill_map.dart';
import '../data/skill_map_layout.dart';
import 'animated_beam.dart';
import 'skill_map_nodes.dart';

class SkillBeamMap extends StatefulWidget {
  const SkillBeamMap({
    super.key,
    required this.insight,
    this.own = false,
    this.onOpenCompetency,
    this.onPlan,
    this.onRequest,
    this.onOpenProfile,
    this.onOpenGaps,
    this.onOpenPlans,
  });

  final EmployeeInsight insight;

  /// The viewer is this employee (texts say "you").
  final bool own;

  /// Opens the competency's details (level guide, holders).
  final ValueChanged<Competency>? onOpenCompetency;

  /// The employee plans training for a gap (own profile only).
  final ValueChanged<GapEntry>? onPlan;

  /// The Team Lead asks HR for a level-up.
  final ValueChanged<CompetencyRow>? onRequest;

  /// Opens the employee's profile (from Reports).
  final VoidCallback? onOpenProfile;

  /// Scrolls to the gaps table / training plan (on the profile).
  final VoidCallback? onOpenGaps;
  final VoidCallback? onOpenPlans;

  @override
  State<SkillBeamMap> createState() => _SkillBeamMapState();
}

class _SkillBeamMapState extends State<SkillBeamMap> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  final GlobalKey _capture = GlobalKey();

  Duration _carried = Duration.zero;
  Duration _lastElapsed = Duration.zero;

  String? _projectId;
  bool _showOther = true;
  String? _hover;
  String? _pinned;
  bool _saving = false;

  // Visibility (beams only move while the map is on screen).
  ScrollPosition? _position;
  double _screenHeight = 0;
  bool _onScreen = false;
  bool _reduceMotion = false;
  bool _introStarted = false;
  bool _checkScheduled = false;

  // Geometry cache: rebuilt only when the width or the drawn data change.
  String? _geometryKey;
  SkillMapLayout? _layout;
  List<Beam> _beams = const <Beam>[];

  String get _employeeId => widget.insight.profile.id;

  // ------------------------------------------------------------ lifecycle

  void _tick(Duration elapsed) {
    _lastElapsed = elapsed;
    _clock.value = (_carried + elapsed).inMicroseconds / Duration.microsecondsPerSecond;
  }

  void _syncTicker() {
    final run = _onScreen && !_reduceMotion;
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _carried += _lastElapsed;
      _lastElapsed = Duration.zero;
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _screenHeight = MediaQuery.sizeOf(context).height;
    if (_reduceMotion && _intro.value != 1) {
      _introStarted = true;
      _intro.value = 1;
    }
    final position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_scheduleVisibilityCheck);
      _position = position;
      _position?.addListener(_scheduleVisibilityCheck);
    }
    _syncTicker();
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(SkillBeamMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insight.profile.id != _employeeId) {
      _projectId = null;
      _hover = null;
      _pinned = null;
      _replay();
    }
  }

  void _scheduleVisibilityCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero).dy;
      final visible = top + box.size.height > 0 && top < _screenHeight;
      if (visible && !_introStarted) {
        _introStarted = true;
        _intro.forward(from: 0);
      }
      if (visible != _onScreen) {
        _onScreen = visible;
        _syncTicker();
      }
    });
  }

  /// Draws the map in again (another person or project).
  void _replay() {
    if (_reduceMotion) {
      _intro.value = 1;
    } else if (_introStarted) {
      _intro.forward(from: 0.12);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleVisibilityCheck);
    _ticker.dispose();
    _intro.dispose();
    _clock.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- actions

  void _hoverNode(String id, bool on) {
    if (on) {
      if (_hover != id) setState(() => _hover = id);
    } else if (_hover == id) {
      setState(() => _hover = null);
    }
  }

  void _tapNode(String id) => setState(() => _pinned = _pinned == id ? null : id);

  void _setProject(String? id) {
    if (id == _projectId) return;
    setState(() {
      _projectId = id;
      _pinned = null;
      _hover = null;
    });
    _replay();
  }

  CompetencyRow? _rowFor(String competencyId) {
    for (final r in widget.insight.rows) {
      if (r.competency.id == competencyId) return r;
    }
    return null;
  }

  /// The biggest gap entry for the competency (for the shown project when
  /// the map is limited to one).
  GapEntry? _gapEntryFor(String competencyId, String? projectId) {
    GapEntry? any;
    for (final e in widget.insight.gapEntries) {
      if (e.competency.id != competencyId) continue;
      if (projectId == null || e.source.project.id == projectId) return e;
      any ??= e;
    }
    return any;
  }

  Future<void> _saveImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    final name = 'SkillMap_${widget.insight.profile.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_'
        '${DateTime.now().toIso8601String().substring(0, 10)}.png';
    try {
      // Let the current frame finish so the picture is complete.
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _capture.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) throw StateError('the map is not on screen');
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('no image data');
      final bytes = data.buffer.asUint8List();
      final FileSaveLocation? location = kIsWeb
          ? const FileSaveLocation('')
          : await getSaveLocation(
              suggestedName: name,
              acceptedTypeGroups: const <XTypeGroup>[
                XTypeGroup(
                  label: 'PNG image',
                  extensions: <String>['png'],
                  mimeTypes: <String>['image/png'],
                  uniformTypeIdentifiers: <String>['public.png'],
                ),
              ],
            );
      if (location == null) return;
      await XFile.fromData(bytes, name: name, mimeType: 'image/png').saveTo(location.path);
      if (mounted) showAdminMessage(context, kIsWeb ? 'Downloaded $name.' : 'Saved $name.');
    } catch (e) {
      if (mounted) showAdminMessage(context, 'Could not save the image: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final projects = widget.insight.projects;
    final projectId = projects.any((p) => p.id == _projectId) ? _projectId : null;
    final map = SkillMap.build(widget.insight, projectId: projectId, includeOther: _showOther);
    final narrow = MediaQuery.sizeOf(context).width < 600;

    return Semantics(
      container: true,
      label: 'Skill map of ${map.profile.name}: ${map.projects.length} projects, ${map.needs.length} '
          'required competencies, ${map.metCount} met, ${map.gapCount} gaps.',
      child: OrgPanel(
        padding: EdgeInsets.fromLTRB(narrow ? 14 : 22, narrow ? 16 : 20, narrow ? 14 : 22, narrow ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(map: map, own: widget.own),
            const SizedBox(height: 14),
            _Controls(
              map: map,
              showOther: _showOther,
              saving: _saving,
              onProject: _setProject,
              onShowOther: (v) => setState(() {
                _showOther = v;
                _pinned = null;
                _hover = null;
              }),
              onSave: _saveImage,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) => _canvas(map, constraints.maxWidth)),
            const SizedBox(height: 14),
            const _Legend(),
            const SizedBox(height: 14),
            _detailsArea(map),
          ],
        ),
      ),
    );
  }

  (SkillMapLayout, List<Beam>) _geometry(SkillMap map, double width) {
    final key = '${width.toStringAsFixed(1)}#${map.signature}';
    final cached = _layout;
    if (cached != null && key == _geometryKey) return (cached, _beams);
    final layout = SkillMapLayout.compute(map, width);
    _layout = layout;
    _beams = buildBeams(map, layout);
    _geometryKey = key;
    return (layout, _beams);
  }

  Widget _canvas(SkillMap map, double width) {
    final (layout, beams) = _geometry(map, width);
    var focus = _hover ?? _pinned;
    if (focus != null && !layout.rects.containsKey(focus)) focus = null;
    final lit = focus == null ? null : map.connectedTo(focus);
    final litLinks = lit == null ? null : map.linksAmong(lit);
    final wide = layout.axis == Axis.horizontal;

    final children = <Widget>[
      // Tapping the background lets go of a pinned node.
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _pinned == null ? null : () => setState(() => _pinned = null),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: BeamPainter(
                beams: beams,
                clock: _clock,
                intro: _intro,
                highlighted: litLinks,
                animate: !_reduceMotion,
              ),
            ),
          ),
        ),
      ),
      for (final entry in layout.headers.entries)
        Positioned.fromRect(
          rect: entry.value,
          child: _Entrance(
            intro: _intro,
            order: entry.key.index,
            child: ColumnHeading(column: entry.key, count: _countIn(map, entry.key), wide: wide),
          ),
        ),
      for (final entry in layout.rects.entries)
        Positioned.fromRect(
          rect: entry.value,
          child: _Entrance(
            intro: _intro,
            order: (layout.columns[entry.key] ?? SkillMapColumn.employee).index,
            child: AnimatedOpacity(
              opacity: lit == null || lit.contains(entry.key) ? 1.0 : 0.3,
              duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
              child: _node(map, entry.key, layout),
            ),
          ),
        ),
      Positioned.fromRect(
        rect: layout.hubLabel,
        child: _Entrance(
          intro: _intro,
          order: SkillMapColumn.employee.index,
          child: HubLabel(
            name: layout.hubLabel.width < 130 ? map.profile.firstName : map.profile.name,
            readiness: map.readiness,
            gaps: map.gapCount,
            centred: wide,
          ),
        ),
      ),
    ];

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: RepaintBoundary(
        key: _capture,
        child: ColoredBox(
          color: Colors.white,
          child: SizedBox(
            width: layout.size.width,
            height: layout.size.height,
            child: Stack(clipBehavior: Clip.none, children: children),
          ),
        ),
      ),
    );
  }

  int _countIn(SkillMap map, SkillMapColumn column) => switch (column) {
        SkillMapColumn.projects => map.projects.length,
        SkillMapColumn.needs => map.needs.length,
        SkillMapColumn.employee => 1,
        SkillMapColumn.current => map.current.length,
        SkillMapColumn.gaps => map.gaps.length,
      };

  Widget _node(SkillMap map, String id, SkillMapLayout layout) {
    void hover(bool on) => _hoverNode(id, on);
    void tap() => _tapNode(id);
    final selected = _pinned == id;

    if (id == SkillMapIds.hub) {
      final readiness = map.readiness;
      return HubNode(
        initials: map.profile.initials,
        readiness: readiness,
        clock: _clock,
        selected: selected,
        semanticLabel: '${map.profile.name}. '
            '${readiness == null ? 'No project needs yet' : '$readiness percent ready'}, '
            '${map.gapCount} ${map.gapCount == 1 ? 'gap' : 'gaps'}.',
        onHover: hover,
        onTap: tap,
      );
    }
    if (id.startsWith('x:')) {
      final column = layout.columns[id] ?? SkillMapColumn.gaps;
      return PlaceholderNode(column: column, hasNeeds: map.needs.isNotEmpty);
    }
    final project = map.projectNode(id);
    if (project != null) return ProjectNode(node: project, selected: selected, onHover: hover, onTap: tap);
    final competencyId = SkillMapIds.competencyOf(id) ?? '';
    if (id.startsWith('n:')) {
      final need = map.needFor(competencyId);
      if (need != null) return NeedNode(node: need, selected: selected, onHover: hover, onTap: tap);
    } else if (id.startsWith('c:')) {
      final current = map.currentFor(competencyId);
      if (current != null) return CurrentNode(node: current, selected: selected, onHover: hover, onTap: tap);
    } else if (id.startsWith('g:')) {
      final gap = map.gapFor(competencyId);
      if (gap != null) return GapNode(node: gap, selected: selected, onHover: hover, onTap: tap);
    }
    return const SizedBox.shrink();
  }

  // -------------------------------------------------------------- details

  /// Details of the pinned (tapped) node. Hover only highlights, so moving
  /// the mouse across the map never changes the page height.
  Widget _detailsArea(SkillMap map) {
    var focus = _pinned;
    final layout = _layout;
    if (focus != null && layout != null && !layout.rects.containsKey(focus)) focus = null;
    final Widget content;
    if (focus == null) {
      content = _Hint(key: const ValueKey<String>('hint'), map: map, own: widget.own);
    } else if (focus == SkillMapIds.hub) {
      content = _PersonDetails(
        key: const ValueKey<String>('hub'),
        map: map,
        onOpenProfile: widget.onOpenProfile,
        onOpenGaps: widget.onOpenGaps,
      );
    } else if (map.projectNode(focus) case final MapProject project) {
      content = _ProjectDetails(
        key: ValueKey<String>(focus),
        map: map,
        node: project,
        onlyThis: map.onlyProject?.id == project.project.id,
        onToggle: () => _setProject(map.onlyProject?.id == project.project.id ? null : project.project.id),
      );
    } else {
      final competencyId = SkillMapIds.competencyOf(focus) ?? '';
      final row = _rowFor(competencyId);
      final gap = map.gapFor(competencyId);
      final entry = gap == null ? null : _gapEntryFor(competencyId, map.onlyProject?.id);
      final plan = widget.onPlan;
      final request = widget.onRequest;
      final open = widget.onOpenCompetency;
      content = _CompetencyDetails(
        key: ValueKey<String>('cmp:$competencyId'),
        map: map,
        competencyId: competencyId,
        onOpen: open,
        onPlan: plan != null && entry != null && gap?.plan == null ? () => plan(entry) : null,
        onRequest: request != null && row != null && row.pending == null ? () => request(row) : null,
        onOpenGaps: gap == null ? null : widget.onOpenGaps,
        onOpenPlans: gap?.plan == null ? null : widget.onOpenPlans,
      );
    }

    return AnimatedSize(
      duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
      curve: HomeMotion.ease,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
        switchInCurve: HomeMotion.ease,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final p in previous) Positioned(left: 0, right: 0, top: 0, child: p),
            if (current != null) current,
          ],
        ),
        transitionBuilder: (child, animation) => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final remaining = 1 - animation.value;
            final matrix = remaining == 0
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..multiply(Matrix4.rotationX(-0.5 * remaining)));
            return Opacity(
              opacity: animation.value,
              child: Transform(alignment: Alignment.topCenter, transform: matrix, child: child),
            );
          },
        ),
        child: content,
      ),
    );
  }
}

// ================================================================ entrance

/// Columns turn in one after the other (left to right) while the beams
/// draw themselves in. Identity matrix at rest.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.intro, required this.order, required this.child});

  final Animation<double> intro;
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: intro,
      child: child,
      builder: (context, child) {
        final start = order * 0.13;
        final value = ((intro.value - start) / 0.4).clamp(0.0, 1.0);
        final eased = HomeMotion.ease.transform(value);
        final remaining = 1 - eased;
        final matrix = remaining == 0
            ? Matrix4.identity()
            : (Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..multiply(Matrix4.translationValues(-26 * remaining, 0, 0))
              ..multiply(Matrix4.rotationY(1.05 * remaining)));
        return Opacity(
          opacity: eased,
          child: Transform(alignment: Alignment.centerLeft, transform: matrix, child: child),
        );
      },
    );
  }
}

// ================================================================== header

class _Header extends StatelessWidget {
  const _Header({required this.map, required this.own});

  final SkillMap map;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final readiness = map.readiness;
    final who = own ? 'you' : map.profile.firstName;
    final role = map.roleName == '—' ? (own ? 'your role' : 'their role') : 'the ${map.roleName} role';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: PanelTitle(
            'Skill map · ${map.profile.name}',
            subtitle: 'Light flows from each project to what it needs from $role, through $who to '
                '${own ? 'your' : 'their'} current levels and on to the gaps. Blue = level reached, '
                'orange = gap.',
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Stat(value: '${map.projects.length}', label: map.projects.length == 1 ? 'project' : 'projects'),
            _Stat(value: '${map.needs.length}', label: 'required'),
            _Stat(value: '${map.metCount}', label: 'met', tone: _StatTone.good),
            _Stat(value: '${map.gapCount}', label: map.gapCount == 1 ? 'gap' : 'gaps', tone: _StatTone.gap),
            if (readiness != null) _Stat(value: '$readiness%', label: 'ready', tone: _StatTone.ink),
          ],
        ),
      ],
    );
  }
}

enum _StatTone { plain, good, gap, ink }

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.tone = _StatTone.plain});

  final String value;
  final String label;
  final _StatTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      _StatTone.plain => (HomeColors.neutralTint, HomeColors.ink),
      _StatTone.good => (OrgColors.goodTint, OrgColors.good),
      _StatTone.gap => value == '0' ? (HomeColors.neutralTint, HomeColors.ink) : (HomeColors.orangeTint, HomeColors.orangeText),
      _StatTone.ink => (HomeColors.ink, Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.all(Radius.circular(999))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value, style: HomeText.body(15, weight: FontWeight.w800, color: fg)),
          const SizedBox(width: 5),
          Text(label, style: HomeText.body(12.5, weight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

// ================================================================ controls

class _Controls extends StatelessWidget {
  const _Controls({
    required this.map,
    required this.showOther,
    required this.saving,
    required this.onProject,
    required this.onShowOther,
    required this.onSave,
  });

  final SkillMap map;
  final bool showOther;
  final bool saving;
  final ValueChanged<String?> onProject;
  final ValueChanged<bool> onShowOther;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final only = map.onlyProject;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (map.allProjects.length > 1) ...[
          OrgFilterPill(label: 'All projects', selected: only == null, onTap: () => onProject(null)),
          for (final p in map.allProjects)
            Tooltip(
              message: p.name,
              waitDuration: const Duration(milliseconds: 500),
              child: OrgFilterPill(label: p.code, selected: only?.id == p.id, onTap: () => onProject(p.id)),
            ),
        ],
        if (map.otherCount > 0)
          _Toggle(
            label: 'Skills no project needs (${map.otherCount})',
            value: showOther,
            onChanged: onShowOther,
          ),
        Tooltip(
          message: 'Download the map as a PNG image',
          child: HoverRaise(
            child: OutlinedButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.image_outlined, size: 18),
              label: const Text('Save image'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HomeColors.ink,
                backgroundColor: Colors.white,
                side: const BorderSide(color: HomeColors.chipBorder),
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: HomeText.body(13.5, weight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill with a check box look (on/off).
class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(side: BorderSide(color: HomeColors.chipBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 18, color: value ? HomeColors.ink : HomeColors.muted),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HomeText.body(13.5, weight: FontWeight.w600, color: HomeColors.ink)),
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

// ================================================================== legend

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: const [
        _LegendItem(tone: BeamTone.met, label: 'Level reached'),
        _LegendItem(tone: BeamTone.gap, label: 'Gap: below the required level'),
        _LegendItem(tone: BeamTone.gap, dashed: true, label: 'Not acquired yet'),
        _LegendItem(tone: BeamTone.other, label: 'Held, not needed by these projects'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.tone, required this.label, this.dashed = false});

  final BeamTone tone;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(30, 10), painter: _LegendLine(tone: tone, dashed: dashed)),
        const SizedBox(width: 8),
        Flexible(child: Text(label, style: HomeText.body(12.5, color: HomeColors.body))),
      ],
    );
  }
}

class _LegendLine extends CustomPainter {
  const _LegendLine({required this.tone, required this.dashed});

  final BeamTone tone;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = BeamColors.of(tone);
    final y = size.height / 2;
    final paint = Paint()
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = colors.base;
    if (dashed) {
      for (var x = 1.0; x < size.width - 6; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(x + 3.5, y), paint);
      }
    } else {
      canvas.drawLine(Offset(1, y), Offset(size.width - 6, y), paint..color = colors.base.withValues(alpha: 0.55));
    }
    canvas.drawCircle(Offset(size.width - 4, y), 3.2, Paint()..color = colors.stop);
  }

  @override
  bool shouldRepaint(_LegendLine oldDelegate) => oldDelegate.tone != tone || oldDelegate.dashed != dashed;
}

// ================================================================= details

/// A small "label / value" box.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.gap = false});

  final String label;
  final String value;
  final bool gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 14, 9),
      decoration: BoxDecoration(
        color: gap ? HomeColors.orangeTint : const Color(0xFFF4F7FB),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: HomeText.body(10.5, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.9)),
          const SizedBox(height: 3),
          Text(value,
              style: HomeText.body(14, weight: FontWeight.w700, color: gap ? HomeColors.orangeText : HomeColors.ink)),
        ],
      ),
    );
  }
}

class _DetailsFrame extends StatelessWidget {
  const _DetailsFrame({required this.title, required this.children, this.leading, this.trailing});

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final lead = leading;
    final tail = trailing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFF),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 12)],
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(16, weight: FontWeight.w800, color: HomeColors.ink)),
              ),
              if (tail != null) ...[const SizedBox(width: 8), tail],
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

Widget _actions(List<Widget> buttons) => buttons.isEmpty
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
      );

PillButton _button(String label, VoidCallback onPressed, {bool primary = false}) => PillButton(
      label: label,
      variant: primary ? PillVariant.primary : PillVariant.outline,
      height: 40,
      fontSize: 13,
      horizontalPadding: 16,
      onPressed: onPressed,
    );

/// Nothing lit: how to use the map.
class _Hint extends StatelessWidget {
  const _Hint({super.key, required this.map, required this.own});

  final SkillMap map;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (map.allProjects.isEmpty) {
      text = '${own ? 'You are' : '${map.profile.firstName} is'} not on a project yet, so nothing is required '
          'and there are no gaps. The beams on the right show the levels held.';
    } else {
      text = 'Hover over a project, a competency or a gap to follow its beams – everything else dims. '
          'Tap it to keep it lit and see its details here; tap again or tap the background to let go.';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: HomeColors.blueTint,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.touch_app_outlined, size: 19, color: HomeColors.blueDeep),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: HomeText.body(13.5, color: HomeColors.ink, height: 1.45))),
        ],
      ),
    );
  }
}

class _PersonDetails extends StatelessWidget {
  const _PersonDetails({super.key, required this.map, required this.onOpenProfile, required this.onOpenGaps});

  final SkillMap map;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenGaps;

  @override
  Widget build(BuildContext context) {
    final readiness = map.readiness;
    final open = onOpenProfile;
    final gaps = onOpenGaps;
    final plans = map.gaps.where((g) => g.plan != null).length;
    return _DetailsFrame(
      title: '${map.profile.name} · ${map.roleName}',
      leading: InitialsAvatar(initials: map.profile.initials, size: 38),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Fact(label: 'Readiness', value: readiness == null ? 'No project needs' : '$readiness%'),
            _Fact(label: 'Projects', value: '${map.projects.length}'),
            _Fact(label: 'Required', value: '${map.needs.length}'),
            _Fact(label: 'Met', value: '${map.metCount}'),
            _Fact(label: 'Gaps', value: '${map.gapCount}', gap: map.gapCount > 0),
            if (map.gapCount > 0) _Fact(label: 'Gaps with a plan', value: '$plans of ${map.gapCount}'),
            if (map.pendingCount > 0) _Fact(label: 'Waiting for HR', value: '${map.pendingCount}'),
          ],
        ),
        _actions([
          if (open != null) _button('Open profile', open, primary: true),
          if (gaps != null && map.gapCount > 0) _button('See the gaps table', gaps),
        ]),
      ],
    );
  }
}

class _ProjectDetails extends StatelessWidget {
  const _ProjectDetails({
    super.key,
    required this.map,
    required this.node,
    required this.onlyThis,
    required this.onToggle,
  });

  final SkillMap map;
  final MapProject node;
  final bool onlyThis;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = node.project;
    final fit = node.fit;
    return _DetailsFrame(
      title: '${p.code} · ${p.name}',
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          gradient: LinearGradient(colors: [Color(0xFF3C7BE8), HomeColors.ink]),
        ),
        child: const Icon(Icons.work_outline_rounded, size: 19, color: Colors.white),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Fact(label: 'Status', value: p.status.label),
            _Fact(label: 'Period', value: p.period),
            _Fact(label: 'Role', value: map.roleName),
            _Fact(label: 'Fit', value: '${fit.percent}%'),
            _Fact(label: 'Needs', value: '${fit.needs.length}'),
            _Fact(label: 'Gaps', value: '${fit.gapCount}', gap: fit.gapCount > 0),
          ],
        ),
        if (fit.needs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(map.roleName == '—' ? 'NEEDS FOR THIS PERSON' : 'NEEDS FROM THE ${map.roleName.toUpperCase()} ROLE',
              style: HomeText.body(11, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.9)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final n in fit.needs) NeedChip(need: n)]),
        ] else ...[
          const SizedBox(height: 10),
          Text('This project lists nothing for this role.', style: HomeText.body(13, color: HomeColors.muted)),
        ],
        if (map.allProjects.length > 1)
          _actions([_button(onlyThis ? 'Show all projects' : 'Show only this project', onToggle, primary: true)]),
      ],
    );
  }
}

class _CompetencyDetails extends StatelessWidget {
  const _CompetencyDetails({
    super.key,
    required this.map,
    required this.competencyId,
    required this.onOpen,
    required this.onPlan,
    required this.onRequest,
    required this.onOpenGaps,
    required this.onOpenPlans,
  });

  final SkillMap map;
  final String competencyId;
  final ValueChanged<Competency>? onOpen;
  final VoidCallback? onPlan;
  final VoidCallback? onRequest;
  final VoidCallback? onOpenGaps;
  final VoidCallback? onOpenPlans;

  @override
  Widget build(BuildContext context) {
    final need = map.needFor(competencyId);
    final current = map.currentFor(competencyId);
    final gap = map.gapFor(competencyId);
    final competency = need?.competency ?? current?.competency ?? gap?.competency;
    if (competency == null) return const SizedBox.shrink();
    final level = current?.level;
    final pending = current?.pending;
    final plan = gap?.plan;
    final open = onOpen;
    final planTraining = onPlan;
    final request = onRequest;
    final gapsTable = onOpenGaps;
    final plans = onOpenPlans;

    return _DetailsFrame(
      title: competency.name,
      leading: CompetencyBadge.of(competency, size: 38),
      trailing: CategoryPill(competency.category, dense: true),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Fact(label: 'Required', value: need == null ? 'Not needed here' : 'L${need.level}'),
            _Fact(
              label: 'Current',
              value: level == null
                  ? 'Not acquired'
                  : '${CompetencyLevel.short(level)} · ${current?.verified ?? false ? 'verified' : 'self-assessed'}',
            ),
            _Fact(
              label: 'Gap',
              value: gap == null ? (need == null ? '—' : 'Met') : '−${gap.size}',
              gap: gap != null,
            ),
            if (gap != null)
              _Fact(label: 'Training plan', value: plan == null ? 'No plan yet' : '${plan.status.label} · ${plan.title}'),
            if (pending != null)
              _Fact(label: 'Level-up', value: 'L${pending.toLevel} waiting for HR', gap: true),
          ],
        ),
        if (need != null) ...[
          const SizedBox(height: 12),
          Text('REQUIRED BY',
              style: HomeText.body(11, weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 0.9)),
          const SizedBox(height: 6),
          for (final s in need.sources) _SourceLine(source: s),
        ],
        if (plan != null && plan.status != PlanStatus.completed) ...[
          const SizedBox(height: 4),
          Text(
            '${plan.completedHours} of ${plan.plannedHours} h done · target ${monthYear(plan.targetDate)}',
            style: HomeText.body(12.5, color: HomeColors.muted),
          ),
        ],
        _actions([
          if (planTraining != null) _button('Plan training', planTraining, primary: true),
          if (request != null) _button('Request level-up', request, primary: planTraining == null),
          if (open != null) _button('Competency details', () => open(competency)),
          if (plans != null) _button('Open the training plan', plans),
          if (gapsTable != null) _button('See the gaps table', gapsTable),
        ]),
      ],
    );
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.source});

  final MapSource source;

  @override
  Widget build(BuildContext context) {
    final met = source.met;
    final held = source.held;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle_rounded : Icons.north_east_rounded,
              size: 16, color: met ? OrgColors.good : HomeColors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${source.project.code} · ${source.project.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.body(13, weight: FontWeight.w600, color: HomeColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          Text('needs L${source.level}', style: HomeText.body(12.5, color: HomeColors.muted)),
          const SizedBox(width: 8),
          StatusPill(
            label: met ? 'Met' : '−${source.size}${held == null ? ' · not held' : ''}',
            icon: met ? Icons.check_rounded : Icons.south_rounded,
            background: met ? OrgColors.goodTint : HomeColors.orangeTint,
            foreground: met ? OrgColors.good : HomeColors.orangeText,
          ),
        ],
      ),
    );
  }
}
