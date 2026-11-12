import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_colors.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/presentation/home_page.dart';

void main() => runApp(const SkillSphereApp());

/// Lets us navigate and show messages from outside a widget's build method.
final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

// ---------------------------------------------------------------------------
// TEMPORARY test login – used only until the Spring Boot auth API is ready.
// Remove these two values before the app is deployed anywhere.
// ---------------------------------------------------------------------------
const _testEmail = 'admin@gmail.com';
const _testPassword = 'root123';

/// Called by the login form's Sign In button.
Future<void> _handleSignIn(String email, String password, bool rememberMe) async {
  // Short pause so the button's loading state is visible, like a real API call.
  await Future<void>.delayed(const Duration(milliseconds: 500));

  final emailMatches = email.trim().toLowerCase() == _testEmail;
  final passwordMatches = password == _testPassword;

  if (emailMatches && passwordMatches) {
    messengerKey.currentState?.hideCurrentSnackBar();
    // pushReplacement: the browser/back button won't return to the login page.
    navigatorKey.currentState?.pushReplacement(HomePage.route());
  } else {
    _showMessage('Incorrect email or password. Please try again.');
  }
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
      home: LoginPage(
        onSignIn: _handleSignIn,
        onForgotPassword: _handleForgotPassword,
      ),
    );
  }
}