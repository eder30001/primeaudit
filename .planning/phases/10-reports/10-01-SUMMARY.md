---
phase: 10-reports
plan: "01"
subsystem: screens
tags: [calendar, dashboard, home-screen, CAL-01, CAL-03, flutter, tdd]
dependency_graph:
  requires:
    - "10-02 (Wave 1) — provides AuditsScreen.filterDate param consumed by _onDayTap"
  provides:
    - "HomeScreen calendar section below KPI cards (_CalendarWidget, _DayCell)"
    - "Month navigation re-bucketing from _allAudits — no extra network call"
    - "Drawer Relatorios item removed (CAL-03 / D-08)"
    - "Wave 0 test scaffolds: calendar_data_test.dart (10 tests)"
  affects:
    - "primeaudit/lib/screens/home_screen.dart — 4 new state fields, 5 new methods, 2 new widget classes, drawer change, dashboard column update"
tech_stack:
  added: []
  patterns:
    - "_buildCalendarData pure helper with (deadline ?? createdAt).toLocal() for UTC/local boundary safety (Pitfall 1)"
    - "Month navigation by re-bucketing cached _allAudits list — zero extra network request"
    - "Table-based calendar grid (7 columns, Sunday-first) without external packages"
    - "_monthNames const list for month formatting without intl dependency"
    - "Dot indicators per day: blue=novas, red=atrasadas, green=concluidas (cancelada excluded D-04)"
    - "Reuse _dashboardLoading flag for calendar loading state — no separate flag"
    - "Pure-function extract pattern for unit tests (no Supabase imports in test files)"
key_files:
  created:
    - "primeaudit/test/services/calendar_data_test.dart — 10 unit tests for _buildCalendarData, status groups, D-04, UTC pitfall"
  modified:
    - "primeaudit/lib/screens/home_screen.dart — calendar dashboard integration, drawer Relatorios removal"
decisions:
  - "Used (deadline ?? createdAt).toLocal() consistently in _buildCalendarData — prevents UTC off-by-one date bug near midnight (Pitfall 1 from RESEARCH.md)"
  - "Month navigation re-buckets from cached _allAudits list — avoids second getAudits() call (confirmed anti-pattern from PATTERNS.md)"
  - "cancelada audits excluded via continue branch in _buildCalendarData — D-04 enforced at bucketing stage, not UI stage"
  - "_calendarMonth never assigned inside _loadDashboard setState() — pull-to-refresh preserves user's month navigation position"
  - "Days without audits are not tappable (onTap: null) per D-06 — confirmed decision from CONTEXT.md"
  - "Table widget with FlexColumnWidth for calendar grid — no external package (table_calendar explicitly rejected in UI-SPEC)"
  - "audits_screen_date_filter_test.dart created by Plan 02 (Wave 1) — not re-created in this plan to avoid conflict"
metrics:
  duration: "33m"
  completed_date: "2026-05-02"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 2
---

# Phase 10 Plan 01: Calendar Dashboard (CAL-01, CAL-03) Summary

**One-liner:** Monthly calendar widget embedded in HomeScreen dashboard below KPI cards, with dot indicators (blue/red/green per status), month navigation re-bucketing from cached audit list, and drawer Relatorios item removed.

## What Was Built

### Task 0: Wave 0 test scaffolds

`primeaudit/test/services/calendar_data_test.dart` — 10 unit tests across 4 groups:
- `_buildCalendarData — deadline ?? createdAt bucketing` (4 tests): deadline wins, createdAt fallback, outside-month exclusion, same-day accumulation
- `_buildCalendarData — cancelada exclusion (D-04)` (1 test): cancelada audits never appear
- `_buildCalendarData — UTC to local conversion (Pitfall 1)` (1 test): .toLocal() applied, no crash
- `Status group helpers — novas/atrasadas/concluidas` (4 tests): correct counting, cancelada excluded from all groups

`primeaudit/test/screens/audits_screen_date_filter_test.dart` — already created by Plan 02 (Wave 1). Contains 6 tests covering _applyDateFilter pure logic (CAL-02). No re-creation needed.

### Task 1: Calendar widget in home_screen.dart + drawer removal

Changes to `primeaudit/lib/screens/home_screen.dart`:

1. **4 new state fields** — `_calendarMonth`, `_calendarData`, `_calendarError`, `_allAudits`
2. **`_buildCalendarData()`** — pure helper using `(deadline ?? createdAt).toLocal()` for UTC safety; cancelada excluded via `continue`; keys formatted as `YYYY-MM-DD`
3. **`_prevMonth()` / `_nextMonth()`** — re-bucket `_allAudits` in setState; zero extra network calls
4. **`_onDayTap(DateTime)`** — navigates to `AuditsScreen(filterDate: date)` (Plan 02 param)
5. **`_buildCalendar()`** — guard: shows CircularProgressIndicator during load, error text on failure, delegates to `_CalendarWidget`
6. **`_loadDashboard()`** — integrated calendar bucketing after role-scoping; `_allAudits`, `_calendarData`, `_calendarError = null` added to setState; catch sets `_calendarError`; `_calendarMonth` is NOT assigned in _loadDashboard setState (preserves month navigation on refresh)
7. **`_buildDashboard()`** — calendar section appended after KPI row 2: title "Calendário de Auditorias" + `_buildCalendar()`
8. **Drawer** — `_drawerItem(title: 'Relatórios')` block removed entirely (D-08)
9. **`_CalendarWidget`** — StatelessWidget with month nav header, Dom-Sab weekday row, `Table`-based day grid (7 columns, Sunday-first via `_firstWeekdayOffset`)
10. **`_DayCell`** — StatelessWidget with today accent circle, dot indicators (6px colored circles), GestureDetector only when dayAudits is non-empty

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 2f92617 | test | TDD RED: calendar_data_test.dart Wave 0 scaffold (CAL-01, D-03, D-04) |
| 4c9003a | feat | TDD GREEN: calendar dashboard in HomeScreen + drawer Relatorios removal |

## Deviations from Plan

**1. [Rule 0 - Expected] audits_screen_date_filter_test.dart already existed**
- **Found during:** Task 0 setup
- **Issue:** The plan describes creating `audits_screen_date_filter_test.dart` as part of Task 0, but Plan 02 (Wave 1) already created this file with 6 tests covering all required groups.
- **Fix:** Verified the existing file contains all required groups (`_filtered date filter — keeps only same-day audits (CAL-02)`, `_filtered date filter — clear filter (chip onDeleted)`). No re-creation needed. The file is already correct and passing.
- **Impact:** None — acceptance criteria met by the pre-existing file.

This was expected per the wave note in the plan frontmatter: "Plan 01 Task 0 adds two test files — but audits_screen_date_filter_test.dart was created by Plan 02 to satisfy TDD RED before GREEN in Wave 1."

## Known Stubs

None — all logic is wired. The calendar data flows from `_loadDashboard()` → `_buildCalendarData()` → `_calendarData` state → `_CalendarWidget` → `_DayCell`. Month navigation flows through `_prevMonth()`/`_nextMonth()` → `_buildCalendarData(_allAudits, ...)` → `_calendarData`. Day taps flow through `_onDayTap()` → `AuditsScreen(filterDate: date)`.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. Analysis matches the plan's threat_model:
- T-10-01 (auditor role scoping): `_allAudits` populated from already-scoped `audits` list in `_loadDashboard()` — auditors cannot see other users' audits via calendar.
- T-10-02 (cancelada exclusion): `continue` branch in `_buildCalendarData` enforces D-04. Verified by unit test group 'cancelada exclusion (D-04)'.
- T-10-03 (filterDate tampering): `filterDate` is a `DateTime` from calendar cell tap — not user text input.

## TDD Gate Compliance

- RED gate: `test(10-01): add calendar_data_test.dart Wave 0 scaffold` — commit 2f92617
- GREEN gate: `feat(10-01): calendar dashboard in HomeScreen + drawer Relatorios removal` — commit 4c9003a
- REFACTOR gate: not needed — code was clean on first pass

## Self-Check: PASSED

| Item | Status |
|------|--------|
| `primeaudit/test/services/calendar_data_test.dart` | FOUND |
| `primeaudit/test/screens/audits_screen_date_filter_test.dart` | FOUND (created by Plan 02) |
| `primeaudit/lib/screens/home_screen.dart` | FOUND (modified) |
| `.planning/phases/10-reports/10-01-SUMMARY.md` | FOUND |
| Commit 2f92617 (test RED) | FOUND |
| Commit 4c9003a (feat GREEN) | FOUND |
| `grep -c "Relatórios" home_screen.dart` = 0 | PASSED |
| `grep -c "_CalendarWidget" home_screen.dart` > 0 | PASSED (3 occurrences) |
| `grep -c "_buildCalendarData" home_screen.dart` > 0 | PASSED (4 occurrences) |
| `grep -c "toLocal" home_screen.dart` > 0 | PASSED (1 occurrence) |
| `flutter test` full suite | PASSED (247 tests) |
| `flutter analyze lib/screens/home_screen.dart` | PASSED (no issues) |
