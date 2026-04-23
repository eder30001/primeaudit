// Unit tests for TemplateBuilderScreen onReorder index logic (TMPL-02).
// Tests the reorder state mutation as a pure function — does NOT instantiate
// the screen (Supabase dependency would throw in tests).
//
// This helper mirrors the onReorder callback applied in
// primeaudit/lib/screens/templates/template_builder_screen.dart inside the
// ReorderableListView for both sectioned and unsectioned item lists.
// Kept in sync manually — any change to the screen onReorder must update the
// helper here.

import 'package:flutter_test/flutter_test.dart';

// Pure helper mirroring the onReorder callback logic in TemplateBuilderScreen.
// Matches: if (oldIndex < newIndex) newIndex -= 1; removeAt; insert.
// Returns the resulting list of IDs in their new order — this is exactly the
// list that will be passed to AuditTemplateService.reorderItems(ids).
List<String> applyReorder(List<String> ids, int oldIndex, int newIndex) {
  final list = List<String>.from(ids);
  if (oldIndex < newIndex) newIndex -= 1;
  final item = list.removeAt(oldIndex);
  list.insert(newIndex, item);
  return list;
}

void main() {
  group('TemplateBuilderScreen onReorder — index adjustment (TMPL-02)', () {
    test('move item down: index adjustment is applied (oldIndex < newIndex)', () {
      // Start: [a, b, c, d]
      // User drags 'a' (index 0) to drop at position 2 (between 'b' and 'c').
      // Flutter reports newIndex=2, but after removing 'a' all items shift
      // down; without adjustment the item would be inserted at index 2 of a
      // 3-item list, placing it after 'c' instead of before it.
      // With adjustment newIndex becomes 1 — correct slot.
      final result = applyReorder(['a', 'b', 'c', 'd'], 0, 2);
      expect(result, equals(['b', 'a', 'c', 'd']));
    });

    test('move item up: no adjustment needed (oldIndex > newIndex)', () {
      // Start: [a, b, c, d]
      // User drags 'c' (index 2) to position 0 — no adjustment.
      final result = applyReorder(['a', 'b', 'c', 'd'], 2, 0);
      expect(result, equals(['c', 'a', 'b', 'd']));
    });

    test('IDs passed to reorderItems match the new list order after reorder', () {
      // Simulates the exact flow: user reorders, onReorder updates the list,
      // the resulting ids are handed to AuditTemplateService.reorderItems.
      final original = ['item-1', 'item-2', 'item-3', 'item-4', 'item-5'];
      final afterReorder = applyReorder(original, 4, 1);
      // 'item-5' moves from index 4 to index 1 (oldIndex > newIndex, no adj).
      expect(afterReorder, equals(['item-1', 'item-5', 'item-2', 'item-3', 'item-4']));
      // reorderItems(afterReorder) would assign order_index 0..4 to these IDs
      // in this exact order — that is what the drop should persist.
    });

    test('move to end of list (newIndex == length) lands at the last slot', () {
      // Start: [a, b, c]
      // User drags 'a' (index 0) to the very end — Flutter reports
      // newIndex == list.length (3). After adjustment newIndex becomes 2,
      // then removeAt(0) + insert(2) places 'a' at the tail.
      final result = applyReorder(['a', 'b', 'c'], 0, 3);
      expect(result, equals(['b', 'c', 'a']));
    });

    test('no-op reorder (drag to same position) leaves list unchanged', () {
      // Drag index 1 to newIndex 2 — adjustment makes newIndex 1, so
      // removeAt(1) + insert(1) restores the original order.
      final result = applyReorder(['a', 'b', 'c'], 1, 2);
      expect(result, equals(['a', 'b', 'c']));
    });
  });
}
