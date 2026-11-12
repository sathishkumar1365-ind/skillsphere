import 'package:flutter/material.dart';

import '../../../core/sphere_page_route.dart';
import '../data/home_models.dart';
import 'home_theme.dart';
import 'widgets/drifting_clouds.dart';
import 'widgets/gaps_section.dart';
import 'widgets/hero_section.dart';
import 'widgets/home_footer.dart';
import 'widgets/home_nav_bar.dart';
import 'widgets/projects_section.dart';
import 'widgets/scroll_reveal.dart';
import 'widgets/skill_section.dart';
import 'widgets/smooth_wheel_scroll.dart';

/// SkillSphere Home page — design Option A "Sky Sphere".
///
/// Pass real data in [data] and wire the callbacks to your navigation / API.
/// Any callback left null shows a small "not connected yet" message.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.data = HomeData.sample,
    this.onUpdateSkills,
    this.onOpenProject,
    this.onFindCourse,
    this.onOpenLearningPlan,
    this.onSearch,
    this.onNotifications,
    this.onProfile,
  });

  final HomeData data;
  final VoidCallback? onUpdateSkills;
  final ValueChanged<ProjectItem>? onOpenProject;
  final ValueChanged<SkillGap>? onFindCourse;
  final VoidCallback? onOpenLearningPlan;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  /// Opens the Home page with SkillSphere's 3D page transition.
  static Route<void> route({HomeData data = HomeData.sample}) =>
      SpherePageRoute<void>(builder: (_) => HomePage(data: data));

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();
  final Map<HomeSection, GlobalKey> _keys = {
    for (final section in HomeSection.values) section: GlobalKey(),
  };
  HomeSection _active = HomeSection.home;
  double _viewportHeight = 800;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateActiveSection);
  }

  @override
  void dispose() {
    _scroll.removeListener(_updateActiveSection);
    _scroll.dispose();
    super.dispose();
  }

  /// Highlights the nav link of the section currently in view.
  void _updateActiveSection() {
    var next = HomeSection.home;
    for (final section in const [HomeSection.skills, HomeSection.projects, HomeSection.gaps]) {
      final box = _keys[section]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        if (box.localToGlobal(Offset.zero).dy <= _viewportHeight * 0.3) next = section;
      }
    }
    final position = _scroll.position;
    if (position.maxScrollExtent > 0 && position.pixels >= position.maxScrollExtent - 2) {
      next = HomeSection.gaps;
    }
    if (next != _active) setState(() => _active = next);
  }

  /// Smoothly scrolls to a section.
  void _scrollTo(HomeSection section) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (section == HomeSection.home) {
      if (reduceMotion) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(0, duration: HomeMotion.scrollTo, curve: Curves.easeInOutCubic);
      }
      return;
    }
    final target = _keys[section]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: reduceMotion ? Duration.zero : HomeMotion.scrollTo,
      curve: Curves.easeInOutCubic,
    );
  }

  void _notConnected(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$what is not connected yet'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    _viewportHeight = media.size.height;
    final width = media.size.width;
    final sidePadding = width < 600 ? 18.0 : 32.0;
    final sectionGap = width < 600 ? 72.0 : 104.0;
    final maxWidth = 1200 + sidePadding * 2;
    final data = widget.data;

    // Each section carries its own top gap, so jumping to it leaves room for
    // the floating navigation bar.
    Widget section(HomeSection id, Widget child) => KeyedSubtree(
          key: _keys[id],
          child: Padding(
            padding: EdgeInsets.only(top: sectionGap),
            child: ScrollReveal(child: child),
          ),
        );

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
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: sidePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: media.padding.top + 112),
                          KeyedSubtree(
                            key: _keys[HomeSection.home],
                            child: HeroSection(
                              data: data,
                              onUpdateSkills: widget.onUpdateSkills ??
                                  () => _notConnected('Update my skills'),
                              onSeeGaps: () => _scrollTo(HomeSection.gaps),
                            ),
                          ),
                          section(
                            HomeSection.skills,
                            SkillsSection(skills: data.skills),
                          ),
                          section(
                            HomeSection.projects,
                            ProjectsSection(
                              projects: data.projects,
                              onOpenProject: widget.onOpenProject ??
                                  (ProjectItem project) => _notConnected('Project details'),
                            ),
                          ),
                          section(
                            HomeSection.gaps,
                            GapsSection(
                              gaps: data.gaps,
                              learningPlan: data.learningPlan,
                              nextReview: data.nextReview,
                              onFindCourse: widget.onFindCourse ??
                                  (SkillGap gap) => _notConnected('Course search'),
                              onOpenLearningPlan: widget.onOpenLearningPlan ??
                                  () => _notConnected('Learning plan'),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: sectionGap, bottom: 48),
                            child: const HomeFooter(),
                          ),
                        ],
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
                    child: HomeNavBar(
                      active: _active,
                      onSelect: _scrollTo,
                      initials: data.initials,
                      unreadNotifications: data.unreadNotifications,
                      onSearch: widget.onSearch ?? () => _notConnected('Search'),
                      onNotifications:
                          widget.onNotifications ?? () => _notConnected('Notifications'),
                      onProfile: widget.onProfile ?? () => _notConnected('Profile'),
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
