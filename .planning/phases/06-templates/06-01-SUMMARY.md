---
phase: 06-templates
plan: "01"
subsystem: audit-execution
tags: [flutter, audit-execution, sort, orderIndex, unit-test, TMPL-01]
requirements: [TMPL-01]

dependency_graph:
  requires: []
  provides: [TMPL-01-sort-fix, wave0-test-gap-closed]
  affects: [primeaudit/lib/screens/audit_execution_screen.dart, primeaudit/test/screens/audit_execution_ordering_test.dart]

tech_stack:
  added: []
  patterns:
    - "Pure-function unit test mirroring screen logic (no widget, no Supabase)"
    - "In-place List.sort() after putIfAbsent bucket grouping"

key_files:
  created:
    - path: primeaudit/test/screens/audit_execution_ordering_test.dart
      role: "Unit tests for _load() grouping+sort correctness — 4 scenarios, pure function helper groupAndSort"
  modified:
    - path: primeaudit/lib/screens/audit_execution_screen.dart
      role: "TMPL-01 fix: bucket.sort + unsectioned.sort added in _load() grouping block"

decisions:
  - "Pure function test approach (no widget): avoids Supabase.instance.client initialization requirement in test environment"
  - "In-place sort after grouping: minimal change to existing logic, no new data structures"

metrics:
  duration_minutes: 12
  completed_date: "2026-04-23"
  tasks_completed: 2
  files_changed: 2
---

# Phase 06 Plan 01: Audit Execution Item Ordering Fix (TMPL-01) Summary

**One-liner:** Fixed silent ordering bug in `_load()` — added `bucket.sort` and `unsectioned.sort` by `orderIndex` after `putIfAbsent` bucket grouping, covered by 4 pure-function unit tests.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Wave 0: Create unit test audit_execution_ordering_test.dart | f50eb11 | primeaudit/test/screens/audit_execution_ordering_test.dart (created) |
| 2 | Wave 1: Apply sort fix in _load() of audit_execution_screen.dart | 9ec8e0e | primeaudit/lib/screens/audit_execution_screen.dart (modified) |

## What Was Built

### Task 1 — Unit Test (Wave 0)

Created `primeaudit/test/screens/audit_execution_ordering_test.dart` with:
- Self-contained `_FakeItem` class (no import of `TemplateItem` — avoids Supabase init in test environment)
- Pure function `groupAndSort()` helper that mirrors the grouping+sort logic in `_load()`
- 4 test scenarios in one `group`:
  1. Items within a section are sorted by `orderIndex` after grouping
  2. Unsectioned items bucket is sorted by `orderIndex`
  3. Out-of-order insertion is corrected by sort (PostgREST stale cache simulation)
  4. Multiple sections are each sorted independently

### Task 2 — Sort Fix (Wave 1)

Modified the grouping block in `AuditExecutionScreen._load()`:

**Before (buggy):**
```dart
// Associa items às seções
final itemsBySection = <String?, List<TemplateItem>>{};
for (final item in items) {
  itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
}
for (final s in sections) {
  s.items = itemsBySection[s.id] ?? [];
}

// Items sem seção ficam numa seção fictícia "Geral"
final unsectioned = itemsBySection[null] ?? [];
```

**After (fixed):**
```dart
// Associa items às seções — preserva sort por order_index dentro de cada bucket.
// PostgREST já devolve a lista plana ordenada por order_index, mas o
// `putIfAbsent + add` distribui os itens em buckets preservando a ordem
// de iteração (não a ordem relativa por seção). O sort explícito abaixo
// garante que cada bucket esteja ordenado por orderIndex — fix TMPL-01.
final itemsBySection = <String?, List<TemplateItem>>{};
for (final item in items) {
  itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
}
for (final s in sections) {
  final bucket = itemsBySection[s.id] ?? [];
  bucket.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  s.items = bucket;
}

// Items sem seção ficam numa seção fictícia "Geral"
final unsectioned = itemsBySection[null] ?? [];
unsectioned.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
```

**Root cause:** `putIfAbsent + add` distributes items into per-section buckets in the order they are iterated from the flat `items` list. Even though PostgREST returns items ordered by `order_index`, that order is global across all sections — when distributed into per-section buckets, the relative order within each bucket depends on which items appeared first in the global list, not on their individual `orderIndex` values relative to other items in the same section. The explicit `.sort()` after grouping corrects this.

## Verification Results

- `flutter analyze lib/screens/audit_execution_screen.dart` → `No issues found!`
- `flutter test test/screens/audit_execution_ordering_test.dart` → `+4: All tests passed!`
- `flutter test` (full suite) → `+153 ~2: All tests passed!` (exit code 0)

## TMPL-01 Wave 0 Gap: CLOSED

The Wave 0 test gap for TMPL-01 is now closed:
- `primeaudit/test/screens/audit_execution_ordering_test.dart` exists and runs
- 4 tests cover: section bucket sort, unsectioned bucket sort, out-of-order correction, multi-section independence
- Test is pure function — no Supabase, no widget infrastructure required

## Deviations from Plan

None — plan executed exactly as written. The test file contains 4 tests (the plan specified "3 cenarios obrigatorios + 1 extra de multiplas secoes"), which matches the plan's acceptance criteria of `>= 3` tests.

## Threat Surface Scan

No new security surface introduced. This plan modifies only in-memory sort logic in `_load()`. No new network endpoints, no new auth paths, no schema changes. Consistent with the threat model in the plan (T-06-01-04: accept, RLS unaffected).

## Self-Check: PASSED

- [x] `primeaudit/test/screens/audit_execution_ordering_test.dart` — file exists
- [x] commit `f50eb11` — exists in git log
- [x] commit `9ec8e0e` — exists in git log
- [x] `flutter test` exit 0 — 153 tests passed
- [x] `flutter analyze` — No issues found
