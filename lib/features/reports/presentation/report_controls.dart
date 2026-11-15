import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../admin/data/employees.dart';
import '../../admin/data/job_roles.dart';
import '../../admin/data/org_structure.dart';
import '../../admin/data/projects.dart';
import '../../admin/presentation/widgets/admin_common.dart';
import '../../competency/data/competency_models.dart';
import '../../competency/data/competency_repository.dart';
import '../../home/presentation/home_theme.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../data/report_engine.dart';
import '../data/report_export.dart';
import '../data/report_models.dart';

const XTypeGroup _excelGroup = XTypeGroup(
  label: 'Excel workbook',
  extensions: <String>['xlsx'],
  mimeTypes: <String>[ReportExport.xlsxMime],
  uniformTypeIdentifiers: <String>['org.openxmlformats.spreadsheetml.sheet'],
);

const XTypeGroup _csvGroup = XTypeGroup(
  label: 'CSV',
  extensions: <String>['csv'],
  mimeTypes: <String>[ReportExport.csvMime],
  uniformTypeIdentifiers: <String>['public.comma-separated-values-text'],
);

/// Saves an exported report: the browser downloads it on the web; on
/// desktop the user chooses where.
Future<void> saveReportFile(
  BuildContext context, {
  required Uint8List bytes,
  required String fileName,
  required bool excel,
}) async {
  try {
    final FileSaveLocation? location = kIsWeb
        ? const FileSaveLocation('')
        : await getSaveLocation(
            suggestedName: fileName,
            acceptedTypeGroups: <XTypeGroup>[excel ? _excelGroup : _csvGroup],
          );
    if (location == null) return;
    await XFile.fromData(bytes, name: fileName, mimeType: excel ? ReportExport.xlsxMime : ReportExport.csvMime)
        .saveTo(location.path);
    if (context.mounted) showAdminMessage(context, kIsWeb ? 'Downloaded $fileName.' : 'Saved $fileName.');
  } catch (e) {
    if (context.mounted) showAdminMessage(context, 'Could not save $fileName: $e');
  }
}

/// Exports one report as Excel or CSV.
Future<void> exportReport(BuildContext context, ReportResult result, {required bool excel, String? title}) {
  final name = title ?? result.title;
  return saveReportFile(
    context,
    bytes: excel ? ReportExport.xlsx([result], title: name, names: [name]) : ReportExport.csv(result),
    fileName: ReportExport.fileName(name, excel ? 'xlsx' : 'csv', at: result.generatedAt),
    excel: excel,
  );
}

/// Open projects the scope may filter by: all for HRD; for a Team Lead the
/// ones run by their department or with someone from it on the team.
List<ProjectRecord> scopeProjects(ReportScope scope) {
  final ids = scope.departmentIds;
  final employees = EmployeeRepository.instance;
  return ProjectRepository.instance.openProjects.where((p) {
    if (ids == null) return true;
    if (ids.contains(p.departmentId)) return true;
    return p.memberIds.any((id) {
      final e = employees.byId(id);
      return e != null && ids.contains(e.departmentId);
    });
  }).toList();
}

/// The filters [type] offers, as drop-downs and toggles. A Team Lead never
/// sees the division / group / department filters (always own department).
class ReportFilterControls extends StatelessWidget {
  const ReportFilterControls({
    super.key,
    required this.scope,
    required this.type,
    required this.filters,
    required this.onChanged,
  });

  final ReportScope scope;
  final ReportType type;
  final ReportFilters filters;
  final ValueChanged<ReportFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final kinds = type.filters;
    final structure = OrgStructureRepository.instance;
    final f = filters;
    // Narrow screens: one filter per row (never a negative width).
    final fieldWidth = MediaQuery.sizeOf(context).width < 560 ? double.infinity : 220.0;
    final controls = <Widget>[];

