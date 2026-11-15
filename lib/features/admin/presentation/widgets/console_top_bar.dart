import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/account_menu.dart';
import '../../../home/presentation/widgets/home_common.dart';

/// The page frame shared with the dashboards (see SphereScrollPage): the
/// same max width and side padding, so the top bar, the avatar and the page
/// content line up with the dashboard's navigation bar.
class ConsoleFrame {
  ConsoleFrame._();

  /// Width of the content between the side paddings on large screens.
  static const double contentWidth = 1200;

  /// Gap between the top of the window and the bar (same as dashboards).
  static const double topGap = 16;

  static double sidePadding(double screenWidth) => screenWidth < 600 ? 18 : 32;

  static double maxWidth(double screenWidth) => contentWidth + sidePadding(screenWidth) * 2;

  /// Distance from the window edge to the frame's content edge: the side
  /// padding plus, on screens wider than the frame, half of the leftover
  /// width. Used as padding (instead of centring a box) so scroll views can
  /// still reach the window edge and take mouse-wheel input there.
  static double inset(double screenWidth) {
    final extra = (screenWidth - maxWidth(screenWidth)) / 2;
    return sidePadding(screenWidth) + (extra > 0 ? extra : 0);
  }
}

/// Floating top bar for pages opened from a dashboard (HRD console,
/// employee profile, team directory): a back button, the brand, the page
/// title, optional section links and the account menu.
///
/// Same height (64), border and account menu as the dashboard's
/// navigation bar, so moving between the pages does not shift anything.
class ConsoleTopBar extends StatelessWidget {
  const ConsoleTopBar({
    super.key,
    required this.title,
    required this.user,
    required this.onBack,
    this.backLabel = 'Back',
    this.onProfile,
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

  /// "My profile" in the account menu – hidden when null.
  final VoidCallback? onProfile;
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
    // Room the links need: each one is its label (~8.2px a character at
    // 14px) plus 44px padding; the rest of the bar needs about 520px.
    final linksWidth = links.fold<double>(0, (sum, l) => sum + l.length * 8.2 + 44);
    final showLinks = links.isNotEmpty && select != null && width >= linksWidth + 520;
    final showBrand = width >= 560;
    // Brand and title use the same font size, so their baselines line up
    // (two sizes centred in one row sit on different baselines).
    const textSize = 16.0;

    return Container(
      padding: const EdgeInsets.all(10),
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
            const SizedBox(width: 14),
            if (showBrand) ...[
              const SphereMark(size: 28),
              const SizedBox(width: 10),
              Text('SkillSphere',
                  maxLines: 1,
                  style: HomeText.body(textSize, weight: FontWeight.w800, color: HomeColors.ink, letterSpacing: -0.3)),
              Container(
                width: 1.5,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(
                  color: HomeColors.divider,
                  borderRadius: BorderRadius.all(Radius.circular(1)),
                ),
              ),
            ],
            // Expanded (not Flexible + Spacer): a loose Flexible leaves its
            // unused share of the free space AFTER the last child, which
            // parked the avatar in the middle of the bar.
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HomeText.body(textSize, weight: FontWeight.w600, color: HomeColors.body),
              ),
            ),
            const SizedBox(width: 12),
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
            AccountMenuButton(user: user, onProfile: onProfile, onLogout: onLogout),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? HomeColors.ink : const Color.fromRGBO(15, 27, 45, 0),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
          child: Text(label,
              maxLines: 1,
              style: HomeText.body(14, weight: FontWeight.w600, color: selected ? Colors.white : HomeColors.ink)),
        ),
      ),
    );
  }
}
