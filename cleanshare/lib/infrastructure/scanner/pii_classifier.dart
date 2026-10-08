/// On-device PII classification from OCR text and secrets — no cloud NER.
///
/// Patterns are validated (IBAN mod-97, card Luhn, etc.) so PDF/OCR noise
/// does not become fake "Confidential Data" findings.
class PiiClassifier {
  const PiiClassifier();

  static final _email = RegExp(
    r'\b[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}\b',
  );
  /// Stricter phone: requires +country or 10+ digits with separators.
  static final _phone = RegExp(
    r'(?<!\d)(?:\+\d{1,3}[\s\-.]?)?(?:\(?\d{2,4}\)?[\s\-.]?)?\d{3,4}[\s\-.]?\d{4}(?!\d)',
  );
  static final _ssn = RegExp(r'\b\d{3}-\d{2}-\d{4}\b');
  static final _creditCard = RegExp(
    r'\b(?:\d[ -]*?){13,19}\b',
  );
  /// Candidate only — [classify] keeps hits that pass mod-97 + length.
  static final _iban = RegExp(
    r'\b([A-Z]{2}\d{2}[A-Z0-9]{11,30})\b',
    caseSensitive: false,
  );
  static final _awsKey = RegExp(r'\bAKIA[0-9A-Z]{16}\b');
  static final _apiKey = RegExp(
    r'\b(?:sk|pk)_(?:live|test)_[A-Za-z0-9]{20,}\b',
  );
  /// Indian HSRP / older formats, e.g. DL 7CX 6587, MH-12-AB-1234.
  static final _indiaPlate = RegExp(
    r'\b([A-Z]{2})[-\s]?(\d{1,2})[A-Z]{1,3}[-\s]?\d{3,4}\b',
    caseSensitive: false,
  );
  static final _aadhaar = RegExp(r'\b(\d{4})\s?(\d{4})\s?(\d{4})\b');
  static final _pan = RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b');

  /// ISO 13616 IBAN lengths by country (common set).
  static const _ibanLengths = <String, int>{
    'AD': 24, 'AE': 23, 'AL': 28, 'AT': 20, 'AZ': 28, 'BA': 20, 'BE': 16,
    'BG': 22, 'BH': 22, 'BR': 29, 'BY': 28, 'CH': 21, 'CR': 22, 'CY': 28,
    'CZ': 24, 'DE': 22, 'DK': 18, 'DO': 28, 'EE': 20, 'EG': 29, 'ES': 24,
    'FI': 18, 'FO': 18, 'FR': 27, 'GB': 22, 'GE': 22, 'GI': 23, 'GL': 18,
    'GR': 27, 'GT': 28, 'HR': 21, 'HU': 28, 'IE': 22, 'IL': 23, 'IQ': 23,
    'IS': 26, 'IT': 27, 'JO': 30, 'KW': 30, 'KZ': 20, 'LB': 28, 'LC': 32,
    'LI': 21, 'LT': 20, 'LU': 20, 'LV': 21, 'MC': 27, 'MD': 24, 'ME': 22,
    'MK': 19, 'MR': 27, 'MT': 31, 'MU': 30, 'NL': 18, 'NO': 15, 'PK': 24,
    'PL': 28, 'PS': 29, 'PT': 25, 'QA': 29, 'RO': 24, 'RS': 22, 'SA': 24,
    'SE': 24, 'SI': 19, 'SK': 24, 'SM': 27, 'TN': 24, 'TR': 26, 'UA': 29,
    'VA': 22, 'VG': 24, 'XK': 20,
  };

  List<PiiMatch> classify(String text) {
    if (text.trim().isEmpty) return const [];

    final matches = <PiiMatch>[];
    for (final entry in _patterns) {
      for (final match in entry.pattern.allMatches(text)) {
        final value = match.group(0) ?? '';
        if (!_isValid(entry.type, value)) continue;
        matches.add(
          PiiMatch(
            type: entry.type,
            label: entry.label,
            value: value,
            start: match.start,
            end: match.end,
          ),
        );
      }
    }
    return matches;
  }

  String? primaryLabel(List<PiiMatch> matches) {
    if (matches.isEmpty) return null;
    const priority = [
      PiiType.creditCard,
      PiiType.ssn,
      PiiType.apiSecret,
      PiiType.aadhaar,
      PiiType.pan,
      PiiType.licensePlate,
      PiiType.email,
      PiiType.phone,
      PiiType.iban,
      PiiType.address,
    ];
    for (final type in priority) {
      final hit = matches.where((m) => m.type == type);
      if (hit.isNotEmpty) return hit.first.label;
    }
    return matches.first.label;
  }

