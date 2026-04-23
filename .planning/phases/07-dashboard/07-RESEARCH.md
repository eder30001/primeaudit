# Phase 7: Dashboard — Research

**Researched:** 2026-04-23
**Domain:** Flutter dashboard — KPI cards, role-scoped data, pull-to-refresh, fl_chart bar chart
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Card "Total" = todas as auditorias exceto canceladas: `rascunho + em_andamento + concluida + atrasada`.
- **D-02:** Card "Pendentes" = apenas `em_andamento`.
- **D-03:** Card "Atrasadas" = auditorias com `status == atrasada`.
- **D-04:** Card "Ações abertas" = count da tabela `corrective_actions` (Phase 8). Retornar `0` como fallback antes da migration existir. Card sempre visível.
- **D-05:** Auditor vê apenas suas próprias auditorias (`auditor_id == currentUser.id`).
- **D-06:** Admin/Adm vê todas as auditorias da empresa ativa (`company_id == activeCompanyId`).
- **D-07:** Superuser/Dev segue escopo Admin/Adm + card extra com total de empresas.
- **fl_chart** escolhido para DASH-03. Não adicionar duas vezes ao pubspec (Phase 10 REP-04 também usa).
- Pull-to-refresh via `RefreshIndicator` wrapping `SingleChildScrollView` existente.

### Claude's Discretion

- **Estratégia de dados:** Claude decide entre fetch completo + count em Dart vs COUNT queries individuais. Fetch único com contagem em Dart é aceitável dada a escala.
- **DashboardService:** Somente se necessário para isolar lógica de agregação.
- **Gráfico (DASH-03):** Claude decide tipo (bar chart horizontal recomendado) e período ("recente" = últimos 90 dias ou sem filtro — usar `conformity_percent` nas auditorias concluídas).
- **Layout:** Gráfico posicionado abaixo dos 4 cards, substituindo seção "Atividade recente" placeholder.

### Deferred Ideas (OUT OF SCOPE)

- Gráfico interativo com filtro de período.
- Seção "Atividade recente" com lista das últimas N auditorias.
- KPIs em tempo real via Supabase Realtime.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DASH-01 | Usuário vê cards com total de auditorias, pendentes, atrasadas e ações em aberto (scoped por empresa) | AuditService.getAudits() + Dart-side filter; corrective_actions fallback 0 |
| DASH-02 | Usuário pode atualizar o dashboard via pull-to-refresh | RefreshIndicator + _loadDashboard() on refresh callback |
| DASH-03 | Usuário vê gráfico de conformidade média por template de auditoria | fl_chart 1.2.0 BarChart; data derived from Audit.conformityPercent grouped by templateName |
</phase_requirements>

---

## Summary

Phase 7 converts the static `_buildDashboard()` placeholder in `home_screen.dart` into a functional dashboard. The work is self-contained: no new screens, no navigation changes, no new tables required for the core KPI cards. The implementation adds a `_loadDashboard()` call chained after `_loadProfile()` (which sets `_role`), fetches audits via the existing `AuditService.getAudits()`, counts them in Dart by status, and renders results through the existing `_summaryCard()` widget (which only needs its `value` parameter changed from `'—'` to a real count string).

The `corrective_actions` fallback is straightforward: wrap the Supabase count query in a try/catch, return 0 on any exception. This eliminates ordering dependency on Phase 8.

DASH-03 (conformity chart) requires adding `fl_chart ^1.2.0` to `pubspec.yaml` and building a `BarChart` widget from audits grouped by `templateName` with `conformityPercent`. The `rotationQuarterTurns: 1` approach gives horizontal bars suited for template name labels.

