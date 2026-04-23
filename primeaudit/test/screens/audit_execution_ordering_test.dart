// Unit tests for AuditExecutionScreen._load() grouping sort correctness (TMPL-01).
// Tests the bucket sort logic as a pure function — does NOT instantiate the
// screen (Supabase.instance.client would throw in tests).
//
// This helper mirrors the grouping + sort logic applied in
// primeaudit/lib/screens/audit_execution_screen.dart inside _load(). Kept in
// sync manually — any change to the screen grouping must also update the
// helper here.

import 'package:flutter_test/flutter_test.dart';

// Minimal item representation — mirrors the fields of TemplateItem used by the
// grouping/sort logic. Keep in sync with lib/models/audit_template.dart.
class _FakeItem {
  final String id;
  final String? sectionId;
  final int orderIndex;
  const _FakeItem({
    required this.id,
    this.sectionId,
    required this.orderIndex,
  });
}

// Pure helper mirroring the grouping + sort logic in
// AuditExecutionScreen._load(). After the FIX applied in Task 2, each
// bucket (including the unsectioned bucket at key `null`) is sorted by
// orderIndex ascending.
Map<String?, List<_FakeItem>> groupAndSort(List<_FakeItem> items) {
  final bySection = <String?, List<_FakeItem>>{};
  for (final item in items) {
    bySection.putIfAbsent(item.sectionId, () => []).add(item);
  }
  for (final entry in bySection.entries) {
    entry.value.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }
  return bySection;
}

void main() {
  group('AuditExecutionScreen._load() — grouping sort (TMPL-01)', () {
    test('items within a section are sorted by orderIndex after grouping', () {
      final items = <_FakeItem>[
        _FakeItem(id: 'b', sectionId: 's1', orderIndex: 1),
        _FakeItem(id: 'a', sectionId: 's1', orderIndex: 0),
        _FakeItem(id: 'c', sectionId: 's1', orderIndex: 2),
      ];

      final result = groupAndSort(items);

      expect(result['s1']!.map((i) => i.id).toList(), equals(['a', 'b', 'c']));
      expect(result['s1']!.map((i) => i.orderIndex).toList(), equals([0, 1, 2]));
    });

    test('unsectioned items bucket is sorted by orderIndex', () {
      final items = <_FakeItem>[
        _FakeItem(id: 'y', orderIndex: 2),
        _FakeItem(id: 'z', orderIndex: 3),
        _FakeItem(id: 'x', orderIndex: 1),
      ];

      final result = groupAndSort(items);

      expect(result[null], isNotNull);
      expect(result[null]!.map((i) => i.id).toList(), equals(['x', 'y', 'z']));
      expect(result[null]!.map((i) => i.orderIndex).toList(), equals([1, 2, 3]));
    });

    test('out-of-order insertion is corrected by sort', () {
      // Simulates PostgREST returning items in a different order than orderIndex
      // (e.g., after a recent reorder where the cache is stale), or a new item
      // inserted with orderIndex=5 before the list was re-sorted.
      final items = <_FakeItem>[
        _FakeItem(id: 'first',  sectionId: 's1', orderIndex: 1),
        _FakeItem(id: 'last',   sectionId: 's1', orderIndex: 5),
        _FakeItem(id: 'middle', sectionId: 's1', orderIndex: 3),
      ];

      final result = groupAndSort(items);

      expect(
        result['s1']!.map((i) => i.id).toList(),
        equals(['first', 'middle', 'last']),
      );
      expect(
        result['s1']!.map((i) => i.orderIndex).toList(),
        equals([1, 3, 5]),
      );
    });

    test('multiple sections are each sorted independently', () {
      final items = <_FakeItem>[
        _FakeItem(id: 'a2', sectionId: 'A', orderIndex: 1),
        _FakeItem(id: 'b1', sectionId: 'B', orderIndex: 0),
        _FakeItem(id: 'a1', sectionId: 'A', orderIndex: 0),
        _FakeItem(id: 'b2', sectionId: 'B', orderIndex: 1),
      ];

      final result = groupAndSort(items);

      expect(result['A']!.map((i) => i.id).toList(), equals(['a1', 'a2']));
      expect(result['B']!.map((i) => i.id).toList(), equals(['b1', 'b2']));
    });
  });
}
