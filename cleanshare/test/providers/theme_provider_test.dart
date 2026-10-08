import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleanshare/providers/theme_provider.dart';
import 'package:cleanshare/services/theme_storage.dart';

void main() {
  group('ThemeNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to dark when preference unset', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeProvider.future);
      expect(container.read(themeProvider).value, ThemePreference.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('setPreference persists and updates theme mode', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeProvider.future);
      await container
          .read(themeProvider.notifier)
          .setPreference(ThemePreference.dark);

      expect(container.read(themeProvider).value, ThemePreference.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_preference'), 'dark');
    });

    test('toggleLightDark switches between light and dark', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeProvider.future);
      await container
          .read(themeProvider.notifier)
          .setPreference(ThemePreference.light);
      await container.read(themeProvider.notifier).toggleLightDark();

      expect(container.read(themeProvider).value, ThemePreference.dark);
    });
  });
}
