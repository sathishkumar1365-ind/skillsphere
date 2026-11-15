import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../home_theme.dart';

enum _AccountAction { profile, logout }

/// The signed-in user's avatar button and its menu (name, email, role,
/// My profile, Log out). Shared by the dashboard navigation bar and the
/// HRD console top bar so both look and line up the same.
///
/// Layout of the open menu – everything sits on two vertical lines:
/// the avatar and the row icons share one centre line, and the name,
/// email, role badge and row labels share one left edge.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({
    super.key,
    required this.user,
    this.onProfile,
    this.onLogout,
  });

  final AppUser user;

  /// "My profile" – hidden when null.
  final VoidCallback? onProfile;

  /// "Log out" – hidden when null.
  final VoidCallback? onLogout;

  static const double _itemPadding = 16;
  static const double _leadWidth = 40;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final profile = onProfile;
    final logout = onLogout;
    final isEmployee = user.role == UserRole.endUser;
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      offset: const Offset(0, 54),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
      onSelected: (action) {
        if (action == _AccountAction.profile) {
          profile?.call();
        } else {
          logout?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(_itemPadding, 14, _itemPadding, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(user: user, size: _leadWidth),
                const SizedBox(width: _gap),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HomeText.body(15.5, weight: FontWeight.w800, color: HomeColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HomeText.body(13, color: HomeColors.muted),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isEmployee ? HomeColors.neutralTint : HomeColors.blueTint,
                          borderRadius: const BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text(
                          user.role.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HomeText.body(12,
                              weight: FontWeight.w700,
                              color: isEmployee ? HomeColors.body : HomeColors.blueDeep),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (profile != null || logout != null) const PopupMenuDivider(),
        if (profile != null)
          const PopupMenuItem<_AccountAction>(
            value: _AccountAction.profile,
            padding: EdgeInsets.symmetric(horizontal: _itemPadding),
            child: _AccountRow(icon: Icons.person_outline_rounded, label: 'My profile'),
          ),
        if (logout != null)
          const PopupMenuItem<_AccountAction>(
            value: _AccountAction.logout,
            padding: EdgeInsets.symmetric(horizontal: _itemPadding),
            child: _AccountRow(icon: Icons.logout_rounded, label: 'Log out'),
          ),
      ],
      child: UserAvatar(user: user, size: 44),
    );
  }
}

/// Round avatar with the user's initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 44});

  final AppUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: HomeColors.blue, shape: BoxShape.circle),
      child: Text(
        user.initials,
        maxLines: 1,
        style: HomeText.body(size * 0.32, weight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Same width as the avatar above, so icon and avatar share a centre line.
        SizedBox(
          width: AccountMenuButton._leadWidth,
          child: Center(child: Icon(icon, size: 20, color: HomeColors.ink)),
        ),
        const SizedBox(width: AccountMenuButton._gap),
        Text(label, style: HomeText.body(15, weight: FontWeight.w600, color: HomeColors.ink)),
      ],
    );
  }
}
