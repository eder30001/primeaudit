---
phase: 06-templates
reviewed: 2026-04-23T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - primeaudit/lib/screens/audit_execution_screen.dart
  - primeaudit/lib/screens/templates/template_builder_screen.dart
  - primeaudit/test/screens/audit_execution_ordering_test.dart
  - primeaudit/test/screens/template_builder_reorder_test.dart
findings:
  critical: 0
  warning: 4
  info: 2
  total: 6
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-04-23T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Four files reviewed across two production screens and two pure-function test files. The TMPL-01 bucket-sort fix in `audit_execution_screen.dart` is correct and well-placed; the explicit sorts on lines 84 and 90 are the minimal surgical change needed. The TMPL-02 `ReorderableListView` integration in `template_builder_screen.dart` is structurally sound: the index-adjustment idiom (`if (oldIndex < newIndex) newIndex -= 1`) is correct, optimistic updates are properly done before the async persist, and rollback-via-reload on failure follows project convention.

Four warnings were found, all in `template_builder_screen.dart`. None involve the TMPL-01 sort fix. Three are missing error-handling patterns in existing menu actions that were not part of this change set; one is a missing `mounted` guard in the new `_persistSectionOrder`/`_persistUnsectionedOrder` error path. There are no critical issues.

Both test files are correct, well-scoped (pure functions, no Supabase dependency), and cover the key invariants for their respective changes.

---

## Warnings

### WR-01: `_load()` called without `mounted` guard in reorder error rollback

**File:** `primeaudit/lib/screens/templates/template_builder_screen.dart:367-370` and `379-382`

**Issue:** Both `_persistSectionOrder` and `_persistUnsectionedOrder` call `_load()` inside their `catch` blocks. `_load()` begins with an unconditional `setState` call at line 39 (`setState(() => _isLoading = true)`). If the widget is disposed between the `await _service.reorderItems(...)` call and the catch handler executing (e.g., user navigated back during a slow network request), `_load()` will call `setState` on a dead element. In debug mode this throws an assertion error; in release mode the behavior is undefined but the error is suppressed.

`_showError` already has a correct `mounted` guard (`if (!mounted) return`), but that guard does not protect the subsequent `_load()` call.

**Fix:**
```dart
Future<void> _persistSectionOrder(TemplateSection section) async {
  try {
    await _service.reorderItems(section.items.map((i) => i.id).toList());
  } catch (_) {
    _showError('Erro ao salvar nova ordem. A ordem foi restaurada.');
    if (mounted) _load(); // add mounted guard
  }
}

Future<void> _persistUnsectionedOrder() async {
  try {
    await _service.reorderItems(_items.map((i) => i.id).toList());
  } catch (_) {
    _showError('Erro ao salvar nova ordem. A ordem foi restaurada.');
    if (mounted) _load(); // add mounted guard
  }
}
```

---

### WR-02: Item delete has no error handling — failure is silently swallowed

**File:** `primeaudit/lib/screens/templates/template_builder_screen.dart:662-664`

**Issue:** The `delete` branch of the item popup menu calls `await _service.deleteItem(item.id)` with no surrounding `try/catch`. When `deleteItem` throws (network error, RLS rejection, FK constraint), the exception propagates into the `async` `onSelected` callback where Flutter silently swallows it. The user receives no error feedback, but the item remains in the list as if still present until the next reload. The UI and the database are inconsistent until a manual reload.

This is the existing code pattern used by section delete (line 562) which has the same issue, but item delete is now more prominently user-facing with the new reorder UI.

**Fix:**
```dart
if (v == 'delete') {
  try {
    await _service.deleteItem(item.id);
    _load();
  } catch (e) {
    _showError('Erro ao excluir item: $e');
  }
}
```

---

### WR-03: Section rename has no `mounted` check after dialog and no error handling

**File:** `primeaudit/lib/screens/templates/template_builder_screen.dart:526-542`

