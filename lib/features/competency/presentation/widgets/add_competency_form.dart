import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/auth/app_user.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../../home/presentation/widgets/lift_card.dart';
import '../../../organization/presentation/widgets/org_common.dart';
import '../../data/competency_models.dart';
import '../../data/competency_repository.dart';
import 'competency_common.dart';

/// "Add a new competency" form (HRD team only).
///
/// Category, name, short description, optional logo link and what each
/// level from 0 to 5 means. While typing a name, existing competencies with
/// similar names are listed so HRD doesn't add a duplicate.
class AddCompetencyForm extends StatefulWidget {
  const AddCompetencyForm({
    super.key,
    required this.user,
    required this.onAdded,
    required this.onOpenExisting,
  });

  final AppUser user;

  /// Called after the competency is saved.
  final ValueChanged<Competency> onAdded;

  /// Opens an existing competency (from the "already in the library" hints).
  final ValueChanged<Competency> onOpenExisting;

  @override
  State<AddCompetencyForm> createState() => _AddCompetencyFormState();
}

class _AddCompetencyFormState extends State<AddCompetencyForm> {
  static const _nameMax = 60;
  static const _descriptionMax = 300;
  static const _levelMax = 200;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _logo = TextEditingController();
  final List<TextEditingController> _levels =
      List.generate(CompetencyLevel.count, (_) => TextEditingController());

  CompetencyCategory? _category;
  bool _showCategoryError = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _saving = false;

  /// Logo link shown in the preview (updated shortly after typing stops, so
  /// the image isn't requested on every keystroke).
  String _logoPreview = '';
  Timer? _logoDebounce;

  CompetencyRepository get _repository => CompetencyRepository.instance;

  @override
  void dispose() {
    _logoDebounce?.cancel();
    _name.dispose();
    _description.dispose();
    _logo.dispose();
    for (final c in _levels) {
      c.dispose();
    }
    super.dispose();
  }