**Primary recommendation:** Single fetch strategy (`getAudits()` once, filter in Dart) + optional `DashboardService` wrapper for aggregation isolation. The role-scoped fetch (auditor_id filter for auditors) requires adding a new method to `AuditService` since the existing `getAudits()` only accepts `companyId`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| KPI card rendering | Flutter Widget (HomeScreen) | — | Pure UI; data computed in state |
| Data fetching + aggregation | Service layer (AuditService / DashboardService) | — | Follows project pattern: screens call services, not Supabase directly |
| Role-scoped data filtering | Service layer | UI layer (auditor_id check) | Auditor filter can be DB-side (eq auditor_id) or Dart-side from fetched list |
| Corrective actions count | Service layer (try/catch fallback) | — | Isolated fallback; Phase 8 activates real query |
| Pull-to-refresh | UI layer (RefreshIndicator) | — | Standard Flutter widget; calls _loadDashboard() |
| Chart data aggregation | State (_HomeScreenState) | — | Group-by-template + average; pure Dart computation on already-fetched list |
| Chart rendering | Flutter Widget (fl_chart BarChart) | — | Library widget, configured in _buildDashboard() |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `supabase_flutter` | `2.12.2` (already installed) | Supabase client for audit data fetch | Already in project; provides PostgREST query builder |
| `fl_chart` | `^1.2.0` | Bar chart for DASH-03 conformity chart | Decided in CONTEXT.md; pub.dev 7k+ likes, 1.2M+ downloads, MIT |
| `flutter_test` SDK | already installed | Unit tests for aggregation logic | Project standard test framework |

[VERIFIED: pub.dev] fl_chart 1.2.0 is current stable (published ~41 days ago). Requires Dart SDK >=3.6 — project uses >=3.11.4 so no conflict.

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `shared_preferences` | already installed | CompanyContextService reads from it | Already used; no new dependency |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fl_chart BarChart | fl_chart LineChart | Line chart suits time-series; bar chart suits per-template comparison |
| Single fetch + Dart filter | COUNT queries per status | COUNT queries reduce payload but add 3+ round trips; Dart filter is simpler at expected scale |
| DashboardService | Logic inline in _HomeScreenState | Service is cleaner for testing; acceptable either way given project convention |

**Installation:**
```bash
# In primeaudit/ directory
flutter pub add fl_chart
```
Or manually add to `primeaudit/pubspec.yaml`:
```yaml
dependencies:
  fl_chart: ^1.2.0
```
Then run `flutter pub get`.

---

## Architecture Patterns

### System Architecture Diagram

```
User (pull-to-refresh OR initState)
         │
         ▼
_loadDashboard() in _HomeScreenState
         │
         ├──► AuditService.getAudits(companyId: X)       ──► Supabase audits table (with joins)
         │         └── filter auditor_id in Dart if role == auditor
         │
         ├──► DashboardService.getOpenActionsCount(companyId)
         │         └── try { Supabase COUNT corrective_actions } catch { return 0 }
         │
         └──► [superuser/dev only] DashboardService.getCompaniesCount()
                   └── Supabase COUNT companies
         │
         ▼
setState() with:
  _totalAudits, _pendingAudits, _overdueAudits,
  _openActions, _companiesCount (optional),
  _chartData (List<_TemplateConformity>)
         │
         ▼
_buildDashboard()
  ├── Row: _summaryCard(Total), _summaryCard(Pendentes)
  ├── Row: _summaryCard(Atrasadas), _summaryCard(Ações / Empresas)
  └── _ConformityBarChart (fl_chart BarChart)
```

### Recommended Project Structure

No new directories. All changes within:
```
primeaudit/lib/
├── screens/
│   └── home_screen.dart          # Modified: _loadDashboard(), state fields, chart widget
├── services/
│   └── dashboard_service.dart    # NEW (optional): getOpenActionsCount(), getCompaniesCount()
└── pubspec.yaml                  # Modified: add fl_chart ^1.2.0
```

### Pattern 1: AuditService Role-Scoped Fetch

The existing `getAudits({String? companyId})` fetches all company audits. For auditors (D-05), an auditor_id filter is needed. Two valid approaches:

**Option A — Add method to AuditService (recommended):**
```dart
// Source: matches project convention in audit_service.dart
Future<List<Audit>> getAuditsForDashboard({
  String? companyId,
  String? auditorId,
}) async {
  var query = _client.from('audits').select(_select);
  if (companyId != null) query = query.eq('company_id', companyId);
  if (auditorId != null) query = query.eq('auditor_id', auditorId);
  final data = await query.order('created_at', ascending: false);
  return (data as List).map((e) => Audit.fromMap(e)).toList();
}
```

**Option B — Dart-side filter (acceptable, simpler):**
```dart
// Fetch all company audits, filter in Dart
final all = await _auditService.getAudits(companyId: companyId);
final audits = isAuditor
    ? all.where((a) => a.auditorId == currentUserId).toList()
    : all;
```

Option B is simpler and follows the pattern already used in `AuditsScreen._filtered`. Given the scale (audits per company expected to be low-medium), Option B is acceptable and requires no service modification.

[VERIFIED: codebase grep] `AuditsScreen` already uses Dart-side filter for `_AuditFilter.minhas`: `a.auditorId == widget.currentUserId`.

### Pattern 2: KPI Count Computation in Dart

```dart
// Source: [VERIFIED: codebase] AuditStatus enum values confirmed in audit.dart
int _countTotal(List<Audit> audits) =>
    audits.where((a) => a.status != AuditStatus.cancelada).length;

int _countPending(List<Audit> audits) =>
    audits.where((a) => a.status == AuditStatus.emAndamento).length;

int _countOverdue(List<Audit> audits) =>
    audits.where((a) => a.status == AuditStatus.atrasada).length;
```

### Pattern 3: Corrective Actions Fallback

```dart
// Source: [ASSUMED] — corrective_actions table does not exist yet (Phase 8)
Future<int> getOpenActionsCount(String? companyId) async {
  try {
    final query = _client
        .from('corrective_actions')
        .select('id', const FetchOptions(count: CountOption.exact, head: true));
    // add companyId filter if needed
    final response = await query;
    return response.count ?? 0;
  } catch (_) {
    return 0; // fallback when table doesn't exist
  }
}
```

[VERIFIED: codebase] `corrective_actions` table does not exist in codebase (grep found no references). The try/catch fallback pattern is the correct approach.

### Pattern 4: fl_chart BarChart for Conformity by Template

[VERIFIED: pub.dev docs] fl_chart 1.2.0 BarChart data structures:

```dart
// Source: [CITED: pub.dev/documentation/fl_chart/latest]
// Horizontal bars via rotationQuarterTurns: 1
BarChart(
  BarChartData(
    rotationQuarterTurns: 1,       // makes bars horizontal
    barGroups: _chartGroups,        // List<BarChartGroupData>
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) =>
              Text(_templateNames[value.toInt()], style: const TextStyle(fontSize: 10)),
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    maxY: 100,
    borderData: FlBorderData(show: false),
    gridData: const FlGridData(show: false),
  ),
)

// Building groups from audits grouped by template:
List<BarChartGroupData> _buildChartGroups(List<Audit> audits) {
  // Group concluida audits by templateName, average conformityPercent
  final Map<String, List<double>> byTemplate = {};
  for (final a in audits) {
    if (a.status == AuditStatus.concluida && a.conformityPercent != null) {
      byTemplate.putIfAbsent(a.templateName, () => []).add(a.conformityPercent!);
    }
  }
  final entries = byTemplate.entries.toList();
  return List.generate(entries.length, (i) {
    final avg = entries[i].value.reduce((a, b) => a + b) / entries[i].value.length;
    return BarChartGroupData(
      x: i,
      barRods: [
        BarChartRodData(
          toY: avg,
          color: AppColors.primary,
          width: 16,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  });
}
```

[VERIFIED: pub.dev docs] `BarChartGroupData` requires `x: int` and `barRods: List<BarChartRodData>`. `BarChartRodData` requires `toY: double`. All other fields optional.

### Pattern 5: Pull-to-Refresh Integration

