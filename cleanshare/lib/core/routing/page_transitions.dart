import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../animation/app_motion.dart';

bool pageTransitionsReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

CustomTransitionPage<T> _transitionPage<T>({
  required LocalKey key,
  required Widget child,
  required Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) transitionsBuilder,
}) {
  return CustomTransitionPage<T>(
    key: key,
    transitionDuration: AppMotion.pageTransition,
    reverseTransitionDuration: AppMotion.pageTransition,
    child: child,
    transitionsBuilder: transitionsBuilder,
  );
}

/// Fade + gentle scale for onboarding, welcome, and other full-screen swaps.
CustomTransitionPage<T> appFadeThroughPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return _transitionPage<T>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (pageTransitionsReduceMotion(context)) return child;

      final enter = CurvedAnimation(
        parent: animation,
        curve: AppMotion.defaultCurve,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(enter),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(enter),
          child: child,
        ),
      );
    },
  );
}

/// Slide-up for settings sub-routes (marketplace, legal, privacy).
CustomTransitionPage<T> glassSlidePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return _transitionPage<T>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (pageTransitionsReduceMotion(context)) return child;

      final enter = CurvedAnimation(
        parent: animation,
        curve: AppMotion.defaultCurve,
        reverseCurve: Curves.easeInCubic,
      );
      final exit = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInCubic,
        reverseCurve: AppMotion.defaultCurve,
      );

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(enter),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(enter),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.9).animate(exit),
            child: child,
          ),
        ),
      );
    },
  );
}

/// iOS-style horizontal push for workflow and detail screens.
CustomTransitionPage<T> workflowSharedAxisPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return _transitionPage<T>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (pageTransitionsReduceMotion(context)) return child;

      final enter = CurvedAnimation(
        parent: animation,
        curve: AppMotion.defaultCurve,
        reverseCurve: Curves.easeInCubic,
      );
      final exit = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInCubic,
        reverseCurve: AppMotion.defaultCurve,
      );

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(enter),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.94, end: 1).animate(enter),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.18, 0),
            ).animate(exit),
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0.9).animate(exit),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
