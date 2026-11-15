// Organisation-wide data for the Super Admin dashboard and the Team Lead's
// "My Team" view.
//
// Build an [OrgData] from your Spring Boot API later, for example:
//   GET /api/admin/dashboard             (SUPER_ADMIN only – all departments)
//   GET /api/teams/my-department/members (ADMIN / TL – department taken from
//                                          the signed-in user's JWT, never
//                                          from the request)
// [OrgData.sample] is placeholder data for building the UI.

import 'dart:math' as math;

import '../../home/data/home_models.dart';

enum EmployeeStatus {
  allocated('Allocated'),
  available('Available'),
  onLeave('On leave');

  const EmployeeStatus(this.label);
  final String label;
}

/// One row of the employee directory.
class EmployeeRecord {
  const EmployeeRecord({
    required this.id,
    required this.name,
    required this.designation,
    required this.department,
    required this.reportsTo,
    required this.readiness,
    required this.skillCount,
    required this.gapCount,
    required this.topSkills,
    this.projects = const [],
    this.status = EmployeeStatus.allocated,
  });

  final String id;
  final String name;
  final String designation;
  final String department;
  final String reportsTo;

  /// Project readiness, 0–100.
  final int readiness;
  final int skillCount;
  final int gapCount;
  final List<String> topSkills;
  final List<String> projects;
  final EmployeeStatus status;

  String get email => '${name.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@skillsphere.com';

  String get initials {
    final parts = name.split(' ');
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  /// Text the directory search looks in.
  String get searchText =>
      '$id $name $designation $department $reportsTo ${topSkills.join(' ')} ${projects.join(' ')}'
          .toLowerCase();
}

/// Totals for one department, computed from its employees.
class DepartmentSummary {
  const DepartmentSummary({
    required this.name,
    required this.lead,
    required this.headcount,
    required this.avgReadiness,
    required this.openGaps,
    required this.available,
  });

  final String name;
  final String lead;
  final int headcount;
  final int avgReadiness;
  final int openGaps;
  final int available;
}

/// How many employees hold a skill vs how many the projects need.
class SkillDemand {
  const SkillDemand(this.skill, {required this.holders, required this.needed});

  final String skill;
  final int holders;
  final int needed;

  int get shortage => math.max(0, needed - holders);
}

enum ProjectHealth {
  onTrack('On track'),
  atRisk('At risk'),
  staffing('Staffing');

  const ProjectHealth(this.label);
  final String label;
}

class OrgProject {
  const OrgProject({
    required this.name,
    required this.department,
    required this.period,
    required this.members,
    required this.needed,
    required this.matchPercent,
    required this.health,
    this.missingSkills = const [],
  });

  final String name;
  final String department;
  final String period;

  /// People onboarded so far, and the planned team size.
  final int members;
  final int needed;

  /// How well the team's skills match the project's requirements.
  final int matchPercent;
  final ProjectHealth health;
  final List<String> missingSkills;
}

class OrgData {
  const OrgData({
    required this.organizationName,
    required this.departmentLeads,
    required this.employees,
    required this.skillDemand,
    required this.projects,
    required this.pendingVerifications,
  });

  /// The same data with live employees, departments or projects (from the
  /// HRD console repositories).
  OrgData copyWith({
    Map<String, String>? departmentLeads,
    List<EmployeeRecord>? employees,
    List<OrgProject>? projects,
    int? pendingVerifications,
  }) =>
      OrgData(
        organizationName: organizationName,
        departmentLeads: departmentLeads ?? this.departmentLeads,
        employees: employees ?? this.employees,
        skillDemand: skillDemand,
        projects: projects ?? this.projects,
        pendingVerifications: pendingVerifications ?? this.pendingVerifications,
      );

  final String organizationName;

  /// Department name → Team Lead. Also fixes the order departments appear in.
  final Map<String, String> departmentLeads;
  final List<EmployeeRecord> employees;
  final List<SkillDemand> skillDemand;
  final List<OrgProject> projects;

  /// Skill updates waiting for a Team Lead to verify.
  final int pendingVerifications;

  int get headcount => employees.length;

  int get departmentCount => departmentLeads.length;

  int get avgReadiness => _average(employees);

  int get openGaps => employees.fold(0, (sum, e) => sum + e.gapCount);

  int get availableCount =>
      employees.where((e) => e.status == EmployeeStatus.available).length;

