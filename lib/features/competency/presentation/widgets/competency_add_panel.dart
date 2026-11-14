import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/auth/app_user.dart';
import '../../../home/presentation/home_theme.dart';
import '../../data/competency_models.dart';
import 'add_competency_form.dart';
import 'competency_import_panel.dart';

/// HRD's left-hand panel: a switch between adding one competency with the
/// form and importing many from an Excel/CSV file. Both keep their state
/// while hidden, and the one being shown flips in (3D turn).
class CompetencyAddPanel extends StatefulWidget {
  const CompetencyAddPanel({
    super.key,
    required this.user,
    required this.onAdded,
    required this.onImported,
    required this.onOpenExisting,
  });

  final AppUser user;
  final ValueChanged<Competency> onAdded;
  final ValueChanged<List<Competency>> onImported;
  final ValueChanged<Competency> onOpenExisting;

  @override
  State<CompetencyAddPanel> createState() => _CompetencyAddPanelState();
}

class _CompetencyAddPanelState extends State<CompetencyAddPanel> {
  bool _importMode = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeSwitch(
          importMode: _importMode,
          onChanged: (value) => setState(() => _importMode = value),
        ),
        const SizedBox(height: 14),
        _FlipWhenShown(
          visible: !_importMode,
          child: AddCompetencyForm(
            user: widget.user,
            onAdded: widget.onAdded,
            onOpenExisting: widget.onOpenExisting,
          ),
        ),
        _FlipWhenShown(
          visible: _importMode,
          child: CompetencyImportPanel(
            user: widget.user,
            onImported: widget.onImported,
            onOpenExisting: widget.onOpenExisting,
          ),
        ),
      ],
    );
  }
}

/// Two-option pill switch with a sliding ink highlight.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.importMode, required this.onChanged});

  final bool importMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: HomeColors.chipBorder),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 380),
            curve: HomeMotion.ease,
            alignment: importMode ? Alignment.centerRight : Alignment.centerLeft,
            child: const FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HomeColors.ink,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _ModeOption(
                icon: Icons.edit_note_rounded,
                label: 'Add one',
                selected: !importMode,
                onTap: () => onChanged(false),
              ),
              _ModeOption(
                icon: Icons.upload_file_rounded,
                label: 'Import Excel / CSV',
                selected: importMode,
                onTap: () => onChanged(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : HomeColors.ink;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        onTap: onTap,
        label: label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: HomeText.body(13.5, weight: FontWeight.w700, color: color),
                      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
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

/// Keeps [child] (and its state) in the tree; when it becomes visible it
/// turns in around its vertical axis like a card being flipped over.
class _FlipWhenShown extends StatefulWidget {
  const _FlipWhenShown({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<_FlipWhenShown> createState() => _FlipWhenShownState();
}

class _FlipWhenShownState extends State<_FlipWhenShown> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );

  @override
  void didUpdateWidget(_FlipWhenShown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget.visible,
      maintainState: true,
      child: FadeTransition(
        opacity: _controller,
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            final remaining = 1 - Curves.easeOutCubic.transform(_controller.value);
            // Identity at rest, so no transform layer while scrolling.
            final matrix = remaining == 0
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..multiply(Matrix4.rotationY(-math.pi / 2.4 * remaining)));
            return Transform(alignment: Alignment.center, transform: matrix, child: child);
          },
        ),
      ),
    );
  }
}
