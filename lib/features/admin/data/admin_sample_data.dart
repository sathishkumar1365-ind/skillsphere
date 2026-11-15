// Placeholder data for the HRD console until the Spring Boot API exists.
//
// Employees are built from OrgData.sample (EMP-1001 … EMP-1036) so the
// dashboard, the competency library and the console all show the same
// people. Competency ids match competency_sample_data.dart:
//   CMP-001 Java · 002 Python · 003 Dart · 004 SQL · 005 Jira · 006 Docker ·
//   007 Kubernetes · 008 Figma · 009 Selenium · 010 Project Management ·
//   011 Microservices · 012 UX Research · 013 Machine Learning ·
//   014 Atlassian · 015 Banking & Payments · 016 HR & Talent Management

import '../../competency/data/level_hours_policy.dart';
import '../../organization/data/org_models.dart';
import 'approvals.dart';
import 'crowd.dart';
import 'employees.dart';
import 'job_roles.dart';
import 'org_structure.dart';
import 'projects.dart';

// ------------------------------------------------------------- structure
//
// Division → Group → Department.

final List<OrgDivision> sampleDivisions = [
  OrgDivision(
    id: 'DIV-01',
    name: 'Research & Development',
    code: 'RND',
    description: 'Vehicle and application software, validation and quality engineering.',
    crowdGroup: 'div-research-development',
    createdAt: DateTime(2024, 1, 8),
  ),
  OrgDivision(
    id: 'DIV-02',
    name: 'Digital & IT',
    code: 'DIT',
    description: 'Data, analytics, cloud platforms and enterprise IT.',
    crowdGroup: 'div-digital-it',
    createdAt: DateTime(2024, 1, 8),
  ),
  OrgDivision(
    id: 'DIV-03',
    name: 'Corporate Management',
    code: 'CM',
    headId: 'EMP-1034',
    description: 'Human resources, finance and the other corporate functions.',
    crowdGroup: 'div-corporate',
    createdAt: DateTime(2024, 1, 8),
  ),
];

final List<OrgGroup> sampleGroups = [
  OrgGroup(
    id: 'GRP-01',
    name: 'Software Development',
    code: 'SWD',
    divisionId: 'DIV-01',
    description: 'Application and product software teams.',
    crowdGroup: 'grp-software-development',
    createdAt: DateTime(2024, 1, 8),
  ),
  OrgGroup(
    id: 'GRP-02',
    name: 'Quality & Validation',
    code: 'QV',
    divisionId: 'DIV-01',
    description: 'Testing, validation and quality engineering.',
    crowdGroup: 'grp-quality-validation',
    createdAt: DateTime(2024, 1, 8),
  ),
  OrgGroup(
    id: 'GRP-03',
    name: 'Data & Cloud Platforms',
    code: 'DCP',
    divisionId: 'DIV-02',
    description: 'Data engineering, analytics, DevOps and cloud.',
    crowdGroup: 'grp-data-cloud',
    createdAt: DateTime(2024, 1, 8),
  ),
  OrgGroup(
    id: 'GRP-04',
    name: 'Corporate Functions',
    code: 'CORP',
    divisionId: 'DIV-03',
    description: 'Human resources and other corporate teams.',
    crowdGroup: 'grp-corporate',
    createdAt: DateTime(2024, 1, 8),
  ),
];

final List<OrgDepartment> sampleDepartments = [
  OrgDepartment(
    id: 'DEP-01',
    name: 'Engineering',
    code: 'ENG',
    groupId: 'GRP-01',
    headId: 'EMP-1001',
    description: 'Backend, mobile and web development.',
    crowdGroup: 'dept-engineering',
    createdAt: DateTime(2024, 1, 8),
  ),
  OrgDepartment(
    id: 'DEP-02',
    name: 'Quality Assurance',
    code: 'QA',
    groupId: 'GRP-02',
    headId: 'EMP-1013',
    description: 'Manual and automated testing.',
    crowdGroup: 'dept-quality-assurance',
    createdAt: DateTime(2024, 1, 8),
  ),
  OrgDepartment(
    id: 'DEP-03',
    name: 'Data & Analytics',
    code: 'DA',
    groupId: 'GRP-03',
    headId: 'EMP-1019',
    description: 'Data pipelines, BI and machine learning.',
    crowdGroup: 'dept-data-analytics',
    createdAt: DateTime(2024, 1, 8),
  ),
  OrgDepartment(
    id: 'DEP-04',
    name: 'DevOps & Cloud',
    code: 'DOC',
    groupId: 'GRP-03',
    headId: 'EMP-1025',
    description: 'CI/CD, infrastructure and site reliability.',
    crowdGroup: 'dept-devops-cloud',
    createdAt: DateTime(2024, 1, 8),
  ),
  OrgDepartment(
    id: 'DEP-05',
    name: 'UI/UX Design',
    code: 'UX',
    groupId: 'GRP-01',
    headId: 'EMP-1030',
    description: 'Product design and user research.',
    crowdGroup: 'dept-ui-ux',
    createdAt: DateTime(2024, 1, 8),
  ),
  OrgDepartment(
    id: 'DEP-06',
    name: 'Human Resources',
    code: 'HR',
    groupId: 'GRP-04',
    headId: 'EMP-1034',
    description: 'Talent, learning and people operations.',
    crowdGroup: 'dept-human-resources',
    createdAt: DateTime(2024, 1, 8),
  ),
];