  List<String> get departmentNames => departmentLeads.keys.toList();

  List<EmployeeRecord> employeesIn(String department) =>
      employees.where((e) => e.department == department).toList();

  List<DepartmentSummary> get departments => [
        for (final entry in departmentLeads.entries)
          _summarise(entry.key, entry.value, employeesIn(entry.key)),
      ];

  /// Employee counts per readiness band: below 50, 50–69, 70–84, 85+.
  List<int> get readinessBands {
    final bands = [0, 0, 0, 0];
    for (final e in employees) {
      final band = e.readiness < 50
          ? 0
          : e.readiness < 70
              ? 1
              : e.readiness < 85
                  ? 2
                  : 3;
      bands[band]++;
    }
    return bands;
  }

  static const readinessBandLabels = ['Below 50%', '50–69%', '70–84%', '85%+'];

  /// Skills sorted by shortage (largest first), then by how many hold them.
  List<SkillDemand> get skillDemandByShortage => [...skillDemand]
    ..sort((a, b) {
      final byShortage = b.shortage.compareTo(a.shortage);
      return byShortage != 0 ? byShortage : b.holders.compareTo(a.holders);
    });

  /// Strongest skills (blue) mixed with the biggest shortages (orange).
  List<GlobeChip> get globeChips {
    final strong = [...skillDemand.where((s) => s.shortage == 0)]
      ..sort((a, b) => b.holders.compareTo(a.holders));
    final short = skillDemandByShortage.where((s) => s.shortage > 0).take(3).toList();
    final acquired = strong.take(5).map((s) => GlobeChip(s.skill)).toList();
    final gaps = short.map((s) => GlobeChip(s.skill, isGap: true)).toList();
    final result = <GlobeChip>[];
    var a = 0, g = 0;
    for (var i = 0; i < acquired.length + gaps.length; i++) {
      final takeGap = g < gaps.length && (a >= acquired.length || i % 3 == 1);
      result.add(takeGap ? gaps[g++] : acquired[a++]);
    }
    return result;
  }

  static int _average(List<EmployeeRecord> list) => list.isEmpty
      ? 0
      : (list.fold(0, (sum, e) => sum + e.readiness) / list.length).round();

  static DepartmentSummary _summarise(
      String name, String lead, List<EmployeeRecord> people) {
    return DepartmentSummary(
      name: name,
      lead: lead,
      headcount: people.length,
      avgReadiness: _average(people),
      openGaps: people.fold(0, (sum, e) => sum + e.gapCount),
      available: people.where((e) => e.status == EmployeeStatus.available).length,
    );
  }

