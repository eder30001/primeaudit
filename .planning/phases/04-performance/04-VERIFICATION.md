---
phase: 04-performance
verified: 2026-04-18T00:00:00Z
status: human_needed
score: 4/4
overrides_applied: 0
human_verification:
  - test: "Confirm batch upsert is not blocked by RLS for adm and superuser roles"
    expected: "An authenticated user with role adm or superuser who calls reorderItems (via Supabase Dashboard or a real device session) sees template_items updated — PostgREST accepts the batch upsert without a 403 or RLS violation error"
    why_human: "RLS policy correctness requires a live Supabase session; flutter test cannot authenticate against a real Supabase instance. The Phase 2 migrations added RLS to template_items, and the batch upsert uses upsert semantics (ON CONFLICT DO UPDATE) rather than plain UPDATE, which some RLS policies treat differently. This cannot be verified statically."
---

# Phase 4: Performance — Verification Report

**Phase Goal:** Eliminar o N+1 em AuditTemplateService.reorderItems() — PERF-01 satisfied
**Verified:** 2026-04-18T00:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `AuditTemplateService.reorderItems()` does not contain `await` inside a `for` loop — sequential loop replaced by batch operation | VERIFIED | Lines 211–218 of `audit_template_service.dart`: the only `for` in the method body is a collection-for expression inside a list literal (`[for (int i ...) {...}]`), not a statement-level `for { await }` block. Old `.update({'order_index'` pattern confirmed absent by grep (0 matches). |
| 2 | Reordering N items emits at most 1 query to Supabase | VERIFIED | Single `await _client.from('template_items').upsert(payload)` at line 217. No other Supabase calls in the method. Guard clause `if (ids.isEmpty) return;` prevents any query on empty input — 0 queries for that case. |
| 3 | Payload construction logic ({id, order_index} ascending) is covered by unit tests for empty, single, and multiple lists | VERIFIED | `audit_template_service_reorder_test.dart` defines `buildReorderPayload` (line 12) and calls it in 4 tests: empty list (line 22), 1 item (line 26), 3 items (lines 32–35), 20 items (lines 39–44). `AuditTemplateService()` is never instantiated (grep: 0 matches). PERF-01 referenced in header comment and group name. |
| 4 | Visual reordering behavior in template builder continues working | VERIFIED (vacuous) | Grep across all Dart files in `primeaudit/` confirms `reorderItems` has exactly 0 call sites outside its own definition and test. The method signature `Future<void> reorderItems(List<String> ids)` is unchanged — no caller breakage possible. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `primeaudit/lib/services/audit_template_service.dart` | `reorderItems()` batch upsert implementation containing `upsert(payload)` | VERIFIED | File exists (219 lines). `reorderItems` at lines 207–218 contains `upsert(payload)` (line 217). Method is substantive — full service class with 9 methods. No stubs. |
| `primeaudit/test/services/audit_template_service_reorder_test.dart` | Unit tests for reorderItems payload construction (PERF-01) containing `buildReorderPayload` | VERIFIED | File exists (48 lines). `buildReorderPayload` defined once and called 4 times (5 occurrences total — meets plan acceptance criterion of >=5). `order_index` referenced 8 times. PERF-01 in header and group. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `audit_template_service.dart` | Supabase PostgREST (`template_items` table) | `.upsert(payload)` single call | VERIFIED | `upsert(payload)` found at line 217 inside `reorderItems`. Pattern match: `upsert\(payload\)` — 1 occurrence. |
| `audit_template_service_reorder_test.dart` | Payload construction logic | `buildReorderPayload(...)` helper | VERIFIED | `buildReorderPayload([` called 4 times in test bodies. Pattern match: `buildReorderPayload\([` — matches lines 22, 26, 32, 41. |

### Data-Flow Trace (Level 4)

Not applicable. `reorderItems` is a write-only method (no rendered output) — it sends data to Supabase and returns `void`. Level 4 data-flow tracing applies to rendering paths; this method has no render artifact to trace.

### Behavioral Spot-Checks

Step 7b: SKIPPED — `reorderItems` requires a live Supabase connection to execute; no local-only runnable entry point exists for this specific behavior. Static checks (Step 3) confirm the implementation is correct at the code level.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| PERF-01 | 04-01-PLAN.md | `AuditTemplateService.reorderItems()` uses batch update (single query) instead of N sequential queries per item | SATISFIED | Implementation confirmed: single `.upsert(payload)` call, no loop with sequential awaits. REQUIREMENTS.md traceability table maps PERF-01 to Phase 4 (currently marked "Pending" — requires manual update to "Complete" after human verification passes). |

**Orphaned requirements check:** REQUIREMENTS.md maps only PERF-01 to Phase 4. The plan claims PERF-01. No orphaned requirements.

**Note on REQUIREMENTS.md status:** PERF-01 is marked `[ ]` (Pending) in REQUIREMENTS.md and the traceability table shows "Pending". The plan's final success criterion states "PERF-01 marked complete in REQUIREMENTS.md after phase verification." This should be updated to `[x]` and "Complete" once human verification passes.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | — |

Scanned both modified files for: TODO/FIXME/placeholder comments, `return null`, `return []`, `return {}`, empty implementations, hardcoded empty state, console.log-only handlers. None found. The `if (ids.isEmpty) return;` guard returns early from a write-method with no payload — this is a correct defensive pattern, not a stub.

### Human Verification Required

#### 1. RLS Compatibility — Batch Upsert on template_items

**Test:** Using a real Supabase session (Supabase Dashboard Table Editor, a device running the app, or a Supabase client script), authenticate as a user with role `adm` (or `superuser`) and call `reorderItems` with a list of 3+ valid `template_items` IDs belonging to their company. Alternatively, issue a batch upsert directly via the PostgREST API:

```
POST /rest/v1/template_items?on_conflict=id
Authorization: Bearer <adm-user-jwt>
Prefer: resolution=merge-duplicates
Content-Type: application/json

[{"id": "<existing-id-1>", "order_index": 0}, {"id": "<existing-id-2>", "order_index": 1}]
```

**Expected:** HTTP 200/204 returned. The `order_index` values in the database are updated. No RLS violation error (403 or PostgREST 42501).

**Why human:** The Phase 2 migrations added RLS policies to `template_items` (02-02-PLAN.md). The batch upsert uses `ON CONFLICT (id) DO UPDATE` semantics, which some RLS policies distinguish from plain `UPDATE`. This distinction cannot be verified by `flutter test` since tests run without a real Supabase connection. The PLAN explicitly deferred this check to VALIDATION.md "Manual-Only Verifications."

---

### Gaps Summary

No automated gaps found. All 4 truths are verified against the actual codebase. The implementation exactly matches the planned approach: collection-for list literal, single `upsert(payload)` call, empty-list guard, no internal try/catch, unchanged public signature, and a properly isolated test file with 4 passing tests.

One item requires human confirmation: RLS policy compatibility with batch upsert semantics on `template_items`. This is a deployment-time verification that cannot be resolved statically.

---

_Verified: 2026-04-18T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
