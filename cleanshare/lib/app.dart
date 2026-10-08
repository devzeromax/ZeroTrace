import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_branding.dart';
import 'core/routing/router_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/user_facing_error.dart';
import 'providers/engine_providers.dart';
import 'providers/intro_video_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/logo_splash_screen.dart';
import 'widgets/branded_bootstrap_loader.dart';
import 'widgets/engine_bootstrap_error_screen.dart';

class ZeroTraceApp extends ConsumerStatefulWidget {
  const ZeroTraceApp({
    super.key,
    this.skipSplash = false,
  });

  /// Skips the intro splash — use in widget tests.
  final bool skipSplash;

  @override
  ConsumerState<ZeroTraceApp> createState() => _ZeroTraceAppState();
}

class _ZeroTraceAppState extends ConsumerState<ZeroTraceApp> {
  late bool _splashComplete;
  late bool _bootstrapReady;
  String? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _splashComplete = widget.skipSplash;
    _bootstrapReady = widget.skipSplash;
    _bootstrapError = null;
    // Warm up routing targets while the splash plays.
    Future.microtask(_warmUpAfterSplash);
  }

  @override
  void didUpdateWidget(covariant ZeroTraceApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.skipSplash) {
      _splashComplete = true;
      _bootstrapReady = true;
    }
  }

  Future<void> _warmUpAfterSplash() async {
    try {
      // Don't gate splash exit on engine bootstrap — on slow phones that left
      // users staring at a black LogoSplashScreen after the video ended.
      await Future.wait([
        ref.read(introVideoProvider.future),
        ref.read(onboardingProvider.future),
        ref.read(themeProvider.future),
      ]);
      await ref.read(engineBootstrapProvider.future);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootstrapError = UserFacingError.bootstrapMessage(e);
        _bootstrapReady = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _bootstrapReady = true);
  }

  void _retryBootstrap() {
    setState(() {
      _bootstrapError = null;
      _bootstrapReady = false;
    });
    ref.invalidate(engineBootstrapProvider);
    Future.microtask(_warmUpAfterSplash);
  }

  void _onSplashComplete() {
    if (!mounted || _splashComplete) return;
    setState(() => _splashComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: EngineBootstrapErrorScreen(
          message: _bootstrapError!,
          onRetry: _retryBootstrap,
        ),
      );
    }

    if (!_splashComplete) {
      final platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final splashTheme = platformBrightness == Brightness.dark
          ? AppTheme.dark()
          : AppTheme.light();

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: splashTheme,
        home: LogoSplashScreen(onComplete: _onSplashComplete),
      );
    }

    final router = ref.watch(routerProvider);
    final intro = ref.watch(introVideoProvider);
    final onboarding = ref.watch(onboardingProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = ref.watch(themeProvider);

    // After splash: branded loader until prefs + engine cold-start finish.
    if (!_bootstrapReady ||
        intro.isLoading ||
        onboarding.isLoading ||
        theme.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const BrandedBootstrapLoader(),
      );
    }

    return MaterialApp.router(
      title: AppBranding.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final page = child ?? const SizedBox.shrink();
        return AppEntryFade(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: Column(
              children: [
                Expanded(child: page),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// @deprecated Use [ZeroTraceApp]. Kept for test compatibility.
typedef CleanShareApp = ZeroTraceApp;
