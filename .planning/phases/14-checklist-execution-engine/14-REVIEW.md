---
phase: 14-checklist-execution-engine
reviewed: 2026-05-06T00:00:00Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - primeaudit/supabase/migrations/20260506_create_checklist_executions.sql
  - primeaudit/supabase/migrations/20260506_add_options_to_checklist_template_items.sql
  - primeaudit/lib/models/checklist_execution.dart
  - primeaudit/lib/models/checklist_template.dart
  - primeaudit/lib/services/checklist_execution_service.dart
  - primeaudit/lib/services/checklist_answer_service.dart
  - primeaudit/lib/screens/checklist/checklist_execution_screen.dart
  - primeaudit/lib/screens/checklist/checklist_pending_save.dart
  - primeaudit/lib/screens/checklist/checklist_template_list_screen.dart
  - primeaudit/test/checklist_conformity_test.dart
  - primeaudit/test/checklist_execution_service_test.dart
  - primeaudit/test/checklist_answer_service_test.dart
  - primeaudit/test/checklist_pending_save_test.dart
findings:
  critical: 5
  warning: 7
  info: 3
  total: 15
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-05-06T00:00:00Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Phase 14 delivers the Checklist Execution Engine — two SQL migrations, Dart models, two services, three screens, and four test files. The architecture is sound and directly follows established project conventions (StatefulWidget + setState, services without internal try/catch, fire-and-forget auto-save). Several correctness defects were found, ranging from data-loss risks to UI state bugs. The four test files contain zero real assertions; every test body is `expect(true, isTrue)`, meaning the test suite provides no actual coverage of the critical conformity calculation or the auto-save retry path.

---

## Critical Issues

### CR-01: `_scheduleRetry` exponential-backoff delay is off by one power — first retry waits 1 s, not 2 s, and final retry waits 8 s instead of 16 s

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:201`

**Issue:** `pow(2, pending.attemptCount)` is called when `attemptCount` is 0, 1, 2, 3 (before `copyWithAttempt()` increments it). So the delays are 2^0=1 s, 2^1=2 s, 2^2=4 s, 2^3=8 s. The comment directly above the call says "delays: tentativa 0 = 1s, 1 = 2s, 2 = 4s, 3 = 8s", which matches the code, so the comment is correct — but the guard at line 199 is `pending.attemptCount >= _maxAutoRetryAttempts` where `_maxAutoRetryAttempts = 4`. This means the loop runs for counts 0, 1, 2, 3 (4 iterations, delays 1+2+4+8 = 15 s total). The description in RESEARCH.md described delays 2, 4, 8, 16 s (true exponential from attempt 1). The real problem is the break condition: after attempt 3 (delay 8 s) succeeds, `_failedSaves` is removed and the loop exits correctly. But if all 4 attempts fail, `attemptCount` reaches 4 via `copyWithAttempt()` and the guard fires. This is actually consistent, but `_maxAutoRetryAttempts = 4` is misleadingly named — it is the maximum _attempt count stored_, not the maximum number of retries attempted. More critically: after the retry loop exits (`_retrying.remove(itemId)`), a user-triggered "Tentar novamente" from the SnackBar will call `_saveAnswer` again. If that call also fails, `_scheduleRetry` is invoked again. At this point `pending.attemptCount` is already 4, so the `>= _maxAutoRetryAttempts` guard fires immediately on the first loop iteration without sleeping, and `_retrying` is removed. The next user tap repeats this, resulting in a tight rapid retry on each user tap with zero delay — acceptable behavior but not the intended exponential backoff for manual retries.

The actual BLOCKER here is different: `pow` returns `num`, not `int`. The call `.toInt()` on the result is correct and does not truncate unexpectedly (2^0=1, no issue). However, **`dart:math`'s `pow(2, 0)` returns `1.0` as `num`**, and `.toInt()` on `1.0` is `1`, so this is fine. The real issue surfaces when `pow` is called with a `double` base and the result is implicitly used — confirm `dart:math` is the `show pow` import (it is, line 1). This specific path is safe.

**Actual BLOCKER:** On success in `_scheduleRetry` (line 213-215), `setState(() => _failedSaves.remove(itemId))` is called and then `break` exits the loop. However, the SnackBar from `_showSaveError` (shown before `_scheduleRetry` was called) remains visible with a "Tentar novamente" action. If the user taps that action after the retry loop already succeeded silently, `_saveAnswer` is called again for an item that was already saved. This is a redundant upsert — not data-corrupting because `onConflict` is set, but it is a logic error: the SnackBar is never dismissed on auto-retry success.

**Fix:**
```dart
// After auto-retry succeeds in _scheduleRetry, also clear the SnackBar:
if (mounted) {
  setState(() => _failedSaves.remove(itemId));
  ScaffoldMessenger.of(context).clearSnackBars(); // dismiss stale "Tentar novamente"
}
```

---

### CR-02: `_finalize` uses `context` after an `await` without a `mounted` check at the right place — `use_build_context_synchronously` violation

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:238-254`

