// Unit tests for AppRole static helpers (QUAL-02).
// Covers all 5 defined roles against canAccessAdmin, canAccessDev,
// isSuperOrDev, and label. Does NOT test `canEdit` — that method
// does not exist in app_roles.dart (see 03-RESEARCH.md Pitfall 4).

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/core/app_roles.dart';

void main() {
  group('AppRole.canAccessAdmin', () {
    test('true for superuser', () {
      expect(AppRole.canAccessAdmin(AppRole.superuser), isTrue);
    });
    test('true for dev', () {
      expect(AppRole.canAccessAdmin(AppRole.dev), isTrue);
    });
    test('true for adm', () {
      expect(AppRole.canAccessAdmin(AppRole.adm), isTrue);
    });
    test('false for auditor', () {
      expect(AppRole.canAccessAdmin(AppRole.auditor), isFalse);
    });
    test('false for anonymous', () {
      expect(AppRole.canAccessAdmin(AppRole.anonymous), isFalse);
    });
    test('false for unknown role string', () {
      expect(AppRole.canAccessAdmin('chaos_goblin'), isFalse);
    });
  });

  group('AppRole.canAccessDev', () {
    test('true for superuser', () {
      expect(AppRole.canAccessDev(AppRole.superuser), isTrue);
    });
    test('true for dev', () {
      expect(AppRole.canAccessDev(AppRole.dev), isTrue);
    });
    test('false for adm', () {
      expect(AppRole.canAccessDev(AppRole.adm), isFalse);
    });
    test('false for auditor', () {
      expect(AppRole.canAccessDev(AppRole.auditor), isFalse);
    });
    test('false for anonymous', () {
      expect(AppRole.canAccessDev(AppRole.anonymous), isFalse);
    });
  });

  group('AppRole.isSuperOrDev', () {
    test('true for superuser', () {
      expect(AppRole.isSuperOrDev(AppRole.superuser), isTrue);
    });
    test('true for dev', () {
      expect(AppRole.isSuperOrDev(AppRole.dev), isTrue);
    });
    test('false for adm', () {
      expect(AppRole.isSuperOrDev(AppRole.adm), isFalse);
    });
    test('false for auditor', () {
      expect(AppRole.isSuperOrDev(AppRole.auditor), isFalse);
    });
    test('false for anonymous', () {
      expect(AppRole.isSuperOrDev(AppRole.anonymous), isFalse);
    });
  });

  group('AppRole.label', () {
    test('superuser -> Super Usuário', () {
      expect(AppRole.label(AppRole.superuser), equals('Super Usuário'));
    });
    test('dev -> Desenvolvedor', () {
      expect(AppRole.label(AppRole.dev), equals('Desenvolvedor'));
    });
    test('adm -> Administrador', () {
      expect(AppRole.label(AppRole.adm), equals('Administrador'));
    });
    test('auditor -> Auditor', () {
      expect(AppRole.label(AppRole.auditor), equals('Auditor'));
    });
    test('anonymous -> Anônimo', () {
      expect(AppRole.label(AppRole.anonymous), equals('Anônimo'));
    });
    test('unknown role returns role string itself', () {
      expect(AppRole.label('chaos_goblin'), equals('chaos_goblin'));
    });
  });

  group('AppRole.all', () {
    test('contains exactly the 5 defined roles in expected order', () {
      expect(
        AppRole.all,
        equals([
          AppRole.superuser,
          AppRole.dev,
          AppRole.adm,
          AppRole.auditor,
          AppRole.anonymous,
        ]),
      );
    });
  });
}
