import 'package:cleanshare/infrastructure/scanner/pii_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classifier = PiiClassifier();

  test('rejects fake IBAN-looking PDF noise', () {
    final matches = classifier.classify(
      'PDF stream RR12ABCDEFGHIJKLMNOP UC font object',
    );
    expect(matches.any((m) => m.type == PiiType.iban), isFalse);
  });

  test('accepts a real IBAN with mod-97 checksum', () {
    // Well-known valid test IBAN (Germany).
    final matches = classifier.classify('Transfer to DE89370400440532013000 today');
    expect(matches.any((m) => m.type == PiiType.iban), isTrue);
    expect(PiiClassifier.isValidIban('DE89 3704 0044 0532 0130 00'), isTrue);
  });

  test('rejects invalid IBAN checksum', () {
    expect(PiiClassifier.isValidIban('DE00370400440532013000'), isFalse);
  });

  test('credit card requires Luhn', () {
    expect(
      classifier.classify('Card 4111 1111 1111 1111').any((m) => m.type == PiiType.creditCard),
      isTrue,
    );
    expect(
      classifier.classify('Card 4111 1111 1111 1112').any((m) => m.type == PiiType.creditCard),
      isFalse,
    );
  });
}