    if (kinds.contains(ReportFilterKind.orgUnit) && scope.isOrganisation) {
      final divisions = [...structure.divisions.value]..sort((a, b) => a.name.compareTo(b.name));
      final divisionId = f.divisionId;
      final groupId = f.groupId;
      final groups = (divisionId == null ? [...structure.groups.value] : structure.groupsIn(divisionId))
        ..sort((a, b) => a.name.compareTo(b.name));
      final departments = (groupId != null
              ? structure.departmentsIn(groupId)
              : (divisionId != null ? structure.departmentsInDivision(divisionId) : [...structure.departments.value]))
        ..sort((a, b) => a.name.compareTo(b.name));
      controls.addAll([
        SizedBox(
          width: fieldWidth,
          child: AdminDropdown<String>(
            value: f.divisionId ?? '',
            items: ['', for (final d in divisions) d.id],
            labelOf: (id) => id.isEmpty ? 'All divisions' : (structure.divisionById(id)?.name ?? id),
            onChanged: (id) => onChanged(f.copyWith(
              divisionId: id.isEmpty ? null : id,
              groupId: null,
              departmentId: null,
            )),
          ),
        ),
        SizedBox(
          width: fieldWidth,
          child: AdminDropdown<String>(
            value: f.groupId ?? '',
            items: ['', for (final g in groups) g.id],
            labelOf: (id) => id.isEmpty ? 'All groups' : (structure.groupById(id)?.name ?? id),
            onChanged: (id) => onChanged(f.copyWith(groupId: id.isEmpty ? null : id, departmentId: null)),
          ),
        ),
        SizedBox(
          width: fieldWidth,
          child: AdminDropdown<String>(
            value: f.departmentId ?? '',
            items: ['', for (final d in departments) d.id],
            labelOf: (id) => id.isEmpty ? 'All departments' : structure.departmentName(id),
            onChanged: (id) => onChanged(f.copyWith(departmentId: id.isEmpty ? null : id)),
          ),
        ),
      ]);
    }
    if (kinds.contains(ReportFilterKind.role)) {
      final roles = RoleRepository.instance.roles.value;
      controls.add(SizedBox(
        width: fieldWidth,
        child: AdminDropdown<String>(
          value: f.roleId ?? '',
          items: ['', for (final r in roles) r.id],
          labelOf: (id) => id.isEmpty ? 'All roles' : RoleRepository.instance.nameOf(id),
          onChanged: (id) => onChanged(f.copyWith(roleId: id.isEmpty ? null : id)),
        ),
      ));
    }
    if (kinds.contains(ReportFilterKind.project)) {
      final projects = scopeProjects(scope);
      controls.add(SizedBox(
        width: fieldWidth,
        child: AdminDropdown<String>(
          value: f.projectId ?? '',
          items: ['', for (final p in projects) p.id],
          labelOf: (id) {
            if (id.isEmpty) return 'All projects';
            final p = ProjectRepository.instance.byId(id);
            return p == null ? id : '${p.code} · ${p.name}';
          },
          onChanged: (id) => onChanged(f.copyWith(projectId: id.isEmpty ? null : id)),
        ),
      ));
    }
    if (kinds.contains(ReportFilterKind.category)) {
      controls.add(SizedBox(
        width: fieldWidth,
        child: AdminDropdown<String>(
          value: f.category?.name ?? '',
          items: ['', for (final c in CompetencyCategory.values) c.name],
          labelOf: (name) {
            if (name.isEmpty) return 'All categories';
            for (final c in CompetencyCategory.values) {
              if (c.name == name) return c.plural;
            }
            return name;
          },
          onChanged: (name) {
            CompetencyCategory? picked;
            for (final c in CompetencyCategory.values) {
              if (c.name == name) picked = c;
            }
            final competency = CompetencyRepository.instance.byId(f.competencyId ?? '');
            onChanged(f.copyWith(
              category: picked,
              // Keep the competency only if it is in the new category.
              competencyId: picked == null || competency == null || competency.category == picked
                  ? f.competencyId
                  : null,
            ));
          },
        ),
      ));
    }
    if (kinds.contains(ReportFilterKind.competency)) {
      final category = f.category;
      final list = CompetencyRepository.instance.competencies.value
          .where((c) => category == null || c.category == category)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      controls.add(SizedBox(
        width: fieldWidth,
        child: AdminDropdown<String>(
          value: f.competencyId ?? '',
          items: ['', for (final c in list) c.id],
          labelOf: (id) =>
              id.isEmpty ? 'All competencies' : (CompetencyRepository.instance.byId(id)?.name ?? id),
          onChanged: (id) => onChanged(f.copyWith(competencyId: id.isEmpty ? null : id)),
        ),
      ));
    }
    final toggles = <Widget>[
      if (kinds.contains(ReportFilterKind.gapsOnly))
        OrgFilterPill(
          label: 'Gaps only',
          selected: f.gapsOnly,
          onTap: () => onChanged(f.copyWith(gapsOnly: !f.gapsOnly)),
        ),
      if (kinds.contains(ReportFilterKind.includeNotRequired))
        OrgFilterPill(
          label: 'Include competencies no project needs',
          selected: f.includeNotRequired,
          onTap: () => onChanged(f.copyWith(includeNotRequired: !f.includeNotRequired)),
        ),
    ];

    if (controls.isEmpty && toggles.isEmpty) {
      return Text('This report has no filters.', style: HomeText.body(13, color: HomeColors.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controls.isNotEmpty) Wrap(spacing: 10, runSpacing: 10, children: controls),
        if (controls.isNotEmpty && toggles.isNotEmpty) const SizedBox(height: 10),
        if (toggles.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: toggles),
      ],
    );
  }
}

/// "Whole organisation" / "Engineering department only" banner.
class ReportScopeBanner extends StatelessWidget {
  const ReportScopeBanner({super.key, required this.scope});

  final ReportScope scope;

  @override
  Widget build(BuildContext context) {
    final org = scope.isOrganisation;
    return StatusPill(
      label: org
          ? 'Scope: whole organisation · active employees'
          : 'Scope: ${scope.label} only · other departments are never included',
      icon: org ? Icons.public_rounded : Icons.lock_outline_rounded,
      background: org ? HomeColors.blueTint : HomeColors.neutralTint,
      foreground: org ? HomeColors.blueDeep : HomeColors.ink,
    );
  }
}
