import 'package:flutter/material.dart';

import '../core/animation/app_motion.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/theme_surfaces.dart';

/// Solid, theme-aware file picker — no glass effects.
class UploadDropZone extends StatefulWidget {
  const UploadDropZone({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<UploadDropZone> createState() => _UploadDropZoneState();
}

class _UploadDropZoneState extends State<UploadDropZone> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = ThemeSurfaces.isDark(context);

    return Semantics(
      button: true,
      label:
          'Browse files. JPEG, PNG, HEIC, PDF, Office, and code files supported.',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.995 : 1,
          duration: AppDurations.fast,
          curve: AppMotion.defaultCurve,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppMotion.defaultCurve,
            constraints: const BoxConstraints(
              minHeight: 300,
              maxWidth: 520,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x6,
              vertical: AppSpacing.x8,
            ),
            decoration: BoxDecoration(
              color: _pressed
                  ? colorScheme.primary.withValues(alpha: 0.06)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
                  blurRadius: isDark ? 20 : 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x5),
                Text(
                  'Add a file to audit',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Tap to browse photos, PDFs, Office docs, or code',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x5),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  alignment: WrapAlignment.center,
                  children: const [
                    'JPEG',
                    'PNG',
                    'HEIC',
                    'PDF',
                    'DOCX',
                    'TXT',
                  ].map((format) => _FormatChip(label: format)).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

