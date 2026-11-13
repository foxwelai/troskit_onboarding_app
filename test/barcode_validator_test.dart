import 'package:flutter_test/flutter_test.dart';
import 'package:troskit_onboarding_app/core/utils/barcode_validator.dart';

void main() {
  group('BarcodeValidator', () {
    test('accepts valid barcodes', () {
      expect(BarcodeValidator.validate('8901030928341'), isNull);
      expect(BarcodeValidator.validate('12345678'), isNull);
      expect(BarcodeValidator.validate('ABCD1234EFGH'), isNull);
      expect(BarcodeValidator.validate('ITEM-1002_A'), isNull);
      expect(BarcodeValidator.isValid('8901030928341'), isTrue);
    });

    test('rejects web links and QR codes', () {
      expect(BarcodeValidator.isUrlOrLink('https://example.com/product'), isTrue);
      expect(BarcodeValidator.isUrlOrLink('http://example.com'), isTrue);
      expect(BarcodeValidator.isUrlOrLink('www.nestle.com/kitkat'), isTrue);
      expect(BarcodeValidator.isUrlOrLink('https://qrco.de/bC4xY'), isTrue);
      expect(BarcodeValidator.isUrlOrLink('upi://pay?pa=shop@upi'), isTrue);
      expect(BarcodeValidator.isUrlOrLink('wa.me/919999999999'), isTrue);

      final result = BarcodeValidator.validate('https://example.com/prod/123');
      expect(result, contains('QR code links and URLs are not allowed'));
      expect(BarcodeValidator.isValid('https://example.com/prod/123'), isFalse);
    });

    test('rejects empty or whitespace', () {
      expect(BarcodeValidator.validate(''), isNotNull);
      expect(BarcodeValidator.validate('   '), isNotNull);
      expect(BarcodeValidator.validate(null), isNotNull);
    });

    test('rejects barcodes that are too short or too long', () {
      expect(BarcodeValidator.validate('123'), contains('too short'));
      expect(BarcodeValidator.validate('A' * 33), contains('too long'));
    });

    test('rejects barcodes with spaces and special symbols', () {
      expect(BarcodeValidator.validate('890 1030'), contains('only letters, numbers, and dashes'));
      expect(BarcodeValidator.validate('PROD#123'), contains('only letters, numbers, and dashes'));
      expect(BarcodeValidator.validate('ITEM@STORE'), contains('only letters, numbers, and dashes'));
    });
  });
}
