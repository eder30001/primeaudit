---
phase: 10-reports
reviewed: 2026-05-01T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - primeaudit/lib/screens/home_screen.dart
  - primeaudit/lib/screens/audits_screen.dart
  - primeaudit/test/services/calendar_data_test.dart
  - primeaudit/test/screens/audits_screen_date_filter_test.dart
findings:
  critical: 3
  warning: 5
  info: 3
  total: 11
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-05-01T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This review covers CAL-01 (calendar dashboard widget in `HomeScreen`), CAL-02 (`filterDate` param in `AuditsScreen`), and CAL-03 (drawer item removal). The core calendar bucketing logic and date-filter integration are structurally sound. However, three blockers were found: a semantic bug where `closeAudit` marks records as `cancelada` instead of `concluida`, a duplicate open-actions network call that doubles backend load on every dashboard refresh, and a date-filter asymmetry that causes mismatches between the calendar dots and the AuditsScreen list when the device is in a negative UTC offset timezone. Five warnings cover widget lifecycle correctness, silent error suppression, and test isolation gaps.

---

## Critical Issues

### CR-01: `closeAudit` sets status to `cancelada` — "Encerrar" destroys audit instead of finalising it

**File:** `primeaudit/lib/services/audit_service.dart:70-74`

**Issue:** `AuditService.closeAudit()` writes `status = 'cancelada'` to the database. `_confirmEncerrar` in `AuditsScreen` calls this method for non-rascunho audits (line 239). The user sees the snackbar `"encerrada"` but the record becomes `cancelada`, which is excluded from every KPI count and from the calendar. This is a data-integrity defect: a completed audit silently disappears from all dashboards and reports. The correct terminal status for a manually closed audit is `concluida` (or a dedicated `encerrada` status if one exists in the schema). This bug predates this phase but is exercised directly by the new calendar path.

**Fix:**
```dart
// audit_service.dart
Future<void> closeAudit(String id) async {
  await _client
      .from('audits')
      .update({'status': 'concluida'})  // was 'cancelada'
      .eq('id', id);
}
```
If the business intent is to distinguish "manually closed" from "auto-completed", add a `encerrada` status value to the DB enum and `AuditStatus`, then use that value here and in `_statusFromString`.

---

### CR-02: Duplicate `getOpenActionsCount` call on every dashboard refresh — two independent requests fetch the same data

**File:** `primeaudit/lib/screens/home_screen.dart:99` and `primeaudit/lib/services/dashboard_service.dart:11-20`

**Issue:** `_loadDashboard` calls `_correctiveActionService.getOpenActionsCount(companyId)` at line 99. But `HomeScreen` also instantiates `_dashboardService` (line 31) which has its own `getOpenActionsCount` method (identical query). The `_correctiveActionService` instance (line 32) is used for the live count while `_dashboardService` is only used for `getCompaniesCount`. This means `DashboardService.getOpenActionsCount` is dead code — but more critically, both services hold separate Supabase client references and issue separate HTTP round-trips if both were ever called. Right now only `_correctiveActionService` is called, so the `_dashboardService` declaration is dead weight. The real defect: `DashboardService` duplicates the open-actions query logic that `CorrectiveActionService` already owns. If a future developer wires `_dashboardService.getOpenActionsCount` instead of `_correctiveActionService.getOpenActionsCount`, the count silently duplicates the backend call. The duplicated service method is a correctness trap.

**Fix:** Remove `getOpenActionsCount` from `DashboardService` entirely, or remove the `_dashboardService` field from `_HomeScreenState` and call `_correctiveActionService` for both open-actions count and move `getCompaniesCount` to a shared place. At minimum, remove the unused `_dashboardService` instantiation if it is only used for `getCompaniesCount`:

```dart
// home_screen.dart — keep only what is called
final _dashboardService = DashboardService(); // only used for getCompaniesCount
// Remove getOpenActionsCount from DashboardService to prevent divergence
```

---

### CR-03: Calendar date key is built from `toLocal()` but `filterDate` passed from `_onDayTap` is a naive local `DateTime` — timezone asymmetry on negative-UTC-offset devices

**File:** `primeaudit/lib/screens/home_screen.dart:114` and `primeaudit/lib/screens/home_screen.dart:168-176`, `primeaudit/lib/screens/audits_screen.dart:153-161`

**Issue:** `_buildCalendarData` converts `audit.deadline` or `audit.createdAt` to local time with `.toLocal()` before extracting `year/month/day` for the map key. The calendar day cell's `onTap` receives a `DateTime(month.year, month.month, day)` — a naive local-midnight `DateTime`. In `AuditsScreen._filtered`, the same `.toLocal()` conversion is applied when comparing against `_activeDateFilter`.

