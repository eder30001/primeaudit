// Unit tests for AuditsScreen._filtered date filter logic (CAL-02).
// Tests the date filter as a pure function — does NOT instantiate the screen
// (Supabase.instance.client throws in tests).
//
// Requirements: CAL-02 (date filter in _filtered, chip clear behavior)

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
    createdAt: createdAt ?? DateTime(2026, 5, 1),
    deadline: deadline,
    status: status,
    conformityPercent: conformityPercent,
  );
}

// ── Pure helper ───────────────────────────────────────────────────────────────
// Mirrors _AuditsScreenState._filtered date-filter step — keep in sync manually.
// Uses _activeDateFilter (mutable state field) logic: null = no filter.

List<Audit> _applyDateFilter(List<Audit> audits, DateTime? filterDate) {
  if (filterDate == null) return audits;
  return audits.where((a) {
    final effectiveDate = (a.deadline ?? a.createdAt).toLocal();
    return effectiveDate.year == filterDate.year &&
        effectiveDate.month == filterDate.month &&
        effectiveDate.day == filterDate.day;
  }).toList();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Use noon (12:00) local times to avoid any UTC/local day boundary issues.
  // Both filterDate and audit dates are local — no UTC-to-local conversion needed.

  group('_filtered date filter — keeps only same-day audits (CAL-02)', () {
    test('null filterDate returns all audits unchanged', () {
      final audits = [
        _audit(id: '1', createdAt: DateTime(2026, 5, 1, 12)),
        _audit(id: '2', createdAt: DateTime(2026, 5, 2, 12)),
        _audit(id: '3', createdAt: DateTime(2026, 5, 3, 12)),
      ];
      final result = _applyDateFilter(audits, null);
      expect(result.length, equals(3));
      expect(result, equals(audits));
    });

    test('filterDate keeps only audits with matching deadline', () {
      final targetDate = DateTime(2026, 5, 15);
      final audits = [
        _audit(id: '1', deadline: DateTime(2026, 5, 15, 12)),
        _audit(id: '2', deadline: DateTime(2026, 5, 16, 12)),
        _audit(id: '3', deadline: DateTime(2026, 5, 14, 12)),
      ];
      final result = _applyDateFilter(audits, targetDate);
      expect(result.length, equals(1));
      expect(result.first.id, equals('1'));
    });

    test('filterDate falls back to createdAt when deadline is null', () {
      final targetDate = DateTime(2026, 5, 10);
      final audits = [
        // deadline null → uses createdAt (same day as target)
        _audit(id: '1', createdAt: DateTime(2026, 5, 10, 8), deadline: null),
        // deadline null → uses createdAt (different day)
        _audit(id: '2', createdAt: DateTime(2026, 5, 11, 8), deadline: null),
      ];
      final result = _applyDateFilter(audits, targetDate);
      expect(result.length, equals(1));
      expect(result.first.id, equals('1'));
    });

    test('filterDate excludes audits on different days', () {
      final targetDate = DateTime(2026, 5, 20);
      final audits = [
        _audit(id: '1', deadline: DateTime(2026, 5, 19, 12)),
        _audit(id: '2', deadline: DateTime(2026, 5, 21, 12)),
        _audit(id: '3', createdAt: DateTime(2026, 5, 18, 12), deadline: null),
      ];
      final result = _applyDateFilter(audits, targetDate);
      expect(result, isEmpty);
    });

    test('deadline takes precedence over createdAt for date bucketing', () {
      final targetDate = DateTime(2026, 5, 25);
      final audits = [
        // deadline = 25th, createdAt = 10th → bucketed under 25th (deadline wins)
        _audit(
          id: '1',
          createdAt: DateTime(2026, 5, 10, 12),
          deadline: DateTime(2026, 5, 25, 12),
        ),
      ];
      final result = _applyDateFilter(audits, targetDate);
      expect(result.length, equals(1));
      expect(result.first.id, equals('1'));
    });
  });

  group('_filtered date filter — clear filter (chip onDeleted)', () {
    test('setting _activeDateFilter to null restores full list', () {
      // Simulates: user taps calendar day (filterDate = May 15),
      // then taps chip X (filterDate = null → full list restored).
      final audits = [
        _audit(id: '1', createdAt: DateTime(2026, 5, 15, 12)),
        _audit(id: '2', createdAt: DateTime(2026, 5, 16, 12)),
        _audit(id: '3', createdAt: DateTime(2026, 5, 17, 12)),
      ];

      // With filter active:
      final withFilter = _applyDateFilter(audits, DateTime(2026, 5, 15));
      expect(withFilter.length, equals(1));

      // After chip clear (setState(() => _activeDateFilter = null)):
      final afterClear = _applyDateFilter(audits, null);
      expect(afterClear.length, equals(3));
      expect(afterClear, equals(audits));
    });
  });
}
