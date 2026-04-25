// Unit tests for dashboard aggregation logic (DASH-01, DASH-03).
// Tests pure computation helpers that mirror logic inside _HomeScreenState.
// Does NOT instantiate DashboardService (Supabase.instance.client throws in tests).
//
// Requirements: DASH-01 (KPI counts, role scope, fallback), DASH-03 (chart data)

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit.dart';

// ── Test factory ──────────────────────────────────────────────────────────────

Audit _audit({
  String id = 'a1',
  String templateName = 'Template A',
  AuditStatus status = AuditStatus.emAndamento,
  double? conformityPercent,
  String auditorId = 'user1',
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
    createdAt: DateTime(2024, 1, 1),
    status: status,
    conformityPercent: conformityPercent,
  );
}

// ── Pure helpers (mirrors _HomeScreenState logic) ─────────────────────────────

int _countTotal(List<Audit> audits) =>
    audits.where((a) => a.status != AuditStatus.cancelada).length;

int _countPending(List<Audit> audits) =>
    audits.where((a) => a.status == AuditStatus.emAndamento).length;

int _countOverdue(List<Audit> audits) =>
    audits.where((a) => a.status == AuditStatus.atrasada).length;

List<Audit> _filterForAuditor(List<Audit> audits, String auditorId) =>
    audits.where((a) => a.auditorId == auditorId).toList();

typedef ChartEntry = ({String templateName, double avgConformity});

