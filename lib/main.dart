import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_colors.dart';
import 'core/auth/app_user.dart';
import 'core/auth/auth_service.dart';
import 'core/sphere_page_route.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/data/home_models.dart';
import 'features/home/presentation/home_page.dart';
import 'features/organization/data/org_models.dart';
import 'features/organization/presentation/org_dashboard_page.dart';

void main() => runApp(const SkillSphereApp());

/// Lets us navigate and show messages from outside a widget's build method.
final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

// ---------------------------------------------------------------------------
// TEMPORARY test logins (see lib/core/auth/auth_service.dart):
//   Super Admin (HRD) : hrd@gmail.com   / hrd123   → Overall Dashboard
//   Admin (Team Lead) : tl@gmail.com    / teamlead123 → Home + "My Team"
//   End User          : admin@gmail.com / root123  → Home
// ---------------------------------------------------------------------------

/// Called by the login form's Sign In button.
Future<void> _handleSignIn(String email, String password, bool rememberMe) async {
  try {
    final user = await AuthService.instance.signIn(email, password);
    messengerKey.currentState?.hideCurrentSnackBar();
    // pushReplacement: the browser/back button won't return to the login page.
    navigatorKey.currentState?.pushReplacement(_landingRouteFor(user));
  } on AuthException catch (e) {
    _showMessage(e.message);
  }
}

/// Where each role lands after signing in.
Route<void> _landingRouteFor(AppUser user) => switch (user.role) {
      UserRole.superAdmin => OrgDashboardPage.route(
          user: user,
          data: OrgData.sample,
          onLogout: _handleLogout,
        ),
      UserRole.admin => HomePage.route(
          user: user,
          data: _homeDataFor(user),
          // No team list passed: the Home page shows the Team Lead's OWN
          // department live from the HRD console data.
          onLogout: _handleLogout,
        ),
      UserRole.endUser => HomePage.route(
          user: user,
          data: _homeDataFor(user),
          onLogout: _handleLogout,
        ),
    };

/// Sample Home data greeting the signed-in user by name.
HomeData _homeDataFor(AppUser user) =>
    HomeData.sample.copyWith(firstName: user.firstName, initials: user.initials);

void _handleLogout() {
  AuthService.instance.signOut();
  messengerKey.currentState?.hideCurrentSnackBar();
  // Clear every page so Back can't return to the signed-in screens.
  navigatorKey.currentState?.pushAndRemoveUntil(
    SpherePageRoute<void>(builder: (_) => _buildLoginPage()),
    (route) => false,
  );
}

void _handleForgotPassword() {
  _showMessage('Password reset is not connected yet. Please contact your administrator.');
}

void _showMessage(String text) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
    ));
}

Widget _buildLoginPage() => LoginPage(
      onSignIn: _handleSignIn,
      onForgotPassword: _handleForgotPassword,
    );

class SkillSphereApp extends StatelessWidget {
  const SkillSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkillSphere',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.black),
        scaffoldBackgroundColor: AppColors.skyBottom,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: _buildLoginPage(),
    );
  }
}
