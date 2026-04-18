// Unit tests for AuditTemplateService.reorderItems payload logic (PERF-01).
// Tests the payload construction — does NOT instantiate AuditTemplateService
// (the `_client = Supabase.instance.client` field would throw in tests).
// Static verification: after applying the fix, audit_template_service.dart
// must NOT contain a `for (` loop with `await` inside reorderItems (grep check).

import 'package:flutter_test/flutter_test.dart';

// Pure helper mirroring the payload construction inside
// AuditTemplateService.reorderItems. Kept in sync manually — the
// implementation under test uses the same collection-for expression.
List<Map<String, dynamic>> buildReorderPayload(List<String> ids) {
  return [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
}

void main() {
  group('AuditTemplateService.reorderItems — payload construction (PERF-01)', () {
    test('empty list returns empty payload', () {
      expect(buildReorderPayload(<String>[]), isEmpty);
    });

    test('single id produces order_index 0', () {
      expect(buildReorderPayload(['id-a']), equals([
        {'id': 'id-a', 'order_index': 0},
      ]));
    });

    test('three ids produce ascending order_index starting at 0', () {
      expect(buildReorderPayload(['id-a', 'id-b', 'id-c']), equals([
        {'id': 'id-a', 'order_index': 0},
        {'id': 'id-b', 'order_index': 1},
        {'id': 'id-c', 'order_index': 2},
      ]));
    });

    test('20 ids produce payload of length 20 with last order_index == 19', () {
      final ids = List<String>.generate(20, (i) => 'id-$i');
      final payload = buildReorderPayload(ids);
      expect(payload.length, equals(20));
      expect(payload.first, equals({'id': 'id-0', 'order_index': 0}));
      expect(payload.last, equals({'id': 'id-19', 'order_index': 19}));
    });
  });
}