  void _showMessage(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        action: action,
      ));
  }

  void _onLogoChanged(String value) {
    _logoDebounce?.cancel();
    _logoDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final link = value.trim();
      setState(() => _logoPreview = _isValidLink(link) ? link : '');
    });
  }

  static bool _isValidLink(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  void _useStandardWording() {
    var filled = 0;
    for (var i = 0; i < _levels.length; i++) {
      if (_levels[i].text.trim().isEmpty) {
        _levels[i].text = CompetencyLevel.standardDescriptions[i];
        filled++;
      }
    }
    if (filled == 0) {
      _showMessage('All six levels already have a description.');
    } else {
      _showMessage('Standard wording added to $filled '
          '${filled == 1 ? 'level' : 'levels'}. Edit it to fit this competency.');
    }
  }

  void _clear() {
    _logoDebounce?.cancel();
    _formKey.currentState?.reset();
    _name.clear();
    _description.clear();
    _logo.clear();
    for (final c in _levels) {
      c.clear();
    }
    setState(() {
      _category = null;
      _showCategoryError = false;
      _autovalidate = AutovalidateMode.disabled;
      _logoPreview = '';
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final category = _category;
    final fieldsValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _showCategoryError = category == null;
      _autovalidate = AutovalidateMode.onUserInteraction;
    });
    if (category == null || !fieldsValid) {
      _showMessage('Please fill in the highlighted fields.');
      return;
    }

    setState(() => _saving = true);
    try {
      final added = await _repository.add(
        by: widget.user,
        category: category,
        name: _name.text,
        description: _description.text,
        logoUrl: _logo.text,
        levelDescriptions: [for (final c in _levels) c.text],
      );
      if (!mounted) return;
      _clear();
      widget.onAdded(added);
    } on CompetencyException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final example = category?.example ?? 'Java';

    return OrgPanel(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Level tag above its field in the narrow side panel; side by side
          // when the form has the full width.
          final stackLevels = width < 480;

          return Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: HomeColors.ink,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: PanelTitle(
                        'Add a new competency',
                        subtitle: 'HRD team only. Fields marked * are required.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ---------------------------------------------- category
                const _FieldLabel('Category *'),
                const SizedBox(height: 10),
                _CategoryPicker(
                  selected: category,
                  columns: width >= 520 ? 4 : 2,
                  onChanged: (value) => setState(() {
                    _category = value;
                    _showCategoryError = false;
                  }),
                ),
                if (_showCategoryError) ...[
                  const SizedBox(height: 8),
                  const _ErrorText('Choose a category: Skill, Tool, Language or Domain.'),
                ],
                const SizedBox(height: 20),

                // -------------------------------------------------- name
                const _FieldLabel('Name *'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  maxLength: _nameMax,
                  style: _inputStyle,
                  decoration: _decoration(
                    hint: 'e.g. $example',
                    counter: false,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Enter the competency name.';
                    final existing = _repository.findByName(text);
                    if (existing != null) {
                      return '"${existing.name}" is already in the library '
                          '(${existing.category.label}).';
                    }
                    return null;
                  },
                ),
                _SimilarHint(
                  matches: _repository.similarTo(_name.text),
                  typed: _name.text,
                  onOpen: widget.onOpenExisting,
                ),
                const SizedBox(height: 14),

                // ------------------------------------------- description
                const _FieldLabel('Short description *'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: _descriptionMax,
                  keyboardType: TextInputType.multiline,
                  style: _inputStyle,
                  decoration: _decoration(
                    hint: 'One or two sentences: what it is and where we use it.',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Add a short description.';
                    if (text.length < 15) return 'Add a little more detail (15 characters or more).';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // -------------------------------------------------- logo
                const _FieldLabel('Logo (optional)'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: CompetencyBadge(
                        name: _name.text.trim().isEmpty ? example : _name.text.trim(),
                        category: category ?? CompetencyCategory.language,
                        logoUrl: _logoPreview,
                        size: 52,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _logo,
                        keyboardType: TextInputType.url,
                        style: _inputStyle,
                        decoration: _decoration(
                          hint: 'https://…/logo.png',
                          helper: 'Link to a PNG, JPG or WebP image. Leave empty '
                              'to use the lettered badge.',
                        ),
                        onChanged: _onLogoChanged,
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty || _isValidLink(text)) return null;
                          return 'Enter a full link starting with https://';
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                // ----------------------------------------------- levels
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    const _FieldLabel('Level guide · 0 to 5 *'),
                    TextButton.icon(
                      onPressed: _saving ? null : _useStandardWording,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('Use standard wording'),
                      style: TextButton.styleFrom(
                        foregroundColor: HomeColors.blue,
                        textStyle: HomeText.body(13.5, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Describe what someone can do at each level. Employees choose '
                  'their level from this guide and Team Leads verify it.',
                  style: HomeText.body(13.5, color: HomeColors.muted, height: 1.45),
                ),
                const SizedBox(height: 14),
                for (var level = 0; level < CompetencyLevel.count; level++) ...[
                  if (level > 0) const SizedBox(height: 12),
                  _LevelField(
                    level: level,
                    controller: _levels[level],
                    stacked: stackLevels,
                    maxLength: _levelMax,
                  ),
                ],
                const SizedBox(height: 26),

                // ----------------------------------------------- actions
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    PillButton(
                      label: _saving ? 'Adding…' : 'Add competency',
                      onPressed: _saving ? null : _submit,
                    ),
                    PillButton(
                      label: 'Clear',
                      variant: PillVariant.outline,
                      onPressed: _saving ? null : _clear,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------- field style

final TextStyle _inputStyle = HomeText.body(15, color: HomeColors.ink, height: 1.45);

InputDecoration _decoration({required String hint, String? helper, bool counter = true}) {
  const radius = BorderRadius.all(Radius.circular(14));
  return InputDecoration(
    hintText: hint,
    hintStyle: HomeText.body(14.5, color: HomeColors.muted),
    helperText: helper,
    helperMaxLines: 3,
    helperStyle: HomeText.body(12.5, color: HomeColors.muted),
    errorMaxLines: 3,
    errorStyle: HomeText.body(12.5, weight: FontWeight.w600, color: AppColors.error),
    // Hide the "12/60" counter where it adds nothing.
    counterText: counter ? null : '',
    counterStyle: HomeText.body(12, color: HomeColors.muted),
    filled: true,
    fillColor: const Color(0xFFF4F8FC),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomeColors.cardBorder),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomeColors.ink, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.error, width: 1.5),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink));
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(text,
          style: HomeText.body(12.5, weight: FontWeight.w600, color: AppColors.error)),
    );
  }
}

// --------------------------------------------------------- category picker

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.selected,
    required this.columns,
    required this.onChanged,
  });

  final CompetencyCategory? selected;
  final int columns;
  final ValueChanged<CompetencyCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Category',
      child: EqualHeightGrid(
        columns: columns,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final category in CompetencyCategory.values)
            _CategoryOption(
              category: category,
              selected: category == selected,
              onTap: () => onChanged(category),
            ),
        ],
      ),
    );
  }
}

