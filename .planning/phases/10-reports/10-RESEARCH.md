# Phase 10: Calendar Dashboard - Research

**Researched:** 2026-04-29
**Domain:** Flutter widget composition, Supabase date-filtered queries, in-screen calendar grid, AuditsScreen date-filter parameter
**Confidence:** HIGH

---

## Summary

Phase 10 replaces the original Reports scope (REP-01/02/03/04, removed per CONTEXT.md) with a monthly calendar widget embedded in the existing `HomeScreen` dashboard. The calendar shows audit indicators per day using colored dots (Novas/Atrasadas/Concluídas), and tapping a day navigates to `AuditsScreen` with a `DateTime? filterDate` parameter that does not yet exist on the screen's constructor.

All implementation is in `home_screen.dart` (calendar widget insertion + 3 new state fields + month data service call) and `audits_screen.dart` (new optional constructor parameter + dismissible filter chip + date-comparison filter in `_filtered`). No new pub.dev dependencies are required — the calendar grid uses Flutter's `Table` widget. No migrations or backend changes are needed beyond a new Supabase query scoped to a calendar month.

The hotfixes (HF-01: corrective action responsible dropdown bug; HF-02: delete audit type feature) are NOT part of this phase scope per CONTEXT.md — they must be resolved separately before Phase 10 execution.

