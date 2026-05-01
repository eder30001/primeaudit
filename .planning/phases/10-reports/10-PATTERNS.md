# Phase 10: Calendar Dashboard - Pattern Map

**Mapped:** 2026-05-01
**Files analyzed:** 5 (3 modified, 2 new test files)
**Analogs found:** 5 / 5

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `primeaudit/lib/screens/home_screen.dart` | screen (dashboard) | request-response + transform | self (existing file to modify) | exact |
| `primeaudit/lib/screens/audits_screen.dart` | screen (list) | request-response + filter | self (existing file to modify) | exact |
| `primeaudit/lib/services/audit_service.dart` | service | CRUD | self (existing file to modify) | exact |
| `primeaudit/test/services/calendar_data_test.dart` | test (unit) | batch/transform | `primeaudit/test/services/dashboard_service_test.dart` | exact |
| `primeaudit/test/screens/audits_screen_date_filter_test.dart` | test (unit) | filter/transform | `primeaudit/test/screens/audit_execution_ordering_test.dart` | exact |

---

## Pattern Assignments

### `primeaudit/lib/screens/home_screen.dart` — Calendar state fields and `_buildCalendar()`

**Analog:** same file (self-modification)

**Existing state field block** (lines 35–44) — add 3 new fields immediately after line 44:
```dart
// EXISTING (lines 35-44):
String _role = '';
String _name = '';
String _email = '';
bool _loading = true;
int _totalAudits = 0;
int _pendingAudits = 0;
int _overdueAudits = 0;
int _openActions = 0;
int _companiesCount = 0;
bool _dashboardLoading = false;

// ADD after line 44:
DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
Map<String, List<Audit>> _calendarData = {};
String? _calendarError;
List<Audit> _allAudits = []; // retained for re-bucketing on month navigation
```

**Service instantiation pattern** (lines 28–33) — follow exactly:
```dart
final _authService = AuthService();
final _userService = UserService();
final _auditService = AuditService();
final _dashboardService = DashboardService();
final _correctiveActionService = CorrectiveActionService();
final _scaffoldKey = GlobalKey<ScaffoldState>();
```

**`_loadDashboard()` integration point** (lines 76–116) — calendar data computation goes after the auditor-scoped `audits` list is ready and before the `setState()` call. The full pattern is:
```dart
Future<void> _loadDashboard() async {
  if (!mounted) return;
  setState(() => _dashboardLoading = true);
  try {
    final companyId = CompanyContextService.instance.activeCompanyId;
    final currentUserId = _authService.currentUser?.id ?? '';

    final all = await _auditService.getAudits(companyId: companyId);
    final audits = (AppRole.isSuperOrDev(_role) || AppRole.canAccessAdmin(_role))
        ? all
        : all.where((a) => a.auditorId == currentUserId).toList();

    // KPI counts (unchanged) ...

    // ADD: calendar bucketing — reuses the same 'audits' list, zero extra request
    final calendarData = _buildCalendarData(
        audits, _calendarMonth.year, _calendarMonth.month);

    if (mounted) {
      setState(() {
        // existing KPI fields ...
        _allAudits = audits;       // NEW
        _calendarData = calendarData; // NEW
        _calendarError = null;        // NEW
      });
    }
  } catch (e) {
    if (mounted) setState(() => _calendarError = e.toString()); // NEW
  } finally {
    if (mounted) setState(() => _dashboardLoading = false);
  }
}
```

**`_buildCalendarData()` pure helper** — place as a private method on `_HomeScreenState`:
```dart
Map<String, List<Audit>> _buildCalendarData(
    List<Audit> audits, int year, int month) {
  final Map<String, List<Audit>> data = {};
  for (final audit in audits) {
    if (audit.status == AuditStatus.cancelada) continue; // D-04
    final effectiveDate =
        (audit.deadline ?? audit.createdAt).toLocal(); // D-03 + Pitfall 1
    if (effectiveDate.year == year && effectiveDate.month == month) {
      final key =
          '${effectiveDate.year}-'
          '${effectiveDate.month.toString().padLeft(2, "0")}-'
          '${effectiveDate.day.toString().padLeft(2, "0")}';
      data.putIfAbsent(key, () => []).add(audit);
    }
  }
  return data;
}
```

