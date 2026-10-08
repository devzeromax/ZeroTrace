import 'package:flutter/material.dart';

import '../core/theme/glass_scene.dart';
import '../core/theme/glass_tokens.dart';
import 'ambient_background.dart';
import 'adaptive_content.dart';

/// Page wrapper: ambient depth + transparent scaffold for glass layers.
class PremiumPage extends StatelessWidget {
  const PremiumPage({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.constrainBody = true,
    this.scene = GlassScene.home,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool constrainBody;
  final GlassScene scene;

  @override
  Widget build(BuildContext context) {
    final pageBody = constrainBody
        ? AdaptiveContent(child: body)
        : body;

    return AmbientBackground(
      scene: scene,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: false,
        appBar: appBar,
        body: pageBody,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}

/// Frosted app bar — iOS-style translucent chrome over ambient background.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.scene,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final GlassScene? scene;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final useGlass = GlassTokens.useGlass(context);
    final sigma = GlassTokens.blurSigma(context, override: 12, scene: scene);

    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      forceMaterialTransparency: true,
      flexibleSpace: IgnorePointer(
        child: useGlass && sigma > 0
            ? ClipRect(
                child: BackdropFilter(
                  filter: GlassTokens.blurFilter(context, sigma: sigma),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: GlassTokens.chromeFill(context, scene: scene),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(
                        alpha: 0.92,
                      ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
