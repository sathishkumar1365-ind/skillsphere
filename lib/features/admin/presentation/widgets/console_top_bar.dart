import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';

/// Floating top bar for pages opened from a dashboard (HRD console,
/// employee profile, team directory): a back button, the brand, the page
/// title, optional section links and the account menu.
class ConsoleTopBar extends StatelessWidget {
  const ConsoleTopBar({
    super.key,
    required this.title,
    required this.user,
    required this.onBack,
    this.backLabel = 'Back',
    this.onLogout,
    this.links = const [],
    this.activeIndex = 0,
    this.onSelect,
    this.actions = const [],
  });

  final String title;
  final AppUser user;
  final VoidCallback onBack;
  final String backLabel;
  final VoidCallback? onLogout;

  /// Optional section links (e.g. on the profile page).
  final List<String> links;
  final int activeIndex;
  final ValueChanged<int>? onSelect;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final select = onSelect;
    final showLinks = links.isNotEmpty && select != null && width >= 140.0 * links.length + 420;
    final showBrand = width >= 560;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: const BoxDecoration(
        color: Color.fromRGBO(255, 255, 255, 0.94),
        borderRadius: BorderRadius.all(Radius.circular(999)),
        boxShadow: [
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
            Tooltip(
              message: backLabel,
              child: HoverRaise(
                child: Material(
                  color: HomeColors.ink,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onBack,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (showBrand) ...[
              const SphereMark(size: 26),
              const SizedBox(width: 8),
              Text('SkillSphere',
                  style: HomeText.body(16, weight: FontWeight.w800, color: HomeColors.ink, letterSpacing: -0.3)),
              Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: HomeColors.divider,
              ),
            ],
            Flexible(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HomeText.body(13, weight: FontWeight.w800, color: HomeColors.ink, letterSpacing: 1.3),
              ),
            ),
            const Spacer(),
            if (showLinks && select != null)
              for (var i = 0; i < links.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _Link(label: links[i], selected: i == activeIndex, onTap: () => select(i)),
                ),
            if (!showLinks && links.isNotEmpty && select != null)
              PopupMenuButton<int>(
                tooltip: 'Sections',
                onSelected: select,
                offset: const Offset(0, 54),
                color: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                itemBuilder: (context) => [
                  for (var i = 0; i < links.length; i++)
                    PopupMenuItem<int>(
                      value: i,
                      child: Text(links[i],
                          style: HomeText.body(15,
                              weight: i == activeIndex ? FontWeight.w800 : FontWeight.w500, color: HomeColors.ink)),
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
              ),
            for (final a in actions) ...[const SizedBox(width: 8), a],
            const SizedBox(width: 8),
            _AccountMenu(user: user, onLogout: onLogout),
          ],
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.selected, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? HomeColors.ink : const Color.fromRGBO(15, 27, 45, 0),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
          child: Text(label,
              style: HomeText.body(13.5, weight: FontWeight.w600, color: selected ? Colors.white : HomeColors.ink)),
        ),
      ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final logout = onLogout;
    return PopupMenuButton<int>(
      tooltip: 'Account',
      offset: const Offset(0, 54),
      color: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
      onSelected: (_) => logout?.call(),
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.name, style: HomeText.body(16, weight: FontWeight.w800, color: HomeColors.ink)),
                const SizedBox(height: 2),
                Text(user.email, style: HomeText.body(13, color: HomeColors.muted)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: const BoxDecoration(
                    color: HomeColors.blueTint,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(user.role.description,
                      style: HomeText.body(12, weight: FontWeight.w700, color: HomeColors.blueDeep)),
                ),
              ],
            ),
          ),
        ),
        if (logout != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<int>(
            value: 1,
            child: Row(
              children: [
                const Icon(Icons.logout_rounded, size: 20, color: HomeColors.ink),
                const SizedBox(width: 12),
                Text('Log out', style: HomeText.body(15, weight: FontWeight.w600, color: HomeColors.ink)),
              ],
            ),
          ),
        ],
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: HomeColors.blue, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(user.initials, style: HomeText.body(14, weight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}