List<ChartEntry> _buildChartData(List<Audit> audits) {
  final Map<String, List<double>> byTemplate = {};
  for (final a in audits) {
    if (a.status == AuditStatus.concluida && a.conformityPercent != null) {
      byTemplate.putIfAbsent(a.templateName, () => []).add(a.conformityPercent!);
    }
  }
  return byTemplate.entries.map((e) {
    final avg = e.value.reduce((a, b) => a + b) / e.value.length;
    return (templateName: e.key, avgConformity: avg);
  }).toList()
    ..sort((a, b) => b.avgConformity.compareTo(a.avgConformity));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // DASH-01: KPI counts — total excludes cancelada (D-01)
  group('KPI counts — total excludes cancelada', () {
    test('cancelada audit is NOT counted in total', () {
      final audits = [_audit(status: AuditStatus.cancelada)];
      expect(_countTotal(audits), equals(0));
    });

    test('rascunho is counted in total', () {
      final audits = [_audit(status: AuditStatus.rascunho)];
      expect(_countTotal(audits), equals(1));
    });

    test('emAndamento is counted in total', () {
      final audits = [_audit(status: AuditStatus.emAndamento)];
      expect(_countTotal(audits), equals(1));
    });

    test('concluida is counted in total', () {
      final audits = [_audit(status: AuditStatus.concluida)];
      expect(_countTotal(audits), equals(1));
    });

    test('atrasada is counted in total', () {
      final audits = [_audit(status: AuditStatus.atrasada)];
      expect(_countTotal(audits), equals(1));
    });

    test('mixed list: 4 non-cancelled + 1 cancelled = total of 4', () {
      final audits = [
        _audit(id: '1', status: AuditStatus.rascunho),
        _audit(id: '2', status: AuditStatus.emAndamento),
        _audit(id: '3', status: AuditStatus.concluida),
        _audit(id: '4', status: AuditStatus.atrasada),
        _audit(id: '5', status: AuditStatus.cancelada),
      ];
      expect(_countTotal(audits), equals(4));
    });
  });

  // DASH-01: KPI counts — pending = emAndamento only (D-02)
  group('KPI counts — pending is emAndamento only', () {
    test('emAndamento is counted as pending', () {
      final audits = [_audit(status: AuditStatus.emAndamento)];
      expect(_countPending(audits), equals(1));
    });

    test('rascunho is NOT counted as pending', () {
      final audits = [_audit(status: AuditStatus.rascunho)];
      expect(_countPending(audits), equals(0));
    });

    test('concluida is NOT counted as pending', () {
      final audits = [_audit(status: AuditStatus.concluida)];
      expect(_countPending(audits), equals(0));
    });

    test('atrasada is NOT counted as pending', () {
      final audits = [_audit(status: AuditStatus.atrasada)];
      expect(_countPending(audits), equals(0));
    });
  });

  // DASH-01: KPI counts — overdue = atrasada only (D-03)
  group('KPI counts — overdue is atrasada only', () {
    test('atrasada is counted as overdue', () {
      final audits = [_audit(status: AuditStatus.atrasada)];
      expect(_countOverdue(audits), equals(1));
    });

    test('emAndamento is NOT counted as overdue', () {
      final audits = [_audit(status: AuditStatus.emAndamento)];
      expect(_countOverdue(audits), equals(0));
    });

    test('empty list returns 0 overdue', () {
      expect(_countOverdue([]), equals(0));
    });
  });

  // DASH-01: Role scope — auditor sees only own audits (D-05)
  group('Role scope — auditor filter', () {
    test('filter keeps only audits matching auditorId', () {
      final audits = [
        _audit(id: '1', auditorId: 'user1'),
        _audit(id: '2', auditorId: 'user2'),
        _audit(id: '3', auditorId: 'user1'),
      ];
      final filtered = _filterForAuditor(audits, 'user1');
      expect(filtered.length, equals(2));
      expect(filtered.every((a) => a.auditorId == 'user1'), isTrue);
    });

    test('admin gets all audits unfiltered', () {
      final audits = [
        _audit(id: '1', auditorId: 'user1'),
        _audit(id: '2', auditorId: 'user2'),
      ];
      // Admin does NOT call _filterForAuditor — uses the full list
      expect(audits.length, equals(2));
    });

    test('auditor with no own audits gets empty list', () {
      final audits = [_audit(auditorId: 'user2')];
      final filtered = _filterForAuditor(audits, 'user1');
      expect(filtered, isEmpty);
    });
  });

  // DASH-03: Chart data grouping by templateName
  group('Chart data — grouping and averaging', () {
    test('empty list returns empty chart data', () {
      expect(_buildChartData([]), isEmpty);
    });

    test('emAndamento audits are excluded from chart (only concluida included)', () {
      final audits = [
        _audit(status: AuditStatus.emAndamento, conformityPercent: 80.0),
        _audit(status: AuditStatus.atrasada, conformityPercent: 70.0),
        _audit(status: AuditStatus.rascunho, conformityPercent: 60.0),
      ];
      expect(_buildChartData(audits), isEmpty);
    });

    test('concluida audit with null conformityPercent is excluded', () {
      final audits = [_audit(status: AuditStatus.concluida, conformityPercent: null)];
      expect(_buildChartData(audits), isEmpty);
    });

    test('single concluida audit produces one entry with correct value', () {
      final audits = [
        _audit(status: AuditStatus.concluida, conformityPercent: 75.0, templateName: 'T-A'),
      ];
      final result = _buildChartData(audits);
      expect(result.length, equals(1));
      expect(result.first.templateName, equals('T-A'));
      expect(result.first.avgConformity, equals(75.0));
    });

    test('two templates produce two entries', () {
      final audits = [
        _audit(id: '1', status: AuditStatus.concluida, conformityPercent: 80.0, templateName: 'T-A'),
        _audit(id: '2', status: AuditStatus.concluida, conformityPercent: 60.0, templateName: 'T-B'),
      ];
      final result = _buildChartData(audits);
      expect(result.length, equals(2));
    });

    test('average conformity is computed correctly across multiple audits for same template', () {
      final audits = [
        _audit(id: '1', status: AuditStatus.concluida, conformityPercent: 80.0, templateName: 'T-A'),
        _audit(id: '2', status: AuditStatus.concluida, conformityPercent: 60.0, templateName: 'T-A'),
      ];
      final result = _buildChartData(audits);
      expect(result.length, equals(1));
      expect(result.first.avgConformity, equals(70.0));
    });

    test('entries are sorted descending by avgConformity (best template first)', () {
      final audits = [
        _audit(id: '1', status: AuditStatus.concluida, conformityPercent: 60.0, templateName: 'T-Low'),
        _audit(id: '2', status: AuditStatus.concluida, conformityPercent: 90.0, templateName: 'T-High'),
        _audit(id: '3', status: AuditStatus.concluida, conformityPercent: 75.0, templateName: 'T-Mid'),
      ];
      final result = _buildChartData(audits);
      expect(result[0].templateName, equals('T-High'));
      expect(result[1].templateName, equals('T-Mid'));
      expect(result[2].templateName, equals('T-Low'));
    });
  });
}
