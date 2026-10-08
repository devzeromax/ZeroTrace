import 'package:flutter/material.dart';

import '../core/constants/app_branding.dart';
import '../core/theme/design_tokens.dart';

/// Shown when engine integrity or security bootstrap fails (fail-closed).
class EngineBootstrapErrorScreen extends StatelessWidget {
  const EngineBootstrapErrorScreen({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.shield_outlined,
                size: 56,
                color: colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.x5),
              Text(
                '${AppBranding.name} could not start safely',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.x3),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              const Spacer(),
              if (onRetry != null)
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
