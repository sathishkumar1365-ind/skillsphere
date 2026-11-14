/// Who can see what in SkillSphere.
///
/// * [superAdmin] – HRD team. Lands on the Overall Dashboard and sees every
///   employee in every department.
/// * [admin] – Team Lead (TL). Lands on the normal Home page, plus a
///   "My Team" option showing the employees of their own department.
/// * [endUser] – Employee. Lands on the normal Home page only.
enum UserRole {
  superAdmin(label: 'Super Admin', team: 'HRD Team'),
  admin(label: 'Admin', team: 'Team Lead'),
  endUser(label: 'End User', team: 'Employee');

  const UserRole({required this.label, required this.team});

  /// Name of the access level, e.g. "Super Admin".
  final String label;

  /// Who holds it, e.g. "HRD Team".
  final String team;

  /// "Super Admin · HRD Team"
  String get description => '$label · $team';

  /// Organisation-wide data (all departments): Super Admin only.
  bool get canViewOrganization => this == UserRole.superAdmin;

  /// Employee information of a department: Super Admin and Team Leads.
  bool get canViewTeam => this == UserRole.superAdmin || this == UserRole.admin;

  /// Maps the role string the Spring Boot API will send (e.g. in the JWT).
  static UserRole fromApi(String value) => switch (value.toUpperCase()) {
        'SUPER_ADMIN' => UserRole.superAdmin,
        'ADMIN' || 'TEAM_LEAD' => UserRole.admin,
        _ => UserRole.endUser,
      };
}

/// The signed-in user.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    required this.designation,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;

  /// A Team Lead only sees employees of this department.
  final String department;
  final String designation;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}
