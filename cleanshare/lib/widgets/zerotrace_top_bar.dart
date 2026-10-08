import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/app_routes.dart';
import '../core/theme/glass_tokens.dart';
import 'zerotrace_logo.dart';

/// Frosted brand header — navigation lives in shell rail/bottom bar.
class ZeroTraceTopBar extends StatelessWidget implements PreferredSizeWidget {
  const ZeroTraceTopBar({
    super.key,
    this.trailing,
  });

  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRect(
      child: BackdropFilter(
        filter: GlassTokens.blurFilter(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GlassTokens.fill(context),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const ZeroTraceLogo(size: 36, compact: true),
                    const Spacer(),
                    trailing ??
                        IconButton(
                          tooltip: 'Settings',
                          onPressed: () => context.go(AppRoutes.settings),
                          icon: Icon(
                            Icons.settings_outlined,
                            color: colorScheme.onSurface,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