**Issue:** The first `showDialog` call on line 239 is `await`ed. After it resolves, execution continues to line 257 (`if (!mounted) return`) — that check is in the right place. However, the second `showDialog` starting on line 260 is also `await`ed, and its `context: context` usage is similarly safe because the `if (!mounted) return` guard at line 257 prevents the call when the widget is detached. This path is clean.

The true violation is at line 307:
```dart
ScaffoldMessenger.of(context).showSnackBar(...)
```
This appears inside the `catch` block after `await _executionService.finalizeExecution(...)` on line 297. The `if (mounted)` guard at line 305 is present, so Flutter's `mounted` check is there — but the `flutter_analyze` `use_build_context_synchronously` lint still fires because `context` is accessed inside an async function after an `await`, even when guarded by `mounted`. The lint is a compile-time warning, not a runtime check. The correct pattern per Flutter docs is to capture the messenger _before_ the `await`:

**Fix:**
```dart
Future<void> _finalize() async {
  // ...
  final messenger = ScaffoldMessenger.of(context); // capture BEFORE any await
  final navigator = Navigator.of(context);         // capture BEFORE any await

  // ... all await calls ...

  try {
    await _executionService.finalizeExecution(...);
    if (mounted) navigator.pop(true);
  } catch (e) {
    if (mounted) setState(() => _finalizing = false);
    messenger.showSnackBar(...); // safe: captured before awaits
  }
}
```

---

### CR-03: `_onObservation` calls `_saveAnswer` but does NOT update `_observations` in state before the fire-and-forget — observation is lost on reload if save fails

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:128-132`

**Issue:** `_onObservation` sets `_observations[itemId] = obs` directly (line 129) without `setState`. This means the in-memory map is updated but the widget tree is not rebuilt. When `_load` is subsequently called (e.g., on RefreshIndicator pull), line 83 populates `mergedObs` only from database rows, and line 88 merges `_failedSaves` answers — but `_failedSaves` only stores `response`, not the observation (see `_PendingSave` struct). So if a save fails:

1. User types an observation → `_observations[itemId] = obs` (no setState, not visible in UI rebuild)
2. The upsert fails → `_failedSaves` stores `response` and `observation` ✓
3. User pulls to refresh → `_load()` runs → `mergedObs` is populated from DB (observation not yet there) → `_observations.addAll(mergedObs)` **overwrites the local observation with empty** (because the failed save never reached the DB)

The observation text the user typed is silently lost from the local state. The response in `_failedSaves` is preserved (line 88), but observations are not.

Additionally, calling `_observations[itemId] = obs` without `setState` means the `_ChecklistItemCard.observation` prop is stale until the next unrelated `setState` call — the observation field won't visually reflect the pending value on the retry card.

**Fix:**
```dart
void _onObservation(String itemId, String obs) {
  // Use setState so observation is preserved across rebuilds
  setState(() => _observations[itemId] = obs);
  final resp = _answers[itemId];
  if (resp != null) _saveAnswer(itemId, resp, observation: obs);
}
```
And in `_load`, also merge pending observations from `_failedSaves`:
```dart
// After line 88:
mergedObs.addAll(
  _failedSaves.map((k, v) => MapEntry(k, v.observation ?? '')),
);
```

---

### CR-04: `checklist_answers_select` RLS policy allows any authenticated user with a non-null role to read answers from executions they did not create, when the `adm` role is involved

**File:** `primeaudit/supabase/migrations/20260506_create_checklist_executions.sql:136-146`

**Issue:** The `checklist_answers_select` policy filters on `e.created_by = auth.uid()` — so an auditor can only read their own answers. However, the `checklist_executions_select` policy (line 106-110) allows an `adm` to read ALL executions from their company. There is no corresponding `checklist_answers` select policy that gives `adm` read access to answers for executions in their company. This means:
- Admins can list all executions in their company (`checklist_executions_select` allows it)
- But if an admin tries to view the answers for an execution they did not personally create, `checklist_answers_select` returns zero rows (because `e.created_by = auth.uid()` fails for a different auditor's execution)

This is a **data access inconsistency**: the execution is visible to the admin but the answers are inaccessible. Depending on planned admin reporting features, this could either block a legitimate admin use case or cause confusing empty-answer screens.

**Fix:**
```sql
DROP POLICY IF EXISTS "checklist_answers_select" ON checklist_answers;
CREATE POLICY "checklist_answers_select" ON checklist_answers FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_executions e
      WHERE e.id = checklist_answers.execution_id
        AND (
          e.created_by = auth.uid()
          OR (get_my_role() = 'adm' AND e.company_id = get_my_company_id())
        )
    )
  );