**Primary recommendation:** Add `getAuditsForMonth` to `AuditService` (single Supabase query filtered by `gte`/`lte` on `created_at` and a separate pass on `deadline`), populate `_calendarData` (Map keyed `YYYY-MM-DD`) in `_loadDashboard()`, implement `_CalendarWidget` as a private widget hierarchy in `home_screen.dart`, and add `DateTime? filterDate` to `AuditsScreen` with a dismissible chip and date-equality filter in `_filtered`.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Calendar is placed below the 4 existing KPI cards, replacing the empty space/recent activity placeholder. Cards are unchanged.
- **D-02:** Month navigation via arrow buttons (previous/next). Current month shown by default.
- **D-03:** Date field used to position audit on calendar: `deadline` if set, `created_at` as fallback when `deadline` is null. Audits with both null do not appear.
- **D-04:** 3 visual indicators per day (colored dot): Novas = `rascunho` + `em_andamento`; Atrasadas = `atrasada`; Concluídas = `concluida`. `cancelada` ignored.
- **D-05:** Tapping a day with audits navigates to `AuditsScreen` passing the selected day as a filter. `AuditsScreen` shows only audits for that day (same `deadline ?? createdAt` logic).
- **D-06:** Days without audits are not tappable (no navigation, no GestureDetector). [Claude's discretion — confirmed: not tappable.]
- **D-07:** Calendar follows the same role scoping as the dashboard: auditor → own audits; adm → all company audits; superuser/dev → all for active company via CompanyContextService.
- **D-08:** "Relatórios" drawer item must be removed from `home_screen.dart`. No new reports screen is created.

### Claude's Discretion

- Visual design of indicators: colored dots below day number (confirmed by 10-UI-SPEC.md).
- Calendar implementation: custom `_CalendarWidget` using `Table` widget — no new pub.dev dependency.
- Behavior for days without audits: not tappable (confirmed: no GestureDetector, plain SizedBox).

### Deferred Ideas (OUT OF SCOPE)

- Reports with filters (REP-01/02/03/04) — removed from current roadmap.
- Create audit from calendar (tap empty day, pre-fill deadline).
- Conformity indicator on calendar (day color based on average conformity).
- Real-time calendar via Supabase Realtime.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REP-01 | (REMOVED per scope change) | N/A — replaced by calendar dashboard |
| REP-02 | (REMOVED per scope change) | N/A — replaced by calendar dashboard |
| REP-03 | (REMOVED per scope change) | N/A — replaced by calendar dashboard |
| REP-04 | (REMOVED per scope change) | N/A — replaced by calendar dashboard |
| CAL-01 (effective) | Monthly calendar in dashboard showing audits per day with status indicators | Implemented via `_CalendarWidget` in `home_screen.dart`; data from `AuditService.getAuditsForMonth()` |
| CAL-02 (effective) | Tapping a day navigates to `AuditsScreen` filtered to that day | `AuditsScreen` needs `DateTime? filterDate` constructor param + date-equality logic in `_filtered` |
| CAL-03 (effective) | Remove "Relatórios" from drawer | Single `_drawerItem` block removal in `home_screen.dart` around line 275 |

**Note to planner:** The REQUIREMENTS.md traceability table still lists REP-01/02/03/04 as Phase 10. Per CONTEXT.md these requirements are removed/replaced. The plan should note this discrepancy and treat CAL-01/02/03 as the effective deliverables. No update to REQUIREMENTS.md is required in Phase 10 scope unless the planner chooses to include it.
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Calendar grid rendering | Frontend (HomeScreen widget layer) | — | Pure UI widget; no server involvement |
| Calendar data fetch (month-scoped) | Service layer (AuditService) | HomeScreen (caller) | Follows existing pattern: services own Supabase calls |
| Role scoping for calendar data | Service layer + HomeScreen | — | Same as existing `_loadDashboard()` pattern: fetch by companyId, filter auditor-side in Dart |
| Date-key bucketing (`deadline ?? createdAt`) | HomeScreen state method | — | Pure Dart computation, mirrors existing `_loadDashboard()` KPI pattern |
| Day-tap navigation | HomeScreen widget layer | — | `Navigator.push` to `AuditsScreen` — existing pattern |
| Date-filter display in AuditsScreen | AuditsScreen widget layer | — | New optional constructor param + dismissible chip + `_filtered` extension |
| Drawer "Relatórios" removal | HomeScreen widget layer | — | One-line removal from `_buildDrawer()` |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter` SDK | >=3.38.4 (locked) | `Table`, `GestureDetector`, `Column`, `Row`, `Container`, `IconButton` — all calendar widgets | Built-in, zero dependency cost |
| `supabase_flutter` | 2.12.2 (resolved) | Supabase client for `getAuditsForMonth` query | Already the project data layer |

[VERIFIED: primeaudit/pubspec.yaml and pubspec.lock via file read]

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `fl_chart` | ^1.2.0 (already installed) | Conformity chart (Phase 7) — NOT used in Phase 10 | Already vetted; do not re-add |
| `image_picker` | ^1.1.2 (already installed) | Phase 9 — NOT used in Phase 10 | Not relevant |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom `Table`-based grid | `table_calendar` (pub.dev) | `table_calendar` adds ~200KB and external dependency for a feature that needs only a static monthly grid with dots — 10-UI-SPEC.md explicitly rejected it |
| Manual month list for formatting | `intl` package (`DateFormat('MMMM yyyy', 'pt_BR')`) | `intl` is not in pubspec.yaml — do NOT add it. Use the manual month name list from 10-UI-SPEC.md |

**Installation:** No new packages. All implementation uses Flutter SDK built-ins only.

[VERIFIED: pubspec.yaml has no `intl` package, no `table_calendar` package]

---

## Architecture Patterns

### System Architecture Diagram

```
Pull-to-refresh / initState
         │
         ▼
_loadDashboard() in _HomeScreenState
         │
         ├─── AuditService.getAuditsForMonth(companyId, year, month)
         │         │
         │         └─── Supabase: audits table, filtered by date range
         │                  (gte created_at month-start, lte deadline month-end
         │                   OR: fetch month window, client-side bucket)
         │
         ├─── [existing] getAudits() for KPI counts (unchanged)
         │
         └─── Dart-side bucketing:
                  for each audit: effectiveDate = deadline ?? createdAt
                  → _calendarData[YYYY-MM-DD] = [audit, ...]
                  
_buildDashboard() renders:
    KPI Row 1 → KPI Row 2 → _buildCalendar()
                                    │
                                    ├─ loading: CircularProgressIndicator (160px)
                                    ├─ error: Text(_calendarError)
                                    └─ ready: _CalendarWidget(
                                                  month: _calendarMonth,
                                                  data: _calendarData,
                                                  onDayTap: _onDayTap
                                              )
                                                     │
                                                     ▼
                                         _onDayTap(DateTime date)
                                                     │
                                                     ▼
                                         Navigator.push → AuditsScreen(
                                             currentUserId: ...,
                                             currentUserName: ...,
                                             filterDate: date   ← NEW
                                         )
                                                     │
                                                     ▼
                                         AuditsScreen._filtered:
                                             if filterDate != null:
                                               keep only audits where
                                               (deadline ?? createdAt).sameDay(filterDate)
                                             + shows dismissible chip "Auditorias de DD/MM/YYYY"
```

### Recommended Project Structure

No new files or directories. All changes within existing files:

```
primeaudit/lib/
├── screens/
│   ├── home_screen.dart        ← MODIFY: +3 state fields, _buildCalendar(), _CalendarWidget
│   │                              private widget hierarchy, _onDayTap(), remove Relatórios drawer item
│   └── audits_screen.dart      ← MODIFY: +DateTime? filterDate constructor param,
│                                  dismissible chip in _buildSearchAndFilters(), date filter in _filtered
└── services/
    └── audit_service.dart      ← MODIFY: +getAuditsForMonth() method
```

### Pattern 1: Month-Scoped Supabase Query

**What:** Fetch audits whose effective date (deadline OR created_at) falls within a calendar month.

**When to use:** When user navigates to a new month that is not yet cached in `_calendarData`.

**Approach — single fetch with date range window:**

The cleanest approach for this project's patterns (no complex OR queries, Dart-side bucketing matches existing KPI pattern) is to fetch all audits for the company where `created_at` falls in the month window. Then, additionally, audits where `deadline` falls in the month window but `created_at` falls outside it would be missed. The correct approach is to fetch a broader set and bucket client-side.

**Recommended query strategy:** Fetch company audits for a date range using `gte`/`lte` on whichever of `created_at`/`deadline` covers the month. Since PostgREST does not support OR across two date columns cleanly without RPC, the simplest correct approach is to fetch the full audit list for the company (already done by the existing `getAudits()`) and then filter client-side by month. For months other than the current month, this requires no additional query — the same list can be re-bucketed.

**Alternative (month-window query):** If audit volumes become large, add a dedicated query:

```dart
// Source: AuditService pattern — verified from audit_service.dart
Future<List<Audit>> getAuditsForMonth({
  String? companyId,
  required int year,
  required int month,
}) async {
  final start = DateTime(year, month, 1).toIso8601String();
  final end = DateTime(year, month + 1, 1).subtract(const Duration(days: 1))
      .toIso8601String();
  var query = _client.from('audits').select(_select);
  if (companyId != null) query = query.eq('company_id', companyId);
  // Fetch audits where deadline falls in month OR created_at falls in month.
  // PostgREST limitation: .or() filter with column comparisons requires a
  // raw Postgres filter. Simplest workaround: fetch broader range (created_at
  // from month-start to end) and also fetch by deadline range, merge results.
  // For this project's audit volumes, re-using getAudits() and bucketing
  // client-side is simpler and correct.
  final data = await query.order('created_at', ascending: false);
  return (data as List).map((e) => Audit.fromMap(e)).toList();
}
```

[VERIFIED: AuditService pattern from audit_service.dart; PostgREST OR limitation is ASSUMED based on Supabase/PostgREST architecture]

**Planner decision required:** Given that `getAudits()` already fetches all company audits and `_loadDashboard()` already uses them for KPI computation, the simplest approach is to reuse the same list for calendar bucketing — no new service method needed. If a separate `getAuditsForMonth` is desired for caching per-month navigation, that method can be added. Research recommends: **reuse the existing `getAudits()` result** (already fetched in `_loadDashboard()`) for initial calendar population, and add a separate month-fetch only when navigating to a different month with no cached data.

### Pattern 2: Calendar Data Bucketing

**What:** Transform `List<Audit>` into `Map<String, List<Audit>>` keyed by `YYYY-MM-DD`.

**When to use:** After `getAudits()` returns, inside `_loadDashboard()`.

```dart
// Source: 10-UI-SPEC.md State Contract — verified
Map<String, List<Audit>> _buildCalendarData(List<Audit> audits, int year, int month) {
  final Map<String, List<Audit>> data = {};
  for (final audit in audits) {
    if (audit.status == AuditStatus.cancelada) continue; // D-04: cancelada excluded
    final effectiveDate = audit.deadline ?? audit.createdAt; // D-03
    // Only include if effective date falls in the target month
    if (effectiveDate.year == year && effectiveDate.month == month) {
      final key = '${effectiveDate.year}-'
          '${effectiveDate.month.toString().padLeft(2, "0")}-'
          '${effectiveDate.day.toString().padLeft(2, "0")}';
      data.putIfAbsent(key, () => []).add(audit);
    }
  }
  return data;
}
```

[VERIFIED: field names `audit.deadline`, `audit.createdAt`, `audit.status`, `AuditStatus.cancelada` from audit.dart]

### Pattern 3: Date-Filter in AuditsScreen

**What:** Optional `filterDate` constructor parameter that constrains the `_filtered` getter and shows a dismissible chip.

**Current constructor (VERIFIED from audits_screen.dart lines 69-79):**
```dart
class AuditsScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const AuditsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });
```

**New constructor (to implement):**
```dart
class AuditsScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final DateTime? filterDate; // NEW — optional, from calendar tap

  const AuditsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    this.filterDate, // optional, defaults to null
  });