**Issue:** After `await showDialog(...)` resolves on line 528, there is no `mounted` check before `await _service.updateSection(...)` on line 540 and the subsequent `_load()` on line 541. If the widget is disposed while the dialog is open (possible if a route is popped programmatically), the subsequent calls will throw. Additionally, `updateSection` has no try/catch — a network failure propagates silently into the async `onSelected` callback with no user feedback, matching WR-02.

Compare with the `delete` branch in the same popup at lines 544-564, which correctly checks `mounted` before both the dialog and the service call.

**Fix:**
```dart
if (v == 'rename') {
  final ctrl = TextEditingController(text: section.name);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Renomear seção'),
      content: TextField(controller: ctrl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
      ],
    ),
  );
  if (ok == true && ctrl.text.trim().isNotEmpty && mounted) { // add mounted check
    try {
      await _service.updateSection(section.id, ctrl.text.trim());
      _load();
    } catch (e) {
      _showError('Erro ao renomear seção: $e');
    }
  }
}
```

---

### WR-04: Section delete service call lacks error handling

**File:** `primeaudit/lib/screens/templates/template_builder_screen.dart:561-563`

**Issue:** The section delete confirmation flow at lines 561-563 correctly checks `mounted` before proceeding, but `await _service.deleteSection(section.id)` has no try/catch. A network failure or RLS rejection will propagate silently into the async `onSelected` callback. The section remains visible in the UI but the user receives no error feedback. This is the same pattern as WR-02 but in the section menu.

**Fix:**
```dart
if (ok == true && mounted) {
  try {
    await _service.deleteSection(section.id);
    _load();
  } catch (e) {
    _showError('Erro ao excluir seção: $e');
  }
}
```

---

## Info

### IN-01: `_load()` in template_builder_screen makes two sequential awaits instead of parallel

**File:** `primeaudit/lib/screens/templates/template_builder_screen.dart:41-42`

**Issue:** `getSections` and `getItems` are independent calls that could be parallelized with `Future.wait`. The current sequential implementation adds unnecessary latency on every reload (including the rollback-reload triggered by reorder failures). The pattern `Future.wait([...])` is already established in `audit_execution_screen.dart` line 63.

**Fix:**
```dart
final results = await Future.wait([
  _service.getSections(widget.template.id),
  _service.getItems(widget.template.id),
]);
final sections = results[0] as List<TemplateSection>;
final allItems = results[1] as List<TemplateItem>;
```

---

### IN-02: Test helper `groupAndSort` applies a single loop over all entries including `null` key — minor divergence from production code

**File:** `primeaudit/test/screens/audit_execution_ordering_test.dart:34-36`

**Issue:** The `groupAndSort` helper iterates over all `bySection.entries` to sort, including the `null` key for unsectioned items. The production code in `audit_execution_screen.dart` uses two separate sort calls: one inside the `for (final s in sections)` loop (line 83-85) and one explicit sort on the `unsectioned` list (line 90). The test helper is semantically equivalent and tests the correct invariant, but it does not mirror the exact code path. If a future refactor changes the production split-sort into something with a subtle difference (e.g., only sorting named-section buckets), the test would still pass while the production bug goes undetected.

**Fix:** Add a comment noting the intentional equivalence, or restructure the helper to mirror the production code's two-loop structure exactly:

```dart
// Mirrors production code structure: separate loops for section buckets
// and the null (unsectioned) bucket. Functionally equivalent to sorting all
// entries, but tracks the production code path more closely for drift detection.
Map<String?, List<_FakeItem>> groupAndSort(List<_FakeItem> items) {
  final bySection = <String?, List<_FakeItem>>{};
  for (final item in items) {
    bySection.putIfAbsent(item.sectionId, () => []).add(item);
  }
  // Sort each named-section bucket (mirrors the `for (final s in sections)` loop)
  for (final entry in bySection.entries) {
    if (entry.key != null) {
      entry.value.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    }
  }
  // Sort unsectioned bucket separately (mirrors the explicit sort in _load)
  bySection[null]?.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return bySection;
}
```

---

_Reviewed: 2026-04-23T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
