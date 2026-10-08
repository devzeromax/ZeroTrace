import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/storage/storage_layout.dart';
import '../engine/zerotrace_engine_bridge.dart';
import '../storage/installed_models_store.dart';
import 'secure_key_store.dart';

/// Wipes all local ZeroTrace user data (settings delete-all).
class SecureDataWiper {
  SecureDataWiper(this._layout);

  final ZeroTraceLayout _layout;

  static const _installedModelsPrefsKey = 'zerotrace_installed_models';

  /// Deletes scans, exports, packs, history, keys, and install registry.
  /// Built-in scanners re-register on next marketplace load; neural packs
  /// must be downloaded again from the Marketplace.
  Future<void> wipeAllUserData() async {
    final targets = [
      _layout.scans,
      _layout.exports,
      _layout.cache,
      _layout.downloads,
      _layout.settings,
      _layout.packs,
      _layout.logs,
      _layout.models,
    ];

    for (final dir in targets) {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }

    await _layout.ensureCreated();

    await SecureKeyStore.wipeAllSecrets();
    await InstalledModelsStore(_layout).clearAll();
    await _clearLegacyPrefs();
    ZeroTraceEngineBridge.clearOnnxCache();
  }

  Future<void> _clearLegacyPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_installedModelsPrefsKey);

    final legacyKeys = prefs
        .getKeys()
        .where((k) => k.startsWith('zerotrace_secure_'))
        .toList();
    for (final key in legacyKeys) {
      await prefs.remove(key);
    }
  }
}
