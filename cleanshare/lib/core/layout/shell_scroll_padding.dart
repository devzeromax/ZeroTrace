import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_routes.dart';
import '../theme/design_tokens.dart';

/// Bottom padding so scrollable shell content clears the floating nav bar.
abstract final class ShellScrollPadding {
  /// Nav pill height (68) + outer padding (16) + breathing room (20).
  static const navBarClearance = 104.0;

  /// Gap below the status bar / notch before shell content starts.
  static const topBreathingRoom = AppSpacing.x4;

  /// Top inset: system safe area + breathing room (status bar / Dynamic Island).
  static double topOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + topBreathingRoom;

  static EdgeInsets list(BuildContext context, {double extra = 0}) {
    final bottom = MediaQuery.paddingOf(context).bottom + navBarClearance + extra;
    return EdgeInsets.fromLTRB(
      AppSpacing.marginMobile,
      topOf(context),
      AppSpacing.marginMobile,
      bottom,
    );
  }

  /// Home and wide shell scroll views (horizontal margin matches list).
  static EdgeInsets homeScroll(BuildContext context) {
    final bottom =
        MediaQuery.paddingOf(context).bottom + navBarClearance;
    return EdgeInsets.fromLTRB(
      AppSpacing.x4,
      topOf(context),
      AppSpacing.x4,
      bottom,
    );
  }

  /// Sub-routes pushed inside the shell still show the bottom nav on mobile.
  static bool showsBottomNav(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return path.startsWith(AppRoutes.home) ||
        path.startsWith(AppRoutes.history) ||
        path.startsWith(AppRoutes.reports) ||
        path.startsWith(AppRoutes.settings);
  }
}
