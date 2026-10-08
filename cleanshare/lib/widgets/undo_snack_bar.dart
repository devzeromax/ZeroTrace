import 'dart:async';

import 'package:flutter/material.dart';

import '../core/animation/app_motion.dart';
import '../core/theme/design_tokens.dart';

/// Slide-in undo toast — inspired by
/// [pksunny/flutter-ui-and-animations #180-delete-undo-snackbar](https://github.com/pksunny/flutter-ui-and-animations/tree/main/lib/screens/180-delete-undo-snackbar).
abstract final class UndoSnackBar {
  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 4),
  }) {
    dismiss();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _UndoSnackBarOverlay(
        message: message,
        onUndo: () {
          dismiss();
          onUndo();
        },
        onDismiss: dismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _UndoSnackBarOverlay extends StatefulWidget {
  const _UndoSnackBarOverlay({
    required this.message,
    required this.onUndo,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  @override
  State<_UndoSnackBarOverlay> createState() => _UndoSnackBarOverlayState();
}

class _UndoSnackBarOverlayState extends State<_UndoSnackBarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.defaultCurve),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.spring));

    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onDismiss();
      return;
    }
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: AppSpacing.x4,
      right: AppSpacing.x4,
      bottom: AppSpacing.x4 + bottom,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            color: colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x3,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: colorScheme.onInverseSurface,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onUndo();
                    },
                    child: Text(
                      'Undo',
                      style: TextStyle(
                        color: colorScheme.inversePrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _close,
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: colorScheme.onInverseSurface.withValues(alpha: 0.7),
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
