---
plan: 06-02
phase: 06-templates
status: complete
completed: 2026-04-23
requirements: [TMPL-02]
commits:
  - 0693a50: "test(06-02): add unit tests for TemplateBuilderScreen onReorder logic (TMPL-02)"
  - 84d8ee2: "feat(06-02): replace flat ListView with ReorderableListView for item drag & drop (TMPL-02)"
key-files:
  created:
    - primeaudit/test/screens/template_builder_reorder_test.dart
  modified:
    - primeaudit/lib/screens/templates/template_builder_screen.dart
---

# Plan 06-02 Summary — TMPL-02: Drag & Drop Reorder in TemplateBuilderScreen

## What Was Built

Replaced the two flat `ListView` spreads in `TemplateBuilderScreen` with `ReorderableListView` widgets scoped per section, with full persistence via the existing `AuditTemplateService.reorderItems` batch upsert (PERF-01).

## Task 1: Unit Test — template_builder_reorder_test.dart

Created `primeaudit/test/screens/template_builder_reorder_test.dart` with a pure `applyReorder` helper (mirrors the `onReorder` index-adjustment logic) and 5 test scenarios:

1. Move item down — `if (oldIndex < newIndex) newIndex -= 1` adjustment is applied
2. Move item up — no adjustment needed
3. IDs passed to `reorderItems` match the new list order after reorder
4. Move to end of list (`newIndex == length`) lands at the last slot
5. No-op reorder (drag to same position) leaves list unchanged

All 5 tests pass. No Supabase, no widget infrastructure, no `testWidgets`.

## Task 2: ReorderableListView Implementation

### Changes to `template_builder_screen.dart`

**Substitution A — Unsectioned items in `build()`:**
Replaced `..._items.map((item) => _buildItemCard(item))` spread with a `ReorderableListView` (`shrinkWrap: true`, `NeverScrollableScrollPhysics`) whose `onReorder` applies index adjustment, calls `setState` to update `_items` optimistically, then calls `_persistUnsectionedOrder()`.

**Substitution B — Sectioned items in `_buildSection()`:**
Replaced `...section.items.map((item) => _buildItemCard(item, inSection: true))` spread with a `ReorderableListView` per section whose `onReorder` applies index adjustment, calls `setState` to update `section.items` optimistically, then calls `_persistSectionOrder(section)`.

**New helpers added before `_showError`:**

```dart
Future<void> _persistSectionOrder(TemplateSection section) async {
  try {
    await _service.reorderItems(section.items.map((i) => i.id).toList());
  } catch (e) {
    _showError('Erro ao salvar nova ordem. A ordem foi restaurada.');
    _load();
  }
}

Future<void> _persistUnsectionedOrder() async {
  try {
    await _service.reorderItems(_items.map((i) => i.id).toList());
  } catch (e) {
    _showError('Erro ao salvar nova ordem. A ordem foi restaurada.');
    _load();
  }
}
```

`_buildItemCard` signature unchanged. Each child wrapped in `KeyedSubtree(key: ValueKey(item.id))`.

## Verification

- `flutter analyze lib/screens/templates/template_builder_screen.dart` → No issues found
- `flutter test` (154 tests, full suite) → All passed
- All acceptance criteria confirmed via grep:
  - 2x `ReorderableListView(`
  - 2x `if (oldIndex < newIndex) newIndex -= 1;`
  - 2x `KeyedSubtree(`
  - 2x `ValueKey(item.id)`
  - `_persistSectionOrder` + `_persistUnsectionedOrder` present
  - 2x error message `'Erro ao salvar nova ordem. A ordem foi restaurada.'`
  - Old flat spreads removed (0 occurrences)
  - `Widget _buildItemCard(TemplateItem item, {bool inSection = false})` unchanged

## Wave 0 Gap Status: CLOSED

`primeaudit/test/screens/template_builder_reorder_test.dart` created and passing.

## Deviations

None. `buildDefaultDragHandles: true` used as planned. `catch (e)` accepted by analyzer without `unused_catch_clause` warning.

## Manual UAT Pending

- Long-press + drag item in emulator to verify visual reorder
- Close + reopen template to confirm persistence
- Simulate network failure to verify SnackBar error + order restoration

## Self-Check: PASSED