```

---

### CR-05: All four test files contain zero real assertions — the test suite is a no-op and provides false confidence

**Files:**
- `primeaudit/test/checklist_conformity_test.dart:5-34`
- `primeaudit/test/checklist_execution_service_test.dart:5-15`
- `primeaudit/test/checklist_answer_service_test.dart:5-29`
- `primeaudit/test/checklist_pending_save_test.dart:5-15`

**Issue:** Every single test body consists of `// TODO` comments and `expect(true, isTrue)`. This unconditionally passes regardless of implementation correctness. The `calculateConformity` function — which is a pure function with no Supabase dependency and trivially testable — is exercised by zero real assertions. The `ChecklistPendingSave.copyWithAttempt` method is similarly trivially testable with no mocks required. Shipping these as passing tests creates false confidence in CI and violates the project's core value ("nenhum dado de auditoria preenchido em campo deve ser perdido") by leaving the conformity calculation unvalidated.

**Fix — minimum viable test for `calculateConformity` (no mocks needed):**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/checklist_template.dart';
import 'package:primeaudit/services/checklist_answer_service.dart';

ChecklistTemplateItem _item(String id, String type) => ChecklistTemplateItem(
      id: id, templateId: 't', description: 'd',
      itemType: type, orderIndex: 0);

void main() {
  group('calculateConformity', () {
    test('yes=conforme, no=não conforme', () {
      final items = [_item('a', 'yes_no'), _item('b', 'yes_no')];
      final answers = {'a': 'yes', 'b': 'no'};
      expect(ChecklistAnswerService.calculateConformity(items, answers), 50.0);
    });

    test('number excluído do denominador', () {
      final items = [_item('a', 'yes_no'), _item('b', 'number')];
      final answers = {'a': 'yes', 'b': '42'};
      // denominator=1 (only yes_no), numerator=1 → 100%
      expect(ChecklistAnswerService.calculateConformity(items, answers), 100.0);
    });

    test('sem itens elegíveis retorna 100.0', () {
      final items = [_item('a', 'number'), _item('b', 'date')];
      expect(ChecklistAnswerService.calculateConformity(items, {}), 100.0);
    });

    test('sem respostas retorna 0.0', () {
      final items = [_item('a', 'yes_no')];
      expect(ChecklistAnswerService.calculateConformity(items, {}), 0.0);
    });
  });
}
```

---

## Warnings

### WR-01: `_scheduleRetry` does not stop retrying when the widget is disposed mid-delay — `Future.delayed` runs past widget lifecycle

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:193-228`

