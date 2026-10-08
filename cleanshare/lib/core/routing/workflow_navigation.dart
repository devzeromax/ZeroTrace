import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/workflow_provider.dart';
import 'app_routes.dart';

/// Reliable exit/back for full-screen workflow routes (upload → export).
abstract final class WorkflowNavigation {
  /// Pops the workflow route or falls back to home when the stack is empty.
  static void popOrHome(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// Close workflow and return home — clears in-progress file selection.
  static void exitUpload(BuildContext context, WidgetRef ref) {
    ref.read(workflowProvider.notifier).selectFile(null);
    context.go(AppRoutes.home);
  }

  /// Cancel mid-workflow and step back one screen.
  static void cancelStep(BuildContext context, WidgetRef ref) {
    popOrHome(context);
  }

  /// Abandon scan and return to upload (keeps the selected file).
  static void cancelScan(BuildContext context, WidgetRef ref) {
    popOrHome(context);
  }

  /// Leave export flow back to fix step or home.
  static void closeExport(BuildContext context) {
    popOrHome(context);
  }
}

/// Close icon with a 48dp touch target (Material minimum).
class WorkflowCloseButton extends StatelessWidget {
  const WorkflowCloseButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Close',
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.close),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