// ----------------------------------------------------------------- roles

final List<JobRole> sampleRoles = [
  JobRole(id: 'ROL-01', name: 'Team Lead', code: 'TL', createdAt: DateTime(2024, 2, 1),
      description: 'Leads a team: planning, reviews, people development.'),
  JobRole(id: 'ROL-02', name: 'Software Developer', code: 'SD', createdAt: DateTime(2024, 2, 1),
      description: 'Designs, builds and maintains application software.'),
  JobRole(id: 'ROL-03', name: 'Test Engineer', code: 'TE', createdAt: DateTime(2024, 2, 1),
      description: 'Plans and runs manual and automated tests.'),
  JobRole(id: 'ROL-04', name: 'Data Engineer', code: 'DE', createdAt: DateTime(2024, 2, 1),
      description: 'Builds data pipelines and storage.'),
  JobRole(id: 'ROL-05', name: 'Data Scientist', code: 'DS', createdAt: DateTime(2024, 2, 1),
      description: 'Builds models and analyses from data.'),
  JobRole(id: 'ROL-06', name: 'Data Analyst', code: 'DAN', createdAt: DateTime(2024, 2, 1),
      description: 'Reports, dashboards and data analysis.'),
  JobRole(id: 'ROL-07', name: 'DevOps Engineer', code: 'DOE', createdAt: DateTime(2024, 2, 1),
      description: 'CI/CD, infrastructure as code and operations.'),
  JobRole(id: 'ROL-08', name: 'UX Designer', code: 'UXD', createdAt: DateTime(2024, 2, 1),
      description: 'Interaction design, prototyping and research.'),
  JobRole(id: 'ROL-09', name: 'HR Specialist', code: 'HRS', createdAt: DateTime(2024, 2, 1),
      description: 'Recruitment, onboarding, learning and HR operations.'),
  JobRole(id: 'ROL-10', name: 'Embedded Software Engineer', code: 'ESE', createdAt: DateTime(2026, 3, 2),
      description: 'ECU software in C/C++ on AUTOSAR Classic.'),
  JobRole(id: 'ROL-11', name: 'Functional Safety Engineer', code: 'FSE', createdAt: DateTime(2026, 3, 2),
      description: 'ISO 26262 safety analyses and safety cases.'),
  JobRole(id: 'ROL-12', name: 'Systems Engineer', code: 'SYS', createdAt: DateTime(2026, 3, 2),
      description: 'Requirements, architecture and integration of vehicle systems.'),
];

// -------------------------------------------------------------- projects

const _everyone = null;