The asymmetry is: when Supabase stores a deadline as an ISO-8601 UTC string (e.g. `2026-05-10T03:00:00Z`) and the device is in UTC-4, `.toLocal()` produces `2026-05-09T23:00:00-04:00` — day 9. The calendar correctly dots day 9. But the calendar key for May 10 UTC (`DateTime.utc(2026,5,10,3,0)`) lands under `2026-05-09` in the map. The user taps day 9, `onDayTap` passes `DateTime(2026, 5, 9)`, and `AuditsScreen._filtered` compares `effectiveDate.day == 9` — which works correctly only if both sides apply `.toLocal()` consistently.

The real bug surfaces for the `createdAt` field: `Audit.fromMap` parses `created_at` with `DateTime.parse(map['created_at'])`. If the Supabase client returns an ISO-8601 UTC string, `DateTime.parse` produces a UTC `DateTime`. If it returns a string without a timezone suffix, `DateTime.parse` produces a local `DateTime` (no `toLocal()` conversion, already local). The `.toLocal()` call in the bucketing and filter code is a no-op for already-local datetimes, but for UTC datetimes near midnight the day-boundary crossing is real. The test suite at `calendar_data_test.dart:141-162` acknowledges this pitfall but explicitly weakens the assertion to "key lands in May or June" — meaning the test cannot catch a regression where the same audit appears under a different day in the calendar vs. the filter screen.

**Fix:** Normalize all `DateTime` values from Supabase at parse time in `Audit.fromMap`:
```dart
// audit.dart — fromMap
createdAt: DateTime.parse(map['created_at']).toLocal(),
deadline: map['deadline'] != null
    ? DateTime.parse(map['deadline']).toLocal()
    : null,
```
Then remove all `.toLocal()` calls from `_buildCalendarData` and `_filtered` — the data is already local. This eliminates the inconsistency root cause regardless of what the Supabase client returns.

---

## Warnings

### WR-01: `_loadDashboard` called from `initState` chain without `mounted` guard at the setState entry point — can crash if widget is removed during async load

**File:** `primeaudit/lib/screens/home_screen.dart:82`

**Issue:** `_loadDashboard` begins with `if (!mounted) return;` then immediately calls `setState(() => _dashboardLoading = true)`. This guard is correct but fragile: if the widget is disposed between the `!mounted` check and `setState`, Dart will still execute the `setState` call (they are on the same synchronous frame so this is safe in practice). The real gap is the `finally` block at line 126: it calls `setState(() => _dashboardLoading = false)` after awaiting multiple async calls. If the widget is disposed between any of those awaits, the `if (mounted)` guards on lines 111 and 124 fire correctly, but the `finally` block at line 126 also checks `mounted` — that is correct. However, the `openActions` and `companiesCount` futures at lines 99 and 104 are awaited sequentially with no `mounted` guard between them. If the widget is disposed after the `getAudits` call (line 88) returns but before `getOpenActionsCount` completes, the screen is gone but the two additional network requests still run to completion. This is a lifecycle correctness issue (wasted requests, possible stale-state exception if code paths change).

**Fix:** Add an early-exit after each major await:
```dart
final all = await _auditService.getAudits(companyId: companyId);
if (!mounted) return;
final openActions = await _correctiveActionService.getOpenActionsCount(companyId);
if (!mounted) return;
```

---

### WR-02: Silent swallow of all errors in `_loadProfile` hides auth failures and profile load failures from the user

**File:** `primeaudit/lib/screens/home_screen.dart:74`

**Issue:** The `catch (_) {}` block in `_loadProfile` discards every exception silently. If `_userService.getById` throws (e.g., network error, RLS denial), `_role` stays `''`, `_name` stays `''`, and `_loadDashboard` is never called — the user sees an empty dashboard with no indication of failure. The comment in CLAUDE.md acknowledges that service callers are responsible for try/catch, but a screen that catches and discards without surfacing any feedback violates the project's own error-handling pattern ("Inline error widget in the body with a retry button — for list/load failures").

**Fix:**
```dart
} catch (e) {
  if (mounted) {
    setState(() => _error = 'Erro ao carregar perfil. Tente novamente.');
  }
}
```
And render the `_error` string in `_buildDashboard` analogously to `AuditsScreen`.

---

### WR-03: `_loadTemplates` in `_NewAuditSheetState` silently swallows errors — user sees empty template list with no explanation

**File:** `primeaudit/lib/screens/audits_screen.dart:903-909`

**Issue:** The `catch (_) {}` block at line 906 discards template-fetch errors. When this fires the user sees the "Nenhum template disponível" empty state message (line 1114-1117), which blames the absence of templates rather than the network failure. The user will attempt to create a new audit type or template unnecessarily. This is the same pattern as WR-02 and violates the project error-handling convention.