**`_onDayTap()` navigation pattern** — follows `_navigate()` (lines 128–131) without closing the drawer:
```dart
void _onDayTap(DateTime date) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AuditsScreen(
      currentUserId: _authService.currentUser?.id ?? '',
      currentUserName: _name,
      filterDate: date, // NEW param
    ),
  ));
}
```

**Month navigation + re-bucketing** — triggered by arrow buttons in `_CalendarWidget`, updates state in `_HomeScreenState`:
```dart
void _prevMonth() {
  setState(() {
    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
    _calendarData =
        _buildCalendarData(_allAudits, _calendarMonth.year, _calendarMonth.month);
  });
}

void _nextMonth() {
  setState(() {
    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
    _calendarData =
        _buildCalendarData(_allAudits, _calendarMonth.year, _calendarMonth.month);
  });
}
```

**`_buildCalendar()` guard pattern** — mirrors `_dashboardLoading` pattern already used for KPI cards (lines 376, 384, etc.):
```dart
Widget _buildCalendar() {
  if (_dashboardLoading) {
    return const SizedBox(
      height: 160,
      child: Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
  if (_calendarError != null) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(_calendarError!,
          style: TextStyle(
              color: AppTheme.of(context).textSecondary, fontSize: 13)),
    );
  }
  return _CalendarWidget(
    month: _calendarMonth,
    data: _calendarData,
    onDayTap: _onDayTap,
    onPrevMonth: _prevMonth,
    onNextMonth: _nextMonth,
  );
}
```

**`_buildDashboard()` insertion point** (lines 340–428) — add calendar section after line 423 (end of Row 2), before the closing `]` of the Column's children list:
```dart
// EXISTING end of _buildDashboard() Column children:
// ... Row 2 (Atrasadas + Empresas/Ações)
const SizedBox(height: 8),  // existing line 391
// ... Row 2 widgets ...

// ADD after Row 2:
const SizedBox(height: 24),
Text(
  'Calendário de Auditorias',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppTheme.of(context).textPrimary,
  ),
),
const SizedBox(height: 8),
_buildCalendar(),
```

**Drawer removal** (lines 275–279) — remove this exact block entirely:
```dart
// REMOVE:
_drawerItem(
  icon: Icons.bar_chart_rounded,
  title: 'Relatórios',
  onTap: () => Navigator.of(context).pop(), // próxima tela
),
// Keep the Divider on line 280 unchanged.
```

**`_summaryCard` color pattern** (lines 447–496) — `withValues(alpha: ...)` (NOT `withOpacity`):
```dart
color: color.withValues(alpha: 0.12),   // icon container background
color: overdue ? AppColors.error.withValues(alpha: 0.4) : t.divider,  // card border
```

**`_CalendarWidget` private widget structure** — follows the same pattern as `_AuditCard`, `_InfoGrid`, `_Tag` etc. in `audits_screen.dart`: private `StatelessWidget` classes defined at the bottom of the same file. Use `AppTheme.of(context).textSecondary` (NOT `AppColors.textSecondary`) for day labels.

**Month name list** (no `intl` dependency — verified pubspec.yaml has none):
```dart
const _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];
// Usage: _monthNames[_calendarMonth.month - 1]
```

**Dot status computation** — pure functions, placed as top-level or methods on `_CalendarWidget`:
```dart
int _novas(List<Audit> audits) => audits
    .where((a) =>
        a.status == AuditStatus.rascunho ||
        a.status == AuditStatus.emAndamento)
    .length;

int _atrasadas(List<Audit> audits) =>
    audits.where((a) => a.status == AuditStatus.atrasada).length;

int _concluidas(List<Audit> audits) =>
    audits.where((a) => a.status == AuditStatus.concluida).length;
```