[VERIFIED: codebase] `AuditsScreen` already uses `RefreshIndicator` wrapping `ListView`:
```dart
// home_screen.dart — wrap existing SingleChildScrollView
RefreshIndicator(
  onRefresh: _loadDashboard,
  child: SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(), // required for pull-to-refresh on short content
    padding: const EdgeInsets.all(20),
    child: Column(...),
  ),
)
```

`AlwaysScrollableScrollPhysics` is required — without it, `RefreshIndicator` only activates when content overflows the viewport. The current dashboard placeholder may be short enough that refresh won't trigger without it.

### Pattern 6: Load Sequence in HomeScreen

[VERIFIED: codebase] Current `_loadProfile()` sets `_role` then calls `setState()`. Dashboard load depends on `_role` being set first (to determine auditor vs admin scope). Two approaches:

**Option A — Chain after profile (recommended):**
```dart
Future<void> _loadProfile() async {
  try {
    // ... existing profile load ...
    if (mounted) setState(() { _role = ...; _name = ...; });
    await _loadDashboard(); // role now available
  } catch (_) { ... }
}
```

**Option B — Separate _load() triggered by role change in setState:**
Less clean; avoid.

The `_loading` flag currently controls both profile and body display. Phase 7 should introduce a separate `_dashboardLoading` flag to allow dashboard to reload independently (pull-to-refresh) without showing full-screen spinner.

### Anti-Patterns to Avoid

- **Do not use COUNT queries for all KPIs separately:** Three round trips for total/pending/overdue when one fetch + Dart filter achieves the same result. [ASSUMED: likely fine at expected scale]
- **Do not hide the "Ações abertas" card when table is missing:** Per D-04, card must always render (value shows 0 as fallback).
- **Do not check `canAccessAdmin` for the extra companies card:** D-07 specifies superuser/dev, not all admins. Use `AppRole.isSuperOrDev(_role)` — `canAccessAdmin` also includes `adm` which should NOT see the companies count card. [VERIFIED: codebase] `AppRole.isSuperOrDev` is already correct helper.
- **Do not wrap SingleChildScrollView without AlwaysScrollableScrollPhysics:** RefreshIndicator requires it on short content.
- **Do not add fl_chart twice to pubspec.yaml:** Phase 10 (REP-04) also uses it. Check before adding. [VERIFIED: codebase] `fl_chart` is NOT in current `pubspec.yaml` or `pubspec.lock` — safe to add now.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bar chart rendering | Custom Canvas/CustomPainter chart | `fl_chart BarChart` | Touch handling, animations, label clipping, axis scaling all included |
| Pull-to-refresh gesture | GestureDetector + scroll position tracking | `RefreshIndicator` | Standard Flutter widget; handles edge cases, overscroll, platform UX |
| Percentage bar/gauge | Custom painted widget | `LinearProgressIndicator` or fl_chart | Already exists in Flutter SDK |

**Key insight:** The Dart-side aggregation (count by status, group-by-template average) is appropriate to hand-roll because it's pure arithmetic on an already-fetched list — no external library needed.

---

## Runtime State Inventory

> Not applicable — this is a greenfield feature addition (new UI + new dependency), not a rename/refactor/migration phase.

---

## Common Pitfalls

### Pitfall 1: Empty Chart Crashes

**What goes wrong:** `BarChart` with an empty `barGroups` list renders a blank area without error, but `getTitlesWidget` may be called with out-of-range indices if `_templateNames` list is out of sync with groups.

**Why it happens:** Chart is built before data loads, or all audits lack `conformity_percent` (e.g., all are `em_andamento` with no score yet).

**How to avoid:** Guard the chart widget: only render if `_chartData.isNotEmpty`. Show an empty state message ("Nenhuma auditoria concluída para exibir") otherwise.

**Warning signs:** RangeError on `_templateNames[value.toInt()]`.

### Pitfall 2: Role Available Race Condition

**What goes wrong:** `_loadDashboard()` is called before `_role` is set, so the auditor scope filter is skipped and all company audits are shown to an auditor.