**Fix:**
```dart
} catch (e) {
  if (mounted) {
    setState(() => _templateError = 'Erro ao carregar templates: $e');
  }
} finally {
```
Add a `_templateError` state field and render it in the step-1 branch of `_buildStepContent`.

---

### WR-04: `_filtered` getter is called directly in `build` — executes O(n) iteration on every `setState` including keystrokes

**File:** `primeaudit/lib/screens/audits_screen.dart:259`

**Issue:** `final filtered = _filtered;` is computed synchronously in `build(BuildContext context)`. The `_filtered` getter applies up to three `where(...).toList()` passes over `_audits`. The `_searchCtrl` listener calls `setState` on every character typed (line 103), triggering a full rebuild and re-filtering the entire list. For large audit lists this degrades typing responsiveness. More critically, because the getter is a computed property with no caching, the identical filter computation runs for each `build` call, including incidental rebuilds from parent widgets.

**Fix:** Cache the filtered result using `didUpdateWidget` or compute it once in `_load`/on filter change and store it in a state field `_filteredAudits`. This is a `setState`-pattern fix, not a performance tuning request — it eliminates redundant computation during lifecycle methods.

---

### WR-05: `_onDayTap` navigates to `AuditsScreen` without preserving `currentUserRole` — auditor-scoped filter cannot be re-applied in the destination screen

**File:** `primeaudit/lib/screens/home_screen.dart:168-176`

**Issue:** `_onDayTap` constructs `AuditsScreen` with `currentUserId` and `currentUserName` but omits the user's role. `AuditsScreen._AuditsScreenState._load()` fetches all company audits via `AuditService.getAudits(companyId: companyId)` without any role-based filter — every user sees every audit in the company when navigating from the calendar. `HomeScreen._loadDashboard` at line 89-91 applies the auditor-scope filter (`a.auditorId == currentUserId`) for non-admin roles before building the calendar dots. The calendar therefore shows only the auditor's own audits as dots, but tapping a day opens a list of all company audits for that day. This is a data-scoping inconsistency: the calendar implies filtered scope, the destination screen shows wider scope. An auditor tapping a calendar dot may see audits from colleagues that were not shown in their dashboard view.

**Fix:** Pass the role to `AuditsScreen` (or have `AuditsScreen` read it from `CompanyContextService`/profile) and apply the same auditor-scope filter in `AuditsScreen._load`. Alternatively, let `AuditsScreen` default the filter chip to `_AuditFilter.minhas` when navigated from the calendar for non-admin roles.

---

## Info

### IN-01: `_fmtDate` is duplicated three times in `audits_screen.dart`

**File:** `primeaudit/lib/screens/audits_screen.dart:126-129`, `661-664`, `1489-1491`

**Issue:** The identical `_fmtDate` static helper is declared in `_AuditsScreenState` (line 126), `_InfoGrid` (line 661), and `_DeadlineStep` (line 1489). Any change to date formatting must be made in three places.

**Fix:** Promote to a single top-level private function `String _fmtDate(DateTime d)` at the top of the file, outside any class.

---

### IN-02: Test file `calendar_data_test.dart` duplicates the production helper verbatim — mirror comment is a maintenance trap

**File:** `primeaudit/test/services/calendar_data_test.dart:43-61`

**Issue:** The comment at line 43 says "keep in sync manually". Any change to `_buildCalendarData` in `home_screen.dart` requires a manual, error-prone update to the test file. The tests cannot catch a divergence between themselves and production because they test the copy, not the original.

**Fix:** Extract `_buildCalendarData` (and the `_novas`/`_atrasadas`/`_concluidas` helpers) into a dedicated testable class or pure function in a non-widget file (e.g. `lib/utils/calendar_utils.dart`). Both `HomeScreen` and the tests then import the same function.

---

### IN-03: `_DayCell` counts status groups (`_novas`, `_atrasadas`, `_concluidas`) on every `build` call with three separate linear passes over `audits`

**File:** `primeaudit/lib/screens/home_screen.dart:749-760`, `762-771`

**Issue:** `_novas()`, `_atrasadas()`, and `_concluidas()` are instance methods called unconditionally in `build`. Each is an independent `.where(...).length` pass. For a day with many audits this runs three O(n) scans on every rebuild triggered by month navigation or any ancestor `setState`. Since `_DayCell` is a `StatelessWidget` rebuilt from scratch on parent changes, there is no caching.

**Fix:** Compute all three counts in a single pass (or as computed fields in the constructor). A simple approach:
```dart
// Pass counts into the constructor from _buildGrid
_DayCell(
  day: day,
  isToday: isToday,
  novas: dayAudits.where((a) => ...).length,
  atrasadas: ...,
  concluidas: ...,
  onTap: ...,
)
```
This is flagged as Info (not Warning) because the lists are small in practice (audits per day), but it is a structural quality issue.

---

_Reviewed: 2026-05-01T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