final List<ProjectRecord> sampleProjects = [
  ProjectRecord(
    id: 'PRJ-001',
    code: 'THR-26',
    name: 'Talent Hub Revamp',
    customer: 'Internal · Human Resources',
    departmentId: 'DEP-01',
    managerId: 'EMP-1001',
    startDate: DateTime(2026, 8, 3),
    endDate: DateTime(2027, 2, 26),
    status: ProjectStatus.active,
    plannedTeamSize: 7,
    description: 'New talent hub for internal job postings, skills and learning.',
    createdAt: DateTime(2026, 7, 20),
    requirements: const [
      ProjectRequirement('CMP-005', 2, roleId: _everyone),
      ProjectRequirement('CMP-003', 3, roleId: 'ROL-02'),
      ProjectRequirement('CMP-001', 3, roleId: 'ROL-02'),
      ProjectRequirement('CMP-004', 2, roleId: 'ROL-02'),
      ProjectRequirement('CMP-009', 3, roleId: 'ROL-03'),
      ProjectRequirement('CMP-008', 3, roleId: 'ROL-08'),
      ProjectRequirement('CMP-012', 2, roleId: 'ROL-08'),
      ProjectRequirement('CMP-010', 3, roleId: 'ROL-01'),
      ProjectRequirement('CMP-005', 3, roleId: 'ROL-01'),
    ],
    memberIds: const ['EMP-1001', 'EMP-1002', 'EMP-1004', 'EMP-1008', 'EMP-1014', 'EMP-1030', 'EMP-1032'],
  ),
  ProjectRecord(
    id: 'PRJ-002',
    code: 'PAY-MIG',
    name: 'Payments API Migration',
    customer: 'Internal · Finance',
    departmentId: 'DEP-01',
    managerId: 'EMP-1001',
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2027, 3, 31),
    status: ProjectStatus.active,
    plannedTeamSize: 10,
    description: 'Move supplier payments from the legacy monolith to microservices.',
    createdAt: DateTime(2026, 5, 12),
    requirements: const [
      ProjectRequirement('CMP-015', 2, roleId: _everyone),
      ProjectRequirement('CMP-001', 4, roleId: 'ROL-02'),
      ProjectRequirement('CMP-011', 3, roleId: 'ROL-02'),
      ProjectRequirement('CMP-004', 3, roleId: 'ROL-02'),
      ProjectRequirement('CMP-006', 2, roleId: 'ROL-02'),
      ProjectRequirement('CMP-007', 1, roleId: 'ROL-02'),
      ProjectRequirement('CMP-009', 3, roleId: 'ROL-03'),
      ProjectRequirement('CMP-005', 2, roleId: 'ROL-03'),
      ProjectRequirement('CMP-006', 3, roleId: 'ROL-07'),
      ProjectRequirement('CMP-007', 3, roleId: 'ROL-07'),
      ProjectRequirement('CMP-010', 3, roleId: 'ROL-01'),
      ProjectRequirement('CMP-015', 3, roleId: 'ROL-01'),
    ],
    memberIds: const [
      'EMP-1001', 'EMP-1002', 'EMP-1003', 'EMP-1009', 'EMP-1013', 'EMP-1017', 'EMP-1025', 'EMP-1028',
    ],
  ),
  ProjectRecord(
    id: 'PRJ-003',
    code: 'ANP-27',
    name: 'Analytics Platform',
    customer: 'Internal · Data Office',
    departmentId: 'DEP-03',
    managerId: 'EMP-1019',
    startDate: DateTime(2027, 1, 11),
    endDate: DateTime(2027, 12, 17),
    status: ProjectStatus.planned,
    plannedTeamSize: 12,
    description: 'Company-wide data platform for plant, quality and HR analytics.',
    createdAt: DateTime(2026, 9, 28),
    requirements: const [
      ProjectRequirement('CMP-004', 2, roleId: _everyone),
      ProjectRequirement('CMP-002', 2, roleId: 'ROL-02'),
      ProjectRequirement('CMP-004', 3, roleId: 'ROL-02'),
      ProjectRequirement('CMP-006', 2, roleId: 'ROL-02'),
      ProjectRequirement('CMP-002', 3, roleId: 'ROL-04'),
      ProjectRequirement('CMP-004', 3, roleId: 'ROL-04'),
      ProjectRequirement('CMP-006', 2, roleId: 'ROL-04'),
      ProjectRequirement('CMP-002', 4, roleId: 'ROL-05'),
      ProjectRequirement('CMP-013', 3, roleId: 'ROL-05'),
      ProjectRequirement('CMP-004', 3, roleId: 'ROL-06'),
      ProjectRequirement('CMP-002', 2, roleId: 'ROL-06'),
      ProjectRequirement('CMP-009', 2, roleId: 'ROL-03'),
      ProjectRequirement('CMP-006', 3, roleId: 'ROL-07'),
      ProjectRequirement('CMP-007', 2, roleId: 'ROL-07'),
      ProjectRequirement('CMP-008', 3, roleId: 'ROL-08'),
      ProjectRequirement('CMP-012', 2, roleId: 'ROL-08'),
      ProjectRequirement('CMP-010', 3, roleId: 'ROL-01'),
      ProjectRequirement('CMP-002', 3, roleId: 'ROL-01'),
      ProjectRequirement('CMP-013', 2, roleId: 'ROL-01'),
    ],
    memberIds: const [
      'EMP-1002', 'EMP-1005', 'EMP-1012', 'EMP-1018', 'EMP-1019',
      'EMP-1020', 'EMP-1021', 'EMP-1023', 'EMP-1027', 'EMP-1033',
    ],
  ),
  ProjectRecord(
    id: 'PRJ-004',
    code: 'CP2-26',
    name: 'Customer Portal 2.0',
    customer: 'Internal · Customer Service',
    departmentId: 'DEP-01',
    managerId: 'EMP-1001',
    startDate: DateTime(2026, 9, 7),
    endDate: DateTime(2027, 4, 30),
    status: ProjectStatus.active,
    plannedTeamSize: 5,
    description: 'Self-service portal for after-sales parts and warranty requests.',
    createdAt: DateTime(2026, 8, 18),
    requirements: const [
      ProjectRequirement('CMP-005', 2, roleId: _everyone),
      ProjectRequirement('CMP-003', 3, roleId: 'ROL-02'),
      ProjectRequirement('CMP-004', 2, roleId: 'ROL-02'),
      ProjectRequirement('CMP-011', 2, roleId: 'ROL-02'),
      ProjectRequirement('CMP-009', 3, roleId: 'ROL-03'),
      ProjectRequirement('CMP-005', 3, roleId: 'ROL-03'),
      ProjectRequirement('CMP-004', 3, roleId: 'ROL-06'),
      ProjectRequirement('CMP-002', 2, roleId: 'ROL-06'),
      ProjectRequirement('CMP-008', 3, roleId: 'ROL-08'),
      ProjectRequirement('CMP-012', 2, roleId: 'ROL-08'),
    ],
    memberIds: const ['EMP-1007', 'EMP-1011', 'EMP-1015', 'EMP-1024', 'EMP-1031'],
  ),
  ProjectRecord(
    id: 'PRJ-005',
    code: 'CCO-26',
    name: 'Cloud Cost Optimizer',
    customer: 'Internal · IT Infrastructure',
    departmentId: 'DEP-04',
    managerId: 'EMP-1025',
    startDate: DateTime(2026, 10, 5),
    endDate: DateTime(2027, 1, 29),
    status: ProjectStatus.active,
    plannedTeamSize: 3,
    description: 'Right-size cloud workloads and automate shutdown of idle environments.',
    createdAt: DateTime(2026, 9, 21),
    requirements: const [
      ProjectRequirement('CMP-006', 3, roleId: _everyone),
      ProjectRequirement('CMP-007', 3, roleId: 'ROL-07'),
      ProjectRequirement('CMP-002', 2, roleId: 'ROL-07'),
      ProjectRequirement('CMP-010', 3, roleId: 'ROL-01'),
      ProjectRequirement('CMP-007', 4, roleId: 'ROL-01'),
    ],
    memberIds: const ['EMP-1025', 'EMP-1026'],
  ),
  ProjectRecord(
    id: 'PRJ-006',
    code: 'ADAS-DP',
    name: 'ADAS Sensor Data Pipeline',
    customer: 'ADAS Programme',
    departmentId: 'DEP-03',
    managerId: 'EMP-1019',
    startDate: DateTime(2027, 3, 1),
    status: ProjectStatus.planned,
    plannedTeamSize: 6,
    description: 'Ingest and label camera/radar recordings from test vehicles for ADAS validation.',
    createdAt: DateTime(2026, 11, 2),
    requirements: const [
      ProjectRequirement('CMP-002', 3, roleId: _everyone),
      ProjectRequirement('CMP-013', 3, roleId: 'ROL-05'),
      ProjectRequirement('CMP-006', 3, roleId: 'ROL-04'),
      ProjectRequirement('CMP-007', 2, roleId: 'ROL-04'),
    ],
  ),
];

