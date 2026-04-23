---
phase: 06-templates
status: human_needed
verified_at: 2026-04-23
requirements_covered: [TMPL-01, TMPL-02]
must_haves_verified: 9
must_haves_total: 10
human_verification:
  - "Close + reopen template builder confirms drag-reordered items persist in new order (requires live Supabase)"
  - "Long-press drag handle on emulator shows items reordering visually with drag handles"
  - "Network failure during reorder shows 'Erro ao salvar nova ordem. A ordem foi restaurada.' SnackBar and restores original order"
---

# Phase 06 Verification — Templates

## Goal

> Perguntas respeitam a ordem correta em todas as telas e o admin pode reordená-las por drag & drop com persistência.

## Automated Verification

### TMPL-01: Fix item ordering in AuditExecutionScreen._load()

| Check | Expected | Result |
|-------|----------|--------|
| `bucket.sort((a, b) => a.orderIndex.compareTo(b.orderIndex))` in `_load()` | 1 occurrence | ✓ PASS (1) |
| `unsectioned.sort((a, b) => a.orderIndex.compareTo(b.orderIndex))` in `_load()` | 1 occurrence | ✓ PASS (1) |
| Old buggy line `s.items = itemsBySection[s.id] ?? [];` removed | 0 occurrences | ✓ PASS (0) |
| Unit test file `audit_execution_ordering_test.dart` exists | present | ✓ PASS |
| `groupAndSort` helper in test file | 5 occurrences | ✓ PASS |
| `flutter test test/screens/audit_execution_ordering_test.dart` | exit 0 | ✓ PASS (4 tests) |

**TMPL-01 verdict: PASS** — Bucket sort and unsectioned sort applied in `_load()`. Old buggy line removed. Unit test covering 4 scenarios passes.

### TMPL-02: Drag & drop reorder in TemplateBuilderScreen

| Check | Expected | Result |
|-------|----------|--------|
| `ReorderableListView(` count | 2 | ✓ PASS (2) |
| `if (oldIndex < newIndex) newIndex -= 1;` count | 2 | ✓ PASS (2) |
| `_persistSectionOrder` method exists | ≥1 | ✓ PASS (3 — declaration + 2 calls) |
| `_persistUnsectionedOrder` method exists | ≥1 | ✓ PASS (2 — declaration + 1 call) |
| Error message `'Erro ao salvar nova ordem. A ordem foi restaurada.'` | 2 | ✓ PASS (2) |
| `_service.reorderItems(` calls | 2 | ✓ PASS (2) |
| `_buildItemCard` signature unchanged | 1 | ✓ PASS (1) |
| Unit test file `template_builder_reorder_test.dart` exists | present | ✓ PASS |
| `applyReorder` helper in test file | 6 occurrences | ✓ PASS |
| `flutter test test/screens/template_builder_reorder_test.dart` | exit 0 | ✓ PASS (5 tests) |

**TMPL-02 verdict: PASS** — Two `ReorderableListView` widgets with correct index adjustment, persistence helpers, and rollback on failure. `_buildItemCard` signature unchanged.

### Regression Gate

| Check | Result |
|-------|--------|
| `flutter test` (full suite, 158 tests) | ✓ PASS — All 158 tests passed |
| Schema drift detection | ✓ PASS — No schema files changed |
| Prior-phase unit tests | ✓ PASS — No regressions |

### Code Review

Code review ran at standard depth. 0 critical, 4 warnings, 2 info. Warnings are pre-existing issues in `template_builder_screen.dart` (missing `mounted` guards in rename/delete handlers, not introduced by this phase). See `06-REVIEW.md`.

## Phase Success Criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| 1. Na tela de execução de auditoria, as perguntas aparecem na ordem definida por `order_index`, sem embaralhamento | ✓ AUTOMATED | `bucket.sort` + `unsectioned.sort` in `_load()`; unit tests pass |
| 2. No template builder, o admin pode arrastar uma pergunta para cima ou para baixo e a nova ordem é salva no banco após soltar | ✓ AUTOMATED | 2x `ReorderableListView` + `_persistSectionOrder`/`_persistUnsectionedOrder` + `reorderItems` calls verified |
| 3. Após reordenar e fechar o template builder, reabrir o template mostra a nova ordem persistida | ⚠ HUMAN NEEDED | Requires live Supabase + emulator: drag → close → reopen → confirm order |

## Human Verification Items

1. **Drag persistence (criterion 3):** On device/emulator with live Supabase, open a template, long-press and drag an item to a new position, close the template, reopen it, confirm the item is in the new position.

2. **Drag handles visible:** Confirm drag handles appear on items when opening the template builder (Material 3 default drag handle icon in trailing position).

3. **Error rollback:** Simulate network failure (airplane mode) during a drag, confirm the SnackBar "Erro ao salvar nova ordem. A ordem foi restaurada." appears and items revert to original order.

## Requirement Traceability

| Requirement | Status |
|-------------|--------|
| TMPL-01 | Satisfied — fix in `audit_execution_screen.dart:_load()`, unit test in `test/screens/audit_execution_ordering_test.dart` |
| TMPL-02 | Satisfied — `ReorderableListView` in `template_builder_screen.dart`, persistence via `reorderItems`, unit test in `test/screens/template_builder_reorder_test.dart` |
