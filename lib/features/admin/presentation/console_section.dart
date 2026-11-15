import 'package:flutter/material.dart';

/// The options behind the settings (gear) icon of the HRD dashboard.
enum ConsoleSection {
  onboarding(
    'Employee Onboarding',
    'Onboarding',
    Icons.person_add_alt_1_rounded,
    'Add new employees one at a time, from an Excel/CSV file or from Crowd.',
  ),
  employees(
    'All Employees',
    'Employees',
    Icons.groups_2_outlined,
    'Every employee with their readiness and gaps. Open one for the full profile.',
  ),
  changes(
    'Profile Changes',
    'Changes',
    Icons.swap_horiz_rounded,
    'Division, group and department moves (re-orgs, transfers) and other profile changes.',
  ),
  approvals(
    'Approvals',
    'Approvals',
    Icons.verified_outlined,
    'Level-ups that close skill gaps, raised by Team Leads, waiting for HR.',
  ),
  projects(
    'Projects',
    'Projects',
    Icons.work_outline_rounded,
    'Projects with their required competencies and team members.',
  ),
  roles(
    'Roles',
    'Roles',
    Icons.badge_outlined,
    'Project roles such as Software Developer or Test Engineer.',
  ),
  structure(
    'Org Structure',
    'Structure',
    Icons.account_tree_outlined,
    'Divisions, the business groups inside them and their departments.',
  );

  const ConsoleSection(this.title, this.shortTitle, this.icon, this.blurb);

  /// "Employee Onboarding"
  final String title;

  /// "Onboarding" (narrow screens)
  final String shortTitle;
  final IconData icon;
  final String blurb;
}