// ------------------------------------------------------------- employees

const Map<String, String> _departmentIds = {
  'Engineering': 'DEP-01',
  'Quality Assurance': 'DEP-02',
  'Data & Analytics': 'DEP-03',
  'DevOps & Cloud': 'DEP-04',
  'UI/UX Design': 'DEP-05',
  'Human Resources': 'DEP-06',
};

const Map<String, String> _roleOf = {
  'EMP-1001': 'ROL-01', 'EMP-1013': 'ROL-01', 'EMP-1019': 'ROL-01', 'EMP-1025': 'ROL-01',
  'EMP-1030': 'ROL-01', 'EMP-1034': 'ROL-01',
  'EMP-1014': 'ROL-03', 'EMP-1015': 'ROL-03', 'EMP-1016': 'ROL-03', 'EMP-1017': 'ROL-03',
  'EMP-1018': 'ROL-03',
  'EMP-1020': 'ROL-04', 'EMP-1022': 'ROL-04', 'EMP-1023': 'ROL-05',
  'EMP-1021': 'ROL-06', 'EMP-1024': 'ROL-06',
  'EMP-1026': 'ROL-07', 'EMP-1027': 'ROL-07', 'EMP-1028': 'ROL-07', 'EMP-1029': 'ROL-07',
  'EMP-1031': 'ROL-08', 'EMP-1032': 'ROL-08', 'EMP-1033': 'ROL-08',
  'EMP-1035': 'ROL-09', 'EMP-1036': 'ROL-09',
  // Everyone else in Engineering: Software Developer.
};

const Set<String> _women = {
  'Priya', 'Sneha', 'Lakshmi', 'Fatima', 'Ananya', 'Pooja', 'Deepa', 'Kavya', 'Nandini',
  'Meera', 'Shalini', 'Ritu', 'Swathi', 'Bhavana', 'Divya', 'Neha', 'Anitha', 'Ramya',
};

const _hyderabad = EmployeeLocation(country: 'India', state: 'Telangana', city: 'Hyderabad');
const _bengaluru = EmployeeLocation(country: 'India', state: 'Karnataka', city: 'Bengaluru');
const _chennai = EmployeeLocation(country: 'India', state: 'Tamil Nadu', city: 'Chennai');
const _yongin = EmployeeLocation(country: 'South Korea', state: 'Gyeonggi-do', city: 'Yongin');

EmployeeLocation _locationOf(EmployeeRecord r) {
  if (r.id == 'EMP-1028') return _yongin; // on deputation to the Korea R&D centre
  if (r.id == 'EMP-1015') return _chennai;
  return switch (r.department) {
    'Data & Analytics' || 'UI/UX Design' => _bengaluru,
    _ => _hyderabad,
  };
}

