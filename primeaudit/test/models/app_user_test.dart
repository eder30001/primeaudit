// Unit tests for AppUser.fromMap (QUAL-03).
// AppUser is the model equivalent of "UserProfile" referenced in the
// roadmap; see 03-RESEARCH.md Pitfall 5 — the actual class name is AppUser
// and it maps the `profiles` table.

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/app_user.dart';

Map<String, dynamic> _baseMap() => <String, dynamic>{
  'id': 'u1',
  'full_name': 'Ana Silva',
  'email': 'ana@example.com',
  'role': 'adm',
  'company_id': 'c1',
  'active': true,
  'created_at': '2024-01-01T00:00:00.000Z',
  'companies': {'name': 'Acme'},
};

void main() {
  group('AppUser.fromMap — required scalar fields', () {
    test('parses id, fullName, email, role', () {
      final u = AppUser.fromMap(_baseMap());
      expect(u.id, equals('u1'));
      expect(u.fullName, equals('Ana Silva'));
      expect(u.email, equals('ana@example.com'));
      expect(u.role, equals('adm'));
    });

    test('parses createdAt as DateTime', () {
      final u = AppUser.fromMap(_baseMap());
      expect(u.createdAt, equals(DateTime.parse('2024-01-01T00:00:00.000Z')));
    });
  });

  group('AppUser.fromMap — companyId', () {
    test('companyId is populated when present', () {
      expect(AppUser.fromMap(_baseMap()).companyId, equals('c1'));
    });

    test('companyId is null when explicitly null', () {
      final m = _baseMap()..['company_id'] = null;
      expect(AppUser.fromMap(m).companyId, isNull);
    });
  });

  group('AppUser.fromMap — companies join', () {
    test('companyName is populated from companies.name join', () {
      expect(AppUser.fromMap(_baseMap()).companyName, equals('Acme'));
    });

    test('companyName is null when companies join is null', () {
      final m = _baseMap()..['companies'] = null;
      expect(AppUser.fromMap(m).companyName, isNull);
    });
  });

  group('AppUser.fromMap — active default', () {
    test('active defaults to true when key absent', () {
      final m = _baseMap()..remove('active');
      expect(AppUser.fromMap(m).active, isTrue);
    });

    test('active is false when explicitly set (deactivated user)', () {
      final m = _baseMap()..['active'] = false;
      expect(AppUser.fromMap(m).active, isFalse);
    });
  });

  group('AppUser.fromMap — derived getters', () {
    test('canAccessAdmin reflects role (adm -> true)', () {
      expect(AppUser.fromMap(_baseMap()).canAccessAdmin, isTrue);
    });

    test('canAccessAdmin is false for auditor role', () {
      final m = _baseMap()..['role'] = 'auditor';
      expect(AppUser.fromMap(m).canAccessAdmin, isFalse);
    });

    test('isSuperOrDev is true for dev role', () {
      final m = _baseMap()..['role'] = 'dev';
      expect(AppUser.fromMap(m).isSuperOrDev, isTrue);
    });

    test('isSuperOrDev is false for adm role', () {
      expect(AppUser.fromMap(_baseMap()).isSuperOrDev, isFalse);
    });
  });
}
