import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../home_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Five links need a little more room than four.
    final showLinks = width >= (links.length > 4 ? 1040 : 900);
    final showName = width >= 420;
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
            _RoundIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onTap: onSearch,
            ),
            const SizedBox(width: 8),
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
            _ProfileMenu(user: user, onProfile: onProfile, onLogout: onLogout),
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: HomeColors.divider)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20, color: HomeColors.ink),
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

enum _ProfileAction { profile, logout }

/// Avatar button. Opens a menu with the user's name, role and Log out.
class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.user, required this.onProfile, required this.onLogout});

  final AppUser user;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final isEmployee = user.role == UserRole.endUser;
    return PopupMenuButton<_ProfileAction>(
      tooltip: 'Account',
      offset: const Offset(0, 54),
      color: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
      onSelected: (action) => action == _ProfileAction.logout ? onLogout() : onProfile(),
      itemBuilder: (context) => [
        PopupMenuItem<_ProfileAction>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.name,
                    style: HomeText.body(16, weight: FontWeight.w800, color: HomeColors.ink)),
                const SizedBox(height: 2),
                Text(user.email, style: HomeText.body(13, color: HomeColors.muted)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isEmployee ? HomeColors.neutralTint : HomeColors.blueTint,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    user.role.description,
                    style: HomeText.body(12,
                        weight: FontWeight.w700,
                        color: isEmployee ? HomeColors.body : HomeColors.blueDeep),
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_ProfileAction>(
          value: _ProfileAction.profile,
          child: _MenuRow(icon: Icons.person_outline_rounded, label: 'My profile'),
        ),
        const PopupMenuItem<_ProfileAction>(
          value: _ProfileAction.logout,
          child: _MenuRow(icon: Icons.logout_rounded, label: 'Log out'),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: HomeColors.blue, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          user.initials,
          style: HomeText.body(14, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: HomeColors.ink),
        const SizedBox(width: 12),
        Text(label, style: HomeText.body(15, weight: FontWeight.w600, color: HomeColors.ink)),
      ],
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
