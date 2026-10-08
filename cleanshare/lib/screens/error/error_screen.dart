import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/utils/user_facing_error.dart';
import '../../widgets/empty_state.dart';
import '../../core/theme/glass_scene.dart';
import '../../widgets/premium_page.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({
    super.key,
    required this.error,
  });

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return PremiumPage(
      scene: GlassScene.home,
      body: EmptyStatePanel(
        scene: GlassScene.home,
        title: 'Page not found',
        description: error != null
            ? UserFacingError.message(error!)
            : 'That route does not exist. Return to Home.',
        icon: Icons.error_outline,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              label: 'Go to Home',
              onPressed: () => context.go(AppRoutes.home),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Go back',
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
