import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/auth/app_user.dart';
import '../../../competency/data/competency_models.dart';
import '../../../home/presentation/home_theme.dart';
import '../../../home/presentation/widgets/home_common.dart';
import '../../data/additional_competency.dart';
import '../../data/additional_competency_repository.dart';
import 'additional_common.dart';

/// Opens the "Add an additional competency" card (it flips up in 3D).
/// Returns the saved entry, or null when cancelled.
Future<AdditionalCompetency?> showAddAdditionalDialog(
  BuildContext context, {
  required AppUser user,
  String initialName = '',
}) {
  return showGeneralDialog<AdditionalCompetency>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color.fromRGBO(15, 27, 45, 0.38),
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _AddAdditionalCard(user: user, initialName: initialName),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      return FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final eased = animation.status == AnimationStatus.reverse
                ? Curves.easeInCubic.transform(animation.value)
                : Curves.easeOutBack.transform(animation.value);
            final remaining = 1 - eased;
            final matrix = remaining == 0
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..multiply(Matrix4.translationValues(0, 60 * remaining, 0))
                  ..multiply(Matrix4.rotationX(-math.pi / 5 * remaining)));
            return Transform(alignment: Alignment.bottomCenter, transform: matrix, child: child);
          },
        ),
      );
    },
  );
}

class _AddAdditionalCard extends StatefulWidget {
  const _AddAdditionalCard({required this.user, required this.initialName});

  final AppUser user;
  final String initialName;

  @override
  State<_AddAdditionalCard> createState() => _AddAdditionalCardState();
}

class _AddAdditionalCardState extends State<_AddAdditionalCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  final _note = TextEditingController();
  final _link = TextEditingController();
  bool _saving = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  AdditionalCompetencyRepository get _repository => AdditionalCompetencyRepository.instance;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final entry = await _repository.add(
        by: widget.user,
        name: _name.text,
        note: _note.text,
        link: _link.text,
      );
      if (mounted) Navigator.of(context).pop(entry);
    } on AdditionalCompetencyException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(540.0, size.width - 24);
    final typed = _name.text;
    final suggestions = _repository.suggestionsFor(typed, employeeId: widget.user.id);
    final problem = _repository.nameProblem(typed, employeeId: widget.user.id);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AdditionalIconTile(name: typed, size: 48),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text('ADD AN ADDITIONAL COMPETENCY',
                                    style: HomeText.display(width < 420 ? 22 : 26, height: 1.05)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Something you\'re good at outside the competency '
                                'library. No levels, and nobody needs to verify it.',
                                style: HomeText.body(13.5, color: HomeColors.muted, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _Label('Name *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _name,
                      autofocus: widget.initialName.isEmpty,
                      maxLength: AdditionalCompetencyRules.nameMax,
                      textInputAction: TextInputAction.next,
                      style: _style,
                      decoration: _decoration(hint: 'e.g. Poster Design', counter: false),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return 'Enter a name.';
                        return _repository.nameProblem(text, employeeId: widget.user.id);
                      },
                    ),
                    if (problem != null && _autovalidate == AutovalidateMode.disabled)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(problem,
                            style: HomeText.body(12.5,
                                weight: FontWeight.w600, color: AppColors.error)),
                      ),
                    if (suggestions.isNotEmpty) ...[
                      Text(
                        typed.trim().isEmpty ? 'Popular in your organisation:' : 'Did you mean:',
                        style: HomeText.body(12.5, weight: FontWeight.w600, color: HomeColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in suggestions)
                            ActionChip(
                              onPressed: () => setState(() {
                                _name.text = s;
                                _name.selection = TextSelection.collapsed(offset: s.length);
                              }),
                              avatar: Icon(additionalIconFor(s),
                                  size: 16, color: AdditionalColors.foreground),
                              label: Text(s),
                              labelStyle: HomeText.body(12.5,
                                  weight: FontWeight.w600, color: HomeColors.ink),
                              backgroundColor: AdditionalColors.tint,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    const _Label('What have you done with it? (optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 3,
                      maxLength: AdditionalCompetencyRules.noteMax,
                      style: _style,
                      decoration: _decoration(
                          hint: 'e.g. Designed the posters for Road Safety Week 2026.'),
                    ),
                    const SizedBox(height: 10),
                    const _Label('Link to sample work (optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _link,
                      keyboardType: TextInputType.url,
                      style: _style,
                      decoration: _decoration(
                        hint: 'https://…',
                        helper: 'A portfolio, video or shared folder others can open.',
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty || CompetencyRules.isValidLink(text)) return null;
                        return 'Enter a full link starting with https://';
                      },
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        PillButton(
                          label: _saving ? 'Adding…' : 'Add',
                          onPressed: _saving ? null : _submit,
                        ),
                        PillButton(
                          label: 'Cancel',
                          variant: PillVariant.outline,
                          onPressed: _saving ? null : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: HomeText.body(13.5, weight: FontWeight.w700, color: HomeColors.ink));
}

final TextStyle _style = HomeText.body(15, color: HomeColors.ink, height: 1.45);

InputDecoration _decoration({required String hint, String? helper, bool counter = true}) {
  const radius = BorderRadius.all(Radius.circular(14));
  return InputDecoration(
    hintText: hint,
    hintStyle: HomeText.body(14.5, color: HomeColors.muted),
    helperText: helper,
    helperMaxLines: 2,
    helperStyle: HomeText.body(12.5, color: HomeColors.muted),
    errorMaxLines: 3,
    errorStyle: HomeText.body(12.5, weight: FontWeight.w600, color: AppColors.error),
    counterText: counter ? null : '',
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
