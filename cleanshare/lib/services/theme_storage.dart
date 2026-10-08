import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreference { light, dark, system }

abstract final class ThemeStorage {
  static const _key = 'theme_preference';

  static Future<ThemePreference> getPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      final value = prefs.getString(_key);
      return ThemePreference.values.firstWhere(
        (p) => p.name == value,
        orElse: () => ThemePreference.system,
      );
    } catch (_) {
      return ThemePreference.system;
    }
  }

  static Future<void> setPreference(ThemePreference preference) async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.setString(_key, preference.name);
    } catch (_) {}
  }
}
