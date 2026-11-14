import 'package:flutter/material.dart';

import '../../competency/presentation/widgets/competency_common.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../organization/data/org_models.dart';
import '../../organization/presentation/widgets/org_common.dart';
import '../data/additional_competency.dart';
import '../data/additional_competency_repository.dart';
import 'widgets/additional_common.dart';

/// HRD view of everyone's Additional Competencies (self-declared, not
/// verified): search by skill, note, person or department, and filter by
/// skill, e.g. "who can design a poster for Safety Week?".
class AdditionalDirectoryPanel extends StatefulWidget {
  const AdditionalDirectoryPanel({
    super.key,
    required this.employeesById,
    this.onOpenEmployee,
  });

  final Map<String, EmployeeRecord> employeesById;
  final ValueChanged<EmployeeRecord>? onOpenEmployee;

  @override
  State<AdditionalDirectoryPanel> createState() => _AdditionalDirectoryPanelState();
}

class _AdditionalDirectoryPanelState extends State<AdditionalDirectoryPanel> {
  static const _pageSize = 12;

  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _selectedKey; // null = all skills
  int _limit = _pageSize;

  AdditionalCompetencyRepository get _repository => AdditionalCompetencyRepository.instance;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilter(VoidCallback change) => setState(() {
        change();
        _limit = _pageSize;
      });

  void _open(EmployeeRecord? employee) {
    final open = widget.onOpenEmployee;
    if (employee != null && open != null) {
      open(employee);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Employee profile is not connected yet'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AdditionalCompetency>>(
      valueListenable: _repository.entries,
      builder: (context, entries, _) {
        final names = _repository.nameCounts;
        final selected = _selectedKey;
        final query = _query.trim().toLowerCase();
        final employees = widget.employeesById;

        final matches = entries.where((e) {
          if (selected != null && e.key != selected) return false;
          if (query.isEmpty) return true;
          final person = employees[e.employeeId];
          final text = '${e.searchText} ${person?.name ?? ''} ${person?.department ?? ''} '
                  '${person?.designation ?? ''}'
              .toLowerCase();
          return text.contains(query);
        }).toList()
          ..sort((a, b) {
            final byName = a.name.compareTo(b.name);
            if (byName != 0) return byName;
            return (employees[a.employeeId]?.name ?? a.employeeId)
                .compareTo(employees[b.employeeId]?.name ?? b.employeeId);
          });
        final shown = matches.take(_limit).toList();
        final people = {for (final e in entries) e.employeeId}.length;

        return OrgPanel(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 980 ? 3 : (width >= 640 ? 2 : 1);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdditionalIconTile(name: '', size: 40),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: PanelTitle(
                          'Additional competencies',
                          subtitle: 'Self-declared by employees and not verified: skills '
                              'outside the competency library, such as content creation '
                              'or poster design. Use it to find people for events, '
                              'campaigns and internal communication.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: width < 560 ? width : 340,
                        child: CompetencySearchField(
                          controller: _search,
                          hint: 'Search skill, note, person, department…',
                          onChanged: (value) => _setFilter(() => _query = value),
                          onClear: () => _setFilter(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                      ),
                      Text(
                        '${entries.length} entries · ${names.length} skills · $people employees',
                        style: HomeText.body(13.5, weight: FontWeight.w600, color: HomeColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    container: true,
                    label: 'Filter by additional competency',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OrgFilterPill(
                          label: 'All · ${entries.length}',
                          selected: selected == null,
                          onTap: () => _setFilter(() => _selectedKey = null),
                        ),
                        for (final n in names)
                          OrgFilterPill(
                            label: '${n.name} · ${n.count}',
                            selected: selected == AdditionalCompetency.keyFor(n.name),
                            onTap: () => _setFilter(
                                () => _selectedKey = AdditionalCompetency.keyFor(n.name)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (shown.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF4F8FC),
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                      ),
                      child: Text(
                        entries.isEmpty
                            ? 'No employee has added an additional competency yet.'
                            : 'Nobody matches this search.',
                        style: HomeText.body(14.5),
                      ),
                    )
                  else
                    EqualHeightGrid(
                      columns: columns,
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final e in shown)
                          _EntryTile(
                            entry: e,
                            employee: employees[e.employeeId],
                            onTap: () => _open(employees[e.employeeId]),
                          ),
                      ],
                    ),
                  if (matches.length > shown.length) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: PillButton(
                        label: 'Show more (${matches.length - shown.length} left)',
                        variant: PillVariant.outline,
                        height: 46,
                        fontSize: 14,
                        onPressed: () => setState(() => _limit += _pageSize),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.employee, required this.onTap});

  final AdditionalCompetency entry;
  final EmployeeRecord? employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final person = employee;
    final note = noteOf(entry);
    final link = entry.link;
    final initials = person?.initials ?? '?';

    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: HomeColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AdditionalIconTile(name: entry.name, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HomeText.body(15.5,
                            weight: FontWeight.w800, color: AdditionalColors.foreground)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  InitialsAvatar(initials: initials, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person?.name ?? entry.employeeId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.body(14, weight: FontWeight.w700, color: HomeColors.ink)),
                        Text(
                          person == null ? '' : '${person.designation} · ${person.department}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HomeText.body(12.5, color: HomeColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(13.5, color: HomeColors.body, height: 1.45)),
              ],
              const Spacer(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: link != null && link.trim().isNotEmpty
                        ? Align(alignment: Alignment.centerLeft, child: SampleWorkLink(link: link))
                        : Text('No sample link',
                            style: HomeText.body(12, color: HomeColors.muted)),
                  ),
                  Text(formatAddedDate(entry.addedAt),
                      style: HomeText.body(12, color: HomeColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