**Date key helper** — consistent with `_buildCalendarData` bucketing:
```dart
String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';
```

**Calendar dot color mapping** (verified from `app_colors.dart`):
```dart
// Novas (rascunho + emAndamento) → AppColors.accent = Color(0xFF2196F3)
// Atrasadas → AppColors.error = Color(0xFFE53935)
// Concluídas → Colors.green (= Color(0xFF4CAF50) Material default)
// Today circle fill → AppColors.accent
```

**Month grid algorithm** — `Table` widget, 7 columns, Sunday-first:
```dart
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
int _firstWeekdayOffset(int year, int month) {
  // Dart: Monday=1, Sunday=7. Calendar is Sunday-first (offset 0).
  final wd = DateTime(year, month, 1).weekday;
  return wd == 7 ? 0 : wd;
}
```

---

### `primeaudit/lib/screens/audits_screen.dart` — `DateTime? filterDate` parameter

**Analog:** same file (self-modification)

**Existing constructor** (lines 69–77):
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

**New constructor** — add `filterDate` as optional named parameter (no `required`):
```dart
class AuditsScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final DateTime? filterDate; // NEW — from calendar tap (D-05)

  const AuditsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    this.filterDate, // optional, defaults to null
  });
```

**Mutable state field** — initialized from constructor param in `initState()`. Do NOT use `widget.filterDate` directly in `_filtered` (see Research Pitfall 4 — chip "clear" must work in-screen):
```dart
// In _AuditsScreenState:
DateTime? _activeDateFilter; // NOTE: do NOT use 'late' on nullable fields

@override
void initState() {
  super.initState();
  _activeDateFilter = widget.filterDate; // copy to mutable state
  _load();
  _searchCtrl.addListener(
    () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()),
  );
}
```

**`_filtered` getter extension** (existing getter lines 122–144) — append date filter as the LAST step, after existing `_filter` enum and `_searchQuery` filtering:
```dart
List<Audit> get _filtered {
  var list = _audits.where((a) {
    // ... existing switch on _filter (unchanged) ...
  }).toList();

  if (_searchQuery.isNotEmpty) {
    // ... existing search filter (unchanged) ...
  }

  // ADD: date filter — last step (D-05, same deadline ?? createdAt logic as calendar)
  if (_activeDateFilter != null) {
    final fd = _activeDateFilter!;
    list = list.where((a) {
      final effectiveDate = (a.deadline ?? a.createdAt).toLocal(); // Pitfall 1
      return effectiveDate.year == fd.year &&
          effectiveDate.month == fd.month &&
          effectiveDate.day == fd.day;
    }).toList();
  }

  return list;
}
```

**Dismissible chip in `_buildSearchAndFilters()`** (existing method lines 273–344) — insert ABOVE the existing `SingleChildScrollView` of filter chips. Pattern mirrors `_Tag` widget style but uses Flutter's `Chip` with `onDeleted`:
```dart
Widget _buildSearchAndFilters(AppTheme t) {
  return Container(
    color: t.surface,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ... existing TextField (unchanged) ...
        const SizedBox(height: 10),

        // ADD: date filter chip (only when _activeDateFilter is set)
        if (_activeDateFilter != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              children: [
                Chip(
                  label: Text(
                    'Auditorias de ${_fmtDate(_activeDateFilter!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted: () =>
                      setState(() => _activeDateFilter = null),
                ),
              ],
            ),
          ),
        ],

        // ... existing SingleChildScrollView of FilterChips (unchanged) ...
        const SizedBox(height: 4),
      ],
    ),
  );
}
```

**Date formatter** — reuse the private static `_fmtDate` that already exists on `_InfoGrid` (line 614), but `_InfoGrid` is a separate `StatelessWidget`. Define a file-level static or duplicate it on `_AuditsScreenState`:
```dart
// Add as private static method on _AuditsScreenState:
static String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year}';
```

