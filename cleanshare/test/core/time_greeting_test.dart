import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/core/utils/time_greeting.dart';

void main() {
  test('morning greeting before noon', () {
    expect(
      TimeGreeting.greetingFor(DateTime(2026, 6, 18, 9)),
      'Good morning',
    );
  });

  test('afternoon greeting midday', () {
    expect(
      TimeGreeting.greetingFor(DateTime(2026, 6, 18, 14)),
      'Good afternoon',
    );
  });

  test('evening greeting after 5pm', () {
    expect(
      TimeGreeting.greetingFor(DateTime(2026, 6, 18, 19)),
      'Good evening',
    );
  });

  test('night greeting late hours', () {
    expect(
      TimeGreeting.greetingFor(DateTime(2026, 6, 18, 23)),
      'Good night',
    );
  });

  test('subtitle is never empty', () {
    for (var hour = 0; hour < 24; hour++) {
      expect(
        TimeGreeting.subtitleFor(DateTime(2026, 1, 1, hour)),
        isNotEmpty,
      );
    }
  });
}
