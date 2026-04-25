---
phase: 07-dashboard
plan: "02"
subsystem: dashboard
tags: [fl_chart, dashboard, kpi, pull-to-refresh, conformity-chart, home-screen]
dependency_graph:
  requires:
    - primeaudit/lib/services/dashboard_service.dart (DashboardService — from 07-01)
    - primeaudit/pubspec.yaml (fl_chart 1.2.0 — from 07-01)
  provides:
    - primeaudit/lib/screens/home_screen.dart (functional dashboard with real KPIs, pull-to-refresh, conformity chart)
  affects:
    - primeaudit/lib/screens/home_screen.dart (replaces static placeholder with live data)
tech_stack:
  added: []
  patterns:
    - RefreshIndicator + AlwaysScrollableScrollPhysics pattern (RESEARCH.md Pitfall 4)
    - Dart-side auditor scope filter (D-05/D-06) — all.where auditorId == currentUserId
    - AppRole.isSuperOrDev guard for Empresas card (D-07, NOT canAccessAdmin)
    - fl_chart BarChart with rotationQuarterTurns:1 for horizontal bars
    - _dashboardLoading '...' guard for loading state per card
key_files:
  created: []
  modified:
    - primeaudit/lib/screens/home_screen.dart
decisions:
  - "Used AppRole.isSuperOrDev (NOT canAccessAdmin) for Empresas card — adm role correctly excluded (D-07)"
  - "Ações abertas card always renders for non-superuser (never hidden) — value 0 until Phase 8"
  - "Error state replaces chart section only (not entire dashboard) — KPI cards still show last known values"
  - "_buildChartData and _TemplateConformity kept in home_screen.dart (file-scoped) — no new service needed for pure Dart aggregation"
  - "_loadDashboard chained inside _loadProfile try block after setState sets _role — role is guaranteed set before dashboard query runs"
metrics:
  duration: "~3 minutes"
  completed: "2026-04-25"
  tasks_completed: 2
  tasks_total: 2
  files_created: 0
  files_modified: 1
requirements:
  - DASH-01
  - DASH-02
  - DASH-03
---

# Phase 7 Plan 02: Dashboard UI Implementation Summary

**One-liner:** `home_screen.dart` dashboard replaced from static placeholders to live KPI cards (role-scoped), pull-to-refresh via RefreshIndicator, and fl_chart horizontal bar chart for conformity by template.

## What Was Built

### Task 1: Wire data layer (commit 7bc4e13)

Added to `primeaudit/lib/screens/home_screen.dart`:

- Imports: `fl_chart`, `supabase_flutter`, `audit.dart`, `audit_service.dart`, `dashboard_service.dart`
- Service instances: `_auditService = AuditService()`, `_dashboardService = DashboardService()`
- State fields: `_totalAudits`, `_pendingAudits`, `_overdueAudits`, `_openActions`, `_companiesCount`, `_chartData`, `_dashboardLoading`, `_dashboardError`
- `_loadDashboard()` method — fetches audits, applies Dart-side auditor filter (D-05), computes KPI counts, calls `getOpenActionsCount` (Phase 8 fallback) and `getCompaniesCount` (isSuperOrDev only)
- `_buildChartData()` — groups `concluida` audits by `templateName`, averages `conformityPercent`, sorts descending
- `_TemplateConformity` class at file scope (private, leading underscore)
- `await _loadDashboard()` chained at end of `_loadProfile()` try block
- `_summaryCard` icon container `borderRadius` fixed: 10 → 8 (UI-SPEC checker fix)

### Task 2: Replace _buildDashboard() with functional UI (commit 3be2256)

Replaced the entire `_buildDashboard()` method with:

- `RefreshIndicator(onRefresh: _loadDashboard, color: AppColors.primary, ...)`
- `SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.all(16), ...)`
- Row 1: Total + Pendentes cards with `_dashboardLoading ? '...' : '$value'` pattern
- Row 2: Atrasadas + conditional card: `AppRole.isSuperOrDev(_role)` → Empresas, else → Ações abertas
- Chart section: error container (when `_dashboardError != null`) or "Conformidade por template" title + `_buildConformityChart()`

Added `_buildConformityChart()` method:
- Empty state: 120px container with "Nenhuma auditoria concluída para exibir"
- Non-empty: `BarChart` with `rotationQuarterTurns: 1`, left axis = template labels, bottom axis = percentage values
- `maxY: 100`, `borderRadius: BorderRadius.circular(4)` per bar, `FlBorderData(show: false)`, `FlGridData(show: false)`

## Verification Results

| Check | Result |
|-------|--------|
| `dart analyze lib/screens/home_screen.dart` | No issues found |
| `flutter test test/services/dashboard_service_test.dart` | 23/23 passed |
| `flutter test` (full suite) | 172 tests passed, exits 0 |
| `import 'package:fl_chart/fl_chart.dart'` present | Confirmed line 2 |
| `RefreshIndicator` wrapping `SingleChildScrollView` | Confirmed |
| `AlwaysScrollableScrollPhysics()` | Confirmed |
| `AppRole.isSuperOrDev(_role)` for Empresas card | Confirmed (line 408) |
| `const Expanded(child: SizedBox())` removed | Confirmed (grep: no matches) |
| `_TemplateConformity` class at file scope | Confirmed line 615 |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All KPI card values are wired to real state fields (`_totalAudits`, `_pendingAudits`, `_overdueAudits`, `_openActions`, `_companiesCount`) populated by `_loadDashboard()` from Supabase. The `_openActions` value of 0 is an intentional Phase 8 dependency (documented in D-04), not a UI stub — the card renders with real value 0 until `corrective_actions` table exists.

## Threat Flags

No new security surface introduced. T-07-04 (auditor scope) and T-07-05 (Empresas card isSuperOrDev guard) mitigations are both implemented as specified in the threat model.

## Self-Check: PASSED

- `primeaudit/lib/screens/home_screen.dart` — modified (exists)
- Commit 7bc4e13 (feat: wire dashboard data layer) — confirmed
- Commit 3be2256 (feat: replace _buildDashboard() with functional UI) — confirmed
- `dart analyze` — No issues found
- `flutter test` — 172 tests passed