**Why it happens:** If `_loadDashboard()` is called in `initState()` independently from `_loadProfile()`, `_role` is still `''` during the first fetch.

**How to avoid:** Always call `_loadDashboard()` after `_role` is set — chain it inside `_loadProfile()` after the `setState()` that sets `_role`.

**Warning signs:** Auditor sees other people's audits on the dashboard; cards show higher counts than expected.

### Pitfall 3: CompanyContextService Not Yet Initialized

**What goes wrong:** `CompanyContextService.instance.activeCompanyId` returns null for superuser/dev if called before `init()` completes.

**Why it happens:** `_loadDashboard()` could theoretically be called before `CompanyContextService.instance.init()` inside `_loadProfile()`.

**How to avoid:** Chain `_loadDashboard()` only after the profile load (including `CompanyContextService.instance.init()`) succeeds. [VERIFIED: codebase] `_loadProfile()` calls `init()` before `setState()` — chaining after `setState()` is safe.

**Warning signs:** Superuser dashboard shows global unscoped data.

### Pitfall 4: AlwaysScrollableScrollPhysics Missing

**What goes wrong:** Pull-to-refresh gesture does nothing when dashboard content fits within viewport without scrolling.

**Why it happens:** `RefreshIndicator` requires the inner scroll view to be scrollable. Without `AlwaysScrollableScrollPhysics`, a short `SingleChildScrollView` is not scrollable.

**How to avoid:** Set `physics: const AlwaysScrollableScrollPhysics()` on the `SingleChildScrollView`.

**Warning signs:** Pull-to-refresh only works on phones with small screens where content overflows.

### Pitfall 5: fl_chart Version Conflict with Phase 10

**What goes wrong:** Phase 10 (REP-04) adds `fl_chart` again, causing a duplicate key error in `pubspec.yaml` or accidental version downgrade.

**Why it happens:** Phase 10 implementer doesn't check if `fl_chart` is already present.

**How to avoid:** Note in Phase 10 planning that `fl_chart` was added in Phase 7. [VERIFIED: STATE.md] This is already recorded: "fl_chart adicionado em Phase 7 (DASH-03) e reaproveitado em Phase 10 (REP-04) — não adicionar duas vezes ao pubspec."

**Warning signs:** `flutter pub get` error about duplicate dependency.

---

## Code Examples

### Minimal fl_chart BarChart (Horizontal, Conformity by Template)

```dart
// Source: [CITED: pub.dev/documentation/fl_chart/latest/fl_chart/BarChartData-class.html]
// Source: [CITED: pub.dev/documentation/fl_chart/latest/fl_chart/BarChartGroupData-class.html]
// Source: [CITED: pub.dev/documentation/fl_chart/latest/fl_chart/BarChartRodData-class.html]

import 'package:fl_chart/fl_chart.dart';

Widget _buildConformityChart(List<_TemplateConformity> data) {
  if (data.isEmpty) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      child: Text(
        'Nenhuma auditoria concluída',
        style: TextStyle(color: AppTheme.of(context).textSecondary, fontSize: 13),
      ),
    );
  }

  return SizedBox(
    height: data.length * 48.0 + 40,
    child: BarChart(
      BarChartData(
        rotationQuarterTurns: 1,
        maxY: 100,
        barGroups: List.generate(data.length, (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data[i].avgConformity,
              color: AppColors.primary,
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        )),
        titlesData: FlTitlesData(
          // With rotationQuarterTurns:1, "left" axis becomes the bar labels
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 120,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                return Text(
                  data[idx].templateName,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) =>
                  Text('${value.toInt()}%', style: const TextStyle(fontSize: 9)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    ),
  );
}

// Data model (private, in home_screen.dart)
class _TemplateConformity {
  final String templateName;
  final double avgConformity; // 0.0–100.0

  const _TemplateConformity(this.templateName, this.avgConformity);
}

// Builder
List<_TemplateConformity> _buildChartData(List<Audit> audits) {
  final Map<String, List<double>> byTemplate = {};
  for (final a in audits) {
    if (a.status == AuditStatus.concluida && a.conformityPercent != null) {
      byTemplate.putIfAbsent(a.templateName, () => []).add(a.conformityPercent!);
    }
  }
  return byTemplate.entries.map((e) {
    final avg = e.value.reduce((a, b) => a + b) / e.value.length;
    return _TemplateConformity(e.key, avg);
  }).toList()
    ..sort((a, b) => b.avgConformity.compareTo(a.avgConformity)); // best first
}
```