final Map<String, List<CertificateFile>> _certificates = {
  'EMP-1002': [
    CertificateFile(id: 'CRT-0001', name: 'Oracle_Java_SE17_Developer.pdf', sizeBytes: 1258291,
        addedAt: DateTime(2025, 3, 14), mimeType: 'application/pdf'),
    CertificateFile(id: 'CRT-0002', name: 'Flutter_Advanced_Bootcamp.pdf', sizeBytes: 842137,
        addedAt: DateTime(2026, 2, 2), mimeType: 'application/pdf'),
  ],
  'EMP-1001': [
    CertificateFile(id: 'CRT-0003', name: 'PMP_Certificate_2024.pdf', sizeBytes: 963412,
        addedAt: DateTime(2024, 9, 30), mimeType: 'application/pdf'),
  ],
  'EMP-1013': [
    CertificateFile(id: 'CRT-0004', name: 'ISTQB_Advanced_Test_Manager.pdf', sizeBytes: 715020,
        addedAt: DateTime(2023, 11, 21), mimeType: 'application/pdf'),
  ],
  'EMP-1025': [
    CertificateFile(id: 'CRT-0005', name: 'CKA_Certified_Kubernetes_Admin.png', sizeBytes: 486224,
        addedAt: DateTime(2025, 6, 9), mimeType: 'image/png'),
  ],
  'EMP-1019': [
    CertificateFile(id: 'CRT-0006', name: 'AWS_Data_Analytics_Specialty.pdf', sizeBytes: 1102458,
        addedAt: DateTime(2025, 1, 17), mimeType: 'application/pdf'),
  ],
};

String _introOf(EmployeeRecord r) {
  final skills = r.topSkills.take(3).join(', ');
  final projects = r.projects.isEmpty
      ? 'Currently available for a new project.'
      : 'Works on ${r.projects.join(' and ')}.';
  return '${r.designation} in ${r.department}. $projects Strongest in $skills.';
}

/// The 36 sample employees as full profiles.
List<EmployeeProfile> sampleEmployeeProfiles() {
  final idByName = {for (final r in OrgData.sample.employees) r.name: r.id};
  final list = <EmployeeProfile>[];
  for (final r in OrgData.sample.employees) {
    final number = int.parse(r.id.substring(4));
    final managerId = idByName[r.reportsTo];
    list.add(EmployeeProfile(
      id: r.id,
      name: r.name,
      email: r.email,
      gender: _women.contains(r.name.split(' ').first) ? Gender.female : Gender.male,
      status: EmploymentStatus.active,
      departmentId: _departmentIds[r.department] ?? 'DEP-01',
      designation: r.designation,
      roleId: _roleOf[r.id] ?? 'ROL-02',
      managerId: managerId,
      managerName: managerId == null ? r.reportsTo : null,
      location: _locationOf(r),
      intro: _introOf(r),
      certificates: _certificates[r.id] ?? const [],
      onLeave: r.status == EmployeeStatus.onLeave,
      baselineReadiness: r.readiness,
      crowdUsername: r.email.split('@').first,
      onboardedAt: DateTime(2019 + (number % 7), 1 + (number * 5) % 12, 1 + (number * 7) % 27),
    ));
  }
  return list;
}

// ------------------------------------------------------- profile changes

List<ProfileChange> sampleProfileChanges() {
  var n = 0;
  String id() => 'CHG-${(++n).toString().padLeft(4, '0')}';
  ProfileChange change(
    String employeeId,
    ChangeField field,
    String from,
    String to,
    ChangeReason reason,
    DateTime effective, {
    String note = '',
    String? batch,
  }) =>
      ProfileChange(
        id: id(),
        employeeId: employeeId,
        field: field,
        from: from,
        to: to,
        reason: reason,
        note: note,
        effectiveDate: effective,
        changedBy: 'Anitha Joseph',
        changedAt: effective.subtract(const Duration(days: 3)).add(const Duration(hours: 11)),
        batchLabel: batch,
      );

  final list = <ProfileChange>[
    // Ritu Bansal promoted to Data Scientist.
    change('EMP-1023', ChangeField.designation, 'Data Analyst', 'Data Scientist',
        ChangeReason.promotion, DateTime(2026, 6, 15), note: 'Mid-year promotion cycle'),
    change('EMP-1023', ChangeField.role, 'Data Analyst', 'Data Scientist', ChangeReason.promotion,
        DateTime(2026, 6, 15), note: 'Mid-year promotion cycle'),
    // Q3 re-org: DevOps & Cloud joins the data platforms group (and so the
    // Digital & IT division).
    for (final e in ['EMP-1025', 'EMP-1026', 'EMP-1027', 'EMP-1028', 'EMP-1029', 'EMP-1022']) ...[
      change(e, ChangeField.division, 'Research & Development', 'Digital & IT', ChangeReason.reorg,
          DateTime(2026, 7, 1),
          note: 'Q3 2026 re-org: platform teams grouped together',
          batch: 'DevOps & Cloud moved to Data & Cloud Platforms'),
      change(e, ChangeField.group, 'Software Development', 'Data & Cloud Platforms', ChangeReason.reorg,
          DateTime(2026, 7, 1),
          note: 'Q3 2026 re-org: platform teams grouped together',
          batch: 'DevOps & Cloud moved to Data & Cloud Platforms'),
    ],
    // Varun Desai moves to the design team.
    change('EMP-1033', ChangeField.department, 'Engineering', 'UI/UX Design', ChangeReason.reorg,
        DateTime(2026, 8, 3), note: 'Front-end designers moved to UI/UX Design'),
    change('EMP-1033', ChangeField.manager, 'Priya Raman', 'Divya Menon', ChangeReason.reorg,
        DateTime(2026, 8, 3), note: 'Front-end designers moved to UI/UX Design'),
    // Vikram Singh transferred to Engineering.
    change('EMP-1005', ChangeField.division, 'Digital & IT', 'Research & Development',
        ChangeReason.transfer, DateTime(2026, 9, 15), note: 'Backend work for Analytics Platform'),
    change('EMP-1005', ChangeField.group, 'Data & Cloud Platforms', 'Software Development',
        ChangeReason.transfer, DateTime(2026, 9, 15), note: 'Backend work for Analytics Platform'),
    change('EMP-1005', ChangeField.department, 'Data & Analytics', 'Engineering', ChangeReason.transfer,
        DateTime(2026, 9, 15), note: 'Backend work for Analytics Platform'),
    change('EMP-1005', ChangeField.manager, 'Meera Iyer', 'Priya Raman', ChangeReason.transfer,
        DateTime(2026, 9, 15), note: 'Backend work for Analytics Platform'),
    // Sneha Reddy promoted.
    change('EMP-1004', ChangeField.designation, 'Software Engineer', 'Senior Software Engineer',
        ChangeReason.promotion, DateTime(2026, 10, 1), note: 'Annual appraisal'),
    // Nandini Rao moves to QA.
    change('EMP-1018', ChangeField.group, 'Software Development', 'Quality & Validation',
        ChangeReason.transfer, DateTime(2026, 10, 5), note: 'Automation testing for Analytics Platform'),
    change('EMP-1018', ChangeField.department, 'Engineering', 'Quality Assurance', ChangeReason.transfer,
        DateTime(2026, 10, 5), note: 'Automation testing for Analytics Platform'),
    change('EMP-1018', ChangeField.manager, 'Priya Raman', 'Karthik Subramanian', ChangeReason.transfer,
        DateTime(2026, 10, 5), note: 'Automation testing for Analytics Platform'),
    // Harish Chandra moves within the data group.
    change('EMP-1022', ChangeField.department, 'DevOps & Cloud', 'Data & Analytics', ChangeReason.transfer,
        DateTime(2026, 11, 2), note: 'Kafka streaming for the ADAS data pipeline'),
    change('EMP-1022', ChangeField.manager, 'Arjun Nair', 'Meera Iyer', ChangeReason.transfer,
        DateTime(2026, 11, 2), note: 'Kafka streaming for the ADAS data pipeline'),
  ];
  // Newest first.
  list.sort((a, b) {
    final byDate = b.effectiveDate.compareTo(a.effectiveDate);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  });
  return list;
}

