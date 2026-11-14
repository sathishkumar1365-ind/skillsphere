import 'package:flutter/foundation.dart';

import 'app_user.dart';

/// Thrown when sign-in fails. [message] is safe to show to the user.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Signs users in and remembers who is signed in.
///
/// TEMPORARY: checks three hard-coded test accounts. Later, replace the body
/// of [signIn] with a call to the Spring Boot API (POST /api/auth/login),
/// which returns a JWT plus the user's role and department. Everything else
/// in the app keeps working unchanged.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// The signed-in user, or null when signed out.
  final ValueNotifier<AppUser?> currentUser = ValueNotifier<AppUser?>(null);

  // -------------------------------------------------------------------------
  // TEMPORARY test accounts – only until the Spring Boot auth API is ready.
  // This code is public on GitHub: never put real passwords here.
  // -------------------------------------------------------------------------
  static const Map<String, _TestAccount> _testAccounts = {
    // Super Admin (HRD Team) → Overall Dashboard
    'hrd@gmail.com': _TestAccount(
      password: 'hrd123',
      user: AppUser(
        id: 'EMP-1034',
        name: 'Anitha Joseph',
        email: 'hrd@gmail.com',
        role: UserRole.superAdmin,
        department: 'Human Resources',
        designation: 'HR Director',
      ),
    ),
    // Admin (Team Lead) → Home page + "My Team" (own department only)
    'tl@gmail.com': _TestAccount(
      password: 'teamlead123',
      user: AppUser(
        id: 'EMP-1001',
        name: 'Priya Raman',
        email: 'tl@gmail.com',
        role: UserRole.admin,
        department: 'Engineering',
        designation: 'Team Lead',
      ),
    ),
    // End User (Employee) → Home page – the existing test login
    'admin@gmail.com': _TestAccount(
      password: 'root123',
      user: AppUser(
        id: 'EMP-1002',
        name: 'Sathish Kumar',
        email: 'admin@gmail.com',
        role: UserRole.endUser,
        department: 'Engineering',
        designation: 'Senior Software Engineer',
      ),
    ),
  };

  Future<AppUser> signIn(String email, String password) async {
    // Short pause so the button's loading state is visible, like a real API call.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final account = _testAccounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthException('Incorrect email or password. Please try again.');
    }
    currentUser.value = account.user;
    return account.user;
  }

  void signOut() {
    currentUser.value = null;
  }
}

class _TestAccount {
  const _TestAccount({required this.password, required this.user});

  final String password;
  final AppUser user;
}
