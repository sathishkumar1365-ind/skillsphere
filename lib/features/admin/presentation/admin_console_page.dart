import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/sphere_page_route.dart';
import '../../home/presentation/home_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (!user.role.canManageOrganization) {
      return ConsoleNoAccess(onBack: () => Navigator.of(context).maybePop());
    }
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 1060;
    final side = size.width < 600 ? 14.0 : 24.0;

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
                    padding: EdgeInsets.fromLTRB(wide ? 8 : side, 8, side, 48),
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
                  padding: EdgeInsets.fromLTRB(side, 14, side, wide ? 18 : 12),
                  child: ConsoleTopBar(
                    title: 'HRD Console',
                    user: user,
                    backLabel: 'Back to dashboard',
                    onBack: () => Navigator.of(context).maybePop(),
                    onLogout: widget.onLogout,
                  ),
                ),
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MenuStrip(active: _active, onSelect: _select, horizontalPadding: side),
                  ),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(side, 0, 8, 24),
                              child: SizedBox(
                                width: 284,
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: RepaintBoundary(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.user, required this.active, required this.onSelect});

  final AppUser user;
  final ConsoleSection active;
  final ValueChanged<ConsoleSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 22, color: HomeColors.ink),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('HRD CONSOLE', style: HomeText.display(26, height: 1)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
                child: Text('People, projects and organisation settings.',
                    style: HomeText.body(13, color: HomeColors.muted, height: 1.45)),
              ),
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
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F8FC),
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: HomeColors.blue, shape: BoxShape.circle),
                      child: Text(user.initials,
                          style: HomeText.body(13, weight: FontWeight.w800, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink)),
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
    final lift = selected ? 1.0 : (_hover ? 0.55 : 0.0);
    final fg = selected ? Colors.white : HomeColors.ink;

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
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: lift),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 380),
            curve: HomeMotion.ease,
            builder: (context, t, child) {
              // A slight turn toward the content area, like a page tab
              // being pulled out. Identity at rest.
              final matrix = t == 0
                  ? Matrix4.identity()
                  : (Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..multiply(Matrix4.translationValues(6 * t, 0, 0))
                    ..multiply(Matrix4.rotationY(-0.10 * t)));
              return Transform(
                alignment: Alignment.centerLeft,
                transform: matrix,
                child: AnimatedContainer(
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
                  curve: HomeMotion.ease,
                  padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
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
                        : null,
                  ),
                  child: child,
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? const Color.fromRGBO(255, 255, 255, 0.14) : HomeColors.blueTint,
                    borderRadius: const BorderRadius.all(Radius.circular(11)),
                  ),
                  child: Icon(s.icon, size: 19, color: selected ? Colors.white : HomeColors.blueDeep),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.body(14, weight: FontWeight.w700, color: fg)),
                ),
                if (widget.badge > 0) CountBadge(count: widget.badge, inverted: selected),
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
