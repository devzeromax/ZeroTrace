import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/infrastructure/scanner/pii_classifier.dart';

void main() {
  const classifier = PiiClassifier();

  test('detects email addresses', () {
    final matches = classifier.classify('Contact me at jane.doe@example.com');
    expect(matches.any((m) => m.type == PiiType.email), isTrue);
    expect(classifier.primaryLabel(matches), 'Email address');
  });

  test('detects credit card patterns', () {
    final matches = classifier.classify('Card 4111 1111 1111 1111');
    expect(matches.any((m) => m.type == PiiType.creditCard), isTrue);
  });

  test('detects AWS keys', () {
    final matches = classifier.classify('AKIAIOSFODNN7EXAMPLE');
    expect(matches.any((m) => m.type == PiiType.apiSecret), isTrue);
  });
}
