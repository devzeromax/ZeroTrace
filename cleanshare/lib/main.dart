import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:rive/rive.dart' as rive;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/constants/app_rive.dart';
import 'core/performance/display_tuning.dart';
import 'infrastructure/storage/zerotrace_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DisplayTuning.configure();

  bool liquidGlassReady = false;
  try {
    await LiquidGlassWidgets.initialize();
    liquidGlassReady = true;
  } catch (e, stack) {
    debugPrint('LiquidGlass init failed, using fallback shell: $e\n$stack');
  }

  // Never block first frame on prefs — MissingPluginException / channel races
  // were freezing Android cold start before runApp.
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 3));
  } catch (e, stack) {
    debugPrint('SharedPreferences unavailable at boot: $e\n$stack');
  }

  GlassQuality? initialQuality;
  final savedQuality = prefs?.getString('glass_quality');
  if (savedQuality != null) {
    initialQuality = GlassQuality.values
        .cast<GlassQuality?>()
        .firstWhere(
          (quality) => quality?.name == savedQuality,
          orElse: () => null,
        );
  }

  try {
    await rive.RiveNative.init();
    appRiveEnabled = true;
  } catch (_) {
    appRiveEnabled = false;
  }

  try {
    await ZeroTracePaths.ensureInitialized();
  } catch (e, stack) {
    debugPrint('ZeroTracePaths init deferred: $e\n$stack');
  }

  final app = const ProviderScope(
    child: ZeroTraceApp(),
  );

  runApp(
    liquidGlassReady
        ? LiquidGlassWidgets.wrap(
            adaptiveQuality: true,
            // ignore: experimental_member_use
            adaptiveConfig: GlassAdaptiveScopeConfig(
              initialQuality: initialQuality,
              allowStepUp: true,
              onQualityChanged: (_, to) {
                prefs?.setString('glass_quality', to.name);
              },
            ),
            child: app,
          )
        : app,
  );
}
