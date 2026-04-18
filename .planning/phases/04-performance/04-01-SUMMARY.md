---
phase: 04-performance
plan: "01"
subsystem: services
tags: [performance, n+1, batch-upsert, dart, flutter]
dependency_graph:
  requires: []
  provides: [PERF-01]
  affects: [primeaudit/lib/services/audit_template_service.dart]
tech_stack:
  added: []
  patterns: [batch-upsert, collection-for, pure-function-extraction]
key_files:
  created:
    - primeaudit/test/services/audit_template_service_reorder_test.dart
  modified:
    - primeaudit/lib/services/audit_template_service.dart
decisions:
  - "No onConflict parameter in upsert: PostgREST defaults to PK (id), which is the correct conflict key for template_items"
  - "Empty-list guard added: avoids sending empty array to PostgREST; mirrors defensive patterns used elsewhere in services layer"
  - "No internal try/catch: preserves CLAUDE.md service convention — callers handle exceptions"
  - "Pure helper buildReorderPayload in test file: mirrors payload logic without requiring Supabase initialization"
metrics:
  duration: 1313s
  completed: "2026-04-18"
  tasks_completed: 3
  files_changed: 2
---

# Phase 04 Plan 01: Batch Upsert reorderItems (N+1 fix) Summary

**One-liner:** Eliminated N+1 queries in `AuditTemplateService.reorderItems()` by replacing a sequential `for+await update` loop with a single `.upsert(List<Map>)` batch call — reordering N items now costs 1 round-trip instead of N.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create test scaffold with buildReorderPayload helper and 4 tests | 9a1d7c5 | primeaudit/test/services/audit_template_service_reorder_test.dart (created) |
| 2 | Replace reorderItems with batch upsert (N+1 fix) | 968b603 | primeaudit/lib/services/audit_template_service.dart (modified) |
| 3 | Static verification — absence of sequential anti-pattern | (no commit — verification only, no file changes) | — |

## Implementation Details

### Before (N+1 pattern)

```dart
Future<void> reorderItems(List<String> ids) async {
  for (int i = 0; i < ids.length; i++) {
    await _client
        .from('template_items')
        .update({'order_index': i})
        .eq('id', ids[i]);  // N sequential queries
  }
}
```

### After (batch upsert — 1 query)

```dart
Future<void> reorderItems(List<String> ids) async {
  if (ids.isEmpty) return;
  final payload = [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
  await _client.from('template_items').upsert(payload);  // 1 query
}
```

## Test Results

```
flutter test test/services/audit_template_service_reorder_test.dart
→ 4 tests passed (payload construction: empty list, 1 item, 3 items, 20 items)

flutter test (full suite)
→ 149 tests passed (0 failures, 2 skipped)
```

## Static Verification Results (Task 3)

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| 1: exactly 1 `await _client` in reorderItems | 1 | 1 | PASS |
| 2: collection-for present (not statement for loop) | 1 | 1 | PASS |
| 3: old `.update({'order_index'` pattern gone | 0 | 0 | PASS |
| 4: `upsert` present | 1 | 1 | PASS |
| 5: `flutter test` exits 0 | 0 | 0 | PASS |

Visual confirmation of check 2: the `for (int i` line is inside a list literal `[...]` — it is a collection-for expression, not a statement-level for loop (no `{` follows the expression).

## PERF-01 Success Criteria Verification

1. **`reorderItems()` does not contain `await` inside a `for` loop** — SATISFIED. The statement-level `for+await` loop is gone; only a collection-for inside a list literal remains (no async operation inside the loop).

2. **Reordering N items emits at most 1 query to Supabase** — SATISFIED. A single `.upsert(payload)` call handles all N items in one round-trip.

3. **Visual reordering behavior continues to work** — VACUOUSLY SATISFIED. `reorderItems` has 0 callers in the current UI (confirmed by RESEARCH.md). The public method signature `Future<void> reorderItems(List<String> ids)` is unchanged; future callers will work without modification.

## Analyze Output

```
flutter analyze lib/services/audit_template_service.dart
→ No issues found!
```

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — no stubs, placeholders, or hardcoded empty values introduced.

## Threat Flags

No new security-relevant surface introduced. The change replaces a `.update()` loop with a single `.upsert()` call on the same `template_items` table, under the same RLS policies. No new endpoints, auth paths, or schema changes.

## Self-Check: PASSED

- [x] `primeaudit/test/services/audit_template_service_reorder_test.dart` — FOUND
- [x] `primeaudit/lib/services/audit_template_service.dart` — FOUND (modified)
- [x] Commit 9a1d7c5 — FOUND
- [x] Commit 968b603 — FOUND
- [x] `flutter test` exits 0 (149 tests passed)
- [x] `flutter analyze lib/services/audit_template_service.dart` — No issues found
