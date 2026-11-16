import 'package:flutter/material.dart';

import '../../../core/auth/app_user.dart';
import '../../home/presentation/home_theme.dart';
import '../../home/presentation/widgets/home_common.dart';
import '../../home/presentation/widgets/lift_card.dart';
import '../data/additional_competency.dart';
import '../data/additional_competency_repository.dart';
import 'widgets/add_additional_dialog.dart';
import 'widgets/additional_common.dart';

/// Home page section where employees (and Team Leads) list what they are
/// good at outside the competency library: Content Creation, Poster Design…
/// No levels and no verification; HRD can see the list.
class MyAdditionalSection extends StatelessWidget {
  const MyAdditionalSection({super.key, required this.user});

  final AppUser user;

  AdditionalCompetencyRepository get _repository => AdditionalCompetencyRepository.instance;

  Future<void> _add(BuildContext context, {String name = ''}) async {
    final entry = await showAddAdditionalDialog(context, user: user, initialName: name);
    if (entry == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${entry.name} added to your additional competencies.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _remove(BuildContext context, AdditionalCompetency entry) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repository.remove(entry, by: user);
    } on AdditionalCompetencyException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${entry.name} removed.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _repository
                .add(by: user, name: entry.name, note: entry.note, link: entry.link)
                .catchError((Object _) => entry);
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AdditionalCompetency>>(
      valueListenable: _repository.entries,
      builder: (context, _, _) {
        final mine = _repository.forEmployee(user.id);
        final canAddMore = mine.length < AdditionalCompetencyRules.maxPerEmployee;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 980 ? 3 : (width >= 620 ? 2 : 1);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'ADDITIONAL COMPETENCIES',
                  subtitle: 'What you\'re good at outside the company competency library, '
                      'like content creation or poster design. Add them yourself: no '
                      'levels and nobody needs to verify them. HRD can find you when an '
                      'event or campaign needs these skills.',
                  trailing: canAddMore
                      ? PillButton(
                          label: 'Add additional competency',
                          onPressed: () => _add(context),
                        )
                      : null,
                ),
                const SizedBox(height: 32),
                if (mine.isEmpty)
                  _EmptyState(
                    suggestions: _repository.suggestionsFor('', employeeId: user.id, limit: 6),
                    onPick: (name) => _add(context, name: name),
                  )
                else
                  EqualHeightGrid(
                    columns: columns,
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      for (final entry in mine)
                        _AdditionalCard(
                          key: ValueKey(entry.id),
                          entry: entry,
                          onRemove: () => _remove(context, entry),
                        ),
                      if (canAddMore) _AddTile(onTap: () => _add(context)),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AdditionalCard extends StatelessWidget {
  const _AdditionalCard({super.key, required this.entry, required this.onRemove});

  final AdditionalCompetency entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final note = noteOf(entry);
    final link = entry.link;
    return LiftCard(
      padding: EdgeInsets.zero,
      child: DashedOutline(
        color: AdditionalColors.dash,
        radius: 22,
        strokeWidth: 1.4,
        dash: 6,
        gap: 4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdditionalIconTile(name: entry.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.name,
                            style: HomeText.body(17, weight: FontWeight.w800, color: HomeColors.ink)),
                        const SizedBox(height: 5),
                        const SelfDeclaredPill(),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove ${entry.name}',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, size: 18, color: HomeColors.muted),
                  ),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(note, style: HomeText.body(14, color: HomeColors.body, height: 1.5)),
              ],
              const Spacer(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: link != null && link.trim().isNotEmpty
                        ? Align(alignment: Alignment.centerLeft, child: SampleWorkLink(link: link))
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('Added ${formatAddedDate(entry.addedAt)}',
                        style: HomeText.body(12, color: HomeColors.muted)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed "+ Add another" tile at the end of the grid.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add another additional competency',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: const Color.fromRGBO(255, 255, 255, 0.55),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: DashedOutline(
            color: HomeColors.chipBorder,
            radius: 22,
            strokeWidth: 1.4,
            dash: 6,
            gap: 4,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: HomeColors.ink, shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text('Add another',
                      style: HomeText.body(15, weight: FontWeight.w700, color: HomeColors.ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return DashedOutline(
      color: AdditionalColors.dash,
      radius: 24,
      strokeWidth: 1.4,
      dash: 6,
      gap: 4,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: const BoxDecoration(
          color: Color.fromRGBO(255, 255, 255, 0.7),
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nothing here yet.',
                style: HomeText.body(17, weight: FontWeight.w800, color: HomeColors.ink)),
            const SizedBox(height: 6),
            Text(
              'Add things you\'re good at outside your job role. Tap one to start:',
              style: HomeText.body(14.5, color: HomeColors.body, height: 1.5),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in suggestions)
                  ActionChip(
                    onPressed: () => onPick(s),
                    avatar: Icon(additionalIconFor(s), size: 16, color: AdditionalColors.foreground),
                    label: Text(s),
                    labelStyle:
                        HomeText.body(13, weight: FontWeight.w600, color: HomeColors.ink),
                    backgroundColor: AdditionalColors.tint,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
