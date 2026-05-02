// Unit tests for Audit.fromMap (QUAL-03).
// Audit is the highest-surface parsing target — 5 nested join keys
// plus status enum mapping and numeric/date optional fields.

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit.dart';

Map<String, dynamic> _fullAuditMap() => <String, dynamic>{
  'id': 'a1',
  'title': 'Auditoria Teste',
  'audit_type_id': 'at1',
  'template_id': 't1',
  'company_id': 'c1',
  'auditor_id': 'u1',
  'perimeter_id': 'per1',
  'status': 'em_andamento',
  'created_at': '2024-01-01T00:00:00.000Z',
  'deadline': '2024-06-01T00:00:00.000Z',
  'conformity_percent': 87.5,
  'audit_types': {'name': 'Safety', 'icon': '📋', 'color': '#2196F3'},
  'audit_templates': {'name': 'Template A'},
  'companies': {'name': 'Acme', 'requires_perimeter': true},
  'perimeters': {'name': 'Area A'},
  'auditor': {'full_name': 'Ana'},
};

void main() {
  group('Audit.fromMap — scalar fields', () {
    test('parses required ids and title', () {
      final a = Audit.fromMap(_fullAuditMap());
      expect(a.id, equals('a1'));
      expect(a.title, equals('Auditoria Teste'));
      expect(a.auditTypeId, equals('at1'));
      expect(a.templateId, equals('t1'));
      expect(a.companyId, equals('c1'));
      expect(a.auditorId, equals('u1'));
    });

    test('parses createdAt as local DateTime', () {
      // fromMap applies .toLocal() to preserve timezone-aware parsing
      final a = Audit.fromMap(_fullAuditMap());
      expect(a.createdAt, equals(DateTime.parse('2024-01-01T00:00:00.000Z').toLocal()));
    });

    test('parses deadline as date-only local DateTime (no UTC day shift)', () {
      // _parseDateOnly extracts date from UTC to prevent UTC→local day-before bug
      final a = Audit.fromMap(_fullAuditMap());
      expect(a.deadline, equals(DateTime(2024, 6, 1)));
    });

    test('deadline is null when absent', () {
      final m = _fullAuditMap()..['deadline'] = null;
      expect(Audit.fromMap(m).deadline, isNull);
    });

    test('conformityPercent is double when present', () {
      final a = Audit.fromMap(_fullAuditMap());
      expect(a.conformityPercent, closeTo(87.5, 0.01));
    });

    test('conformityPercent is null when absent', () {
      final m = _fullAuditMap()..['conformity_percent'] = null;
      expect(Audit.fromMap(m).conformityPercent, isNull);
    });
  });

  group('Audit.fromMap — nested audit_types join', () {
    test('parses name, icon, color', () {
      final a = Audit.fromMap(_fullAuditMap());
      expect(a.auditTypeName, equals('Safety'));
      expect(a.auditTypeIcon, equals('📋'));
      expect(a.auditTypeColor, equals('#2196F3'));
    });

    test('falls back to defaults when audit_types is null', () {
      final m = _fullAuditMap()..['audit_types'] = null;
      final a = Audit.fromMap(m);
      expect(a.auditTypeName, equals(''));
      expect(a.auditTypeIcon, equals('📋'));
      expect(a.auditTypeColor, equals('#2196F3'));
    });
  });

  group('Audit.fromMap — nested audit_templates join', () {
    test('parses templateName', () {
      expect(Audit.fromMap(_fullAuditMap()).templateName, equals('Template A'));
    });

    test('templateName falls back to empty string when join absent', () {
      final m = _fullAuditMap()..['audit_templates'] = null;
      expect(Audit.fromMap(m).templateName, equals(''));
    });
  });

  group('Audit.fromMap — nested companies join', () {
    test('parses companyName and companyRequiresPerimeter', () {
      final a = Audit.fromMap(_fullAuditMap());
      expect(a.companyName, equals('Acme'));
      expect(a.companyRequiresPerimeter, isTrue);
    });

    test('falls back to defaults when companies is null', () {
      final m = _fullAuditMap()..['companies'] = null;
      final a = Audit.fromMap(m);
      expect(a.companyName, equals(''));
      expect(a.companyRequiresPerimeter, isFalse);
    });
  });

  group('Audit.fromMap — nested auditor join', () {
    test('parses auditorName', () {
      expect(Audit.fromMap(_fullAuditMap()).auditorName, equals('Ana'));
    });

    test('auditorName falls back to empty string when auditor is null', () {
      final m = _fullAuditMap()..['auditor'] = null;
      expect(Audit.fromMap(m).auditorName, equals(''));
    });
  });

  group('Audit.fromMap — nested perimeters join', () {
    test('parses perimeterName when present', () {
      expect(Audit.fromMap(_fullAuditMap()).perimeterName, equals('Area A'));
    });

    test('perimeterName is null when perimeters is null', () {
      final m = _fullAuditMap()..['perimeters'] = null;
      expect(Audit.fromMap(m).perimeterName, isNull);
    });
  });

  group('Audit.fromMap — status enum mapping', () {
    test('em_andamento string -> AuditStatus.emAndamento', () {
      final m = _fullAuditMap()..['status'] = 'em_andamento';
      expect(Audit.fromMap(m).status, equals(AuditStatus.emAndamento));
    });

    test('concluida string -> AuditStatus.concluida', () {
      final m = _fullAuditMap()..['status'] = 'concluida';
      expect(Audit.fromMap(m).status, equals(AuditStatus.concluida));
    });

    test('atrasada string -> AuditStatus.atrasada', () {
      final m = _fullAuditMap()..['status'] = 'atrasada';
      expect(Audit.fromMap(m).status, equals(AuditStatus.atrasada));
    });

    test('cancelada string -> AuditStatus.cancelada', () {
      final m = _fullAuditMap()..['status'] = 'cancelada';
      expect(Audit.fromMap(m).status, equals(AuditStatus.cancelada));
    });

    test('unknown status string -> AuditStatus.rascunho (fallback)', () {
      final m = _fullAuditMap()..['status'] = 'imaginary_status';
      expect(Audit.fromMap(m).status, equals(AuditStatus.rascunho));
    });

    test('null status -> AuditStatus.rascunho (fallback)', () {
      final m = _fullAuditMap()..['status'] = null;
      expect(Audit.fromMap(m).status, equals(AuditStatus.rascunho));
    });
  });
}