/// One category choice: lifts in 3D on hover, turns ink-black when chosen.
class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final CompetencyCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category);
    final foreground = selected ? Colors.white : HomeColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      onTap: onTap,
      label: '${category.label}, for example ${category.example}',
      excludeSemantics: true,
      child: LiftCard(
        padding: EdgeInsets.zero,
        radius: 16,
        liftBy: 5,
        tiltDegrees: 8,
        color: selected ? HomeColors.ink : Colors.white,
        borderColor: selected ? HomeColors.ink : HomeColors.chipBorder,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selected ? const Color.fromRGBO(255, 255, 255, 0.14) : style.tint,
                          borderRadius: const BorderRadius.all(Radius.circular(9)),
                        ),
                        child: Icon(style.icon,
                            size: 17, color: selected ? Colors.white : style.foreground),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: selected
                            ? const Icon(Icons.check_circle_rounded,
                                key: ValueKey('on'), size: 18, color: HomeColors.peach)
                            : const SizedBox(key: ValueKey('off'), width: 18, height: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(category.label,
                      style: HomeText.body(14.5, weight: FontWeight.w800, color: foreground)),
                  const SizedBox(height: 2),
                  Text(
                    'e.g. ${category.example}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.body(12,
                        color: selected ? HomeColors.onInkMuted : HomeColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------ duplicate warnings

/// "Already in the library: Java · JavaScript" under the name field.
class _SimilarHint extends StatelessWidget {
  const _SimilarHint({required this.matches, required this.typed, required this.onOpen});

  final List<Competency> matches;
  final String typed;
  final ValueChanged<Competency> onOpen;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final exact = matches.any((c) => c.key == Competency.keyFor(typed));
    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      curve: HomeMotion.ease,
      alignment: Alignment.topLeft,
      child: matches.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        exact ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                        size: 16,
                        color: exact ? AppColors.error : HomeColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          exact
                              ? 'This name is already taken. Open it instead:'
                              : 'Similar names already in the library:',
                          style: HomeText.body(12.5,
                              weight: FontWeight.w600,
                              color: exact ? AppColors.error : HomeColors.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in matches)
                        ActionChip(
                          onPressed: () => onOpen(c),
                          tooltip: 'Open ${c.name}',
                          avatar: CompetencyBadge.of(c, size: 22),
                          label: Text('${c.name} · ${c.category.label}'),
                          labelStyle: HomeText.body(12.5,
                              weight: FontWeight.w600, color: HomeColors.ink),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: HomeColors.chipBorder),
                          shape: const StadiumBorder(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
    );
  }
}

// ------------------------------------------------------------ level field

class _LevelField extends StatelessWidget {
  const _LevelField({
    required this.level,
    required this.controller,
    required this.stacked,
    required this.maxLength,
  });

  final int level;
  final TextEditingController controller;
  final bool stacked;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final name = CompetencyLevel.name(level);
    final tag = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: levelBlockColor(level),
            borderRadius: const BorderRadius.all(Radius.circular(11)),
          ),
          child: Text('$level',
              style: HomeText.display(20, color: levelBlockText(level), height: 1.0)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LEVEL $level',
                  maxLines: 1,
                  style: HomeText.body(10.5,
                      weight: FontWeight.w800, color: HomeColors.muted, letterSpacing: 1)),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.body(13, weight: FontWeight.w700, color: HomeColors.ink)),
            ],
          ),
        ),
      ],
    );
    final field = TextFormField(
      controller: controller,
      minLines: 2,
      maxLines: 4,
      maxLength: maxLength,
      keyboardType: TextInputType.multiline,
      style: _inputStyle,
      decoration: _decoration(
        hint: 'What does Level $level ($name) look like?',
        counter: false,
      ),
      validator: (value) =>
          (value ?? '').trim().isEmpty ? 'Describe Level $level ($name).' : null,
    );

    return Semantics(
      container: true,
      label: 'Level $level, $name',
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [tag, const SizedBox(height: 8), field],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Padding(padding: const EdgeInsets.only(top: 4), child: tag),
                ),
                const SizedBox(width: 10),
                Expanded(child: field),
              ],
            ),
    );
  }
}
