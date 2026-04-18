---
phase: 03-test-coverage
reviewed: 2026-04-18T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - primeaudit/test/services/audit_answer_service_test.dart
  - primeaudit/lib/services/audit_answer_service.dart
  - primeaudit/lib/screens/audit_execution_screen.dart
  - primeaudit/test/models/app_role_test.dart
  - primeaudit/test/models/audit_test.dart
  - primeaudit/test/models/audit_answer_test.dart
  - primeaudit/test/models/audit_template_test.dart
  - primeaudit/test/models/company_test.dart
  - primeaudit/test/models/app_user_test.dart
  - primeaudit/test/models/perimeter_test.dart
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-18T00:00:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

The review covers the newly written test suite (QUAL-01 through QUAL-04) and the two production source files those tests exercise. The test code itself is well-structured: helpers are isolated, data fixtures are immutable, and edge-case coverage is meaningful. No security issues were found.

Three warnings stand out in production code:

1. `_ScaleButtons` in `audit_execution_screen.dart` will throw a `RangeError` / `FormatException` at runtime if `selected` holds a value outside `'1'`–`'5'` (e.g., a stale DB value that failed to parse).
2. `audit_execution_screen.dart` line 71 casts the third `Future.wait` result to `List` using an untyped `as List`, then accesses `.templateItemId` / `.response` / `.observation` via `as dynamic` — brittle and bypasses Dart's type system.
3. `calculateConformity` in `audit_answer_service.dart` silently accumulates fractional weights for `scale_1_5` with non-integer parse results; `int.tryParse` returns `null` and falls back to `0` without surfacing the bad value to the caller.

Four info items cover missing test scenarios and a dead-code pattern in the UI.

---

## Warnings

### WR-01: `_ScaleButtons` crashes on out-of-range `selected` value

**File:** `primeaudit/lib/screens/audit_execution_screen.dart:1331`

**Issue:** When `selected` is non-null but not a valid integer in `[1, 5]`, `int.parse(selected!)` succeeds but `_labels[int.parse(selected!) - 1]` throws a `RangeError` (e.g., `selected = '0'` or `selected = '6'`). If `int.parse` itself fails (non-numeric string), it throws a `FormatException`. The `selected != null` guard on line 1327 does not protect against these cases. A corrupted or migrated DB value would crash the audit screen with no recovery path.

**Fix:**
```dart
// Replace the unsafe block (lines 1327-1338) with:
if (selected != null) ...[
  final n = int.tryParse(selected!);
  if (n != null && n >= 1 && n <= 5) ...[
    const SizedBox(height: 4),
    Center(
      child: Text(
        _labels[n - 1],
        style: TextStyle(
            fontSize: 11,
            color: _colorFor(n),
            fontWeight: FontWeight.w600),
      ),
    ),
  ],
],
```

---

### WR-02: Untyped `as dynamic` access on `Future.wait` result bypasses type safety

**File:** `primeaudit/lib/screens/audit_execution_screen.dart:71-91`

**Issue:** The third slot of `Future.wait` returns `List<AuditAnswer>` but is captured as `final answers = results[2] as List`. The subsequent loop then uses `final ans = a as dynamic` and accesses `.templateItemId`, `.response`, `.observation` via dynamic dispatch (lines 87-90). This compiles without warnings but will throw a `NoSuchMethodError` at runtime if the `AuditAnswer` model renames any of these fields, and the error will not be caught by the compiler. The fix is trivially available because `AuditAnswer` is already a typed model.

**Fix:**
```dart
// Change line 71:
final answers = results[2] as List<AuditAnswer>;

// Change lines 86-91:
for (final a in answers) {
  _answers[a.templateItemId] = a.response;
  if (a.observation != null) {
    _observations[a.templateItemId] = a.observation!;
  }
}
```

---

### WR-03: `calculateConformity` silently treats unparseable `scale_1_5` values as zero

**File:** `primeaudit/lib/services/audit_answer_service.dart:70`

**Issue:** `int.tryParse(ans) ?? 0` silently substitutes `0` when `ans` is not a valid integer. This means a corrupted answer (e.g., `'ok'` stored in a `scale_1_5` item due to a migration bug) earns zero weight with no indication to the caller. Because `calculateConformity` is `static` and returns a plain `double`, the caller has no way to distinguish "all items scored correctly" from "some items failed to parse and contributed 0." The current test suite does not cover this path.

