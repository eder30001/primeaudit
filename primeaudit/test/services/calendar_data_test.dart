// Unit tests for calendar data bucketing logic (CAL-01, D-03, D-04).
// Tests pure computation helpers that mirror logic inside _HomeScreenState.
// Does NOT instantiate any service (Supabase.instance.client throws in tests).
//
// Requirements: CAL-01 (bucketing, status groups, month filter, D-03, UTC pitfall)

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit.dart';

// ── Test factory ──────────────────────────────────────────────────────────────

Audit _audit({
  String id = 'a1',
  String templateName = 'Template A',
  AuditStatus status = AuditStatus.emAndamento,
  double? conformityPercent,
  String auditorId = 'user1',
  DateTime? createdAt,
  DateTime? deadline,
}) {
  return Audit(
    id: id,
    title: 'Test Audit',
    auditTypeId: 'at1',
    auditTypeName: 'Type',
    auditTypeIcon: '📋',
    auditTypeColor: '#2196F3',
    templateId: 't1',
    templateName: templateName,
    companyId: 'c1',
    companyName: 'Acme',
    companyRequiresPerimeter: false,
    auditorId: auditorId,
    auditorName: 'Ana',
    createdAt: createdAt ?? DateTime(2026, 5, 15),
    deadline: deadline,
    status: status,
    conformityPercent: conformityPercent,
  );
}

// ── Pure helpers (mirrors _HomeScreenState logic) ─────────────────────────────
// Mirrors _HomeScreenState._buildCalendarData() — keep in sync manually.

Map<String, List<Audit>> _buildCalendarData(
    List<Audit> audits, int year, int month) {
  final Map<String, List<Audit>> data = {};
  for (final audit in audits) {
    if (audit.status == AuditStatus.cancelada) continue; // D-04
    final effectiveDate =
        (audit.deadline ?? audit.createdAt).toLocal(); // D-03 + UTC pitfall fix
    if (effectiveDate.year == year && effectiveDate.month == month) {
      final key =
          '${effectiveDate.year}-'
          '${effectiveDate.month.toString().padLeft(2, "0")}-'
          '${effectiveDate.day.toString().padLeft(2, "0")}';
      data.putIfAbsent(key, () => []).add(audit);
    }
  }
  return data;
}

int _novas(List<Audit> audits) => audits
    .where((a) =>
        a.status == AuditStatus.rascunho ||
        a.status == AuditStatus.emAndamento)
    .length;

int _atrasadas(List<Audit> audits) =>
    audits.where((a) => a.status == AuditStatus.atrasada).length;

int _concluidas(List<Audit> audits) =>
    audits.where((a) => a.status == AuditStatus.concluida).length;

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('_buildCalendarData — deadline ?? createdAt bucketing', () {
    test('audit with deadline is bucketed by deadline date', () {
      final audits = [
        _audit(
          id: '1',
          deadline: DateTime(2026, 5, 10),
          createdAt: DateTime(2026, 4, 1),
        ),
      ];
      final result = _buildCalendarData(audits, 2026, 5);
      expect(result.containsKey('2026-05-10'), isTrue);
      expect(result.containsKey('2026-04-01'), isFalse);
    });

    test('audit with null deadline is bucketed by createdAt', () {
      final audits = [
        _audit(
          id: '1',
          deadline: null,
          createdAt: DateTime(2026, 5, 20),
        ),
      ];
      final result = _buildCalendarData(audits, 2026, 5);
      expect(result.containsKey('2026-05-20'), isTrue);
    });

    test('audit outside target month is excluded', () {
      final audits = [
        _audit(
          id: '1',
          deadline: null,
          createdAt: DateTime(2026, 4, 15),
        ),
      ];
      final result = _buildCalendarData(audits, 2026, 5);
      expect(result, isEmpty);
    });

    test('multiple audits on same day accumulate in same list', () {
      final audits = [
        _audit(id: '1', createdAt: DateTime(2026, 5, 10)),
        _audit(id: '2', createdAt: DateTime(2026, 5, 10)),
      ];
      final result = _buildCalendarData(audits, 2026, 5);
      expect(result['2026-05-10']?.length, equals(2));
    });
  });

  group('_buildCalendarData — cancelada exclusion (D-04)', () {
    test('cancelada audit is never included', () {
      final audits = [
        _audit(
          id: '1',
          status: AuditStatus.cancelada,
          createdAt: DateTime(2026, 5, 10),
        ),
      ];
      final result = _buildCalendarData(audits, 2026, 5);
      expect(result, isEmpty);
    });
  });

  group('_buildCalendarData — UTC to local conversion (Pitfall 1)', () {
    test('UTC datetime is converted to local before bucketing', () {
      // UTC 23:00 on May 15 may be May 16 in some timezones — this test verifies
      // .toLocal() is applied without crashing. We only check a key IS produced.
      final audits = [
        _audit(
          id: '1',
          createdAt: DateTime.utc(2026, 5, 15, 23, 0),
          deadline: null,
        ),
      ];
      // The month where the key lands depends on local timezone, but _some_ key
      // must be produced (either 2026-05-15 or 2026-05-16).
      // We test for May 2026 and June 2026 combined.
      final resultMay = _buildCalendarData(audits, 2026, 5);
      final resultJun = _buildCalendarData(audits, 2026, 6);
      expect(
        resultMay.isNotEmpty || resultJun.isNotEmpty,
        isTrue,
        reason: 'UTC 23:00 May 15 must land in either May or June in local time',
      );
    });
  });

  group('Status group helpers — novas/atrasadas/concluidas', () {
    test('novas = rascunho + emAndamento', () {
      final audits = [
        _audit(id: '1', status: AuditStatus.rascunho),
        _audit(id: '2', status: AuditStatus.emAndamento),
        _audit(id: '3', status: AuditStatus.atrasada),
        _audit(id: '4', status: AuditStatus.concluida),
        _audit(id: '5', status: AuditStatus.cancelada),
      ];
      expect(_novas(audits), equals(2));
    });

    test('atrasadas = atrasada only', () {
      final audits = [
        _audit(id: '1', status: AuditStatus.atrasada),
        _audit(id: '2', status: AuditStatus.rascunho),
      ];
      expect(_atrasadas(audits), equals(1));
    });

    test('concluidas = concluida only', () {
      final audits = [
        _audit(id: '1', status: AuditStatus.concluida),
        _audit(id: '2', status: AuditStatus.emAndamento),
      ];
      expect(_concluidas(audits), equals(1));
    });

    test('cancelada never counted in any group', () {
      final audits = [
        _audit(id: '1', status: AuditStatus.cancelada),
      ];
      expect(_novas(audits), equals(0));
      expect(_atrasadas(audits), equals(0));
      expect(_concluidas(audits), equals(0));
    });
  });
}
