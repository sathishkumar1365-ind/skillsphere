import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/sphere_page_route.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/account_menu.dart';
import '../../home/presentation/widgets/drifting_clouds.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../home/presentation/widgets/smooth_wheel_scroll.dart';
import '../data/approvals.dart';
import '../data/employees.dart';
import 'approvals/approvals_view.dart';
import 'changes/profile_changes_view.dart';
import 'console_section.dart';
import 'employees/all_employees_view.dart';
import 'employees/employee_profile_page.dart';
import 'onboarding/onboarding_view.dart';
import 'projects/projects_view.dart';
import 'roles/roles_view.dart';
import 'structure/structure_view.dart';
import 'widgets/admin_common.dart';
import 'widgets/console_top_bar.dart';

/// The HRD console – opened with the settings (gear) icon on the HRD
/// dashboard. HRD team (Super Admin) only.
///
/// A side menu (a strip of pills on narrow screens) switches between the
/// seven options. Each option keeps its state (typed form text, filters,
/// scroll position) while another one is open, and turns in in 3D when
/// shown.
class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({
    super.key,
    required this.user,
    this.initialSection = ConsoleSection.onboarding,
    this.onLogout,
  });

  final AppUser user;
  final ConsoleSection initialSection;
  final VoidCallback? onLogout;

  static Route<void> route({
    required AppUser user,
    ConsoleSection initialSection = ConsoleSection.onboarding,
    VoidCallback? onLogout,
  }) =>
      SpherePageRoute<void>(
        builder: (_) => AdminConsolePage(user: user, initialSection: initialSection, onLogout: onLogout),
      );

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  late ConsoleSection _active = widget.initialSection;
  late final Set<ConsoleSection> _visited = {widget.initialSection};
  int _turn = 0;

  void _select(ConsoleSection section) {
    if (section == _active) return;
    setState(() {
      _active = section;
      _visited.add(section);
      _turn++;
    });
  }

  void _openEmployee(String employeeId) {
    Navigator.of(context).push(EmployeeProfilePage.route(
      user: widget.user,
      employeeId: employeeId,
      onLogout: widget.onLogout,
    ));
  }

  Widget _viewFor(ConsoleSection section) => switch (section) {
        ConsoleSection.onboarding =>
          OnboardingView(user: widget.user, onOpenEmployee: _openEmployee, onNavigate: _select),
        ConsoleSection.employees => AllEmployeesView(user: widget.user, onOpenEmployee: _openEmployee),
        ConsoleSection.changes => ProfileChangesView(user: widget.user, onOpenEmployee: _openEmployee),
        ConsoleSection.approvals => ApprovalsView(user: widget.user, onOpenEmployee: _openEmployee),
        ConsoleSection.projects => ProjectsView(user: widget.user, onOpenEmployee: _openEmployee),
        ConsoleSection.roles => RolesView(user: widget.user),
        ConsoleSection.structure => StructureView(user: widget.user, onOpenEmployee: _openEmployee),
      };

  void _openOwnProfile() {
    if (EmployeeRepository.instance.byId(widget.user.id) == null) return;
    _openEmployee(widget.user.id);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (!user.role.canManageOrganization) {
      return ConsoleNoAccess(onBack: () => Navigator.of(context).maybePop());
    }
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 1060;
    // Same frame as the dashboards: the top bar, the side menu and the
    // content share one left and one right edge.
    final inset = ConsoleFrame.inset(size.width);
    final hasOwnProfile = EmployeeRepository.instance.byId(user.id) != null;

    final content = Stack(
      children: [
        for (final s in ConsoleSection.values)
          if (_visited.contains(s))
            Offstage(
              key: ValueKey<ConsoleSection>(s),
              offstage: s != _active,
              child: TickerMode(
                enabled: s == _active,
                child: TurnIn(
                  replayKey: s == _active ? _turn : -1,
                  fromSide: wide,
                  child: _ConsoleScroll(
                    // Wide: no top gap, so each view's heading starts level
                    // with the top of the side menu.
                    padding: wide
                        ? EdgeInsets.fromLTRB(_menuGap, 0, inset, 48)
                        : EdgeInsets.fromLTRB(inset, 8, inset, 48),
                    child: _viewFor(s),
                  ),
                ),
              ),
            ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFE),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: HomeColors.skyGradient)),
          ),
          const Positioned.fill(child: DriftingClouds()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, ConsoleFrame.topGap, inset, wide ? 20 : 12),
                  child: ConsoleTopBar(
                    title: wide ? 'HRD Console' : 'HRD Console · ${_active.shortTitle}',
                    user: user,
                    backLabel: 'Back to dashboard',
                    onBack: () => Navigator.of(context).maybePop(),
                    onProfile: hasOwnProfile ? _openOwnProfile : null,
                    onLogout: widget.onLogout,
                  ),
                ),
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MenuStrip(active: _active, onSelect: _select, horizontalPadding: inset),
                  ),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(inset, 0, 0, 24),
                              child: SizedBox(
                                width: _menuWidth,
                                child: _SideMenu(user: user, active: _active, onSelect: _select),
                              ),
                            ),
                            Expanded(child: content),
                          ],
                        )
                      : content,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Width of the side menu and the gap between it and the content.