**Empty state text update** (lines 386–399) — extend condition to also cover `_activeDateFilter`:
```dart
// EXISTING condition (line 386):
_searchQuery.isNotEmpty || _filter != _AuditFilter.todas
    ? 'Nenhuma auditoria encontrada'
    : 'Nenhuma auditoria ainda'

// UPDATED condition:
_searchQuery.isNotEmpty ||
        _filter != _AuditFilter.todas ||
        _activeDateFilter != null
    ? (_activeDateFilter != null
        ? 'Nenhuma auditoria em ${_fmtDate(_activeDateFilter!)}'
        : 'Nenhuma auditoria encontrada')
    : 'Nenhuma auditoria ainda'
```

**`FilterChip` pattern** (lines 313–338) — existing chips use `selectedColor: AppColors.primary`, `backgroundColor: t.background`, `side: BorderSide(...)`. The new `Chip` (not `FilterChip`) uses the theme's default chip style — keep it simple.

---

### `primeaudit/lib/services/audit_service.dart` — No new service method needed

**Analog:** same file (reuse `getAudits()`)

**Research conclusion:** `getAudits()` (lines 32–39) already fetches all company audits. The calendar bucketing in `_loadDashboard()` reuses this list client-side. **No new service method is added in this phase.** The research recommends `getAuditsForMonth()` as a future optimization only.

**Existing `getAudits()` signature** (lines 32–39) — unchanged:
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

**If a `getAuditsForMonth()` is added later**, copy this exact signature style and add `gte`/`lte` filters:
```dart
Future<List<Audit>> getAuditsForMonth({
  String? companyId,
  required int year,
  required int month,
}) async {
  final start = DateTime(year, month, 1).toIso8601String();
  final end = DateTime(year, month + 1, 0).toIso8601String();
  var query = _client.from('audits').select(_select);
  if (companyId != null) query = query.eq('company_id', companyId);
  // Note: PostgREST .or() across two date columns is complex;
  // fetching by created_at range and bucketing client-side is simpler.
  final data = await query
      .gte('created_at', start)
      .lte('created_at', end)
      .order('created_at', ascending: false);
  return (data as List).map((e) => Audit.fromMap(e)).toList();
}
```

---

### `primeaudit/test/services/calendar_data_test.dart` — New unit tests

**Analog:** `primeaudit/test/services/dashboard_service_test.dart` (exact match)

**File header pattern** (lines 1–9 of dashboard_service_test.dart):
```dart
// Unit tests for calendar data bucketing logic (CAL-01, D-03, D-04).
// Tests pure computation helpers that mirror logic inside _HomeScreenState.
// Does NOT instantiate any service (Supabase.instance.client throws in tests).
//
// Requirements: CAL-01 (bucketing, status groups, month filter, D-03 null exclusion)

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit.dart';
```

**`_audit()` test factory** (lines 12–37 of dashboard_service_test.dart) — copy and extend with `deadline` parameter:
```dart
Audit _audit({
  String id = 'a1',
  String templateName = 'Template A',
  AuditStatus status = AuditStatus.emAndamento,
  double? conformityPercent,
  String auditorId = 'user1',
  DateTime? createdAt,
  DateTime? deadline,
}) {
  return Audit(
    id: id,
    title: 'Test Audit',
    auditTypeId: 'at1',
    auditTypeName: 'Type',
    auditTypeIcon: '📋',
    auditTypeColor: '#2196F3',
    templateId: 't1',
    templateName: templateName,
    companyId: 'c1',
    companyName: 'Acme',
    companyRequiresPerimeter: false,
    auditorId: auditorId,
    auditorName: 'Ana',
    createdAt: createdAt ?? DateTime(2026, 5, 1),
    deadline: deadline,
    status: status,
    conformityPercent: conformityPercent,
  );
}
```

