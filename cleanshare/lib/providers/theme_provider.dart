import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/theme_storage.dart';

final themeProvider =
    AsyncNotifierProvider<ThemeNotifier, ThemePreference>(ThemeNotifier.new);

final themeModeProvider = Provider<ThemeMode>((ref) {
  final preference = ref.watch(themeProvider).value ?? ThemePreference.system;
  return switch (preference) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
    ThemePreference.system => ThemeMode.system,
  };
});

class ThemeNotifier extends AsyncNotifier<ThemePreference> {
  @override
  Future<ThemePreference> build() => ThemeStorage.getPreference();

  Future<void> setPreference(ThemePreference preference) async {
    await ThemeStorage.setPreference(preference);
    state = AsyncData(preference);
  }

  Future<void> toggleLightDark() async {
    final current = state.value ?? ThemePreference.system;
    final next = switch (current) {
      ThemePreference.light => ThemePreference.dark,
      ThemePreference.dark => ThemePreference.light,
      ThemePreference.system => ThemePreference.dark,
    };
    await setPreference(next);
  }
}
