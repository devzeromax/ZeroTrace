import 'package:cleanshare/infrastructure/scanner/pii_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classifier = PiiClassifier();

  test('detects Indian license plate numbers', () {
    final matches = classifier.classify('Car plate DL 7CX 6587 parked');
    expect(matches.any((m) => m.type == PiiType.licensePlate), isTrue);
    expect(classifier.primaryLabel(matches), 'License plate number');
  });

  test('detects Aadhaar and PAN', () {
    final matches = classifier.classify('Aadhaar 2345 6789 0123 PAN ABCDE1234F');
    expect(matches.any((m) => m.type == PiiType.aadhaar), isTrue);
    expect(matches.any((m) => m.type == PiiType.pan), isTrue);
  });
}
