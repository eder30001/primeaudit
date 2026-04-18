// Unit tests for AuditAnswerService.calculateConformity (QUAL-01).
// All 6 response types + empty list + multi-weight scenarios.
// Uses the static form — does NOT instantiate AuditAnswerService
// (the `_client = Supabase.instance.client` field would throw in tests).

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/services/audit_answer_service.dart';
import 'package:primeaudit/models/audit_template.dart';

TemplateItem _item({
  String id = 'i1',
  String responseType = 'ok_nok',
  int weight = 1,
}) {
  return TemplateItem(
    id: id,
    templateId: 't1',
    question: 'Q',
    responseType: responseType,
    required: true,
    weight: weight,
    orderIndex: 0,
  );
}

void main() {
  group('AuditAnswerService.calculateConformity — edge cases', () {
    test('empty items list returns 100.0', () {
      expect(
        AuditAnswerService.calculateConformity([], {}),
        equals(100.0),
      );
    });

    test('items with no answers produce 0.0 conformity (totalWeight > 0)', () {
      final items = [_item(weight: 2)];
      expect(
        AuditAnswerService.calculateConformity(items, {}),
        equals(0.0),
      );
    });

    test('empty-string answer is treated as no answer (skipped)', () {
      final items = [_item(responseType: 'text', weight: 2)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': ''}),
        equals(0.0),
      );
    });
  });

  group('AuditAnswerService.calculateConformity — ok_nok', () {
    test('ok answer earns full weight (weight=2)', () {
      final items = [_item(responseType: 'ok_nok', weight: 2)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': 'ok'}),
        equals(100.0),
      );
    });

    test('nok answer earns zero', () {
      final items = [_item(responseType: 'ok_nok', weight: 2)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': 'nok'}),
        equals(0.0),
      );
    });

    test('ok answer with weight=3 still earns full 100% (single item)', () {
      final items = [_item(responseType: 'ok_nok', weight: 3)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': 'ok'}),
        equals(100.0),
      );
    });
  });

  group('AuditAnswerService.calculateConformity — yes_no', () {
    test('yes answer earns full weight', () {
      final items = [_item(responseType: 'yes_no', weight: 2)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': 'yes'}),
        equals(100.0),
      );
    });

    test('no answer earns zero', () {
      final items = [_item(responseType: 'yes_no', weight: 2)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': 'no'}),
        equals(0.0),
      );
    });
  });

  group('AuditAnswerService.calculateConformity — scale_1_5', () {
    test('scale 5 earns 100%', () {
      final items = [_item(responseType: 'scale_1_5', weight: 1)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': '5'}),
        closeTo(100.0, 0.01),
      );
    });

    test('scale 3 with weight=5 earns 60% (3/5 of full)', () {
      final items = [_item(responseType: 'scale_1_5', weight: 5)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': '3'}),
        closeTo(60.0, 0.01),
      );
    });

    test('scale 1 earns 20%', () {
      final items = [_item(responseType: 'scale_1_5', weight: 1)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': '1'}),
        closeTo(20.0, 0.01),
      );
    });
  });

  group('AuditAnswerService.calculateConformity — percentage', () {
    test('100 earns 100%', () {
      final items = [_item(responseType: 'percentage', weight: 1)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': '100'}),
        closeTo(100.0, 0.01),
      );
    });

    test('50 with weight=4 earns 50%', () {
      final items = [_item(responseType: 'percentage', weight: 4)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': '50'}),
        closeTo(50.0, 0.01),
      );
    });

    test('0 earns 0%', () {
      final items = [_item(responseType: 'percentage', weight: 1)];
      // Note: '0' is a non-empty string so it is NOT skipped by the empty guard
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': '0'}),
        closeTo(0.0, 0.01),
      );
    });
  });

  group('AuditAnswerService.calculateConformity — text', () {
    test('non-empty text earns full weight', () {
      final items = [_item(responseType: 'text', weight: 3)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': 'algum texto'}),
        equals(100.0),
      );
    });
  });

  group('AuditAnswerService.calculateConformity — selection', () {
    test('non-empty selection earns full weight', () {
      final items = [_item(responseType: 'selection', weight: 3)];
      expect(
        AuditAnswerService.calculateConformity(items, {'i1': 'option_a'}),
        equals(100.0),
      );
    });
  });

  group('AuditAnswerService.calculateConformity — multi-weight scenarios', () {
    test('two items with weights 1 and 3 — ok on weight=1, nok on weight=3 → 25%', () {
      final items = [
        _item(id: 'a', responseType: 'ok_nok', weight: 1),
        _item(id: 'b', responseType: 'ok_nok', weight: 3),
      ];
      expect(
        AuditAnswerService.calculateConformity(
          items,
          {'a': 'ok', 'b': 'nok'},
        ),
        closeTo(25.0, 0.01),
      );
    });

    test('two items with weights 1 and 3 — nok on weight=1, ok on weight=3 → 75%', () {
      final items = [
        _item(id: 'a', responseType: 'ok_nok', weight: 1),
        _item(id: 'b', responseType: 'ok_nok', weight: 3),
      ];
      expect(
        AuditAnswerService.calculateConformity(
          items,
          {'a': 'nok', 'b': 'ok'},
        ),
        closeTo(75.0, 0.01),
      );
    });

    test('mixed types — yes_no(w=2) yes + scale_1_5(w=5) answer=3 → (2 + 3) / 7 * 100 ≈ 71.43%', () {
      final items = [
        _item(id: 'a', responseType: 'yes_no', weight: 2),
        _item(id: 'b', responseType: 'scale_1_5', weight: 5),
      ];
      // earned: yes_no yes → +2, scale_1_5 '3' → 3/5 * 5 = +3; total = 5
      // totalWeight = 7 → 5/7*100 ≈ 71.4286
      expect(
        AuditAnswerService.calculateConformity(
          items,
          {'a': 'yes', 'b': '3'},
        ),
        closeTo(71.43, 0.01),
      );
    });
  });
}