const double _menuWidth = 272;
const double _menuGap = 24;

/// Each console view scrolls on its own (smooth wheel), so switching keeps
/// every view's scroll position.
class _ConsoleScroll extends StatefulWidget {
  const _ConsoleScroll({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  State<_ConsoleScroll> createState() => _ConsoleScrollState();
}

class _ConsoleScrollState extends State<_ConsoleScroll> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: widget.padding,
        child: SmoothWheelScroll(
          controller: _scroll,
          // Fills the frame: the left edge sits next to the side menu and
          // the right edge under the end of the top bar.
          child: RepaintBoundary(child: widget.child),
        ),
      ),
    );
  }
}

// Side menu geometry. Every row – header, options and the signed-in user –
// puts its 36px tile at the same x and its text at the same x, so the
// icons form one column and the labels another.
const double _menuInset = 14; // panel edge -> option row
const double _rowPadding = 10; // option row edge -> tile
const double _tile = 36;
const double _tileGap = 12;

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.user, required this.active, required this.onSelect});

  final AppUser user;
  final ConsoleSection active;
  final ValueChanged<ConsoleSection> onSelect;

  @override
  Widget build(BuildContext context) {
    const lead = _menuInset + _rowPadding;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.9),
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.95)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 27, 45, 0.18),
            blurRadius: 30,
            spreadRadius: -16,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          ApprovalRepository.instance.requests,
          EmployeeRepository.instance.employees,
        ]),
        builder: (context, _) {
          final pending = ApprovalRepository.instance.pendingCount;
          final incomplete = EmployeeRepository.instance.active.where((e) => !e.isComplete).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- header
              Padding(
                padding: const EdgeInsets.fromLTRB(lead, 22, 18, 0),
                child: Row(
                  children: [
                    Container(
                      width: _tile,
                      height: _tile,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: HomeColors.ink,
                        borderRadius: BorderRadius.all(Radius.circular(11)),
                      ),
                      child: const Icon(Icons.settings_outlined, size: 19, color: Colors.white),
                    ),
                    const SizedBox(width: _tileGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('HRD CONSOLE', maxLines: 1, style: HomeText.display(22, height: 1.0)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Organisation settings',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(12.5, color: HomeColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.fromLTRB(lead, 18, lead, 10),
                color: HomeColors.cardBorder,
              ),
              // ---- options (scroll if the window is short)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(_menuInset, 0, _menuInset, 8),
                  children: [
                    for (final s in ConsoleSection.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _MenuItem(
                          section: s,
                          selected: s == active,
                          badge: switch (s) {
                            ConsoleSection.approvals => pending,
                            ConsoleSection.employees => incomplete,
                            _ => 0,
                          },
                          badgeHint: switch (s) {
                            ConsoleSection.approvals => '$pending pending',
                            ConsoleSection.employees => '$incomplete incomplete profiles',
                            _ => '',
                          },
                          onTap: () => onSelect(s),
                        ),
                      ),
                  ],
                ),
              ),
              // ---- signed-in user, pinned to the bottom of the panel
              Padding(
                padding: const EdgeInsets.fromLTRB(_menuInset, 6, _menuInset, _menuInset),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(_rowPadding, 10, 12, 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F8FC),
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(user: user, size: _tile),
                      const SizedBox(width: _tileGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink)),
                            const SizedBox(height: 1),
                            Text(user.role.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HomeText.body(12, color: HomeColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  const _MenuItem({
    required this.section,
    required this.selected,
    required this.badge,
    required this.badgeHint,
    required this.onTap,
  });

  final ConsoleSection section;
  final bool selected;
  final int badge;
  final String badgeHint;
  final VoidCallback onTap;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final s = widget.section;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final fg = selected ? Colors.white : HomeColors.ink;

    // The label never moves (an earlier version slid and tilted the whole
    // row, which pushed the selected label out of line with the others).
    // The 3D motion is on the icon tile only: one full turn when the option
    // is chosen and a slight tilt on hover. Identity at rest.
    final tile = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 700),
      curve: HomeMotion.ease,
      builder: (context, turn, child) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _hover && !selected ? 1 : 0),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
        curve: HomeMotion.ease,
        child: child,
        builder: (context, tilt, child) {
          final atRest = (turn == 0 || turn == 1) && tilt == 0;
          final matrix = atRest
              ? Matrix4.identity()
              : (Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..multiply(Matrix4.rotationY(2 * math.pi * turn + 0.45 * tilt)));
          return Transform(alignment: Alignment.center, transform: matrix, child: child);
        },
      ),
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
        curve: HomeMotion.ease,
        width: _tile,
        height: _tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color.fromRGBO(255, 255, 255, 0.14) : HomeColors.blueTint,
          borderRadius: const BorderRadius.all(Radius.circular(11)),
        ),
        child: Icon(s.icon, size: 19, color: selected ? Colors.white : HomeColors.blueDeep),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '${s.title}${widget.badge > 0 ? ', ${widget.badgeHint}' : ''}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
            curve: HomeMotion.ease,
            padding: const EdgeInsets.fromLTRB(_rowPadding, 8, 12, 8),
            decoration: BoxDecoration(
              color: selected
                  ? HomeColors.ink
                  : (_hover ? const Color(0xFFF1F6FC) : const Color.fromRGBO(255, 255, 255, 0)),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color.fromRGBO(15, 27, 45, 0.35),
                        blurRadius: 18,
                        spreadRadius: -8,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
                tile,
                const SizedBox(width: _tileGap),
                Expanded(
                  child: Text(s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.body(14, weight: FontWeight.w700, color: fg)),
                ),
                if (widget.badge > 0) ...[
                  const SizedBox(width: 8),
                  CountBadge(count: widget.badge, inverted: selected),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Narrow screens: the options as a scrolling row of pills.
class _MenuStrip extends StatelessWidget {
  const _MenuStrip({required this.active, required this.onSelect, required this.horizontalPadding});

  final ConsoleSection active;
  final ValueChanged<ConsoleSection> onSelect;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ApprovalRepository.instance.requests,
      builder: (context, _) {
        final pending = ApprovalRepository.instance.pendingCount;
        return SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            children: [
              for (final s in ConsoleSection.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: s == active ? HomeColors.ink : Colors.white,
                    shape: StadiumBorder(
                      side: BorderSide(color: s == active ? HomeColors.ink : HomeColors.chipBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onSelect(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(s.icon, size: 17, color: s == active ? Colors.white : HomeColors.ink),
                            const SizedBox(width: 6),
                            Text(s.shortTitle,
                                style: HomeText.body(13.5,
                                    weight: FontWeight.w700, color: s == active ? Colors.white : HomeColors.ink)),
                            if (s == ConsoleSection.approvals && pending > 0) ...[
                              const SizedBox(width: 6),
                              CountBadge(count: pending, inverted: s == active),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown if someone without HRD rights reaches a console page.
class ConsoleNoAccess extends StatelessWidget {
  const ConsoleNoAccess({super.key, required this.onBack, this.message});

  final VoidCallback onBack;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: HomeColors.skyGradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('NO ACCESS', style: HomeText.display(48)),
                const SizedBox(height: 12),
                Text(message ?? 'The HRD console is only available to the HRD team.',
                    textAlign: TextAlign.center, style: HomeText.body(16)),
                const SizedBox(height: 24),
                PillButton(label: 'Go back', onPressed: onBack),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
