import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../organization/data/org_models.dart';
import '../data/competency_models.dart';
import '../data/competency_repository.dart';
import '../../additional_competency/presentation/additional_directory_panel.dart';
import 'widgets/competency_add_panel.dart';
import 'widgets/competency_details_panel.dart';
import 'widgets/competency_library.dart';

/// "Competencies" section of the HRD dashboard.
///
/// HRD (Super Admin) sees the Add form next to the library, so the current
/// competencies stay in view while a new one is being typed. Selecting any
/// competency opens its details (logo, description, Level 0–5 guide and the
/// employees who hold it) in a panel over the page; the form keeps its text.
///
/// HRD can also switch the left panel to a bulk import from Excel/CSV, and
/// below both sees the employees' self-declared Additional Competencies.
///
/// Anyone else gets the library only (read-only), so the same widget can be
/// reused later for Team Leads and employees.
class CompetencySection extends StatefulWidget {
  const CompetencySection({
    super.key,
    required this.user,
    required this.employees,
    this.onOpenEmployee,
  });

  final AppUser user;

  /// Used to show who holds each competency.
  final List<EmployeeRecord> employees;
  final ValueChanged<EmployeeRecord>? onOpenEmployee;

  @override
  State<CompetencySection> createState() => _CompetencySectionState();
}

class _CompetencySectionState extends State<CompetencySection> {
  late Map<String, EmployeeRecord> _employeesById = _index(widget.employees);

  /// The competency added last; its card flips into the library.
  String? _justAddedId;

  // Keep the typed form text and the library filters when a window resize
  // switches between side-by-side and stacked layouts.
  final GlobalKey _formKey = GlobalKey(debugLabel: 'add-competency-panel');
  final GlobalKey _libraryKey = GlobalKey(debugLabel: 'competency-library');

  CompetencyRepository get _repository => CompetencyRepository.instance;

  static Map<String, EmployeeRecord> _index(List<EmployeeRecord> employees) =>
      {for (final e in employees) e.id: e};

  @override
  void didUpdateWidget(CompetencySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.employees, widget.employees)) {
      _employeesById = _index(widget.employees);
    }
  }

  void _open(Competency competency) {
    showCompetencyDetails(
      context,
      competency: competency,
      employeesById: _employeesById,
      onOpenEmployee: widget.onOpenEmployee,
    );
  }

  void _handleImported(List<Competency> added) {
    if (added.isEmpty) return;
    setState(() => _justAddedId = added.first.id);
    final count = added.length;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$count ${count == 1 ? 'competency' : 'competencies'} imported. '
            'They are marked NEW in the library.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'View first', onPressed: () => _open(added.first)),
      ));
  }

  void _handleAdded(Competency competency) {
    setState(() => _justAddedId = competency.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${competency.name} added to ${competency.category.plural}.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'View', onPressed: () => _open(competency)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.user.role.canManageCompetencies;

    return ValueListenableBuilder<List<Competency>>(
      valueListenable: _repository.competencies,
      builder: (context, competencies, _) {
        final library = CompetencyLibrary(
          key: _libraryKey,
          competencies: competencies,
          onOpen: _open,
          isNew: _repository.isNew,
          spotlightId: _justAddedId,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final sideBySide = width >= 940;
            final formWidth = width >= 1100 ? 440.0 : 400.0;

            final Widget body;
            if (!canManage) {
              body = library;
            } else {
              final form = CompetencyAddPanel(
                key: _formKey,
                user: widget.user,
                onAdded: _handleAdded,
                onImported: _handleImported,
                onOpenExisting: _open,
              );
              body = sideBySide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: formWidth, child: form),
                        const SizedBox(width: 24),
                        Expanded(child: library),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [form, const SizedBox(height: 24), library],
                    );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'COMPETENCIES',
                  subtitle: canManage
                      ? 'Add the skills, tools, languages and domains employees are '
                          'rated on, each with a Level 0–5 guide, one at a time or '
                          'from an Excel/CSV file. Select any competency to see its '
                          'levels and who holds it.'
                      : 'The skills, tools, languages and domains employees are rated '
                          'on. Select one to see its Level 0–5 guide.',
                ),
                const SizedBox(height: 32),
                body,
                if (canManage) ...[
                  const SizedBox(height: 24),
                  AdditionalDirectoryPanel(
                    employeesById: _employeesById,
                    onOpenEmployee: widget.onOpenEmployee,
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
