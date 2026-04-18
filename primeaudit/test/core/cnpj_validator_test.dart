import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/core/cnpj_validator.dart';

void main() {
  group('isValidCnpj', () {
    test('accepts a known valid formatted CNPJ', () {
      expect(isValidCnpj('11.222.333/0001-81'), isTrue);
    });

    test('accepts the raw (unformatted) form of the same valid CNPJ', () {
      expect(isValidCnpj('11222333000181'), isTrue);
    });

    test('accepts another known valid CNPJ (60.746.948/0001-12)', () {
      expect(isValidCnpj('60.746.948/0001-12'), isTrue);
    });

    test('rejects a CNPJ with wrong first check digit', () {
      expect(isValidCnpj('11.222.333/0001-80'), isFalse);
    });

    test('rejects a CNPJ with wrong second check digit', () {
      expect(isValidCnpj('11.222.333/0001-91'), isFalse);
    });

    test('rejects all-zeros (same-digit sequence)', () {
      expect(isValidCnpj('00000000000000'), isFalse);
    });

    test('rejects all-ones (same-digit sequence)', () {
      expect(isValidCnpj('11111111111111'), isFalse);
    });

    test('rejects too-short input', () {
      expect(isValidCnpj('123'), isFalse);
    });

    test('rejects too-long input', () {
      expect(isValidCnpj('12345678901234567890'), isFalse);
    });

    test('rejects input containing non-digit chars in 14-char positions', () {
      expect(isValidCnpj('1234567890123a'), isFalse);
    });
  });

  group('validateCnpj', () {
    test('returns null for null input (optional field)', () {
      expect(validateCnpj(null), isNull);
    });

    test('returns null for empty string (optional field)', () {
      expect(validateCnpj(''), isNull);
    });

    test('returns null for whitespace-only input (optional field)', () {
      expect(validateCnpj('   '), isNull);
    });

    test('returns null for a valid CNPJ', () {
      expect(validateCnpj('11.222.333/0001-81'), isNull);
    });

    test('returns length error for non-empty input shorter than 14 digits', () {
      expect(validateCnpj('123'), equals('CNPJ deve ter 14 dígitos'));
    });

    test('returns checksum error for 14-digit input with invalid check digits', () {
      expect(
        validateCnpj('11.222.333/0001-80'),
        equals('CNPJ inválido — dígitos verificadores incorretos'),
      );
    });
  });
}
