import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../home_theme.dart';
import 'home_common.dart';

/// Sections of the Home page the navigation bar can jump to.
enum HomeSection { home, skills, projects, gaps }

extension HomeSectionLabel on HomeSection {
  String get label => const ['Home', 'My Skills', 'Projects', 'Skill Gaps'][index];
}

/// Floating frosted-glass navigation pill pinned to the top of the page.
/// The highlighted link follows the section currently in view.
class HomeNavBar extends StatelessWidget {
  const HomeNavBar({
    super.key,
    required this.active,
    required this.onSelect,
    required this.initials,
    required this.onSearch,
    required this.onNotifications,
    required this.onProfile,
    this.unreadNotifications = 0,
  });

  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;
  final String initials;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final showLinks = width >= 900;
    final showName = width >= 420;
    final unread = unreadNotifications;

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(999)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(15, 27, 45, 0.30),
            blurRadius: 30,
            spreadRadius: -18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.72),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.9)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                children: [
                  _Brand(showName: showName, onTap: () => onSelect(HomeSection.home)),
                  const Spacer(),
                  if (showLinks) ...[
                    for (final section in HomeSection.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _NavLink(
                          label: section.label,
                          selected: section == active,
                          onTap: () => onSelect(section),
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
                    _SectionMenu(active: active, onSelect: onSelect),
                    const SizedBox(width: 8),
                  ],
                  _Avatar(initials: initials, onTap: onProfile),
                ],
              ),
            ),
          ),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.onTap});

  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'My profile',
      child: Material(
        color: HomeColors.blue,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                initials,
                style: HomeText.body(14, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// On narrow screens the section links move into this menu.
class _SectionMenu extends StatelessWidget {
  const _SectionMenu({required this.active, required this.onSelect});

  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HomeSection>(
      tooltip: 'Sections',
      onSelected: onSelect,
      offset: const Offset(0, 54),
      color: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      itemBuilder: (context) => [
        for (final section in HomeSection.values)
          PopupMenuItem<HomeSection>(
            value: section,
            child: Text(
              section.label,
              style: HomeText.body(15,
                  weight: section == active ? FontWeight.w800 : FontWeight.w500,
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