// ------------------------------------------------------------- approvals

List<LevelUpRequest> sampleLevelUpRequests() {
  var n = 0;
  String id() => 'APR-${(++n).toString().padLeft(4, '0')}';
  LevelUpRequest request(
    String employeeId,
    String competencyId,
    int? from,
    int to,
    String tl,
    String tlName,
    DateTime raisedAt,
    String note, {
    required int hours,
    int? required,
    List<String> projects = const [],
    String evidence = '',
    ApprovalStatus status = ApprovalStatus.pending,
    DateTime? decidedAt,
    String decision = '',
  }) =>
      LevelUpRequest(
        id: id(),
        employeeId: employeeId,
        competencyId: competencyId,
        fromLevel: from,
        toLevel: to,
        requiredLevel: required,
        projectIds: projects,
        note: note,
        hours: hours,
        requiredHours: LevelHoursPolicy.instance.hoursFor(competencyId, from, to),
        evidence: evidence,
        raisedById: tl,
        raisedByName: tlName,
        raisedAt: raisedAt,
        status: status,
        decidedByName: status == ApprovalStatus.pending ? null : 'Anitha Joseph',
        decidedAt: decidedAt,
        decisionNote: decision,
      );

  const priya = 'EMP-1001';
  const karthik = 'EMP-1013';
  const meera = 'EMP-1019';
  const arjun = 'EMP-1025';
  const divya = 'EMP-1030';

  final list = <LevelUpRequest>[
    // ---- decided
    request('EMP-1008', 'CMP-003', 2, 3, priya, 'Priya Raman', DateTime(2026, 9, 22),
        'Built the offline sync module of Talent Hub on her own and reviews Dart PRs.',
        hours: 430,
        required: 3, projects: ['PRJ-001'], status: ApprovalStatus.approved,
        decidedAt: DateTime(2026, 9, 24), decision: 'Matches the L3 guide. Approved.'),
    request('EMP-1014', 'CMP-009', 2, 3, karthik, 'Karthik Subramanian', DateTime(2026, 9, 30),
        'Owns the Selenium regression suite for Talent Hub (180 tests, stable for 6 sprints).',
        hours: 415,
        required: 3, projects: ['PRJ-001'], status: ApprovalStatus.approved,
        decidedAt: DateTime(2026, 10, 3)),
    request('EMP-1011', 'CMP-011', null, 2, priya, 'Priya Raman', DateTime(2026, 10, 8),
        'Split the portal backend into three services with Priya\'s guidance.',
        hours: 500,
        required: 2, projects: ['PRJ-004'], status: ApprovalStatus.approved,
        decidedAt: DateTime(2026, 10, 9)),
    request('EMP-1012', 'CMP-002', null, 2, priya, 'Priya Raman', DateTime(2026, 10, 12),
        'Completed the internal Python for Engineers course and wrote the data export scripts.',
        hours: 540,
        required: 2, projects: ['PRJ-003'], evidence: 'Python_for_Engineers_certificate.pdf',
        status: ApprovalStatus.approved, decidedAt: DateTime(2026, 10, 15)),
    request('EMP-1020', 'CMP-006', null, 2, meera, 'Meera Iyer', DateTime(2026, 10, 19),
        'Containerised all Airflow jobs for the Analytics Platform prototype.',
        hours: 600,
        required: 2, projects: ['PRJ-003'], status: ApprovalStatus.approved,
        decidedAt: DateTime(2026, 10, 21), decision: 'Approved – please add the Docker course certificate.'),
    request('EMP-1003', 'CMP-004', 3, 4, priya, 'Priya Raman', DateTime(2026, 10, 26),
        'Tuned the slow payment reconciliation queries (from 40 s to 2 s).',
        hours: 260,
        required: 3, projects: ['PRJ-002'], status: ApprovalStatus.rejected,
        decidedAt: DateTime(2026, 10, 29),
        decision: 'Good work, but L4 needs the advanced SQL tuning assessment. Please book it first.'),
    request('EMP-1016', 'CMP-009', 1, 3, karthik, 'Karthik Subramanian', DateTime(2026, 11, 3),
        'Automated 40 smoke tests for the portal.',
        hours: 210,
        status: ApprovalStatus.rejected, decidedAt: DateTime(2026, 11, 5),
        decision: 'Two levels at once – request L2 first, with the automation work as proof.'),
    // ---- pending
    request('EMP-1002', 'CMP-006', null, 2, priya, 'Priya Raman', DateTime(2026, 11, 6),
        'Finished the Docker Mastery course and containerised the Talent Hub API locally.',
        hours: 420,
        required: 2, projects: ['PRJ-002', 'PRJ-003'], evidence: 'https://learn.example.com/cert/DM-48213'),
    request('EMP-1024', 'CMP-002', 1, 2, meera, 'Meera Iyer', DateTime(2026, 11, 8),
        'Writes pandas notebooks for the warranty dashboards every week now.',
        hours: 340,
        required: 2, projects: ['PRJ-004']),
    request('EMP-1026', 'CMP-007', 2, 3, arjun, 'Arjun Nair', DateTime(2026, 11, 9),
        'Runs the cost-optimizer cluster on his own, including upgrades and autoscaling.',
        hours: 410,
        required: 3, projects: ['PRJ-005']),
    request('EMP-1004', 'CMP-001', 2, 3, priya, 'Priya Raman', DateTime(2026, 11, 10),
        'Took over the Java notification service of Talent Hub; code reviews show L3 practices.',
        hours: 300,
        required: 3, projects: ['PRJ-001']),
    request('EMP-1032', 'CMP-008', 2, 3, divya, 'Divya Menon', DateTime(2026, 11, 11),
        'Built the Talent Hub component library in Figma with variants and auto layout.',
        hours: 450,
        required: 3, projects: ['PRJ-001'], evidence: 'https://figma.example.com/file/talent-hub-ui'),
    request('EMP-1009', 'CMP-011', 2, 3, priya, 'Priya Raman', DateTime(2026, 11, 12),
        'Designed the retry/outbox pattern for the payments events.',
        hours: 380,
        required: 3, projects: ['PRJ-002']),
    request('EMP-1017', 'CMP-015', 1, 2, karthik, 'Karthik Subramanian', DateTime(2026, 11, 12),
        'Completed the payments domain training and wrote the settlement test plan.',
        hours: 170,
        required: 2, projects: ['PRJ-002']),
    request('EMP-1031', 'CMP-012', 1, 2, divya, 'Divya Menon', DateTime(2026, 11, 13),
        'Ran 8 usability sessions for the portal and presented the findings.',
        hours: 200,
        required: 2, projects: ['PRJ-004']),
    request('EMP-1007', 'CMP-003', 2, 3, priya, 'Priya Raman', DateTime(2026, 11, 14),
        'Leads the Flutter screens of Customer Portal 2.0.',
        hours: 420,
        required: 3, projects: ['PRJ-004']),
  ];
  return list..sort((a, b) => b.raisedAt.compareTo(a.raisedAt));
}

