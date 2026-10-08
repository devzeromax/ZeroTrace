import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';

/// In-shell page title — one title per screen, no marketing copy.
class ShellPageHeader extends StatelessWidget {
  const ShellPageHeader({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
  });

  final String? title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                  ),
                if (title != null && subtitle != null)
                  const SizedBox(height: AppSpacing.x1),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: (title != null
                            ? Theme.of(context).textTheme.bodyMedium
                            : Theme.of(context).textTheme.titleMedium)
                        ?.copyWith(
                      color: title != null
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                      fontWeight:
                          title == null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
