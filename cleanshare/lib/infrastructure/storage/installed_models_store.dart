import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/platform/platform_storage.dart';
import '../../domain/marketplace/marketplace_models.dart';
import '../../domain/storage/storage_layout.dart';
import '../engine/zerotrace_engine_bridge.dart';

/// Persists installed model records.
class InstalledModelsStore {
  InstalledModelsStore(this._layout);

  static const _prefsKey = 'zerotrace_installed_models';

  final ZeroTraceLayout _layout;

  Future<Map<String, InstalledModelRecord>> readAll() async {
    if (!PlatformStorage.supportsLocalFileSystem) {
      return _readFromPrefs();
    }

    final file = _layout.installedModelsIndex();
    if (!await file.exists()) return {};

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _parseMap(json);
    } catch (_) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      return {};
    }
  }

  Future<void> writeAll(Map<String, InstalledModelRecord> records) async {
    if (!PlatformStorage.supportsLocalFileSystem) {
      await _writeToPrefs(records);
      return;
    }

    final file = _layout.installedModelsIndex();
    final json = records.map((key, value) => MapEntry(key, value.toJson()));
    await file.writeAsString(jsonEncode(json));
  }

  Future<void> upsert(InstalledModelRecord record) async {
    final all = await readAll();
    all[record.id] = record;
    await writeAll(all);
  }

  Future<void> remove(String id) async {
    final all = await readAll();
    all.remove(id);
    await writeAll(all);

    if (!PlatformStorage.supportsLocalFileSystem) return;

    final pluginDir = _layout.pluginDirectory(id);
    if (await pluginDir.exists()) {
      await pluginDir.delete(recursive: true);
    }
    ZeroTraceEngineBridge.clearOnnxCache();
  }

  /// Removes all install records (does not delete pack dirs — use [SecureDataWiper]).
  Future<void> clearAll() async {
    await writeAll({});
  }

  Map<String, InstalledModelRecord> _parseMap(Map<String, dynamic> json) {
    return json.map(
      (key, value) => MapEntry(
        key,
        InstalledModelRecord.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<Map<String, InstalledModelRecord>> _readFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _parseMap(json);
    } catch (_) {
      await prefs.remove(_prefsKey);
      return {};
    }
  }

  Future<void> _writeToPrefs(Map<String, InstalledModelRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final json = records.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString(_prefsKey, jsonEncode(json));
  }
}