  bool _isValid(PiiType type, String raw) {
    switch (type) {
      case PiiType.iban:
        return isValidIban(raw);
      case PiiType.creditCard:
        return _isValidLuhn(_digitsOnly(raw));
      case PiiType.phone:
        final digits = _digitsOnly(raw);
        return digits.length >= 10 && digits.length <= 15;
      case PiiType.aadhaar:
        final digits = _digitsOnly(raw);
        // Reject obvious non-IDs (all same digit, leading 0/1 often invalid).
        if (digits.length != 12) return false;
        if (RegExp(r'^(\d)\1{11}$').hasMatch(digits)) return false;
        if (digits.startsWith('0') || digits.startsWith('1')) return false;
        return true;
      case PiiType.licensePlate:
        return _isPlausibleIndiaPlate(raw);
      case PiiType.email:
        return raw.contains('@') && raw.contains('.');
      case PiiType.pan:
        return raw.length == 10;
      case PiiType.ssn:
      case PiiType.apiSecret:
      case PiiType.address:
      case PiiType.name:
        return raw.trim().length >= 4;
    }
  }

  /// Public for tests — ISO 13616 length + mod-97 checksum.
  static bool isValidIban(String raw) {
    final iban = raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]+$').hasMatch(iban)) return false;
    if (iban.length < 15 || iban.length > 34) return false;
    final cc = iban.substring(0, 2);
    final expected = _ibanLengths[cc];
    if (expected == null || iban.length != expected) return false;

    final rearranged = iban.substring(4) + iban.substring(0, 4);
    final numeric = StringBuffer();
    for (final codeUnit in rearranged.codeUnits) {
      if (codeUnit >= 65 && codeUnit <= 90) {
        numeric.write(codeUnit - 55); // A=10
      } else {
        numeric.writeCharCode(codeUnit);
      }
    }
    return _mod97(numeric.toString()) == 1;
  }

  static int _mod97(String digits) {
    var remainder = 0;
    for (var i = 0; i < digits.length; i++) {
      remainder = (remainder * 10 + (digits.codeUnitAt(i) - 48)) % 97;
    }
    return remainder;
  }

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  static bool _isValidLuhn(String digits) {
    if (digits.length < 13 || digits.length > 19) return false;
    if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return false;
    var sum = 0;
    var alternate = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = digits.codeUnitAt(i) - 48;
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  static bool _isPlausibleIndiaPlate(String raw) {
    final m = _indiaPlate.firstMatch(raw.toUpperCase());
    if (m == null) return false;
    final state = m.group(1)!;
    // Common Indian state/UT codes only — blocks random "RR12…" PDF noise.
    const states = {
      'AN', 'AP', 'AR', 'AS', 'BR', 'CH', 'CG', 'DD', 'DL', 'GA', 'GJ', 'HR',
      'HP', 'JH', 'JK', 'KA', 'KL', 'LA', 'LD', 'MP', 'MH', 'MN', 'ML', 'MZ',
      'NL', 'OD', 'PB', 'PY', 'RJ', 'SK', 'TN', 'TS', 'TR', 'UP', 'UK', 'WB',
    };
    return states.contains(state);
  }

  static final _patterns = <_Pattern>[
    _Pattern(PiiType.email, _email, 'Email address'),
    _Pattern(PiiType.phone, _phone, 'Phone number'),
    _Pattern(PiiType.ssn, _ssn, 'Social Security number'),
    _Pattern(PiiType.creditCard, _creditCard, 'Credit card'),
    _Pattern(PiiType.iban, _iban, 'Bank account (IBAN)'),
    _Pattern(PiiType.apiSecret, _awsKey, 'AWS access key'),
    _Pattern(PiiType.apiSecret, _apiKey, 'API secret key'),
    _Pattern(PiiType.licensePlate, _indiaPlate, 'License plate number'),
    _Pattern(PiiType.aadhaar, _aadhaar, 'Aadhaar number'),
    _Pattern(PiiType.pan, _pan, 'PAN number'),
  ];
}

class _Pattern {
  const _Pattern(this.type, this.pattern, this.label);
  final PiiType type;
  final RegExp pattern;
  final String label;
}

enum PiiType {
  email,
  phone,
  ssn,
  creditCard,
  iban,
  apiSecret,
  address,
  name,
  licensePlate,
  aadhaar,
  pan,
}

class PiiMatch {
  const PiiMatch({
    required this.type,
    required this.label,
    required this.value,
    required this.start,
    required this.end,
  });

  final PiiType type;
  final String label;
  final String value;
  final int start;
  final int end;
}
