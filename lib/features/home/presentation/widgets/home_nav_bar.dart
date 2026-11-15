import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../home_theme.dart';
import 'account_menu.dart';
import 'home_common.dart';

/// Floating navigation pill pinned to the top of the page.
/// The highlighted link follows the section currently in view.
///
/// Used by the Home page and the Super Admin dashboard: pass the section
/// names in [links] and the highlighted one in [activeIndex].
///
/// Note: an earlier version blurred the page behind the bar
/// (BackdropFilter). On Flutter web that blur is recalculated on every
/// scroll frame and was a main cause of scroll lag, so the bar is now
/// near-opaque white instead.
class HomeNavBar extends StatelessWidget {
  const HomeNavBar({
    super.key,
    required this.links,
    required this.activeIndex,
    required this.onSelect,
    required this.user,
    required this.onSearch,
    required this.onNotifications,
    required this.onProfile,
    required this.onLogout,
    this.unreadNotifications = 0,
    this.onOpenConsole,
    this.consoleBadge = 0,
  });

  final List<String> links;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final AppUser user;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  final int unreadNotifications;

  /// Opens the HRD console (settings icon). Pass it ONLY for the HRD team:
  /// the icon is not shown when this is null.
  final VoidCallback? onOpenConsole;

  /// Items waiting in the console (e.g. pending approvals) – shown as a dot.
  final int consoleBadge;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // More links need more room; below the threshold they move into a menu.
    final extra = onOpenConsole == null ? 0 : 52;
    final showLinks =
        width >= (links.length > 5 ? 1120 : (links.length > 4 ? 1040 : 900)) + extra;
    final hasConsole = onOpenConsole != null;
    // The settings icon needs 52px more: hide the brand name sooner, and
    // on very narrow screens drop the (not yet connected) search button.
    final showName = width >= (hasConsole ? 500 : 420);
    final showSearch = !hasConsole || width >= 380;
    final unread = unreadNotifications;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.94),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.95)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 27, 45, 0.22),
            blurRadius: 24,
            spreadRadius: -14,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            _Brand(showName: showName, onTap: () => onSelect(0)),
            const Spacer(),
            if (showLinks) ...[
              for (var i = 0; i < links.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _NavLink(
                    label: links[i],
                    selected: i == activeIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
              const Spacer(),
            ],
            if (onOpenConsole case final openConsole?) ...[
              _RoundIconButton(
                icon: Icons.settings_outlined,
                tooltip: consoleBadge > 0
                    ? 'HRD console, $consoleBadge waiting for approval'
                    : 'HRD console',
                onTap: openConsole,
                showDot: consoleBadge > 0,
                spinOnHover: true,
              ),
              const SizedBox(width: 8),
            ],
            if (showSearch) ...[
              _RoundIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onTap: onSearch,
              ),
              const SizedBox(width: 8),
            ],
            _RoundIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: unread > 0 ? 'Notifications, $unread new' : 'Notifications',
              onTap: onNotifications,
              showDot: unread > 0,
            ),
            const SizedBox(width: 8),
            if (!showLinks) ...[
              _SectionMenu(links: links, activeIndex: activeIndex, onSelect: onSelect),
              const SizedBox(width: 8),
            ],
            AccountMenuButton(user: user, onProfile: onProfile, onLogout: onLogout),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.showName, required this.onTap});

  final bool showName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SkillSphere, back to top',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SphereMark(size: 30),
              if (showName) ...[
                const SizedBox(width: 10),
                Text(
                  'SkillSphere',
                  style: HomeText.body(20,
                      weight: FontWeight.w800,
                      color: HomeColors.ink,
                      letterSpacing: -0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: HomeMotion.ease,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? HomeColors.ink : const Color.fromRGBO(15, 27, 45, 0),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 350),
            style: HomeText.body(14,
                weight: FontWeight.w600,
                color: selected ? Colors.white : HomeColors.ink),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatefulWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
    this.spinOnHover = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;

  /// Turns the icon a little on hover (used by the settings gear).
  final bool spinOnHover;

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    final tooltip = widget.tooltip;
    final onTap = widget.onTap;
    final showDot = widget.showDot;
    final turns = widget.spinOnHover && _hover && !MediaQuery.disableAnimationsOf(context) ? 0.25 : 0.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: HomeColors.divider)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onHover: widget.spinOnHover ? (value) => setState(() => _hover = value) : null,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedRotation(
                  turns: turns,
                  duration: const Duration(milliseconds: 450),
                  curve: HomeMotion.ease,
                  child: Icon(icon, size: 20, color: HomeColors.ink),
                ),
                if (showDot)
                  Positioned(
                    top: 10,
                    right: 11,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: HomeColors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// On narrow screens the section links move into this menu.
class _SectionMenu extends StatelessWidget {
  const _SectionMenu({required this.links, required this.activeIndex, required this.onSelect});

  final List<String> links;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Sections',
      onSelected: onSelect,
      offset: const Offset(0, 54),
      color: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      itemBuilder: (context) => [
        for (var i = 0; i < links.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(
              links[i],
              style: HomeText.body(15,
                  weight: i == activeIndex ? FontWeight.w800 : FontWeight.w500,
                  color: HomeColors.ink),
            ),
          ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: HomeColors.divider),
        ),
        child: const Icon(Icons.menu_rounded, size: 20, color: HomeColors.ink),
      ),
    );
  }
}