**Fix:** Two acceptable approaches:
- **Option A (least invasive):** Assert and throw on parse failure, making the bug visible:
  ```dart
  case 'scale_1_5':
    final v = int.tryParse(ans);
    assert(v != null && v >= 1 && v <= 5,
        'Invalid scale_1_5 value: "$ans" for item ${item.id}');
    earned += (v ?? 0) / 5 * item.weight;
  ```
- **Option B (clean):** Add a `bool invalidAnswers` output parameter or return a result object — appropriate if the service is extended for reporting. This is a larger refactor outside phase scope.

---

## Info

### IN-01: Test missing — `calculateConformity` with invalid `scale_1_5` value

**File:** `primeaudit/test/services/audit_answer_service_test.dart`

**Issue:** No test covers the case where `scale_1_5` holds a non-numeric string (e.g., `'ok'`, `'N/A'`). The current fallback returns `0.0` for that item's weight, which is undocumented behavior and directly related to WR-03 above.

**Fix:** Add a test case:
```dart
test('scale_1_5 with non-numeric answer is treated as 0 (parse fallback)', () {
  final items = [_item(responseType: 'scale_1_5', weight: 4)];
  expect(
    AuditAnswerService.calculateConformity(items, {'i1': 'ok'}),
    closeTo(0.0, 0.01),
  );
});
```
This makes the fallback behavior explicit and detectable in CI if the implementation changes.

---

### IN-02: Test missing — `Audit.isOverdue` computed getter is untested

**File:** `primeaudit/test/models/audit_test.dart`

**Issue:** `audit_test.dart` covers `fromMap` parsing and status enum mapping comprehensively, but `Audit.isOverdue` (line 121-125 in `audit.dart`) has three distinct code paths — `status == atrasada`, `deadline before now with status == emAndamento`, and the `false` baseline — none of which are tested. `isOverdue` is a derived getter with a `DateTime.now()` dependency making it time-sensitive.

**Fix:** Add tests for the three paths, using a past/future deadline relative to the test timestamp:
```dart
test('isOverdue true when status is atrasada', () {
  final m = _fullAuditMap()..['status'] = 'atrasada';
  expect(Audit.fromMap(m).isOverdue, isTrue);
});

test('isOverdue true when emAndamento and deadline in the past', () {
  final m = _fullAuditMap()
    ..['status'] = 'em_andamento'
    ..['deadline'] = DateTime(2020, 1, 1).toIso8601String();
  expect(Audit.fromMap(m).isOverdue, isTrue);
});

test('isOverdue false when emAndamento and deadline in the future', () {
  final m = _fullAuditMap()
    ..['status'] = 'em_andamento'
    ..['deadline'] = DateTime(2099, 1, 1).toIso8601String();
  expect(Audit.fromMap(m).isOverdue, isFalse);
});
```

---

### IN-03: `_GuidanceTile` renders the same string regardless of expanded state — dead branch

**File:** `primeaudit/lib/screens/audit_execution_screen.dart:1099`

**Issue:** Both branches of the `_expanded` ternary on line 1099 evaluate to `widget.guidance`. Only `maxLines` and `overflow` differ. This means the `_expanded` state correctly clamps/uncollapse the text visually (via `maxLines: null`), but if `guidance` were ever conditionally trimmed in future, this pattern would silently fail to show the full text. This is dead-code-path logic: the ternary on line 1099 is always `widget.guidance`.

**Fix:** Remove the ternary and use the value directly:
```dart
child: Text(
  widget.guidance,
  maxLines: _expanded ? null : 1,
  overflow: _expanded ? null : TextOverflow.ellipsis,
  ...
),
```

---

### IN-04: `audit_answer_service_test.dart` comment incorrectly states "6 response types" but only 5 are type-switched in `calculateConformity`

**File:** `primeaudit/test/services/audit_answer_service_test.dart:2`

**Issue:** The file header says "All 6 response types" but the switch in `calculateConformity` (and the test file's own groups) covers exactly 5 distinct types: `ok_nok`, `yes_no`, `scale_1_5`, `percentage`, and `text`/`selection` (which share the same branch). The comment is misleading — it counts `text` and `selection` as separate types (correctly so by domain), making the total 6, but there are only 5 `case` branches. The comment should clarify this distinction.

**Fix:** Update the header comment:
```dart
// All 6 response types (text and selection share one branch in calculateConformity)
// + empty list + multi-weight scenarios.
```

---

_Reviewed: 2026-04-18T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