### State Fields to Add to _HomeScreenState

```dart
// Source: [VERIFIED: codebase] — follows project's _isLoading/_error pattern
int _totalAudits = 0;
int _pendingAudits = 0;
int _overdueAudits = 0;
int _openActions = 0;
int _companiesCount = 0;        // only used for superuser/dev
List<_TemplateConformity> _chartData = [];
bool _dashboardLoading = false;
String? _dashboardError;
```

### _loadDashboard() Pattern

```dart
// Source: [VERIFIED: codebase] — matches _load() pattern in AuditsScreen
Future<void> _loadDashboard() async {
  if (!mounted) return;
  setState(() { _dashboardLoading = true; _dashboardError = null; });
  try {
    final companyId = CompanyContextService.instance.activeCompanyId;
    final currentUserId = _authService.currentUser?.id ?? '';

    // 1. Fetch audits (role-scoped)
    final all = await _auditService.getAudits(companyId: companyId);
    final audits = AppRole.isSuperOrDev(_role) || AppRole.canAccessAdmin(_role)
        ? all
        : all.where((a) => a.auditorId == currentUserId).toList();

    // 2. Compute KPIs
    final total    = audits.where((a) => a.status != AuditStatus.cancelada).length;
    final pending  = audits.where((a) => a.status == AuditStatus.emAndamento).length;
    final overdue  = audits.where((a) => a.status == AuditStatus.atrasada).length;

    // 3. Open actions (fallback 0)
    int openActions = 0;
    try {
      final res = await Supabase.instance.client
          .from('corrective_actions')
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('company_id', companyId ?? '')
          .eq('status', 'aberta');
      openActions = res.count ?? 0;
    } catch (_) {
      openActions = 0;
    }

    // 4. Companies count (superuser/dev only)
    int companiesCount = 0;
    if (AppRole.isSuperOrDev(_role)) {
      final res = await Supabase.instance.client
          .from('companies')
          .select('id', const FetchOptions(count: CountOption.exact, head: true));
      companiesCount = res.count ?? 0;
    }

    // 5. Chart data
    final chartData = _buildChartData(audits);

    if (mounted) {
      setState(() {
        _totalAudits = total;
        _pendingAudits = pending;
        _overdueAudits = overdue;
        _openActions = openActions;
        _companiesCount = companiesCount;
        _chartData = chartData;
      });
    }
  } catch (e) {
    if (mounted) setState(() => _dashboardError = 'Erro ao carregar dashboard.\n$e');
  } finally {
    if (mounted) setState(() => _dashboardLoading = false);
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `fl_chart` 0.x (breaking API changes) | `fl_chart` 1.x stable | fl_chart 1.0.0 ~11 months ago | `BarChartRodData.colors` removed; use `color` (single) |
| `color` deprecated warning | Use `.withValues(alpha: ...)` not `.withOpacity(...)` | Flutter 3.x | Already used in project: `color.withValues(alpha: 0.12)` in `_summaryCard` |

**Deprecated/outdated:**
- `fl_chart` `colors: [Color]` list on `BarChartRodData` — replaced by single `color` or `gradient` in v1.x [CITED: pub.dev changelog].
- `withOpacity()` — project already uses `withValues(alpha: ...)` which is the correct API.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All Dart/Flutter code | ✓ | >=3.38.4 (locked) | — |
| `fl_chart` | DASH-03 chart | ✗ (not in pubspec yet) | — | None — must add |
| Supabase `corrective_actions` table | DASH-01 open actions | ✗ (Phase 8) | — | Return 0 via try/catch |
| Dart SDK | All code | ✓ | >=3.11.4 | — |

**Missing dependencies with no fallback:**
- `fl_chart` must be added to `pubspec.yaml` before DASH-03 can be implemented. Installation: `flutter pub add fl_chart` in `primeaudit/` directory.

**Missing dependencies with fallback:**
- `corrective_actions` table: fallback is returning 0 (D-04 confirmed in CONTEXT.md).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` SDK (no version — bundled with Flutter) |
| Config file | none — standard Flutter test discovery |
| Quick run command | `flutter test test/services/dashboard_service_test.dart` (Wave 0 gap) |
| Full suite command | `flutter test` in `primeaudit/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DASH-01 | KPI counts correct (total excludes cancelled, pending = emAndamento only, overdue = atrasada) | unit | `flutter test test/services/dashboard_service_test.dart -x` | ❌ Wave 0 |
| DASH-01 | Role scope: auditor sees only own audits in counts | unit | `flutter test test/services/dashboard_service_test.dart::auditor_scope -x` | ❌ Wave 0 |
| DASH-01 | Open actions returns 0 when table missing | unit | `flutter test test/services/dashboard_service_test.dart::fallback -x` | ❌ Wave 0 |
| DASH-02 | Pull-to-refresh triggers data reload | manual | — | manual only — widget test requires Supabase init |
| DASH-03 | Chart data grouping: audits grouped by templateName, average conformity correct | unit | `flutter test test/services/dashboard_service_test.dart::chart_data -x` | ❌ Wave 0 |
| DASH-03 | Empty chart state: no concluida audits shows empty state (not crash) | unit | `flutter test test/services/dashboard_service_test.dart::empty_chart -x` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/services/dashboard_service_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/services/dashboard_service_test.dart` — covers DASH-01 counts, role scope, fallback, DASH-03 chart data grouping and empty state
- [ ] If `DashboardService` is not created, aggregation logic tested via `home_screen.dart` private helpers — use `@visibleForTesting` annotation or extract to pure functions in a testable location