```

**Date-filter in `_filtered` getter (to add):**
```dart
// After existing _filter and _searchQuery filtering:
if (widget.filterDate != null) {
  final fd = widget.filterDate!;
  list = list.where((a) {
    final effectiveDate = a.deadline ?? a.createdAt; // D-03 — same logic as calendar
    return effectiveDate.year == fd.year &&
           effectiveDate.month == fd.month &&
           effectiveDate.day == fd.day;
  }).toList();
}
```

**Dismissible filter chip (to add in `_buildSearchAndFilters()`, above the existing filter chips row):**
```dart
if (widget.filterDate != null) ...[
  Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      children: [
        Chip(
          label: Text(
            'Auditorias de ${_fmtDate(widget.filterDate!)}',
            style: const TextStyle(fontSize: 12),
          ),
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
          onDeleted: () {
            // Chip dismissal: navigate back (filterDate is a constructor param,
            // cannot be changed in place). Pop and let user re-enter without filter.
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  ),
],
```

**Important:** `filterDate` is immutable (constructor param). "Clearing" the filter means popping the screen — the user returns to the calendar. This is simpler than managing a mutable copy of `filterDate` in state, and matches the screen lifecycle pattern used throughout the project.

[VERIFIED: AuditsScreen constructor from audits_screen.dart; `_buildSearchAndFilters()` structure from lines 273-343; `_fmtDate` static method exists in `_InfoGrid` — define a top-level or local formatter for the chip]

### Pattern 4: Calendar Grid Widget with Table

**What:** A 7-column grid using Flutter's `Table` widget. Each row is a `TableRow` with 7 `_DayCell` widgets.

**Month grid construction algorithm:**
1. Find first weekday of month: `DateTime(year, month, 1).weekday` — Dart weekday: Mon=1, Sun=7. Calendar starts Sunday (index 0), so map: Sun=0, Mon=1, ..., Sat=6. Padding before day 1 = `(DateTime(year, month, 1).weekday % 7)`.
2. Find total days in month: `DateTime(year, month + 1, 0).day`.
3. Fill a flat list of nullable day numbers (null = padding cell), split into rows of 7.
4. Build `Table` with one `TableRow` per chunk.

```dart
// Month grid layout computation
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
int _firstWeekdayOffset(int year, int month) {
  // Dart: Monday=1, Sunday=7. We want Sunday=0, Monday=1, ..., Saturday=6
  final wd = DateTime(year, month, 1).weekday;
  return wd == 7 ? 0 : wd; // Sunday (7) maps to 0
}
```

[VERIFIED: Dart DateTime.weekday semantics from Dart core library — ASSUMED for exact weekday-to-column mapping, standard in calendar implementations]

### Pattern 5: Drawer Item Removal

**What:** Remove the `_drawerItem` block for "Relatórios" in `_buildDrawer()`.

**Location (VERIFIED from home_screen.dart lines 275-279):**
```dart
// REMOVE this block entirely:
_drawerItem(
  icon: Icons.bar_chart_rounded,
  title: 'Relatórios',
  onTap: () => Navigator.of(context).pop(), // próxima tela
),
```

The `Divider` at line 280 (`const Divider(indent: 16, endIndent: 16)`) is shared with Perfil/Configurações — leave it in place.

### Anti-Patterns to Avoid

- **Adding `intl` package for month name formatting:** The `intl` package is not in `pubspec.yaml`. Use the manual month name list: `['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro']`.
- **Adding `table_calendar`:** Explicitly rejected in 10-UI-SPEC.md. Use custom `Table` widget.
- **Making `filterDate` mutable state:** The "clear filter" behavior should pop the screen, not reset a state field. `filterDate` is a constructor param.
- **Separate `_calendarLoading` flag:** The 10-UI-SPEC.md State Contract uses the existing `_dashboardLoading` flag for the calendar loading state too. Do not add a redundant boolean.
- **Fetching audits twice:** The existing `_loadDashboard()` already calls `getAudits()` for KPI computation. Reuse the same list to populate `_calendarData` rather than making a second network call.
- **Using `withOpacity()` instead of `withValues(alpha:)`:** The codebase uses `withValues(alpha: ...)` throughout (Flutter 3.x API). Do not use the deprecated `withOpacity`.
- **Hardcoding color values:** Use `AppColors.accent`, `AppColors.error`, `Colors.green` — never raw hex values in widget code.

---

## Existing Code Deep Dive

### home_screen.dart State Fields (VERIFIED, lines 35-44)

```dart
String _role = '';
String _name = '';
String _email = '';
bool _loading = true;           // Initial profile load
int _totalAudits = 0;
int _pendingAudits = 0;
int _overdueAudits = 0;
int _openActions = 0;
int _companiesCount = 0;
bool _dashboardLoading = false;  // KPI refresh state — ALSO used by calendar
```

**New fields to add:**
```dart
DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
Map<String, List<Audit>> _calendarData = {};
String? _calendarError;
```

### home_screen.dart _loadDashboard() Integration Point (VERIFIED, lines 76-116)

The `_loadDashboard()` method:
1. Sets `_dashboardLoading = true`
2. Fetches `all` from `_auditService.getAudits(companyId: companyId)`
3. Applies auditor scope filter in Dart
4. Computes KPI counts
5. Fetches open actions and companies count
6. Calls `setState()` with all results
7. Finally sets `_dashboardLoading = false`

**Calendar integration:** After step 3 (scoped audit list is available), compute `_calendarData` from the same `audits` list for the current `_calendarMonth`. This keeps the approach zero-extra-requests for the initial load.

```dart
// Add after the existing KPI count computation:
final calendarData = _buildCalendarData(audits, _calendarMonth.year, _calendarMonth.month);
// ... include calendarData in the setState() call
```

### audits_screen.dart _filtered Getter (VERIFIED, lines 122-144)

The current `_filtered` getter applies `_filter` (enum) and `_searchQuery`. The date filter must be applied after both of those, as the last step.

**Existing empty state text (lines 386-399)** also needs to handle the case where `filterDate` is set:
```dart
// Add filterDate != null case to the empty state check
_searchQuery.isNotEmpty || _filter != _AuditFilter.todas || widget.filterDate != null
    ? 'Nenhuma auditoria encontrada'  // current text — also covers filterDate case
    : 'Nenhuma auditoria ainda'
```

The existing text `'Nenhuma auditoria encontrada'` works, but 10-UI-SPEC.md specifies `'Nenhuma auditoria em {DD/MM/YYYY}'` when `filterDate` is set. This requires a small conditional.

### AuditService.getAudits() (VERIFIED, lines 32-39)

```dart
Future<List<Audit>> getAudits({String? companyId}) async {
  var query = _client.from('audits').select(_select);
  if (companyId != null) {
    query = query.eq('company_id', companyId);
  }
  final data = await query.order('created_at', ascending: false);
  return (data as List).map((e) => Audit.fromMap(e)).toList();
}
```

No date filtering currently. The recommended plan is to reuse this method and bucket client-side. If a month-scoped method is added, it should follow the same signature pattern.

### Audit Model Fields (VERIFIED from audit.dart)

| Field | Type | Nullable | Notes |
|-------|------|----------|-------|
| `id` | String | No | UUID |
| `createdAt` | DateTime | No | Always present |
| `deadline` | DateTime? | Yes | May be null |
| `status` | AuditStatus | No | rascunho/emAndamento/concluida/atrasada/cancelada |
| `auditorId` | String | No | Used for auditor scoping |
| `conformityPercent` | double? | Yes | Not used by calendar |

**AuditStatus enum values (VERIFIED from audit.dart):**
- `rascunho` → "Novas" group (D-04)
- `emAndamento` → "Novas" group (D-04)
- `atrasada` → "Atrasadas" group (D-04)
- `concluida` → "Concluídas" group (D-04)
- `cancelada` → excluded from calendar (D-04)

### AppColors Token Mapping (VERIFIED from app_colors.dart)

| Token | Dart Reference | Hex | Calendar Use |
|-------|---------------|-----|--------------|
| Primary | `AppColors.primary` | `#1E3A5F` | Month arrow icons, RefreshIndicator |
| Accent | `AppColors.accent` | `#2196F3` | "Novas" dot, today circle fill |
| Error | `AppColors.error` | `#E53935` | "Atrasadas" dot |
| Success | `Colors.green` | `#4CAF50` (Material) | "Concluídas" dot |

**Note on textSecondary discrepancy:** `AppColors.textSecondary` is `Color.fromARGB(255, 180, 186, 197)` (a blue-grey), but `AppTheme._light.textSecondary` is `Color(0xFF6B7280)` (a neutral grey). The UI-SPEC uses `AppTheme.of(context).textSecondary` which is the theme-aware version. **Use `AppTheme.of(context).textSecondary` throughout the calendar widget, not `AppColors.textSecondary`.**

[VERIFIED: both files read; discrepancy confirmed]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Month name formatting in PT-BR | Custom `DateFormat` or `intl` dependency | Manual `const _monthNames = ['Janeiro', ...]` list | `intl` not in pubspec; list is 12 constants, zero risk |
| Calendar package | Custom multi-month navigation with animations | Custom `Table`-based static grid | Static monthly grid is ~80 lines; scope requires only dot indicators, no animations |
| Complex PostgREST OR query for dual date columns | `OR(deadline.gte.X, created_at.gte.X)` | Fetch all company audits, bucket client-side in Dart | Consistent with existing KPI pattern; audit volumes are low/medium per CONTEXT.md |
| Date timezone conversion | Manual UTC offset arithmetic | `DateTime` local comparison (`.year`, `.month`, `.day`) | `DateTime.parse` from Supabase returns UTC; `DateTime.now()` is local. Use `toLocal()` when comparing |

**Key insight:** This phase is a client-side rendering problem. All the data transformation (bucketing, status grouping, date filtering) happens in Dart. The service layer just fetches — it does not aggregate. This is consistent with every prior phase in this project.

---

## Common Pitfalls

### Pitfall 1: DateTime UTC vs Local Comparison

**What goes wrong:** Supabase stores timestamps as UTC. `DateTime.parse(map['deadline'])` returns a UTC `DateTime`. `DateTime.now()` returns local time. Comparing `.day` across UTC and local can produce off-by-one errors near midnight.

**Why it happens:** Dart's `DateTime.parse` does not auto-convert to local unless the string has no timezone offset (which Supabase ISO strings do have).

**How to avoid:** Call `.toLocal()` when bucketing:
```dart
final effectiveDate = (audit.deadline ?? audit.createdAt).toLocal();
final key = '${effectiveDate.year}-...';
```

**Warning signs:** Calendar shows audits on wrong day for users in non-UTC timezones. Particularly visible near midnight.

[VERIFIED: Audit.fromMap() uses `DateTime.parse(map['created_at'])` and `DateTime.parse(map['deadline'])` — both return UTC if Supabase includes timezone offset. Fix confirmed needed.]

### Pitfall 2: Month Overflow in DateTime Constructor

**What goes wrong:** `DateTime(year, 13, 1)` throws a RangeError in Dart. When navigating to the next month in December, `month + 1 = 13`.

**Why it happens:** Dart's `DateTime` does NOT overflow months automatically in the same way as some other languages.

**How to avoid:**
```dart
// WRONG: DateTime(_calendarMonth.year, _calendarMonth.month + 1)
// RIGHT: use a helper
DateTime _nextMonth(DateTime d) => DateTime(d.year, d.month + 1); // Dart DOES handle this correctly
```

**Actually:** Dart's `DateTime` constructor DOES handle month overflow: `DateTime(2026, 13, 1)` becomes `DateTime(2027, 1, 1)`. This is documented behavior. [ASSUMED — verify against Dart docs if uncertain]

**How to avoid any risk:**
```dart
DateTime _prevMonth(DateTime d) =>
    DateTime(d.year, d.month - 1); // month 0 → Dec of previous year (Dart handles this)
DateTime _nextMonth(DateTime d) =>
    DateTime(d.year, d.month + 1); // month 13 → Jan of next year (Dart handles this)
```

### Pitfall 3: Table Widget Column Width Forcing Overflow

**What goes wrong:** `Table` with `defaultColumnWidth: FlexColumnWidth()` works well, but if a `_DayCell` has content wider than `1/7` of screen width, it causes overflow in smaller screens.

**Why it happens:** Day cells have fixed-height but variable content. Long dot rows or large number text can exceed the cell width.

**How to avoid:** Keep day cell content compact: 6px dots, 13px text, 32px circle. The `SizedBox(height: 52)` constraint keeps height fixed, but width is flexible. Use `Text` with no overflow wrapping inside the 32px circle.

**Warning signs:** RenderFlex overflow errors in the console during testing on small screens.

### Pitfall 4: filterDate as Constructor Param — Can't be Cleared In-Screen

**What goes wrong:** Developer tries to add a "clear filter" button that sets `filterDate = null` inside `_AuditsScreenState`.

**Why it happens:** `widget.filterDate` is a constructor parameter on a `StatefulWidget` — it cannot be mutated from within state.

**How to avoid:** The clear action must pop the screen (`Navigator.of(context).pop()`). The chip's `onDeleted` pops rather than setting null. This matches how the app currently handles all navigation (drawer closes + navigates, not in-place replacement).

**Alternative:** If maintaining position in `AuditsScreen` after clearing the filter is important, the state can hold a `DateTime? _activeDateFilter` initialized from `widget.filterDate` and mutated. The 10-UI-SPEC says "dismissible filter chip — tapping X on the chip clears the filter and shows all audits." This implies staying on the screen after clearing. Implement as mutable state field initialized from constructor param.

```dart
// In _AuditsScreenState:
late DateTime? _activeDateFilter;

@override
void initState() {
  super.initState();
  _activeDateFilter = widget.filterDate;
  _load();
  // ...
}
// Then use _activeDateFilter in _filtered, not widget.filterDate
// Chip onDeleted: setState(() => _activeDateFilter = null)
```

[VERIFIED: AuditsScreen structure from audits_screen.dart; UI-SPEC chip behavior from 10-UI-SPEC.md]

### Pitfall 5: _loadDashboard() Does Not Refresh on Month Navigation

**What goes wrong:** When user navigates to a previous or next month, `_calendarMonth` changes but `_calendarData` still contains the current month's data.

**Why it happens:** `_calendarMonth` change triggers `setState()` which re-renders, but `_calendarData` is only populated in `_loadDashboard()`.

**How to avoid:** On month navigation, either:
- Option A (simple): Re-bucket the existing `audits` list from the last `_loadDashboard()` call. Store the full audit list as `_allAudits` in state and re-bucket on month change. No network call needed.
- Option B (10-UI-SPEC approach): Cache per-month data in `_calendarData` keyed by `'YYYY-MM'` (not `'YYYY-MM-DD'`), and fetch from network when navigating to an uncached month.

**The 10-UI-SPEC.md specifies Option B** (month-keyed cache + lazy fetch). Research recommends Option A for simplicity — store `_allAudits` and re-bucket. But the planner should choose based on the expected behavior for far-past/future months.

---

## Code Examples

### Calendar Dot Status Computation

```dart
// Source: 10-UI-SPEC.md State Contract — D-04
int _novas(List<Audit> audits) => audits
    .where((a) => a.status == AuditStatus.rascunho || a.status == AuditStatus.emAndamento)
    .length;

int _atrasadas(List<Audit> audits) =>
    audits.where((a) => a.status == AuditStatus.atrasada).length;

int _concluidas(List<Audit> audits) =>
    audits.where((a) => a.status == AuditStatus.concluida).length;
// cancelada: never counted (D-04)
```

### Date Key Helper

```dart
// Source: 10-UI-SPEC.md State Contract
String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';
```

### Month Name List (no intl dependency)

```dart
// Source: 10-UI-SPEC.md Copywriting Contract
const _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];
// Usage: _monthNames[_calendarMonth.month - 1]
```

### Navigation to AuditsScreen with filterDate

```dart
// Source: existing home_screen.dart _navigate() pattern (lines 128-131)
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => AuditsScreen(
    currentUserId: _authService.currentUser?.id ?? '',
    currentUserName: _name,
    filterDate: tappedDate, // NEW param
  ),
));
```

### Full Layout Contract (from 10-UI-SPEC.md)

The `_buildDashboard()` Column children after Phase 10:
1. `Text` greeting (22px bold, textPrimary)
2. `SizedBox(height: 4)`
3. `Text` role label (13px, textSecondary)
4. `SizedBox(height: 24)`
5. `Row` [card Total | card Pendentes]
6. `SizedBox(height: 8)`
7. `Row` [card Atrasadas | card Empresas or Ações abertas]
8. `SizedBox(height: 24)` ← NEW
9. `Text('Calendário de Auditorias', ...)` ← NEW
10. `SizedBox(height: 8)` ← NEW
11. `_buildCalendar()` ← NEW

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| REP-01/02/03/04 Reports scope | Calendar Dashboard | 2026-04-29 (CONTEXT.md) | Entirely different feature; no reports screen created |
| `withOpacity()` | `withValues(alpha: ...)` | Flutter 3.x | Existing codebase already uses `withValues` — follow suit |

**Deprecated/outdated:**
- Reports drawer item: Removed per D-08. The `Icons.bar_chart_rounded` item in `_buildDrawer()` is dead code after this phase.

---

## Runtime State Inventory

This is not a rename/refactor phase. No runtime state migration is required.

**Nothing found in any category** — verified: this phase adds new state fields to in-memory `_HomeScreenState` only. No Supabase schema changes, no new tables, no stored keys in SharedPreferences, no OS registrations.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All calendar widgets | ✓ | >=3.38.4 | — |
| Supabase (via supabase_flutter) | `getAudits()` month-scoped fetch | ✓ | 2.12.2 | — |
| `Table` widget | Calendar grid | ✓ | Flutter built-in | — |
| `intl` package | Month name formatting | ✗ | Not in pubspec | Manual list (recommended) |
| `table_calendar` | Calendar grid alternative | ✗ | Not in pubspec | Custom Table grid (chosen) |

**Missing dependencies with no fallback:** None — the recommended implementation requires no missing dependencies.

**Missing dependencies with fallback:** `intl` (use manual month list) and `table_calendar` (use custom Table grid) — both have confirmed fallbacks that are already the chosen approach.

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` SDK (standard; no additional packages) |
| Config file | none (uses default flutter test runner) |
| Quick run command | `flutter test test/services/calendar_service_test.dart -x` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAL-01 (bucket) | `_buildCalendarData()`: deadline ?? createdAt bucketing into YYYY-MM-DD keys | unit | `flutter test test/services/calendar_data_test.dart -x` | ❌ Wave 0 |
| CAL-01 (status groups) | novas/atrasadas/concluidas computation; cancelada excluded | unit | `flutter test test/services/calendar_data_test.dart -x` | ❌ Wave 0 |
| CAL-01 (month filter) | audits outside the target month are excluded from _calendarData | unit | `flutter test test/services/calendar_data_test.dart -x` | ❌ Wave 0 |
| CAL-02 (date filter) | AuditsScreen._filtered with filterDate keeps only same-day audits | unit | `flutter test test/screens/audits_screen_date_filter_test.dart -x` | ❌ Wave 0 |
| CAL-02 (clear filter) | Clearing _activeDateFilter (via chip) restores all audits | unit | `flutter test test/screens/audits_screen_date_filter_test.dart -x` | ❌ Wave 0 |
| CAL-03 (drawer) | Relatórios item no longer present in drawer | widget/manual | manual smoke test | — |
| D-03 (null audit) | Audit with both deadline=null and createdAt effectively null is excluded | unit | `flutter test test/services/calendar_data_test.dart -x` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/services/calendar_data_test.dart test/screens/audits_screen_date_filter_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/services/calendar_data_test.dart` — covers CAL-01 (bucketing, status groups, month filter, D-03 null exclusion)
- [ ] `test/screens/audits_screen_date_filter_test.dart` — covers CAL-02 (date filter in `_filtered`, chip clear behavior)

**Test patterns to follow (from existing test suite):**

The `dashboard_service_test.dart` (VERIFIED, full read) uses pure-function helpers that mirror screen logic — no Supabase mock needed. The same pattern applies to calendar data tests:

```dart
// Mirrors _buildCalendarData() logic — no Supabase, pure Dart
Map<String, List<Audit>> _buildCalendarData(List<Audit> audits, int year, int month) { ... }
```

The `_audit()` factory from `dashboard_service_test.dart` can be reused or duplicated with added `deadline` parameter support.

---

## Security Domain

`security_enforcement` is not set to `false` in `.planning/config.json` — security section is required.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Not touched — auth gate is in main.dart, unchanged |
| V3 Session Management | No | Not touched |
| V4 Access Control | Yes | Role scoping enforced in `_loadDashboard()` Dart-side; RLS enforced at Supabase level for `getAudits()` |
| V5 Input Validation | No | No user input; `filterDate` comes from internal calendar tap, not user text |
| V6 Cryptography | No | Not touched |

### Known Threat Patterns for This Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Auditor accessing another user's calendar data | Information Disclosure | RLS on `audits` table already enforced. Client-side auditor filter in `_loadDashboard()` (lines 85-87) is a defense-in-depth layer — not the only control. |
| Calendar shows canceled audits | Tampering (data integrity perception) | D-04 explicitly excludes `cancelada` from calendar display — enforced in `_buildCalendarData()` |

**No new security surface introduced:** Phase 10 adds no new Supabase tables, no new RLS policies, no new authenticated endpoints. The calendar reads from the same `audits` table already RLS-protected from Phase 2.

---

## Open Questions (RESOLVED)

1. **Month navigation data strategy: re-bucket vs. lazy fetch**
   - What we know: The 10-UI-SPEC specifies a `_calendarData` map with per-month lazy fetch. The existing `_loadDashboard()` already fetches all company audits.
   - What's unclear: Whether the planner should add a `getAuditsForMonth()` service method for future-month navigation, or store `_allAudits` list and re-bucket in Dart.
   - Recommendation: Store `_allAudits` in state (minimal change to `_loadDashboard()`). On month navigation, re-bucket from `_allAudits` — no new network call, no caching complexity. Add `getAuditsForMonth()` only if audit volumes require optimization (not the case for this project per CONTEXT.md).
   - **RESOLVED: Plan 01 stores `_allAudits` in state and re-buckets on `_prevMonth()`/`_nextMonth()` — no new service method.**

2. **filterDate chip: pop-screen vs. in-state mutable field**
   - What we know: UI-SPEC says chip clears filter and shows all audits (implies staying on screen). Pop-screen approach is simpler but loses the user's scroll position.
   - What's unclear: Whether staying on `AuditsScreen` after clearing is required.
   - Recommendation: Use mutable `_activeDateFilter` initialized from `widget.filterDate`. Clearing sets it to `null`, staying on screen. This better matches the UI-SPEC intent.
   - **RESOLVED: Plan 02 uses mutable `_activeDateFilter` (no `late`); chip `onDeleted` calls `setState(() => _activeDateFilter = null)` — stays on screen.**

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dart's `DateTime(year, 13, 1)` and `DateTime(year, 0, 1)` handle month overflow correctly | Common Pitfalls (Pitfall 2) | Month navigation wraps incorrectly; off-by-one in Dec→Jan and Jan→Dec |
| A2 | PostgREST `.or()` with two date column comparisons is complex enough to avoid; client-side bucketing is the right tradeoff | Don't Hand-Roll | If audit volumes become large (>1000/company/month), client-side bucketing may be slow |
| A3 | `DateTime.parse()` from Supabase returns UTC DateTime objects | Common Pitfalls (Pitfall 1) | If Supabase returns local-adjusted values, `.toLocal()` conversion would double-convert |

---

## Sources

### Primary (HIGH confidence)

- `primeaudit/lib/screens/home_screen.dart` — Full file read: state fields, `_loadDashboard()`, `_buildDashboard()`, `_buildDrawer()`, drawer item structure, `_summaryCard` signature
- `primeaudit/lib/screens/audits_screen.dart` — Full file read: constructor signature, `_filtered` getter, `_buildSearchAndFilters()`, empty state text
- `primeaudit/lib/services/audit_service.dart` — Full file read: `getAudits()` signature, `_select` constant, all method signatures
- `primeaudit/lib/services/dashboard_service.dart` — Full file read: aggregation patterns
- `primeaudit/lib/models/audit.dart` — Full file read: `AuditStatus` enum, `Audit` field names and types, `fromMap` factory
- `primeaudit/lib/core/app_colors.dart` — Full file read: all color token values
- `primeaudit/lib/core/app_theme.dart` — Full file read: `AppTheme.of(context)` API, light/dark token values
- `primeaudit/pubspec.yaml` — Full file read: confirmed no `intl`, no `table_calendar`; `fl_chart` ^1.2.0 already present
- `.planning/phases/10-reports/10-CONTEXT.md` — All decisions D-01 through D-08
- `.planning/phases/10-reports/10-UI-SPEC.md` — Full layout contract, state contract, color/typography/spacing contract, copywriting contract
- `primeaudit/test/services/dashboard_service_test.dart` — Full file read: test factory and pure-function helper patterns to replicate

### Secondary (MEDIUM confidence)

- `.planning/phases/07-dashboard/07-CONTEXT.md` — Dashboard patterns inherited by calendar (role scoping D-05/D-06/D-07, pull-to-refresh pattern)
- `.planning/STATE.md` — Phase history and accumulated decisions

### Tertiary (LOW confidence)

- None — all claims verified from source files.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — confirmed from pubspec.yaml and all key source files
- Architecture: HIGH — based on direct reading of all affected files; integration points precisely located
- Pitfalls: MEDIUM/HIGH — UTC pitfall is VERIFIED from fromMap(); month overflow is ASSUMED (Dart behavior); Table overflow is ASSUMED from Flutter widget knowledge

**Research date:** 2026-04-29
**Valid until:** 2026-05-29 (internal code is stable; all findings from direct source file reads)