**Pure helper** — copy `_buildCalendarData` logic directly into the test file as a top-level function (same pattern as `_countTotal`, `_buildChartData` etc. in `dashboard_service_test.dart`):
```dart
// Mirrors _HomeScreenState._buildCalendarData() — keep in sync manually.
Map<String, List<Audit>> _buildCalendarData(
    List<Audit> audits, int year, int month) {
  final Map<String, List<Audit>> data = {};
  for (final audit in audits) {
    if (audit.status == AuditStatus.cancelada) continue;
    final effectiveDate = (audit.deadline ?? audit.createdAt).toLocal();
    if (effectiveDate.year == year && effectiveDate.month == month) {
      final key =
          '${effectiveDate.year}-'
          '${effectiveDate.month.toString().padLeft(2, "0")}-'
          '${effectiveDate.day.toString().padLeft(2, "0")}';
      data.putIfAbsent(key, () => []).add(audit);
    }
  }
  return data;
}
```

**`group()` / `test()` structure** (lines 71–241 of dashboard_service_test.dart):
```dart
void main() {
  group('_buildCalendarData — deadline ?? createdAt bucketing', () {
    test('audit with deadline is bucketed by deadline date', () { ... });
    test('audit with null deadline is bucketed by createdAt', () { ... });
    test('audit with both null is excluded (not expected in prod)', () { ... });
    test('audit outside target month is excluded', () { ... });
  });

  group('_buildCalendarData — cancelada exclusion (D-04)', () {
    test('cancelada audit is never included', () { ... });
  });

  group('_buildCalendarData — status grouping helpers', () {
    test('novas = rascunho + emAndamento', () { ... });
    test('atrasadas = atrasada only', () { ... });
    test('concluidas = concluida only', () { ... });
    test('cancelada is never counted in any group', () { ... });
  });
}
```

---

### `primeaudit/test/screens/audits_screen_date_filter_test.dart` — New unit tests

**Analog:** `primeaudit/test/screens/audit_execution_ordering_test.dart` (pure-function pattern for screen logic)

**File header pattern** (lines 1–11 of audit_execution_ordering_test.dart):
```dart
// Unit tests for AuditsScreen._filtered date filter logic (CAL-02).
// Tests the date filter as a pure function — does NOT instantiate the screen
// (Supabase.instance.client throws in tests).
//
// Requirements: CAL-02 (date filter in _filtered, chip clear behavior)

import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/audit.dart';
```

**Pure helper** — extract `_filtered` date-filter step as a top-level function in the test file:
```dart
// Mirrors _AuditsScreenState._filtered date-filter step — keep in sync manually.
List<Audit> _applyDateFilter(List<Audit> audits, DateTime? filterDate) {
  if (filterDate == null) return audits;
  return audits.where((a) {
    final effectiveDate = (a.deadline ?? a.createdAt).toLocal();
    return effectiveDate.year == filterDate.year &&
        effectiveDate.month == filterDate.month &&
        effectiveDate.day == filterDate.day;
  }).toList();
}
```

**`group()` / `test()` structure**:
```dart
void main() {
  group('_filtered date filter — keeps only same-day audits (CAL-02)', () {
    test('null filterDate returns all audits unchanged', () { ... });
    test('filterDate keeps only audits with matching deadline', () { ... });
    test('filterDate falls back to createdAt when deadline is null', () { ... });
    test('filterDate excludes audits on different days', () { ... });
  });

  group('_filtered date filter — clear filter (chip onDeleted)', () {
    test('setting _activeDateFilter to null restores full list', () { ... });
    // Note: chip onDeleted sets _activeDateFilter = null in state;
    // test simulates this by calling _applyDateFilter(audits, null)
  });
}
```

---

## Shared Patterns

### `AppTheme.of(context)` — Theme-aware tokens
**Source:** `primeaudit/lib/core/app_theme.dart` (referenced throughout both screen files)
**Apply to:** All new widget code in `home_screen.dart` and `audits_screen.dart`
```dart
final t = AppTheme.of(context);
// Token usage:
t.background    // scaffold/fill background
t.surface       // card/container background
t.textPrimary   // heading text color
t.textSecondary // secondary/hint text color — USE THIS, NOT AppColors.textSecondary
t.divider       // border/divider color
```