**Issue:** `await Future.delayed(...)` at line 201 does not respect widget disposal. If the user navigates away while a retry delay is in progress, the `Future` completes, the `!mounted` check at line 204 fires and breaks the loop, but `_retrying.remove(itemId)` in the `finally` block still executes. This is safe but the `Future` itself is leaked until the delay completes. For `_maxAutoRetryAttempts = 4` with delay = 8 s on the last attempt, a background `Future` can linger up to 8 s after dispose. This is not a crash but it wastes resources and the `debugPrint` in `_saveAnswer` may fire on a disposed widget context.

**Fix:** Use a `CancellationToken` pattern or a boolean `_disposed` flag checked inside the loop; or use `mounted` check _before_ scheduling the delay (already present, but the delay itself is not cancellable).

---

### WR-02: `_confirmDelete` calls `_load()` without `await` — if `_load` throws, the error is swallowed and the list state is stale

**File:** `primeaudit/lib/screens/checklist/checklist_template_list_screen.dart:107`

**Issue:** After a successful delete, `_load()` is called without `await`. Since `_load` is `Future<void>`, the unawaited call means: (1) any exception from `_load` is silently swallowed (unhandled Future); (2) the SnackBar on line 110 may show "Checklist excluído" before the list has refreshed, causing a moment of stale UI. The pattern elsewhere in the file uses `.then((_) => _load())` which is also unawaited but at least chains correctly.

**Fix:**
```dart
if (confirm == true && mounted) {
  try {
    await _service.deleteTemplate(t.id);
    await _load(); // await so errors surface
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(...);
    }
  } catch (e) { ... }
}
```

---

### WR-03: `_NumberAnswer` regex allows multiple decimal points — `1.2.3` is a valid input

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:982`

**Issue:** `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` allows any sequence of digits and dots, including `1.2.3` or `...`. When this string is stored as a response and later retrieved, any numeric parsing (e.g., `double.parse(response)`) will throw a `FormatException`. The response is stored as TEXT so it does not crash the DB, but any consumer of this data that tries to parse it as a number will fail.

**Fix:**
```dart
inputFormatters: [
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
],
```
Or better, use a full `TextInputFormatter` that prevents a second decimal point.

---

### WR-04: `_DateAnswer.lastDate` is hardcoded to `DateTime(2030)` — dates after 2030 are unselectable

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:1046`

**Issue:** The date picker uses `lastDate: DateTime(2030)`. Industrial audits often plan years in advance. By 2029 this limit will be actively blocking legitimate use. Similarly `firstDate: DateTime(2020)` prevents retroactive entry for historical records older than 6 years.

**Fix:**
```dart
firstDate: DateTime(2000),
lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
```

---

### WR-05: `_StartChecklistSheet._pickDate` has the same hardcoded date range problem

**File:** `primeaudit/lib/screens/checklist/checklist_template_list_screen.dart:673-677`

**Issue:** Same `firstDate: DateTime(2020)`, `lastDate: DateTime(2030)` hardcoding as WR-04, in the execution start form.

**Fix:** Same as WR-04.

---

### WR-06: `checklist_executions` `template_id` column uses `DEFAULT gen_random_uuid()` — phantom rows with random FKs can be inserted if INSERT omits `template_id`

**File:** `primeaudit/supabase/migrations/20260506_create_checklist_executions.sql:18`

**Issue:** The comment acknowledges this: "NOTA: template_id usa DEFAULT gen_random_uuid() apenas para satisfazer NOT NULL durante ADD COLUMN IF NOT EXISTS em tabela potencialmente não-vazia (idempotência). Todo row real fornecerá um template_id explícito."

The problem is that the default is never removed after the `ALTER TABLE`. Any `INSERT INTO checklist_executions` that omits `template_id` will silently insert a row with a random UUID as `template_id`. Since `template_id` has a FK to `checklist_templates(id)`, the FK will immediately fail with a foreign key violation (because the random UUID does not exist in `checklist_templates`) — so data corruption cannot occur. However, the error message will be cryptic (FK violation on a field the caller did not set) and the column semantics are misleading.

