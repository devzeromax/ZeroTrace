import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_sounds.dart';

/// Fire-and-forget UI sounds. Failures are ignored so audio never blocks UX.
///
/// ponytail: single shared player — overlapping plays cut each other off.
/// Upgrade path: pool of 2 players if concurrent cues become required.
abstract final class AppSoundPlayer {
  static final AudioPlayer _player = AudioPlayer();
  static bool _configured = false;

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.lowLatency);
    } catch (e) {
      if (kDebugMode) debugPrint('AppSoundPlayer config: $e');
    }
  }

  static Future<void> play(String assetPath) async {
    try {
      await _ensureConfigured();
      await _player.stop();
      await _player.play(AssetSource(_stripAssetsPrefix(assetPath)));
    } catch (e) {
      if (kDebugMode) debugPrint('AppSoundPlayer play: $e');
    }
  }

  /// Export finished — strong success cue.
  static Future<void> playExportSuccess() => play(AppSounds.exportSuccess);

  /// Snackbar / pack install — short confirm cue.
  static Future<void> playUiConfirm() => play(AppSounds.uiConfirm);

  /// audioplayers AssetSource paths are relative to the Flutter assets root.
  static String _stripAssetsPrefix(String path) =>
      path.startsWith('assets/') ? path.substring('assets/'.length) : path;
}