*(Existing test infrastructure: `flutter_test` SDK already installed, test directory exists with 14 test files. No new framework setup needed.)*

---

## Security Domain

> Phase 7 is UI-only with read-only Supabase queries. No new mutations, no new auth surfaces.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Handled by existing Supabase auth gate |
| V3 Session Management | no | Existing `_AuthGate` / `StreamBuilder<AuthState>` |
| V4 Access Control | yes | Role-scoped queries via `_role` + `AppRole` helpers; auditor cannot see other's audits |
| V5 Input Validation | no | No user text input in this phase |
| V6 Cryptography | no | No new crypto operations |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Auditor sees other users' KPIs | Info disclosure | Dart-side filter (`auditor_id == currentUserId`) + RLS on `audits` table already enforces this at DB level |
| Open actions count leaks cross-company data | Info disclosure | Pass `company_id` filter to `corrective_actions` query when table exists |

**RLS note:** [ASSUMED] The existing RLS policy on `audits` table (from Phase 2 security work) should already restrict auditors to their own records. The Dart-side filter is defense-in-depth, not the primary enforcement layer.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dart-side auditor filter is sufficient given low-medium audit volume per company | Architecture Patterns Pattern 1 | If scale grows large (1000+ audits/company), fetch + filter wastes bandwidth; would need DB-side filter |
| A2 | `corrective_actions` table absence throws an exception (not silent empty result) in PostgREST | Code Examples _loadDashboard | If PostgREST returns empty list instead of throwing, the catch block never fires and `openActions` stays 0 anyway — no functional impact |
| A3 | RLS on `audits` table already enforces auditor scope at DB level (Phase 2) | Security Domain | If RLS is missing or misconfigured, the Dart-side filter is the only gate; KPI cards would still be correct, but underlying fetch returns more data than needed |
| A4 | `fl_chart` 1.2.0 BarChart `rotationQuarterTurns: 1` produces correct horizontal layout with left-axis template labels | Code Examples fl_chart pattern | If axis label positioning is off with horizontal rotation, may need to switch to vertical BarChart with truncated labels or use `leftTitles` differently |
| A5 | `companies` table is accessible to superuser/dev without company_id filter for count | Code Examples _loadDashboard | If RLS restricts companies table, the count query will fail — would need a different approach (e.g., admin API or edge function) |

