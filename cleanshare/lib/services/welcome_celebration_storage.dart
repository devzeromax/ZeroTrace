import 'package:shared_preferences/shared_preferences.dart';

abstract final class WelcomeCelebrationStorage {
  static const _key = 'welcome_celebration_seen';

  static Future<bool> hasSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setSeen({required bool value}) async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.setBool(_key, value);
    } catch (_) {}
  }
}