// ----------------------------------------------------------------- Crowd

/// A simulated Crowd directory (see CrowdService).
const List<CrowdUser> sampleCrowdUsers = [
  CrowdUser(username: 'priya.raman', employeeNumber: 'EMP-1001', displayName: 'Priya Raman',
      email: 'priya.raman@skillsphere.com', active: true, groups: ['mobis-employees', 'dept-engineering']),
  CrowdUser(username: 'sathish.kumar', employeeNumber: 'EMP-1002', displayName: 'Sathish Kumar',
      email: 'sathish.kumar@skillsphere.com', active: true, groups: ['mobis-employees', 'dept-engineering']),
  CrowdUser(username: 'lakshmi.narayanan', employeeNumber: 'EMP-1006', displayName: 'Lakshmi Narayanan',
      email: 'lakshmi.n@skillsphere.com', active: true, groups: ['mobis-employees', 'dept-engineering']),
  CrowdUser(username: 'pooja.agarwal', employeeNumber: 'EMP-1012', displayName: 'Pooja Agarwal Mehta',
      email: 'pooja.mehta@skillsphere.com', active: true, groups: ['mobis-employees', 'dept-engineering']),
  CrowdUser(username: 'prakash.rao', employeeNumber: 'EMP-1036', displayName: 'Prakash Rao',
      email: 'prakash.rao@skillsphere.com', active: false, groups: ['mobis-employees', 'dept-human-resources']),
  CrowdUser(username: 'kiran.kumar', employeeNumber: 'EMP-1037', displayName: 'Kiran Kumar',
      email: 'kiran.kumar@skillsphere.com', active: true, groups: ['mobis-employees', 'dept-engineering'],
      title: 'Software Engineer', country: 'India', city: 'Hyderabad'),
  CrowdUser(username: 'jiho.park', employeeNumber: 'EMP-1038', displayName: 'Ji-ho Park',
      email: 'jiho.park@skillsphere.com', active: true, groups: ['mobis-employees', 'dept-quality-assurance'],
      title: 'Senior QA Engineer', country: 'South Korea', city: 'Yongin'),
  CrowdUser(username: 'aisha.fernandes', employeeNumber: 'EMP-1039', displayName: 'Aisha Fernandes',
      email: 'aisha.fernandes@skillsphere.com', active: true, groups: ['mobis-employees', 'dept-data-analytics'],
      title: 'Data Analyst', country: 'India', city: 'Bengaluru'),
  CrowdUser(username: 'rajesh.pandian', employeeNumber: 'EMP-1040', displayName: 'Rajesh Pandian',
      email: 'rajesh.pandian@skillsphere.com', active: true, groups: ['mobis-employees', 'dept-devops-cloud'],
      title: 'DevOps Engineer', country: 'India', city: 'Chennai'),
  CrowdUser(username: 'minseo.kim', employeeNumber: 'EMP-1041', displayName: 'Min-seo Kim',
      email: 'minseo.kim@skillsphere.com', active: true, groups: ['mobis-employees', 'dept-functional-safety'],
      title: 'Functional Safety Engineer', country: 'South Korea', city: 'Uiwang'),
  CrowdUser(username: 'svc-jenkins', employeeNumber: '', displayName: 'Jenkins service account',
      email: 'jenkins@skillsphere.com', active: true, groups: ['service-accounts']),
];