---

## Open Questions

1. **DashboardService vs inline in HomeScreen**
   - What we know: Project convention allows services instanced per-screen; CompanyContextService is the only singleton exception.
   - What's unclear: Whether the aggregation methods warrant a service class for testability.
   - Recommendation: Create `DashboardService` to isolate `getOpenActionsCount()` and `getCompaniesCount()`. Aggregation (counting by status, building chart data) stays in `_HomeScreenState` as private helpers since it's pure Dart arithmetic on an already-fetched list.

2. **Chart time period for DASH-03**
   - What we know: CONTEXT.md says "recente = últimos 90 dias ou sem filtro — usar dados disponíveis."
   - What's unclear: Whether "recente" matters when total audit volume is low.
   - Recommendation: No date filter for now (use all concluida audits). The empty-state guard handles the case where no completed audits exist. This matches the Claude's Discretion grant.

3. **Superuser with no active company context**
   - What we know: `CompanyContextService.instance.activeCompanyId` can be null for superuser/dev if no company was selected in a previous session.
   - What's unclear: Should the dashboard show cross-company totals (all audits, no company filter) or show "select a company" prompt?
   - Recommendation: If `activeCompanyId` is null for superuser, pass `companyId: null` to `getAudits()` to get all audits. The existing `AuditService.getAudits(companyId: null)` already handles this (returns all). This is already the existing behavior.

---

## Sources

### Primary (HIGH confidence)

- [VERIFIED: codebase] `primeaudit/lib/screens/home_screen.dart` — confirmed `_buildDashboard()`, `_summaryCard()`, `SingleChildScrollView`, `_loading` flag, `_role` field
- [VERIFIED: codebase] `primeaudit/lib/services/audit_service.dart` — confirmed `getAudits({String? companyId})` signature returning `List<Audit>`
- [VERIFIED: codebase] `primeaudit/lib/models/audit.dart` — confirmed `AuditStatus` enum values and `conformityPercent: double?`
- [VERIFIED: codebase] `primeaudit/lib/core/app_roles.dart` — confirmed `AppRole.isSuperOrDev()`, `AppRole.canAccessAdmin()`
- [VERIFIED: codebase] `primeaudit/lib/services/company_context_service.dart` — confirmed `activeCompanyId` getter
- [CITED: pub.dev/packages/fl_chart] — version 1.2.0, Dart SDK >=3.6, current stable
- [CITED: pub.dev/documentation/fl_chart/latest] — `BarChartData`, `BarChartGroupData`, `BarChartRodData` constructor signatures
- [VERIFIED: codebase] `primeaudit/pubspec.yaml` — confirmed `fl_chart` NOT present; safe to add
- [VERIFIED: codebase] grep — `corrective_actions` table has zero references in codebase

### Secondary (MEDIUM confidence)

- [CITED: github.com/imaNNeo/fl_chart docs] — `rotationQuarterTurns: 1` for horizontal bars; verified via pub.dev docs page

### Tertiary (LOW confidence)

- [ASSUMED] PostgREST throws exception (not returns empty) when table doesn't exist — low risk since catch returns 0 either way

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — fl_chart version verified on pub.dev; all other deps already in project
- Architecture: HIGH — all integration points verified in codebase
- Pitfalls: HIGH — verified by reading actual code patterns; race condition confirmed by code flow analysis
- fl_chart API: MEDIUM-HIGH — verified from pub.dev documentation; one detail (axis label positioning with horizontal rotation) tagged ASSUMED

**Research date:** 2026-04-23
**Valid until:** 2026-05-23 (fl_chart stable; internal code stable; 30 days)
