---
phase: 10
slug: calendar-dashboard
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-29
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` SDK (built-in, no extra packages) |
| **Config file** | none — default flutter test runner |
| **Quick run command** | `flutter test test/services/calendar_data_test.dart test/screens/audits_screen_date_filter_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/services/calendar_data_test.dart test/screens/audits_screen_date_filter_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| cal-bucketing | Plan 01 Task 0 | 2 | CAL-01 | — | Auditor sees only own audits in calendar data | unit | `flutter test test/services/calendar_data_test.dart` | ❌ W0 | ⬜ pending |
| cal-status-groups | Plan 01 Task 0 | 2 | CAL-01 | — | cancelada excluded; novas/atrasadas/concluidas correct | unit | `flutter test test/services/calendar_data_test.dart` | ❌ W0 | ⬜ pending |
| cal-month-filter | Plan 01 Task 0 | 2 | CAL-01 | — | Audits outside target month excluded from _calendarData | unit | `flutter test test/services/calendar_data_test.dart` | ❌ W0 | ⬜ pending |
| cal-null-audit | Plan 01 Task 0 | 2 | D-03 | — | Audit with both deadline=null and createdAt=null excluded | unit | `flutter test test/services/calendar_data_test.dart` | ❌ W0 | ⬜ pending |
| cal-utc-local | Plan 01 Task 0 | 2 | CAL-01 | — | UTC datetime bucketed to correct local day | unit | `flutter test test/services/calendar_data_test.dart` | ❌ W0 | ⬜ pending |
| audits-date-filter | Plan 01 Task 0 | 2 | CAL-02 | — | filterDate keeps only same-day audits in _filtered | unit | `flutter test test/screens/audits_screen_date_filter_test.dart` | ❌ W0 | ⬜ pending |
| audits-filter-clear | Plan 01 Task 0 | 2 | CAL-02 | — | Clearing _activeDateFilter restores all audits | unit | `flutter test test/screens/audits_screen_date_filter_test.dart` | ❌ W0 | ⬜ pending |
| drawer-removal | Plan 01 Task 1 | 2 | CAL-03/D-08 | — | N/A — drawer item removed | manual | grep 'Relatórios' primeaudit/lib/screens/home_screen.dart | ✅ (grep) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `primeaudit/test/services/calendar_data_test.dart` — covers CAL-01 (bucketing, status groups, month filter, UTC pitfall, D-03 null exclusion) — created by **Plan 01 Task 0**
- [ ] `primeaudit/test/screens/audits_screen_date_filter_test.dart` — covers CAL-02 (date filter in `_filtered`, chip clear behavior via mutable `_activeDateFilter`) — created by **Plan 01 Task 0**

*Note: Both test files are new (do not exist yet). They are scheduled in Plan 01 Task 0 (Wave 2, runs after Plan 02).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Calendar grid renders correctly (7-column grid, dots visible) | CAL-01 | Widget test would require full Flutter render context; visual check is faster | Run app on Android emulator; open HomeScreen; verify calendar section appears below KPI cards with month navigation arrows and day grid |
| Tapping a day with audits navigates to AuditsScreen with filter chip | CAL-02 | Navigation integration — widget test complexity > manual verification cost | Tap a day cell with at least one dot indicator; verify AuditsScreen opens showing filter chip "Auditorias de DD/MM/YYYY"; verify only that day's audits are shown |
| "Relatórios" item absent from drawer | CAL-03/D-08 | One-time removal; greppable | `grep -r 'Relatórios' primeaudit/lib/screens/home_screen.dart` → expect no match |
| Month navigation shows correct month name and year | CAL-01 | String formatting — visual check | Tap right arrow 2x; verify month label advances correctly (e.g., "Abril 2026" → "Maio 2026" → "Junho 2026") |
| Today's date circle is accent-colored | CAL-01 | Visual token — no programmatic check | Open HomeScreen; current day cell should have `AppColors.accent` (#2196F3) filled circle |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (both test files assigned to Plan 01 Task 0)
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending execution
