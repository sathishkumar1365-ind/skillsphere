import 'dart:async';

import 'package:flutter/material.dart';

import '../home_theme.dart';
import 'drifting_clouds.dart';
import 'home_footer.dart';
import 'scroll_reveal.dart';
import 'smooth_wheel_scroll.dart';

/// One section of a [SphereScrollPage]: its name in the nav bar and content.
class SphereSection {
  const SphereSection({required this.label, required this.child});

  final String label;
  final Widget child;
}

/// Builds the floating nav bar. [activeIndex] is the section in view;
/// call [onSelect] to scroll to a section.
typedef SphereNavBarBuilder = Widget Function(
  BuildContext context,
  int activeIndex,
  ValueChanged<int> onSelect,
);

/// The "Sky Sphere" single-page layout shared by the Home page and the
/// Super Admin dashboard: sky + drifting clouds, smooth wheel scrolling,
/// sections that rise in on scroll, and a pinned nav bar whose highlighted
/// link follows the section in view.
///
/// The first section is the hero: it has no top gap and handles its own
/// reveal animations.
///
/// Scroll performance:
/// * every section is its own RepaintBoundary, and so is the whole page, so
///   scrolling only moves already-painted layers instead of repainting all
///   cards every frame;
/// * the active nav link is a ValueNotifier, so only the nav bar rebuilds
///   when it changes (not the whole page);
/// * hover effects are paused while the page is moving, so cards sliding
///   under a still mouse cursor don't start 3D lift animations mid-scroll.
class SphereScrollPage extends StatefulWidget {
  const SphereScrollPage({
    super.key,
    required this.sections,
    required this.navBarBuilder,
    this.footer = const HomeFooter(),
  });

  final List<SphereSection> sections;
  final SphereNavBarBuilder navBarBuilder;
  final Widget footer;

  @override
  State<SphereScrollPage> createState() => SphereScrollPageState();
}

class SphereScrollPageState extends State<SphereScrollPage> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<int> _active = ValueNotifier<int>(0);
  final ValueNotifier<bool> _scrolling = ValueNotifier<bool>(false);
  Timer? _scrollIdle;
  List<GlobalKey> _keys = const [];
  double _viewportHeight = 800;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.sections.length, (_) => GlobalKey());
    _scroll.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(SphereScrollPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sections.length != widget.sections.length) {
      _keys = List.generate(widget.sections.length, (_) => GlobalKey());
      if (_active.value >= widget.sections.length) _active.value = 0;
    }
  }

  @override
  void dispose() {
    _scrollIdle?.cancel();
    _scroll.removeListener(_handleScroll);
    _scroll.dispose();
    _active.dispose();
    _scrolling.dispose();
    super.dispose();
  }

  void _handleScroll() {
    _updateActiveSection();
    _scrolling.value = true;
    _scrollIdle?.cancel();
    _scrollIdle = Timer(const Duration(milliseconds: 180), () => _scrolling.value = false);
  }

  /// Highlights the nav link of the section currently in view.
  void _updateActiveSection() {
    var next = 0;
    for (var i = 1; i < _keys.length; i++) {
      final box = _keys[i].currentContext?.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        if (box.localToGlobal(Offset.zero).dy <= _viewportHeight * 0.3) next = i;
      }
    }
    final position = _scroll.position;
    if (position.maxScrollExtent > 0 && position.pixels >= position.maxScrollExtent - 2) {
      next = _keys.length - 1;
    }
    _active.value = next;
  }

  /// Smoothly scrolls to the section at [index].
  void scrollToSection(int index) {
    if (!_scroll.hasClients || index < 0 || index >= _keys.length) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (index == 0) {
      if (reduceMotion) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(0, duration: HomeMotion.scrollTo, curve: Curves.easeInOutCubic);
      }
      return;
    }
    final target = _keys[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: reduceMotion ? Duration.zero : HomeMotion.scrollTo,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    _viewportHeight = size.height;
    final width = size.width;
    final sidePadding = width < 600 ? 18.0 : 32.0;
    final sectionGap = width < 600 ? 72.0 : 104.0;
    final maxWidth = 1200 + sidePadding * 2;
    final sections = widget.sections;

    final content = <Widget>[SizedBox(height: topInset + 112)];
    for (var i = 0; i < sections.length; i++) {
      // Each section carries its own top gap, so jumping to it leaves room
      // for the floating navigation bar.
      content.add(KeyedSubtree(
        key: _keys[i],
        child: i == 0
            ? RepaintBoundary(child: sections[i].child)
            : Padding(
                padding: EdgeInsets.only(top: sectionGap),
                child: ScrollReveal(
                  child: RepaintBoundary(child: sections[i].child),
                ),
              ),
      ));
    }
    content.add(Padding(
      padding: EdgeInsets.only(top: sectionGap, bottom: 48),
      child: widget.footer,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFE),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: HomeColors.skyGradient)),
          ),
          Positioned.fill(child: DriftingClouds(scrollController: _scroll)),
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scroll,
              child: SmoothWheelScroll(
                controller: _scroll,
                // Inside the wheel listener, so wheel events still arrive
                // while hover/clicks are paused during scrolling.
                child: ValueListenableBuilder<bool>(
                  valueListenable: _scrolling,
                  builder: (context, scrolling, child) =>
                      IgnorePointer(ignoring: scrolling, child: child),
                  child: RepaintBoundary(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: sidePadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 0),
                    child: ValueListenableBuilder<int>(
                      valueListenable: _active,
                      builder: (context, active, _) =>
                          widget.navBarBuilder(context, active, scrollToSection),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
