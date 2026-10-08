import 'package:shared_preferences/shared_preferences.dart';

abstract final class OnboardingStorage {
  static const _key = 'onboarding_complete';

  static Future<bool> isComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      // First-run default when plugin channel is unavailable.
      return false;
    }
  }

  static Future<void> setComplete({required bool value}) async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.setBool(_key, value);
    } catch (_) {
      // Best-effort; UI still advances.
    }
  }
}