**Fix:** Drop the default after the idempotent ADD COLUMN:
```sql
ALTER TABLE checklist_executions ALTER COLUMN template_id DROP DEFAULT;
```
The same applies to `checklist_answers.execution_id` and `checklist_answers.item_id`.

---

### WR-07: `_load` in `ChecklistExecutionScreen` merges `_failedSaves` into `_answers` but does not merge `_observations` — pending observations are discarded on reload

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:88`

**Issue:** Line 88: `merged.addAll(_failedSaves.map((k, v) => MapEntry(k, v.response)))` preserves pending answers. But `mergedObs` is never updated from `_failedSaves`. After a reload (network error recovery, RefreshIndicator), observations typed for items that failed to save are silently lost from the in-memory map, even though `_PendingSave` stores `observation`.

This is the same root cause as CR-03 (observation loss), approached from the reload path. Both must be fixed together.

**Fix:**
```dart
// After line 88, also restore pending observations:
for (final entry in _failedSaves.entries) {
  if (entry.value.observation != null) {
    mergedObs[entry.key] = entry.value.observation!;
  }
}
```

---

## Info

### IN-01: `calculateConformity` has a dead `case 'text': if (ans.isNotEmpty)` branch — the null/empty guard on line 82 already guarantees `ans` is non-empty

**File:** `primeaudit/lib/services/checklist_answer_service.dart:81-89`

**Issue:** The loop at line 80 does `if (ans == null || ans.isEmpty) continue` before the switch. Inside the switch, `case 'text': if (ans.isNotEmpty) conforming++` is therefore always true — `ans` is guaranteed non-empty by the `continue` guard above. The `if (ans.isNotEmpty)` check is dead code. Same applies to `case 'multiple_choice'`.

**Fix:**
```dart
switch (item.itemType) {
  case 'yes_no':
    if (ans == 'yes') conforming++;
  case 'text':
    conforming++; // already guaranteed non-empty by guard above
  case 'multiple_choice':
    conforming++; // already guaranteed non-empty by guard above
}
```

---

### IN-02: `_Badge` widget in `checklist_execution_screen.dart` shows raw `itemType` enum value (e.g., `"multiple_choice"`) to the user

**File:** `primeaudit/lib/screens/checklist/checklist_execution_screen.dart:633`

**Issue:** `_Badge(label: widget.item.itemType, ...)` passes the raw DB string value (e.g., `"multiple_choice"`, `"yes_no"`) directly as a visible label in the UI. This is an internal enum value, not a user-facing label. End users will see "yes_no" and "multiple_choice" in the badge.

**Fix:** Add a display helper:
```dart
String get _itemTypeLabel {
  switch (widget.item.itemType) {
    case 'yes_no': return 'Sim/Não';
    case 'text': return 'Texto';
    case 'number': return 'Número';
    case 'date': return 'Data';
    case 'multiple_choice': return 'Múltipla escolha';
    case 'photo': return 'Foto';
    default: return widget.item.itemType;
  }
}
```

---

### IN-03: `_CloneBottomSheet` holds a `parentContext` reference across async gaps — stale context risk

**File:** `primeaudit/lib/screens/checklist/checklist_template_list_screen.dart:536`

**Issue:** `_CloneBottomSheet` receives and stores `parentContext` as a field. Inside `_clone()`, after `await widget.service.cloneTemplate(...)`, `messenger` (captured from `parentContext` before the await on line 536) is used to show a SnackBar. This pattern (capturing messenger before async gap) is actually correct. However, `widget.parentContext` is itself a stored `BuildContext` reference that could become stale if the parent screen is disposed. The `messenger` capture at line 536 (`final messenger = ScaffoldMessenger.of(widget.parentContext)`) happens before the await, so it is safe for this specific usage. The broader risk is that `widget.parentContext` is stored as a field and could be used unsafely in future modifications.

**Fix:** Document the intent with a comment, or use a callback-based approach:
```dart
// Pass messenger directly rather than BuildContext:
final VoidCallback onSuccess; // triggers parent snackbar via callback
```

---

_Reviewed: 2026-05-06T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