const List<CrowdGroup> sampleCrowdGroups = [
  CrowdGroup(name: 'div-research-development', description: 'Research & Development', members: 5),
  CrowdGroup(name: 'div-digital-it', description: 'Digital & IT', members: 2),
  CrowdGroup(name: 'div-corporate', description: 'Corporate Management', members: 1),
  CrowdGroup(name: 'div-electrification', description: 'Electrification – EV and battery systems', members: 0),
  CrowdGroup(name: 'grp-software-development', description: 'Software Development', parent: 'div-research-development', members: 3),
  CrowdGroup(name: 'grp-quality-validation', description: 'Quality & Validation', parent: 'div-research-development', members: 2),
  CrowdGroup(name: 'grp-data-cloud', description: 'Data & Cloud Platforms', parent: 'div-digital-it', members: 2),
  CrowdGroup(name: 'grp-corporate', description: 'Corporate Functions', parent: 'div-corporate', members: 1),
  CrowdGroup(name: 'grp-vehicle-software', description: 'Vehicle Software – embedded and safety', parent: 'div-research-development', members: 2),
  CrowdGroup(name: 'grp-battery-systems', description: 'Battery Systems', parent: 'div-electrification', members: 0),
  CrowdGroup(name: 'dept-engineering', description: 'Engineering', parent: 'grp-software-development', members: 14),
  CrowdGroup(name: 'dept-ui-ux', description: 'UI/UX Design', parent: 'grp-software-development', members: 4),
  CrowdGroup(name: 'dept-quality-assurance', description: 'Quality Assurance', parent: 'grp-quality-validation', members: 7),
  CrowdGroup(name: 'dept-adas-validation', description: 'ADAS Validation', parent: 'grp-quality-validation', members: 0),
  CrowdGroup(name: 'dept-data-analytics', description: 'Data & Analytics', parent: 'grp-data-cloud', members: 7),
  CrowdGroup(name: 'dept-devops-cloud', description: 'DevOps & Cloud', parent: 'grp-data-cloud', members: 5),
  CrowdGroup(name: 'dept-human-resources', description: 'Human Resources', parent: 'grp-corporate', members: 3),
  CrowdGroup(name: 'dept-functional-safety', description: 'Functional Safety – ISO 26262', parent: 'grp-vehicle-software', members: 1),
  CrowdGroup(name: 'dept-embedded-software', description: 'Embedded Software – AUTOSAR Classic', parent: 'grp-vehicle-software', members: 0),
  CrowdGroup(name: 'dept-bms-software', description: 'BMS Software', parent: 'grp-battery-systems', members: 0),
  CrowdGroup(name: 'mobis-employees', description: 'All employees', members: 41),
  CrowdGroup(name: 'service-accounts', description: 'Technical accounts', members: 1),
];
