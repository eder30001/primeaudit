---
phase: 04-performance
reviewed: 2026-04-18T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - primeaudit/lib/services/audit_template_service.dart
  - primeaudit/test/services/audit_template_service_reorder_test.dart
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-18T00:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Two files reviewed: the `AuditTemplateService` (full service, ~220 lines) and the new
`audit_template_service_reorder_test.dart` test file. The PERF-01 fix itself — replacing
the sequential `for + await update` loop with a single batch `upsert` — is correctly
implemented and the method signature is preserved. No critical issues found.

The two warnings are pre-existing in the service and not regressions from this phase:
a data-scoping gap in `getAllTemplates` and unchecked type casts on every query result.
The four info findings cover test design trade-offs and missing negative-path coverage.

---

## Warnings

### WR-01: `getAllTemplates` leaks cross-tenant templates when `companyId` is null

**File:** `primeaudit/lib/services/audit_template_service.dart:72-83`

**Issue:** When `companyId` is `null`, the `OR` filter is skipped entirely and the query
returns **all** rows from `audit_templates` — including company-specific templates for
every tenant. The analogous methods `getTemplates` (line 62-65) and `getTypes` (line
20-21) both apply a `.filter('company_id', 'is', null)` fallback when `companyId` is
absent. The asymmetry means a caller that omits the argument (or passes null at a
superuser prompt before a company is selected) silently receives data it should not see.

**Current code:**
```dart
Future<List<AuditTemplate>> getAllTemplates({String? companyId}) async {
  var query = _client
      .from('audit_templates')
      .select('*, audit_types(name, icon)');

  if (companyId != null) {
    query = query.or('company_id.is.null,company_id.eq.$companyId');
  }
  // ← No else branch: companyId == null → no filter → all rows returned

  final data = await query.order('name');
  return (data as List).map((e) => AuditTemplate.fromMap(e)).toList();
}
```

**Fix:** Add the same `else` fallback present in the other methods:
```dart
  if (companyId != null) {
    query = query.or('company_id.is.null,company_id.eq.$companyId');
  } else {
    query = query.filter('company_id', 'is', null);
  }
```

---

### WR-02: Unsafe `as List` cast on every query result obscures errors

**File:** `primeaudit/lib/services/audit_template_service.dart:24,69,82,126,153`

**Issue:** Every `await query` result is cast with `(data as List)` before calling
`.map(...)`. The PostgREST client in `supabase_flutter` already returns
`List<Map<String, dynamic>>` — the cast is redundant. More critically, if a Supabase
error materializes as a non-list value (e.g., an error object returned when RLS blocks
the query in an unexpected way), the `as List` throws an opaque `TypeError: type ... is
not a subtype of type 'List<dynamic>'` instead of a `PostgrestException`, making
debugging harder. All five occurrences follow the same pattern.

**Example (line 23-24):**
```dart
final data = await query.eq('active', true).order('name');
return (data as List).map((e) => AuditType.fromMap(e)).toList();
```

**Fix:** Remove the redundant cast and let the SDK's return type drive inference. For
the `getTypes` case (and equivalently for the other four):
```dart
final data = await query.eq('active', true).order('name');
return data.map((e) => AuditType.fromMap(e)).toList();
```
The `supabase_flutter` client's `.select()` chain returns `List<Map<String, dynamic>>`
directly; no cast is required. If there is a query error, the SDK throws a
`PostgrestException` which propagates cleanly per project convention.

---

## Info

### IN-01: Test helper is a manual copy of production logic, not the real code under test

**File:** `primeaudit/test/services/audit_template_service_reorder_test.dart:12-17`

**Issue:** `buildReorderPayload` is a local pure function that mirrors the payload
construction inside `reorderItems`. The test comment on line 5 explicitly acknowledges
"Kept in sync manually." If `reorderItems` is changed without updating the test helper,
the tests continue to pass — they test the copy, not the production code. This is
exactly the anti-pattern the test comment warns about.

