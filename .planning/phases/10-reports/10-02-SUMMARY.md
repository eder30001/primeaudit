---
phase: 10-reports
plan: "02"
subsystem: screens
tags: [calendar, date-filter, audits-screen, CAL-02, flutter]
dependency_graph:
  requires:
    - "10-01 (calendar widget in HomeScreen) — provides filterDate navigation trigger"
  provides:
    - "AuditsScreen with optional filterDate constructor param (consumed by 10-01 _onDayTap)"
    - "Dismissible date filter chip UI with in-screen clear"
    - "Date-equality filter in _filtered using deadline ?? createdAt .toLocal()"
  affects:
    - "primeaudit/lib/screens/audits_screen.dart — adds filterDate param; existing callers unaffected (param is optional)"
tech_stack:
  added: []
  patterns:
    - "Mutable state copy of constructor param (_activeDateFilter from widget.filterDate) for in-screen clear without Navigator.pop"
    - "Date-equality filter using .toLocal() to prevent UTC/local day boundary mismatch"
    - "Static _fmtDate on state class for DD/MM/YYYY formatting without intl package"
key_files:
  created:
    - "primeaudit/test/screens/audits_screen_date_filter_test.dart — 6 unit tests for date filter pure logic"
  modified:
    - "primeaudit/lib/screens/audits_screen.dart — filterDate param, _activeDateFilter state, chip, _filtered date step, empty state"
decisions:
  - "Used mutable _activeDateFilter (not widget.filterDate directly) so chip clear stays on screen without Navigator.pop — matches 10-UI-SPEC.md behavior"
  - "Date filter applied as LAST step in _filtered (after status and search filters)"
  - ".toLocal() applied to (a.deadline ?? a.createdAt) to prevent UTC day mismatch near midnight (Pitfall 1 from RESEARCH.md)"
  - "No late modifier on _activeDateFilter — nullable fields need no late"
metrics:
  duration: "14m"
  completed_date: "2026-05-02"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 2
---

# Phase 10 Plan 02: AuditsScreen Date Filter (CAL-02) Summary

**One-liner:** Added optional `DateTime? filterDate` to `AuditsScreen` with mutable `_activeDateFilter` state, dismissible chip showing "Auditorias de DD/MM/YYYY", and `(deadline ?? createdAt).toLocal()` date-equality filter as the last step in `_filtered`.

## What Was Built

`AuditsScreen` now accepts an optional `filterDate` constructor parameter, enabling the calendar (Plan 01) to navigate to it with a pre-applied day filter. The filter is stored as a mutable copy (`_activeDateFilter`) so users can clear it via a chip X button without leaving the screen. All existing callers pass the screen without `filterDate` — fully backward compatible.

### Changes to `primeaudit/lib/screens/audits_screen.dart`

1. **Constructor** — Added `final DateTime? filterDate;` field and `this.filterDate` optional param
2. **State field** — `DateTime? _activeDateFilter;` (no `late` modifier)
3. **initState** — `_activeDateFilter = widget.filterDate;` copies param to mutable state
4. **`_fmtDate` static method** — `DD/MM/YYYY` formatter on `_AuditsScreenState` (no `intl` dependency)
5. **`_filtered` getter** — Date-equality filter as last step using `(a.deadline ?? a.createdAt).toLocal()`
6. **`_buildSearchAndFilters()`** — Dismissible `Chip` with "Auditorias de DD/MM/YYYY" label; `onDeleted` calls `setState(() => _activeDateFilter = null)` (stays on screen)
7. **Empty state text** — Shows "Nenhuma auditoria em DD/MM/YYYY" when `_activeDateFilter != null` and list is empty

### New test file: `primeaudit/test/screens/audits_screen_date_filter_test.dart`

6 tests covering:
- `null filterDate` returns all audits unchanged
- `filterDate` keeps only audits with matching `deadline`
- Falls back to `createdAt` when `deadline` is null
- Excludes audits on different days
- `deadline` takes precedence over `createdAt` (D-03)
- Chip clear (`null` filter) restores full list

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 1a3fa43 | test | TDD RED: audits_screen_date_filter_test.dart (6 tests, CAL-02) |
| a6e79e3 | feat | TDD GREEN: filterDate param, _activeDateFilter, chip, date filter, empty state |

## Deviations from Plan

None — plan executed exactly as written.

The test file was created in this plan (not Plan 01 Task 0 as documented) because Plan 01 is in Wave 2, which runs after Wave 1. Creating the test file here satisfies the TDD RED requirement before implementing the production code.

## TDD Gate Compliance

- RED gate: `test(10-02): add failing tests for AuditsScreen date filter (CAL-02)` — commit 1a3fa43
- GREEN gate: `feat(10-02): add filterDate param and date filter to AuditsScreen (CAL-02)` — commit a6e79e3
- REFACTOR gate: not needed — code was clean on first pass

## Known Stubs

None — all logic is wired. The `filterDate` parameter flows correctly from constructor → `_activeDateFilter` state → `_filtered` getter → UI chip. The empty state message uses the actual `_activeDateFilter` value.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. The `filterDate` is an internal DateTime from a calendar tap; all security analysis from the plan's `<threat_model>` applies (T-10-05, T-10-06, T-10-07 all accepted).

## Self-Check: PASSED

| Item | Status |
|------|--------|
| `primeaudit/lib/screens/audits_screen.dart` | FOUND |
| `primeaudit/test/screens/audits_screen_date_filter_test.dart` | FOUND |
| `.planning/phases/10-reports/10-02-SUMMARY.md` | FOUND |
| Commit 1a3fa43 (test RED) | FOUND |
| Commit a6e79e3 (feat GREEN) | FOUND |
