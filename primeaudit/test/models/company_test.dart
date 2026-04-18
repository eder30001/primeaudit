// Unit tests for Company.fromMap (QUAL-03).

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/company.dart';

Map<String, dynamic> _baseMap() => <String, dynamic>{
  'id': 'c1',
  'name': 'Acme',
  'cnpj': null,
  'email': null,
  'phone': null,
  'address': null,
  'active': true,
  'requires_perimeter': false,
  'created_at': '2024-01-01T00:00:00.000Z',
};

void main() {
  group('Company.fromMap — required fields', () {
    test('parses id, name, createdAt', () {
      final c = Company.fromMap(_baseMap());
      expect(c.id, equals('c1'));
      expect(c.name, equals('Acme'));
      expect(c.createdAt, equals(DateTime.parse('2024-01-01T00:00:00.000Z')));
    });
  });

  group('Company.fromMap — optional fields null when absent', () {
    test('cnpj, email, phone, address are null', () {
      final c = Company.fromMap(_baseMap());
      expect(c.cnpj, isNull);
      expect(c.email, isNull);
      expect(c.phone, isNull);
      expect(c.address, isNull);
    });
  });

  group('Company.fromMap — optional fields populated when present', () {
    test('cnpj is populated', () {
      final m = _baseMap()..['cnpj'] = '11.222.333/0001-81';
      expect(Company.fromMap(m).cnpj, equals('11.222.333/0001-81'));
    });

    test('email is populated', () {
      final m = _baseMap()..['email'] = 'contato@acme.com';
      expect(Company.fromMap(m).email, equals('contato@acme.com'));
    });

    test('phone is populated', () {
      final m = _baseMap()..['phone'] = '+55 11 99999-0000';
      expect(Company.fromMap(m).phone, equals('+55 11 99999-0000'));
    });

    test('address is populated', () {
      final m = _baseMap()..['address'] = 'Rua X, 123';
      expect(Company.fromMap(m).address, equals('Rua X, 123'));
    });
  });

  group('Company.fromMap — defaults', () {
    test('active defaults to true when key absent', () {
      final m = _baseMap()..remove('active');
      expect(Company.fromMap(m).active, isTrue);
    });

    test('requires_perimeter defaults to false when key absent', () {
      final m = _baseMap()..remove('requires_perimeter');
      expect(Company.fromMap(m).requiresPerimeter, isFalse);
    });

    test('requiresPerimeter is true when explicitly set', () {
      final m = _baseMap()..['requires_perimeter'] = true;
      expect(Company.fromMap(m).requiresPerimeter, isTrue);
    });

    test('active is false when explicitly set', () {
      final m = _baseMap()..['active'] = false;
      expect(Company.fromMap(m).active, isFalse);
    });
  });
}