**Fix (preferred):** Extract the payload-building logic into a package-private or
`@visibleForTesting` static helper directly inside `AuditTemplateService`, then import
it in the test. This makes the test a true regression guard:
```dart
// In audit_template_service.dart:
@visibleForTesting
static List<Map<String, dynamic>> buildReorderPayload(List<String> ids) => [
  for (int i = 0; i < ids.length; i++) {'id': ids[i], 'order_index': i},
];

Future<void> reorderItems(List<String> ids) async {
  if (ids.isEmpty) return;
  await _client.from('template_items').upsert(buildReorderPayload(ids));
}
```

**Fix (minimal, no refactor):** Add a comment on the test group header explicitly
naming the contract being validated (`payload is List<Map> with ascending order_index`)
and add a CI check (e.g., grep assertion in `04-VALIDATION.md`) that the production
body still contains the identical `collection-for` expression. The plan already
documents this in `04-01-PLAN.md` Task 3.

---

### IN-02: No negative-path tests — duplicate IDs, null entries

**File:** `primeaudit/test/services/audit_template_service_reorder_test.dart:19-47`

**Issue:** All four test cases test valid inputs. The method documentation states "IDs
inválidos causam erro de constraint (não silencioso)" but there is no test that verifies
this contract. Duplicate IDs in the list (e.g., `['id-a', 'id-a']`) would produce a
payload with two entries for the same `id`, and the DB upsert would silently overwrite
the first with the second — `order_index` for `id-a` would be 1, not 0. This is a
silent-loss scenario relevant to CLAUDE.md's core value: "nenhum dado de auditoria
preenchido em campo deve ser perdido."

**Fix:** Add at minimum one test that documents the current behavior with duplicate IDs:
```dart
test('duplicate ids: last order_index wins (documents known behavior)', () {
  final payload = buildReorderPayload(['id-a', 'id-a']);
  // Both entries are in the payload; upsert will apply last one (order_index 1).
  expect(payload, equals([
    {'id': 'id-a', 'order_index': 0},
    {'id': 'id-a', 'order_index': 1},
  ]));
});
```
If the intent is to prevent duplicate IDs, add a guard in `reorderItems` before
building the payload:
```dart
assert(ids.length == ids.toSet().length, 'reorderItems: duplicate IDs detected');
```

---

### IN-03: `reorderItems` upsert is not scoped to the template — cross-template corruption is silent

**File:** `primeaudit/lib/services/audit_template_service.dart:211-218`

**Issue:** The upsert payload only contains `{id, order_index}`. There is no
`template_id` field in the payload and no runtime check that all IDs belong to the same
template. A caller that accidentally passes IDs from different templates would silently
update `order_index` values across template boundaries. The UI does not currently have
this caller pattern, but the method's public contract does not document this restriction
beyond "todos os IDs devem existir."

**Fix (defensive, no schema change):** Add a dev-mode assertion to surface
cross-template bugs early:
```dart
Future<void> reorderItems(List<String> ids) async {
  if (ids.isEmpty) return;
  // (Optional) assert ids are from a single source — validated by caller.
  final payload = [
    for (int i = 0; i < ids.length; i++)
      {'id': ids[i], 'order_index': i},
  ];
  await _client.from('template_items').upsert(payload);
}
```
Alternatively, extend the docstring to explicitly state the caller invariant, and add a
test that demonstrates what happens when IDs from two different templates are mixed.

---

### IN-04: `TemplateItem.fromMap` and `AuditTemplate.fromMap` silently fail if `id` is null

**File:** `primeaudit/lib/models/audit_template.dart:32,115` (model, not a file in scope, but called by reviewed service)

**Issue:** `map['id']` is assigned directly to `required String id` without a null
check. All other fields that could be null use `?? fallback` (e.g., `map['weight'] ?? 1`).
If a DB row is missing `id` (schema violation or test fixture error), the resulting
`TypeError` has no diagnostic context — no indication of which table or row caused the
failure. This is a pre-existing issue surfaced while tracing the service's data path.

**Fix:** Add a null-check assertion in the factory for `id` (and `template_id`):
```dart
factory TemplateItem.fromMap(Map<String, dynamic> map) {
  assert(map['id'] != null, 'TemplateItem.fromMap: missing required field "id"');
  return TemplateItem(
    id: map['id'] as String,
    templateId: map['template_id'] as String,
    // ...
  );
}
```

---

_Reviewed: 2026-04-18T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