### `withValues(alpha:)` — Color opacity pattern
**Source:** `primeaudit/lib/screens/home_screen.dart` (line 467), `audits_screen.dart` (line 466, 595, 597, 698)
**Apply to:** ALL color opacity usage in new calendar widgets
```dart
// CORRECT:
color.withValues(alpha: 0.12)
AppColors.error.withValues(alpha: 0.4)
AppColors.primary.withValues(alpha: 0.06)
// WRONG (deprecated):
color.withOpacity(0.12)
```

### Loading / error state pattern
**Source:** `primeaudit/lib/screens/home_screen.dart` (lines 76–116), `audits_screen.dart` (lines 109–120, 346–374)
**Apply to:** `_buildCalendar()` and any new async calls
```dart
// Boolean loading flag: setState(() => _dashboardLoading = true) / false
// Error stored as String?: setState(() => _error = 'Erro...$e')
// Guard in build: if (_isLoading) return CircularProgressIndicator(color: AppColors.primary)
// Guard in build: if (_error != null) return Column([Icon, Text(_error!), OutlinedButton(retry)])
```

### SnackBar error pattern
**Source:** `primeaudit/lib/screens/audits_screen.dart` (lines 228–233)
**Apply to:** Any user-facing error in new code
```dart
void _snack(String msg) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    behavior: SnackBarBehavior.floating,
  ));
}
```

### Navigator.push pattern
**Source:** `primeaudit/lib/screens/home_screen.dart` (lines 128–131)
**Apply to:** `_onDayTap()` navigation to `AuditsScreen`
```dart
void _navigate(Widget screen) {
  Navigator.of(context).pop(); // closes drawer
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}
// For _onDayTap (no drawer to close):
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => AuditsScreen(...),
));
```

### `mounted` guard pattern
**Source:** `primeaudit/lib/screens/home_screen.dart` (lines 62, 77, 103, 113, 114)
**Apply to:** All `setState()` calls after `await` in new async methods
```dart
if (mounted) setState(() => _field = value);
if (!mounted) return;
```

---

## No Analog Found

None — all 5 files have direct analogs or are self-modifications to well-understood existing files.

---

## Critical Anti-Patterns (from RESEARCH.md)

| Anti-Pattern | Correct Approach | Source |
|---|---|---|
| `color.withOpacity(x)` | `color.withValues(alpha: x)` | Existing codebase throughout |
| `AppColors.textSecondary` in calendar widgets | `AppTheme.of(context).textSecondary` | `app_colors.dart` vs `app_theme.dart` discrepancy confirmed |
| Adding `intl` package for month names | `const _monthNames = ['Janeiro', ...]` manual list | `pubspec.yaml` has no `intl` |
| Adding `table_calendar` package | Custom `Table`-based grid | Explicitly rejected in 10-UI-SPEC.md |
| `widget.filterDate` directly in `_filtered` | `_activeDateFilter` mutable state field initialized from `widget.filterDate` | Research Pitfall 4 |
| Second `getAudits()` call for calendar | Reuse `audits` list already fetched in `_loadDashboard()` | Research anti-pattern |
| Separate `_calendarLoading` flag | Reuse existing `_dashboardLoading` flag | 10-UI-SPEC.md State Contract |
| `DateTime.parse(...)` raw comparison | `.toLocal()` before `.year`/`.month`/`.day` comparison | Research Pitfall 1 — `Audit.fromMap` lines 104–105 return UTC |

---

## Metadata

**Analog search scope:** `primeaudit/lib/screens/`, `primeaudit/lib/services/`, `primeaudit/lib/models/`, `primeaudit/lib/core/`, `primeaudit/test/`
**Files scanned:** 8 source files (full reads) + 2 test structure files
**Pattern extraction date:** 2026-05-01
