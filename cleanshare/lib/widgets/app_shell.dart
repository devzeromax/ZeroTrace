import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/animation/app_motion.dart';
import '../core/layout/adaptive_breakpoints.dart';
import '../core/theme/glass_scene.dart';
import 'ambient_background.dart';
import 'glass_navigation_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tabFade;
  late final CurvedAnimation _tabCurve;
  late int _tabIndex;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.navigationShell.currentIndex;
    _tabFade = AnimationController(
      vsync: this,
      duration: AppMotion.pageTransition,
      value: 1,
    );
    _tabCurve = CurvedAnimation(
      parent: _tabFade,
      curve: AppMotion.defaultCurve,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.navigationShell.currentIndex;
    if (nextIndex == _tabIndex) return;
    _tabIndex = nextIndex;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _tabFade.forward(from: 0);
  }

  @override
  void dispose() {
    _tabCurve.dispose();
    _tabFade.dispose();
    super.dispose();
  }

  Widget _animatedShellBody(Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: _tabCurve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.02, 0),
          end: Offset.zero,
        ).animate(_tabCurve),
        child: child,
      ),
    );
  }

  static const _destinations = [
    (
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    (
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: 'History',
    ),
    (
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment,
      label: 'Reports',
    ),
    (
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  static GlassScene _sceneForIndex(int index) => switch (index) {
        0 => GlassScene.home,
        1 => GlassScene.history,
        2 => GlassScene.reports,
        3 => GlassScene.settings,
        _ => GlassScene.home,
      };

  @override
  Widget build(BuildContext context) {
    final scene = _sceneForIndex(widget.navigationShell.currentIndex);
    final shellBody = _animatedShellBody(widget.navigationShell);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail =
            constraints.maxWidth > AdaptiveBreakpoints.largeScreenMinWidth;

        if (useRail) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: AmbientBackground(
              scene: scene,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NavigationRail(
                    backgroundColor: Theme.of(context)
                        .navigationRailTheme
                        .backgroundColor,
                    selectedIndex: widget.navigationShell.currentIndex,
                    onDestinationSelected: widget.navigationShell.goBranch,
                    labelType: constraints.maxWidth > 900
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.selected,
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  Container(
                    width: 1,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  Expanded(child: shellBody),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: AmbientBackground(
            scene: scene,
            child: shellBody,
          ),
          bottomNavigationBar: GlassNavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: widget.navigationShell.goBranch,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