  // -------------------------------------------------------------------------
  // Sample data (placeholder until the API exists).
  // -------------------------------------------------------------------------
  static const OrgData sample = OrgData(
    organizationName: 'SkillSphere',
    pendingVerifications: 9,
    departmentLeads: {
      'Engineering': 'Priya Raman',
      'Quality Assurance': 'Karthik Subramanian',
      'Data & Analytics': 'Meera Iyer',
      'DevOps & Cloud': 'Arjun Nair',
      'UI/UX Design': 'Divya Menon',
      'Human Resources': 'Anitha Joseph',
    },
    skillDemand: [
      SkillDemand('Java', holders: 14, needed: 12),
      SkillDemand('Spring Boot', holders: 9, needed: 10),
      SkillDemand('Flutter', holders: 6, needed: 7),
      SkillDemand('PostgreSQL', holders: 8, needed: 6),
      SkillDemand('Python', holders: 7, needed: 5),
      SkillDemand('Docker', holders: 6, needed: 6),
      SkillDemand('Kubernetes', holders: 3, needed: 7),
      SkillDemand('AWS', holders: 4, needed: 8),
      SkillDemand('Kafka', holders: 2, needed: 5),
      SkillDemand('Terraform', holders: 2, needed: 4),
    ],
    projects: [
      OrgProject(
        name: 'Talent Hub Revamp',
        department: 'Engineering',
        period: 'Since Aug 2026',
        members: 6,
        needed: 7,
        matchPercent: 86,
        health: ProjectHealth.onTrack,
        missingSkills: ['Firebase'],
      ),
      OrgProject(
        name: 'Payments API Migration',
        department: 'Engineering',
        period: 'Since Jun 2026',
        members: 8,
        needed: 10,
        matchPercent: 68,
        health: ProjectHealth.atRisk,
        missingSkills: ['Kafka', 'Kubernetes'],
      ),
      OrgProject(
        name: 'Analytics Platform',
        department: 'Data & Analytics',
        period: 'Starts Jan 2027',
        members: 5,
        needed: 9,
        matchPercent: 57,
        health: ProjectHealth.staffing,
        missingSkills: ['AWS', 'Terraform', 'Spark'],
      ),
      OrgProject(
        name: 'Customer Portal 2.0',
        department: 'Engineering',
        period: 'Since Sep 2026',
        members: 4,
        needed: 5,
        matchPercent: 81,
        health: ProjectHealth.onTrack,
        missingSkills: ['GraphQL'],
      ),
      OrgProject(
        name: 'Cloud Cost Optimizer',
        department: 'DevOps & Cloud',
        period: 'Since Oct 2026',
        members: 3,
        needed: 4,
        matchPercent: 88,
        health: ProjectHealth.onTrack,
      ),
    ],
    employees: [
      // Engineering
      EmployeeRecord(id: 'EMP-1001', name: 'Priya Raman', designation: 'Team Lead', department: 'Engineering', reportsTo: 'Delivery Head', readiness: 88, skillCount: 24, gapCount: 2, topSkills: ['Java', 'Spring Boot', 'Microservices'], projects: ['Payments API Migration', 'Talent Hub Revamp']),
      EmployeeRecord(id: 'EMP-1002', name: 'Sathish Kumar', designation: 'Senior Software Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 75, skillCount: 18, gapCount: 6, topSkills: ['Java', 'Flutter', 'Spring Boot'], projects: ['Talent Hub Revamp', 'Payments API Migration', 'Analytics Platform']),
      EmployeeRecord(id: 'EMP-1003', name: 'Rahul Verma', designation: 'Software Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 68, skillCount: 14, gapCount: 5, topSkills: ['Java', 'PostgreSQL', 'REST APIs'], projects: ['Payments API Migration']),
      EmployeeRecord(id: 'EMP-1004', name: 'Sneha Reddy', designation: 'Senior Software Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 82, skillCount: 20, gapCount: 3, topSkills: ['Flutter', 'Dart', 'Firebase'], projects: ['Talent Hub Revamp']),
      EmployeeRecord(id: 'EMP-1005', name: 'Vikram Singh', designation: 'Software Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 61, skillCount: 12, gapCount: 6, topSkills: ['Java', 'Spring Boot', 'Docker'], projects: ['Analytics Platform']),
      EmployeeRecord(id: 'EMP-1006', name: 'Lakshmi Narayanan', designation: 'Associate Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 52, skillCount: 9, gapCount: 7, topSkills: ['Java', 'SQL', 'Git'], status: EmployeeStatus.available),
      EmployeeRecord(id: 'EMP-1007', name: 'Aditya Sharma', designation: 'Software Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 73, skillCount: 15, gapCount: 4, topSkills: ['React', 'TypeScript', 'Node.js'], projects: ['Customer Portal 2.0']),
      EmployeeRecord(id: 'EMP-1008', name: 'Fatima Shaikh', designation: 'Senior Software Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 86, skillCount: 22, gapCount: 2, topSkills: ['Kotlin', 'Android', 'Flutter'], projects: ['Talent Hub Revamp']),
      EmployeeRecord(id: 'EMP-1009', name: 'Nikhil Joshi', designation: 'Software Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 66, skillCount: 13, gapCount: 5, topSkills: ['Java', 'Kafka', 'Spring Boot'], projects: ['Payments API Migration']),
      EmployeeRecord(id: 'EMP-1010', name: 'Ananya Krishnan', designation: 'Associate Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 48, skillCount: 8, gapCount: 8, topSkills: ['Python', 'SQL', 'Git'], status: EmployeeStatus.available),
      EmployeeRecord(id: 'EMP-1011', name: 'Mohammed Irfan', designation: 'Software Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 71, skillCount: 14, gapCount: 4, topSkills: ['Flutter', 'Dart', 'REST APIs'], projects: ['Customer Portal 2.0']),
      EmployeeRecord(id: 'EMP-1012', name: 'Pooja Agarwal', designation: 'Senior Software Engineer', department: 'Engineering', reportsTo: 'Priya Raman', readiness: 79, skillCount: 19, gapCount: 3, topSkills: ['Java', 'Spring Boot', 'AWS'], projects: ['Analytics Platform'], status: EmployeeStatus.onLeave),
      // Quality Assurance
      EmployeeRecord(id: 'EMP-1013', name: 'Karthik Subramanian', designation: 'Team Lead', department: 'Quality Assurance', reportsTo: 'Delivery Head', readiness: 84, skillCount: 17, gapCount: 2, topSkills: ['Selenium', 'Test Strategy', 'JMeter'], projects: ['Payments API Migration']),
      EmployeeRecord(id: 'EMP-1014', name: 'Deepa Pillai', designation: 'QA Engineer', department: 'Quality Assurance', reportsTo: 'Karthik Subramanian', readiness: 72, skillCount: 12, gapCount: 3, topSkills: ['Selenium', 'Java', 'Postman'], projects: ['Talent Hub Revamp']),
      EmployeeRecord(id: 'EMP-1015', name: 'Suresh Babu', designation: 'Senior QA Engineer', department: 'Quality Assurance', reportsTo: 'Karthik Subramanian', readiness: 77, skillCount: 14, gapCount: 3, topSkills: ['Appium', 'Cypress', 'Jira'], projects: ['Customer Portal 2.0']),
      EmployeeRecord(id: 'EMP-1016', name: 'Kavya Hegde', designation: 'QA Engineer', department: 'Quality Assurance', reportsTo: 'Karthik Subramanian', readiness: 58, skillCount: 9, gapCount: 5, topSkills: ['Manual Testing', 'Postman', 'SQL'], status: EmployeeStatus.available),
      EmployeeRecord(id: 'EMP-1017', name: 'Rohit Malhotra', designation: 'Automation Engineer', department: 'Quality Assurance', reportsTo: 'Karthik Subramanian', readiness: 69, skillCount: 11, gapCount: 4, topSkills: ['Cypress', 'JavaScript', 'CI/CD'], projects: ['Payments API Migration']),
      EmployeeRecord(id: 'EMP-1018', name: 'Nandini Rao', designation: 'QA Engineer', department: 'Quality Assurance', reportsTo: 'Karthik Subramanian', readiness: 64, skillCount: 10, gapCount: 4, topSkills: ['Playwright', 'TypeScript', 'API Testing'], projects: ['Analytics Platform']),
      // Data & Analytics
      EmployeeRecord(id: 'EMP-1019', name: 'Meera Iyer', designation: 'Team Lead', department: 'Data & Analytics', reportsTo: 'Delivery Head', readiness: 87, skillCount: 21, gapCount: 2, topSkills: ['Python', 'Spark', 'PostgreSQL'], projects: ['Analytics Platform']),
      EmployeeRecord(id: 'EMP-1020', name: 'Arvind Kumar', designation: 'Data Engineer', department: 'Data & Analytics', reportsTo: 'Meera Iyer', readiness: 70, skillCount: 13, gapCount: 4, topSkills: ['Python', 'Airflow', 'SQL'], projects: ['Analytics Platform']),
      EmployeeRecord(id: 'EMP-1021', name: 'Shalini Gupta', designation: 'Data Analyst', department: 'Data & Analytics', reportsTo: 'Meera Iyer', readiness: 74, skillCount: 12, gapCount: 3, topSkills: ['Power BI', 'SQL', 'Excel'], projects: ['Analytics Platform']),
      EmployeeRecord(id: 'EMP-1022', name: 'Harish Chandra', designation: 'Data Engineer', department: 'Data & Analytics', reportsTo: 'Meera Iyer', readiness: 55, skillCount: 10, gapCount: 6, topSkills: ['Python', 'Kafka', 'Spark'], status: EmployeeStatus.available),
      EmployeeRecord(id: 'EMP-1023', name: 'Ritu Bansal', designation: 'Data Scientist', department: 'Data & Analytics', reportsTo: 'Meera Iyer', readiness: 81, skillCount: 16, gapCount: 2, topSkills: ['Python', 'Machine Learning', 'TensorFlow'], projects: ['Analytics Platform']),
      EmployeeRecord(id: 'EMP-1024', name: 'Ganesh Murthy', designation: 'BI Developer', department: 'Data & Analytics', reportsTo: 'Meera Iyer', readiness: 63, skillCount: 11, gapCount: 4, topSkills: ['Tableau', 'SQL', 'DAX'], projects: ['Customer Portal 2.0']),
      // DevOps & Cloud
      EmployeeRecord(id: 'EMP-1025', name: 'Arjun Nair', designation: 'Team Lead', department: 'DevOps & Cloud', reportsTo: 'Delivery Head', readiness: 90, skillCount: 22, gapCount: 1, topSkills: ['Kubernetes', 'AWS', 'Terraform'], projects: ['Cloud Cost Optimizer', 'Payments API Migration']),
      EmployeeRecord(id: 'EMP-1026', name: 'Siddharth Patil', designation: 'DevOps Engineer', department: 'DevOps & Cloud', reportsTo: 'Arjun Nair', readiness: 76, skillCount: 14, gapCount: 3, topSkills: ['Docker', 'Jenkins', 'AWS'], projects: ['Cloud Cost Optimizer']),
      EmployeeRecord(id: 'EMP-1027', name: 'Swathi Ramesh', designation: 'Cloud Engineer', department: 'DevOps & Cloud', reportsTo: 'Arjun Nair', readiness: 68, skillCount: 12, gapCount: 4, topSkills: ['Azure', 'Terraform', 'Linux'], projects: ['Analytics Platform']),
      EmployeeRecord(id: 'EMP-1028', name: 'Manoj Kumar', designation: 'Site Reliability Engineer', department: 'DevOps & Cloud', reportsTo: 'Arjun Nair', readiness: 72, skillCount: 13, gapCount: 3, topSkills: ['Kubernetes', 'Prometheus', 'Grafana'], projects: ['Payments API Migration']),
      EmployeeRecord(id: 'EMP-1029', name: 'Bhavana Shetty', designation: 'DevOps Engineer', department: 'DevOps & Cloud', reportsTo: 'Arjun Nair', readiness: 57, skillCount: 9, gapCount: 5, topSkills: ['Docker', 'GitHub Actions', 'Linux'], status: EmployeeStatus.available),
      // UI/UX Design
      EmployeeRecord(id: 'EMP-1030', name: 'Divya Menon', designation: 'Team Lead', department: 'UI/UX Design', reportsTo: 'Delivery Head', readiness: 85, skillCount: 15, gapCount: 2, topSkills: ['Figma', 'Design Systems', 'UX Research'], projects: ['Talent Hub Revamp']),
      EmployeeRecord(id: 'EMP-1031', name: 'Akash Jain', designation: 'UI Designer', department: 'UI/UX Design', reportsTo: 'Divya Menon', readiness: 71, skillCount: 10, gapCount: 3, topSkills: ['Figma', 'Prototyping', 'Illustration'], projects: ['Customer Portal 2.0']),
      EmployeeRecord(id: 'EMP-1032', name: 'Neha Kapoor', designation: 'UX Researcher', department: 'UI/UX Design', reportsTo: 'Divya Menon', readiness: 66, skillCount: 9, gapCount: 3, topSkills: ['Usability Testing', 'Interviews', 'Miro'], projects: ['Talent Hub Revamp']),
      EmployeeRecord(id: 'EMP-1033', name: 'Varun Desai', designation: 'Product Designer', department: 'UI/UX Design', reportsTo: 'Divya Menon', readiness: 78, skillCount: 12, gapCount: 2, topSkills: ['Figma', 'Interaction Design', 'Flutter'], projects: ['Analytics Platform']),
      // Human Resources
      EmployeeRecord(id: 'EMP-1034', name: 'Anitha Joseph', designation: 'HR Director', department: 'Human Resources', reportsTo: 'Managing Director', readiness: 80, skillCount: 12, gapCount: 1, topSkills: ['Talent Management', 'HR Analytics', 'Workday']),
      EmployeeRecord(id: 'EMP-1035', name: 'Ramya Krishnan', designation: 'HR Business Partner', department: 'Human Resources', reportsTo: 'Anitha Joseph', readiness: 74, skillCount: 10, gapCount: 2, topSkills: ['Recruitment', 'Onboarding', 'Excel']),
      EmployeeRecord(id: 'EMP-1036', name: 'Prakash Rao', designation: 'L&D Specialist', department: 'Human Resources', reportsTo: 'Anitha Joseph', readiness: 77, skillCount: 11, gapCount: 2, topSkills: ['Training Design', 'LMS', 'Coaching']),
    ],
  );
}
