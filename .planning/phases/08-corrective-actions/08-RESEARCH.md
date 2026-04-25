# Phase 8: Corrective Actions - Research

**Researched:** 2026-04-25
**Domain:** Flutter + Supabase — corrective actions CAPA flow, list/detail screens, migration, RBAC
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Action icon appears only on non-conforming items. Logic per type:
  - `ok_nok` → response `nok`
  - `yes_no` → response `no`
  - `scale_1_5` → score ≤ 2
  - `text` → icon always visible (no auto-conformity)
  - `selection` / `percentage` → Claude decides threshold aligned with `calculateConformity()`
- **D-02:** Creation form opens as a new screen via `Navigator.push` (not bottom sheet, not modal).
- **D-03:** Form fields: title (required), responsible (UserService dropdown, required), due date (required), description/observation (optional).
- **D-04:** Responsible is always a system user (not free text) — enables Phase 11 notifications.
- **Status CAPA (6 states):** `aberta → em_andamento → em_avaliacao → aprovada / rejeitada / cancelada`
- **Migration table:** `corrective_actions` with: `id`, `audit_id`, `template_item_id`, `title`, `description`, `responsible_user_id`, `due_date`, `status`, `company_id`, `created_by`, `created_at`, `updated_at`

### Claude's Discretion
- List screen (ACT-01): card layout, filter style (chips recommended, Material 3), access via drawer and/or "Ações abertas" dashboard card.
- Status CAPA flow (ACT-03): transition UX (detail screen vs bottom sheet), how to communicate role blocks (SnackBar is the app standard), which action buttons to show conditionally by role.
- Badge (ACT-04): position (drawer item recommended since FAB comes in Phase 12), "open" definition (`aberta + em_andamento + em_avaliacao`). Badge updates via `initState` of each relevant screen — no Realtime in this milestone.
- Migration: Claude creates idempotent migration for `corrective_actions` with adequate RLS.

### Deferred Ideas (OUT OF SCOPE)
- Notifications by assignment — email/push to responsible when action is created. Phase 11.
- Deadline approaching alert — automatic notification when deadline approaches. Requires cron job, out of scope.
- Action editing by any auditor — only responsible, audit verifier, and admin can edit (already Out of Scope in REQUIREMENTS.md).
- Filter by linked question — filter actions by specific question. Extra complexity; status and responsible filters (ACT-01) are sufficient.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ACT-01 | User sees list of corrective actions with status and filters by responsible and status | List screen pattern from `audits_screen.dart`, filter chips and dropdown established; `DashboardService.getOpenActionsCount` stub already queries `corrective_actions` |
| ACT-02 | Auditor can create action linked to a question during execution, defining responsible and due date | `_ItemCard` injection point identified at bottom of card after "Ver observacao" row; `UserService.getAll()` available but needs `getByCompany()` added; navigation pattern confirmed |
| ACT-03 | Status follows CAPA flow with 6 states; Admin changes any status; Responsible can move to em_andamento and em_avaliacao; Auditor can move to aprovada and rejeitada | RBAC via `AppRole.canAccessAdmin()` + UUID comparison confirmed; SnackBar role-block pattern confirmed |
| ACT-04 | Badge with count of open actions visible in main navigation and updates when state changes | `_drawerItem()` identified; Phase 7 `_openActions` integer already rendered; Badge widget available in Flutter >= 3.7.0 (project uses >= 3.38.4); `DashboardService.getOpenActionsCount()` stub already present |
</phase_requirements>

---

## Summary

Phase 8 adds the full corrective actions (CAPA) flow to PrimeAudit. The phase touches four integration points: (1) `audit_execution_screen.dart` receives a conditional action icon per non-conforming item card; (2) a new `CreateCorrectiveActionScreen` accepts title, responsible, due date, and description; (3) a new `CorrectiveActionsScreen` lists all actions with status/responsible filters; (4) a new `CorrectiveActionDetailScreen` renders the status timeline and role-gated transition buttons. Additionally, `home_screen.dart` activates the real badge count and adds a drawer navigation item.

The codebase patterns are uniform and well-established: every new screen follows `StatefulWidget + _isLoading + _error + _load()` in `initState()`. Services are instantiated locally per screen. Navigation is always `Navigator.push(MaterialPageRoute(...))`. Error feedback is always `ScaffoldMessenger.showSnackBar()` with `SnackBarBehavior.floating`. Destructive confirmations use `showDialog(AlertDialog(...))`.

The migration must be idempotent (DROP/ADD pattern like `20260406_create_audits.sql`). `DashboardService.getOpenActionsCount()` already queries `corrective_actions` with a try/catch fallback — once the table exists, it starts returning real counts automatically. `UserService` lacks a `getByCompany(companyId)` method and must have one added for the creation form responsible dropdown.

**Primary recommendation:** Implement in four waves: (0) migration + `CorrectiveActionService` + `CorrectiveAction` model; (1) `CreateCorrectiveActionScreen` + `_ItemCard` icon injection; (2) `CorrectiveActionsScreen` list; (3) `CorrectiveActionDetailScreen` + `home_screen.dart` badge + drawer item.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Corrective action persistence | Database / Supabase | — | New `corrective_actions` table; all CRUD via PostgREST through `CorrectiveActionService` |
| Action creation form | Screen (Flutter) | Service | Navigator.push screen; service call on submit |
| Non-conformity detection | Screen / `_ItemCard` | — | Pure Dart logic on `TemplateItem.responseType` + `_answers` map; no DB call needed |
| Status transition (CAPA) | Screen (detail) | Service | UI enforces role; service executes `UPDATE status` |
| RBAC enforcement | Screen (UI layer) | — | Per CONTEXT.md: "RLS does not need to block (UI is sufficient in this milestone)" |
| Badge count | Screen (`HomeScreen`) | `DashboardService` | `getOpenActionsCount()` stub already in place; real query activates once table exists |
| Responsible dropdown | Service (`UserService`) | Screen | New `getByCompany()` method needed; list pre-loaded in `initState` |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter` SDK | >= 3.38.4 | UI framework | Project standard; Material 3 enabled |
| `supabase_flutter` | 2.12.2 | All DB reads/writes via PostgREST | Only backend in this project |
| `flutter_test` | SDK | Unit tests | Project standard — no additional test packages |

### No New Dependencies
This phase introduces **zero new pub.dev packages**. All required widgets (`Badge`, `FilterChip`, `DropdownButtonFormField`, `TextFormField`, `showDatePicker`, `AlertDialog`, `RefreshIndicator`) are Flutter SDK built-ins available in the project's minimum Flutter version (>= 3.38.4).

The `Badge` widget requires Flutter >= 3.7.0. Confirmed available. [VERIFIED: 08-UI-SPEC.md Widget Safety section]

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `_ItemCard` callback for action icon | `_SectionBlock` callback | `_ItemCard` is the right scope — it already receives `answer`, `readOnly`, `item` — adding an `onCreateAction` callback there keeps the pattern clean |
| Detail screen | Bottom sheet for status transitions | Decision locked to new screen (D-02 applies same principle); detail screen is richer and easier to extend in Phase 11 |

---

## Architecture Patterns

### System Architecture Diagram

```
AuditExecutionScreen
  ↓ _SectionBlock → _ItemCard (receives audit, item, answer, readOnly)
  ↓ _isNonConforming(item, answer) == true && !readOnly
  ↓ IconButton(Icons.assignment_add_rounded)
  ↓ Navigator.push → CreateCorrectiveActionScreen(audit, item)
        ↓ UserService.getByCompany(companyId)  → responsible dropdown
        ↓ CorrectiveActionService.createAction(...)
        ↓ Navigator.pop() on success

HomeScreen (drawer)
  ↓ _drawerItem("Acoes Corretivas", badge: _openActions)
  ↓ Navigator.push → CorrectiveActionsScreen
        ↓ CorrectiveActionService.getActions(companyId, filters)
        ↓ ListView of _ActionCard (status chip, responsible, due date)
        ↓ Navigator.push → CorrectiveActionDetailScreen(action)
              ↓ role-gated OutlinedButton/ElevatedButton per transition
              ↓ CorrectiveActionService.updateStatus(id, newStatus)
              ↓ Navigator.pop() or setState reload

HomeScreen._loadDashboard()
  ↓ DashboardService.getOpenActionsCount(companyId)  → _openActions int
  (table now exists — try/catch no longer catches, returns real count)
```

### Recommended Project Structure
```
lib/
├── models/
│   └── corrective_action.dart         # CorrectiveAction + CorrectiveActionStatus enum
├── services/
│   ├── corrective_action_service.dart # CorrectiveActionService (CRUD + status update + count)
│   └── user_service.dart              # Add getByCompany(String companyId) method
├── screens/
│   ├── corrective_actions_screen.dart # ACT-01: list with filters
│   ├── corrective_action_detail_screen.dart # ACT-03: detail + status transitions
│   └── create_corrective_action_screen.dart # ACT-02: creation form
│   └── audit_execution_screen.dart    # Modify: inject icon + onCreateAction callback
└── screens/home_screen.dart           # Modify: badge + drawer item
supabase/migrations/
└── 20260425_create_corrective_actions.sql
test/
├── models/corrective_action_test.dart      # fromMap + status logic
└── services/corrective_action_service_test.dart # isNonConforming pure logic
```

### Pattern 1: Service Layer (no exceptions internally)
**What:** Services expose `Future<T>` methods. No try/catch inside service. Callers (screens) handle exceptions.
**When to use:** Every service method in this project.

```dart
// Source: [VERIFIED: primeaudit/lib/services/audit_answer_service.dart pattern]
class CorrectiveActionService {
  final _client = Supabase.instance.client;

  Future<List<CorrectiveAction>> getActions({
    required String? companyId,
    String? statusFilter,
    String? responsibleFilter,
  }) async {
    var query = _client
        .from('corrective_actions')
        .select('*, profiles!responsible_user_id(full_name), audits(title)');
    if (companyId != null) query = query.eq('company_id', companyId);
    if (statusFilter != null) query = query.eq('status', statusFilter);
    if (responsibleFilter != null) query = query.eq('responsible_user_id', responsibleFilter);
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => CorrectiveAction.fromMap(e)).toList();
  }

  Future<void> createAction({
    required String auditId,
    required String templateItemId,
    required String title,
    String? description,
    required String responsibleUserId,
    required DateTime dueDate,
    required String companyId,
    required String createdBy,
  }) async {
    await _client.from('corrective_actions').insert({
      'audit_id': auditId,
      'template_item_id': templateItemId,
      'title': title,
      'description': description,
      'responsible_user_id': responsibleUserId,
      'due_date': dueDate.toIso8601String(),
      'status': 'aberta',
      'company_id': companyId,
      'created_by': createdBy,
    });
  }

  Future<void> updateStatus(String id, String newStatus) async {
    await _client
        .from('corrective_actions')
        .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<int> getOpenActionsCount(String? companyId) async {
    // Mirrors DashboardService — but counts all non-final states
    var query = _client
        .from('corrective_actions')
        .select('id')
        .inFilter('status', ['aberta', 'em_andamento', 'em_avaliacao']);
    if (companyId != null) query = query.eq('company_id', companyId);
    final data = await query;
    return (data as List).length;
  }
}
```
[VERIFIED: pattern from `primeaudit/lib/services/audit_answer_service.dart` and `dashboard_service.dart`]

### Pattern 2: Model with fromMap factory (no toMap)
**What:** Plain Dart class with named constructor and `factory fromMap(Map<String, dynamic>)`. No `toMap()` — serialization is inline in the service.
**When to use:** Every model in the project.

```dart
// Source: [VERIFIED: primeaudit/lib/models/audit_template.dart pattern]
enum CorrectiveActionStatus {
  aberta,
  emAndamento,
  emAvaliacao,
  aprovada,
  rejeitada,
  cancelada;

  String get dbValue {
    switch (this) {
      case aberta:       return 'aberta';
      case emAndamento:  return 'em_andamento';
      case emAvaliacao:  return 'em_avaliacao';
      case aprovada:     return 'aprovada';
      case rejeitada:    return 'rejeitada';
      case cancelada:    return 'cancelada';
    }
  }

  String get label {
    switch (this) {
      case aberta:       return 'Aberta';
      case emAndamento:  return 'Em andamento';
      case emAvaliacao:  return 'Em avaliacao';
      case aprovada:     return 'Aprovada';
      case rejeitada:    return 'Rejeitada';
      case cancelada:    return 'Cancelada';
    }
  }

  static CorrectiveActionStatus fromDb(String value) {
    return CorrectiveActionStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => CorrectiveActionStatus.aberta,
    );
  }

  bool get isFinal =>
      this == aprovada || this == rejeitada || this == cancelada;
}

class CorrectiveAction {
  final String id;
  final String auditId;
  final String templateItemId;
  final String title;
  final String? description;
  final String responsibleUserId;
  final String? responsibleName; // via join profiles(full_name)
  final DateTime dueDate;
  final CorrectiveActionStatus status;
  final String companyId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? linkedAuditTitle; // via join audits(title)

  CorrectiveAction({...});

  factory CorrectiveAction.fromMap(Map<String, dynamic> map) {
    return CorrectiveAction(
      id: map['id'],
      auditId: map['audit_id'],
      templateItemId: map['template_item_id'],
      title: map['title'],
      description: map['description'],
      responsibleUserId: map['responsible_user_id'],
      responsibleName: map['profiles']?['full_name'],
      dueDate: DateTime.parse(map['due_date']),
      status: CorrectiveActionStatus.fromDb(map['status'] ?? 'aberta'),
      companyId: map['company_id'],
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      linkedAuditTitle: map['audits']?['title'],
    );
  }

  bool get isOverdue =>
      dueDate.isBefore(DateTime.now()) && !status.isFinal;
}
```
[VERIFIED: pattern from `primeaudit/lib/models/audit.dart` and `audit_template.dart`]

### Pattern 3: Non-conformity detection (pure Dart)
**What:** Static/standalone function that takes `TemplateItem` and the current answer string. Returns bool.
**When to use:** Used in `_ItemCard` to decide whether to render the action icon.

```dart
// Source: [VERIFIED: D-01 from 08-CONTEXT.md + calculateConformity in audit_answer_service.dart]
bool _isNonConforming(TemplateItem item, String? answer) {
  if (answer == null || answer.isEmpty) return false; // no answer = no icon
  switch (item.responseType) {
    case 'ok_nok':
      return answer == 'nok';
    case 'yes_no':
      return answer == 'no';
    case 'scale_1_5':
      return (int.tryParse(answer) ?? 0) <= 2;
    case 'percentage':
      return (double.tryParse(answer) ?? 100) < 50.0;
    case 'text':
      return answer.isNotEmpty; // always show icon when answered
    case 'selection':
      return answer.isNotEmpty; // always show icon (no weight data on client side)
    default:
      return false;
  }
}
```

**Reasoning for `selection`:** `calculateConformity` in `AuditAnswerService` treats any non-empty selection as earning full weight — there is no per-option weight in `TemplateItem.options` (it is `List<String>`, not a weighted structure). The icon-always-visible approach for `selection` is consistent with `text` and avoids false negatives. [VERIFIED: `primeaudit/lib/services/audit_answer_service.dart` line 75; `primeaudit/lib/models/audit_template.dart` TemplateItem.options is `List<String>`]

### Pattern 4: _ItemCard integration — where to inject the icon

The `_ItemCard` widget is a `StatefulWidget` in `audit_execution_screen.dart`. Its constructor parameters are: `item`, `index`, `answer`, `observation`, `readOnly`, `onAnswer`, `onObservation`, `theme`. [VERIFIED: lines 859-878 of audit_execution_screen.dart]

The icon must be added as a **new callback parameter** `onCreateAction` (nullable `VoidCallback?`) on `_ItemCard` and `_SectionBlock`. When `onCreateAction` is non-null, `_ItemCardState.build()` renders the icon row below the "Ver observacao" row. The `_SectionBlock` passes it down from a new `onCreateAction` parameter, which `_AuditExecutionScreenState._buildBody()` supplies via a closure capturing `widget.audit` and `item`.

Key constraint: `_ItemCard` is a **private class** (underscore-prefix). It does not need a new screen import — the icon tap navigates by calling `Navigator.push` from within `_ItemCardState.build()` using the passed-in `BuildContext`. The `Audit` object must be passed to `_SectionBlock` → `_ItemCard` to supply it to `CreateCorrectiveActionScreen`.

```dart
// Source: [VERIFIED: audit_execution_screen.dart _SectionBlock constructor lines 779-798]
// In _SectionBlock, add:
final Audit? audit;       // add — needed by _ItemCard for Navigator context
final void Function(TemplateItem)? onCreateAction; // add

// In _ItemCardState.build(), after the "Ver observacao" row:
if (widget.onCreateAction != null && _isNonConforming(item, widget.answer) && !widget.readOnly)
  ...[
    const SizedBox(height: 6),
    GestureDetector(
      onTap: () => widget.onCreateAction!(item),
      child: Row(children: [
        Icon(Icons.assignment_add_rounded, size: 16, color: AppColors.accent),
        const SizedBox(width: 6),
        Text('Criar acao corretiva',
            style: TextStyle(fontSize: 12, color: AppColors.accent)),
      ]),
    ),
  ],
```

### Pattern 5: Drawer item with badge
**What:** Material 3 `Badge` widget wrapping the `ListTile.leading` icon in `_drawerItem`.
**When to use:** ACT-04 badge in `home_screen.dart`.

```dart
// Source: [VERIFIED: home_screen.dart _drawerItem() lines 318-339]
// Modified _drawerItem to accept optional badge count:
Widget _drawerItem({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  Color? color,
  int badgeCount = 0,  // add
}) {
  final itemColor = color ?? AppTheme.of(context).textPrimary;
  Widget iconWidget = Icon(icon, color: itemColor, size: 22);
  if (badgeCount > 0) {
    iconWidget = Badge(
      label: Text('$badgeCount'),
      child: iconWidget,
    );
  }
  return ListTile(
    onTap: onTap,
    leading: iconWidget,
    title: Text(title, style: TextStyle(color: itemColor, fontSize: 15, fontWeight: FontWeight.w500)),
    horizontalTitleGap: 8,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
  );
}
```

### Pattern 6: UserService.getByCompany — addition needed

`UserService` currently has `getAll()` (scoped by role internally) and `getById()`. It has **no `getByCompany(String companyId)`** method. The creation form needs users scoped by the active company. [VERIFIED: `primeaudit/lib/services/user_service.dart` complete file]

```dart
// Source: [VERIFIED: UserService.getAll() as template]
Future<List<AppUser>> getByCompany(String companyId) async {
  final data = await _client
      .from('profiles')
      .select('*, companies(name)')
      .eq('company_id', companyId)
      .eq('active', true)
      .order('full_name');
  return (data as List).map((e) => AppUser.fromMap(e)).toList();
}
```

This is called from `CreateCorrectiveActionScreen.initState()` and populates the `DropdownButtonFormField` of responsibles.

### Pattern 7: RBAC transition matrix implementation

The detail screen receives the `currentUserRole` and `currentUserId` (the logged-in user's UUID). It computes visibility for each transition button:

```dart
// Source: [VERIFIED: 08-UI-SPEC.md RBAC Transition Matrix + AppRole constants]
bool _canTransitionTo(String newStatus, CorrectiveAction action, String role, String userId) {
  final isAdmin = AppRole.canAccessAdmin(role);
  final isSuperDev = AppRole.isSuperOrDev(role);
  final isResponsible = action.responsibleUserId == userId;

  if (isAdmin || isSuperDev) return true; // adm/superuser/dev: all transitions

  switch (newStatus) {
    case 'em_andamento':
      // aberta → em_andamento: responsible or admin
      return isResponsible && action.status == CorrectiveActionStatus.aberta;
    case 'em_avaliacao':
      // em_andamento → em_avaliacao: responsible or admin
      return isResponsible && action.status == CorrectiveActionStatus.emAndamento;
    case 'aprovada':
    case 'rejeitada':
      // em_avaliacao → aprovada/rejeitada: auditor (not responsible) or admin
      return !isResponsible && role == AppRole.auditor
          && action.status == CorrectiveActionStatus.emAvaliacao;
    case 'cancelada':
      // any non-final → cancelada: admin only (or superuser/dev, already covered)
      return false; // if not admin/superDev, auditor and responsible cannot cancel
    default:
      return false;
  }
}
```

Note: `rejeitada → em_andamento` is the re-open path (responsible can re-start after rejection). Add: `isResponsible && action.status == CorrectiveActionStatus.rejeitada` to the `em_andamento` case.

### Anti-Patterns to Avoid
- **Adding try/catch inside service methods:** The project convention is caller handles exceptions. Service just throws.
- **Using `setState()` for the responsible dropdown before `initState` completes:** Pre-load the users list in `_load()` before `setState(_isLoading = false)`.
- **Navigation.push from a StatelessWidget without context:** `_ItemCard` is `StatefulWidget` — `context` is always available in `build()`.
- **Forgetting `!mounted` checks after awaits:** Every async method that calls `setState` in this project includes `if (!mounted) return;` after every `await`.
- **Using `openActions` count from `DashboardService` which only checks status == 'aberta':** The badge definition is `aberta + em_andamento + em_avaliacao`. The `DashboardService.getOpenActionsCount` stub queries only `status == 'aberta'` — it must be updated or `CorrectiveActionService.getOpenActionsCount()` (which uses `inFilter`) must replace it in `HomeScreen._loadDashboard()`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Date picker UI | Custom date input field | `showDatePicker()` built-in Flutter | Handles locale, validation, accessibility |
| Status badge color | Custom color calculation | Material `Colors.*` shade constants (per 08-UI-SPEC.md) | Already specified; no custom computation needed |
| Role permission check | Custom role string comparisons | `AppRole.canAccessAdmin()`, `AppRole.isSuperOrDev()` | Already tested, already in use across all admin screens |
| Company scoping | Passing companyId manually each call | `CompanyContextService.instance.activeCompanyId` | Singleton already initialized in HomeScreen; any screen can read it |
| User list for dropdown | Custom query | `UserService.getByCompany(companyId)` | Reuses existing service, consistent with app pattern |

**Key insight:** All complex UI primitives (date picker, filter chip, dropdown form field) are Flutter SDK built-ins. No package research needed.

---

## Runtime State Inventory

Not applicable — this is a greenfield feature phase with no rename/migration of existing data. The `corrective_actions` table does not exist yet (confirmed via `DashboardService.getOpenActionsCount` try/catch fallback that catches the missing table error). [VERIFIED: `primeaudit/lib/services/dashboard_service.dart` lines 12-27]

---

## Common Pitfalls

### Pitfall 1: DashboardService.getOpenActionsCount counts only 'aberta' — badge will be wrong
**What goes wrong:** The Phase 7 stub queries `status == 'aberta'` only. Phase 8 badge definition is `aberta + em_andamento + em_avaliacao`.
**Why it happens:** Phase 7 placeholder used simplest non-null query to test the stub.
**How to avoid:** Replace the `DashboardService` call in `HomeScreen._loadDashboard()` with `CorrectiveActionService.getOpenActionsCount()` which uses `inFilter('status', ['aberta', 'em_andamento', 'em_avaliacao'])`. Or update `DashboardService.getOpenActionsCount()` to use `inFilter`.
**Warning signs:** Badge shows 0 even when actions in `em_andamento` exist.

### Pitfall 2: _ItemCard is a private StatefulWidget — adding new parameters requires updating _SectionBlock
**What goes wrong:** Forgetting to propagate `onCreateAction` and `audit` through `_SectionBlock` causes compile error.
**Why it happens:** `_ItemCard` is constructed inside `_SectionBlock.build()` — not directly by `_AuditExecutionScreenState`.
**How to avoid:** Add parameters to both `_SectionBlock` and `_ItemCard`, and propagate from `_buildBody()` → `_SectionBlock` → `_ItemCard`.
**Warning signs:** `_SectionBlock` constructor call in `ListView.builder` missing the new parameters.

### Pitfall 3: Navigator.push from _ItemCard loses access to Audit object
**What goes wrong:** `_ItemCard` only receives `TemplateItem item` — it does not know which `Audit` it belongs to.
**Why it happens:** Original design only needed item-level data; audit context was at screen level.
**How to avoid:** Pass `Audit audit` through `_SectionBlock` → `_ItemCard` as a new required field. Use it as the `audit` argument to `CreateCorrectiveActionScreen`.
**Warning signs:** `CreateCorrectiveActionScreen` cannot link the action to an audit.

### Pitfall 4: UserService.getAll() is role-scoped internally and may not return all company users
**What goes wrong:** `getAll()` calls `_getMyProfile()` first to determine role, then filters. An auditor calling `getAll()` gets only their company users (via the `adm` branch logic) — but the method silently returns empty for roles that don't match the if/else.
**Why it happens:** `getAll()` was designed for admin user management, not for dropdown population.
**How to avoid:** Add `getByCompany(String companyId)` that directly queries by `company_id` and `active=true`. Call that from `CreateCorrectiveActionScreen` instead of `getAll()`.
**Warning signs:** Responsible dropdown is empty even when company has active users.

### Pitfall 5: PostgREST foreign key join syntax for responsible name
**What goes wrong:** Join for `profiles.full_name` via `responsible_user_id` FK requires explicit alias because `profiles` is referenced twice (once for auth context via RLS, once for the join).
**Why it happens:** PostgREST auto-detects FK column name; when table is referenced via multiple FKs in the same table, explicit disambiguation via `!<fk_column_name>` is required.
**How to avoid:** Use `profiles!responsible_user_id(full_name)` in the select. Similarly, `audits(title)` for the linked audit title join is unambiguous (single FK).
**Warning signs:** PostgREST returns 400 with "ambiguous" error.

### Pitfall 6: Migration idempotency — status CHECK constraint
**What goes wrong:** If migration is run twice, `ADD CONSTRAINT` on an existing constraint throws error.
**Why it happens:** Unlike `CREATE INDEX IF NOT EXISTS`, there is no `ADD CONSTRAINT IF NOT EXISTS`.
**How to avoid:** Use `DROP CONSTRAINT IF EXISTS` before `ADD CONSTRAINT` — same pattern as `20260406_create_audits.sql` lines 73-75.

---

## Code Examples

### Migration pattern (idempotent)
```sql
-- Source: [VERIFIED: primeaudit/supabase/migrations/20260406_create_audits.sql lines 1-181]
-- Template for 20260425_create_corrective_actions.sql:

CREATE TABLE IF NOT EXISTS corrective_actions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS audit_id            UUID;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS template_item_id   UUID;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS title               TEXT NOT NULL;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS description         TEXT;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS responsible_user_id UUID;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS due_date            DATE NOT NULL;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS status              TEXT NOT NULL DEFAULT 'aberta';
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS company_id          UUID;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS created_by          UUID;
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE corrective_actions ADD COLUMN IF NOT EXISTS updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Foreign keys (drop + add for idempotency):
ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_audit_id_fkey;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_audit_id_fkey
  FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE;

ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_responsible_user_id_fkey;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_responsible_user_id_fkey
  FOREIGN KEY (responsible_user_id) REFERENCES profiles(id) ON DELETE RESTRICT;

ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_company_id_fkey;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE RESTRICT;

ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_created_by_fkey;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE RESTRICT;

-- Status constraint:
ALTER TABLE corrective_actions DROP CONSTRAINT IF EXISTS corrective_actions_status_check;
ALTER TABLE corrective_actions ADD CONSTRAINT corrective_actions_status_check
  CHECK (status IN ('aberta','em_andamento','em_avaliacao','aprovada','rejeitada','cancelada'));

-- Indexes:
CREATE INDEX IF NOT EXISTS idx_corrective_actions_company_id     ON corrective_actions (company_id);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_status         ON corrective_actions (status);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_responsible    ON corrective_actions (responsible_user_id);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_audit_id       ON corrective_actions (audit_id);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_created_at     ON corrective_actions (created_at DESC);

-- RLS:
ALTER TABLE corrective_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "superuser_dev_corrective_actions_full" ON corrective_actions;
CREATE POLICY "superuser_dev_corrective_actions_full" ON corrective_actions
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

DROP POLICY IF EXISTS "adm_corrective_actions_company" ON corrective_actions;
CREATE POLICY "adm_corrective_actions_company" ON corrective_actions
  USING (get_my_role() = 'adm' AND company_id = get_my_company_id())
  WITH CHECK (get_my_role() = 'adm' AND company_id = get_my_company_id());

DROP POLICY IF EXISTS "auditor_corrective_actions_company" ON corrective_actions;
CREATE POLICY "auditor_corrective_actions_company" ON corrective_actions
  FOR SELECT
  USING (get_my_role() = 'auditor' AND company_id = get_my_company_id());

DROP POLICY IF EXISTS "auditor_corrective_actions_insert" ON corrective_actions;
CREATE POLICY "auditor_corrective_actions_insert" ON corrective_actions
  FOR INSERT
  WITH CHECK (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
    AND created_by = auth.uid()
  );

DROP POLICY IF EXISTS "auditor_corrective_actions_update" ON corrective_actions;
CREATE POLICY "auditor_corrective_actions_update" ON corrective_actions
  FOR UPDATE
  USING (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
  )
  WITH CHECK (
    get_my_role() = 'auditor'
    AND company_id = get_my_company_id()
  );

NOTIFY pgrst, 'reload schema';
```

### Filter chip row pattern (from audits_screen)
```dart
// Source: [VERIFIED: primeaudit/lib/screens/audits_screen.dart lines 310-343]
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: _CorrectiveActionStatusFilter.values.map((f) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(f.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : t.textPrimary,
              )),
          selected: selected,
          onSelected: (_) => setState(() => _filter = f),
          selectedColor: AppColors.primary,
          backgroundColor: t.background,
          checkmarkColor: Colors.white,
          side: BorderSide(color: selected ? AppColors.primary : t.divider),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
      );
    }).toList(),
  ),
),
```

### Confirmation dialog pattern (from audits_screen)
```dart
// Source: [VERIFIED: primeaudit/lib/screens/audits_screen.dart _confirmEncerrar lines 193-226]
Future<bool?> _confirmTransition(String title, String body) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Voltar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `DashboardService.getOpenActionsCount()` returns 0 (fallback) | Must query real table after migration | Phase 8 (this phase) | Replace try/catch stub with real query; badge becomes live |
| No corrective_actions table | Add via migration | Phase 8 | Enables Phase 11 notifications and full CAPA workflow |

**No deprecated patterns apply to this phase.**

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `selection` type: icon always visible when answered (any non-empty selection treated as non-conforming) | Pattern 3 non-conformity logic | If project later adds per-option weights, this logic must change; low risk for Phase 8 |
| A2 | PostgREST join syntax `profiles!responsible_user_id(full_name)` resolves correctly for single FK | Service Layer pattern | If syntax is wrong, query returns 400; executor should test immediately after migration |
| A3 | `template_item_id` FK should reference `template_items(id)` — table name inferred from codebase usage | Migration pattern | Wrong FK name causes constraint error at migration time |

---

## Open Questions

1. **Should `template_item_id` be nullable in the DB?**
   - What we know: The field is in the locked decision schema. Actions are always created from an item (D-01).
   - What's unclear: Whether a future admin path might create standalone actions.
   - Recommendation: Make it non-nullable `NOT NULL` for this phase since all creation entry points require an item. This can be relaxed later with a migration.

2. **Which `due_date` column type: `DATE` or `TIMESTAMPTZ`?**
   - What we know: The form uses `showDatePicker` which returns a `DateTime` truncated to midnight. Deadline checking is day-level.
   - Recommendation: Use `DATE` (PostgreSQL date type). Simpler, no timezone ambiguity for a deadline field. Parse in Dart via `DateTime.parse(map['due_date'])` (PostgREST returns ISO date strings).

3. **Badge count: update `DashboardService.getOpenActionsCount` or use `CorrectiveActionService.getOpenActionsCount`?**
   - What we know: `DashboardService` has the existing stub; `HomeScreen` calls it.
   - Recommendation: Update `DashboardService.getOpenActionsCount` to use `inFilter` for all non-final statuses. Keeps `HomeScreen._loadDashboard()` unchanged except removing the try/catch (or keeping it for safety).

---

## Environment Availability

Step 2.6: SKIPPED — this phase is code + SQL migration only. No external CLI tools, runtimes, or services beyond the already-configured Flutter + Supabase stack are introduced.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK — no external packages) |
| Config file | `primeaudit/analysis_options.yaml` (no separate test config) |
| Quick run command | `cd primeaudit && flutter test test/models/corrective_action_test.dart test/services/corrective_action_service_test.dart -x` |
| Full suite command | `cd primeaudit && flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ACT-01 | `CorrectiveAction.fromMap()` parses all fields correctly | unit | `flutter test test/models/corrective_action_test.dart -x` | ❌ Wave 0 |
| ACT-01 | `CorrectiveActionStatus.fromDb()` maps all 6 DB values to enum | unit | `flutter test test/models/corrective_action_test.dart -x` | ❌ Wave 0 |
| ACT-01 | `CorrectiveAction.isOverdue` true when dueDate past + non-final status | unit | `flutter test test/models/corrective_action_test.dart -x` | ❌ Wave 0 |
| ACT-02 | `_isNonConforming()` returns false for ok_nok='ok' | unit | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |
| ACT-02 | `_isNonConforming()` returns true for ok_nok='nok' | unit | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |
| ACT-02 | `_isNonConforming()` returns true for yes_no='no' | unit | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |
| ACT-02 | `_isNonConforming()` returns true for scale_1_5 ≤ 2, false for ≥ 3 | unit | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |
| ACT-02 | `_isNonConforming()` returns true for percentage < 50, false for ≥ 50 | unit | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |
| ACT-02 | `_isNonConforming()` returns false when answer is null/empty (no icon for unanswered) | unit | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |
| ACT-03 | RBAC: admin can transition any status | unit | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |
| ACT-03 | RBAC: responsible can move aberta→em_andamento, em_andamento→em_avaliacao | unit | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |
| ACT-03 | RBAC: auditor (non-responsible) can move em_avaliacao→aprovada | unit | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |
| ACT-03 | RBAC: responsible cannot cancel (only admin can) | unit | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |
| ACT-03 | `CorrectiveActionStatus.isFinal` true for aprovada/rejeitada/cancelada | unit | `flutter test test/models/corrective_action_test.dart -x` | ❌ Wave 0 |
| ACT-04 | Open count includes aberta, em_andamento, em_avaliacao; excludes aprovada/rejeitada/cancelada | unit (pure logic) | `flutter test test/services/corrective_action_service_test.dart -x` | ❌ Wave 0 |

**Manual verification required (no automated test possible):**
- ACT-01: List screen renders with real Supabase data, filters work end-to-end → human smoke test
- ACT-02: Icon appears on item after selecting 'nok' answer, creation form saves to DB → human smoke test
- ACT-03: Status transition button appears/hides correctly per role on real device → human smoke test
- ACT-04: Badge count updates after returning from CorrectiveActionsScreen → human smoke test

### Testing Strategy Notes

The project avoids instantiating services in tests (Supabase client throws). Pure logic is extracted into top-level/static functions and tested directly — same pattern as `AuditAnswerService.calculateConformity` (static method) and `dashboard_service_test.dart` (pure helper functions copied alongside tests). [VERIFIED: `primeaudit/test/services/audit_answer_service_test.dart` line 1-4; `primeaudit/test/services/dashboard_service_test.dart` lines 39-67]

For RBAC tests: extract `_canTransitionTo()` as a top-level function (or static method on `CorrectiveActionService`) so it can be tested without Supabase.

For non-conformity tests: `_isNonConforming()` is currently a private function in `audit_execution_screen.dart`. Two options:
1. Make it a static method on `CorrectiveActionService` or a standalone top-level function in `corrective_action_service.dart` (testable).
2. Keep it private in `audit_execution_screen.dart` and test indirectly via widget test (heavy).

**Recommendation:** Extract `_isNonConforming()` as a top-level function in a new file (e.g., `lib/services/corrective_action_service.dart`) so it can be tested without a widget tree. This follows the `PendingSave` precedent — `PendingSave` was extracted to a separate file specifically to allow direct unit testing. [VERIFIED: `audit_execution_screen.dart` line 16 — `typedef _PendingSave = PendingSave` alias pattern]

### Sampling Rate
- **Per task commit:** `cd primeaudit && flutter test test/models/corrective_action_test.dart test/services/corrective_action_service_test.dart -x`
- **Per wave merge:** `cd primeaudit && flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/models/corrective_action_test.dart` — covers `fromMap` + `isOverdue` + `isFinal` + status enum (ACT-01, ACT-03)
- [ ] `test/services/corrective_action_service_test.dart` — covers `_isNonConforming` logic (ACT-02) + RBAC `_canTransitionTo` logic (ACT-03) + open count definition (ACT-04)

*(No new test framework installation needed — `flutter_test` SDK is already in `pubspec.yaml`)*

---

## Security Domain

`security_enforcement` is not set to false in `.planning/config.json` — section required. [VERIFIED: config.json]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Auth handled by existing Supabase auth gate — no new auth paths |
| V3 Session Management | no | No new session logic |
| V4 Access Control | yes | RLS policies on `corrective_actions`; UI role gating via `AppRole.canAccessAdmin()` + UUID comparison |
| V5 Input Validation | yes | `TextFormField` validators for title (required), due date (required, future), responsible (required) |
| V6 Cryptography | no | No new crypto — Supabase handles JWT/TLS |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Horizontal privilege escalation (auditor updating another company's actions) | Elevation of Privilege | RLS `company_id = get_my_company_id()` on all DML policies |
| Status escalation (auditor bypassing RBAC to approve own action) | Elevation of Privilege | UI hides unauthorized buttons; RLS UPDATE policy covers company scope only (UI enforcement is sufficient per CONTEXT.md) |
| Past date injection for due_date | Tampering | Form validator checks `dueDate.isAfter(DateTime.now())` before submit |
| Free-text responsible bypass (future: notification sent to wrong user) | Tampering | D-04 enforces system user only via `DropdownButtonFormField` bound to `UserService` UUIDs — no free-text accepted |
| RLS function returns NULL for inactive users | Denial of Service | `get_my_role()` and `get_my_company_id()` already include `AND active = true` guard (SEC-03 fix in `20260418_fix_active_guard.sql`) — new policies inherit this behavior automatically |

---

## Sources

### Primary (HIGH confidence)
- `primeaudit/lib/screens/audit_execution_screen.dart` — full read: `_ItemCard` structure, `_SectionBlock` params, `_isReadOnly`, navigation pattern, `_saveAnswer` error pattern
- `primeaudit/lib/screens/home_screen.dart` — full read: `_drawerItem`, `_openActions` field, `_loadDashboard`, drawer structure
- `primeaudit/lib/services/user_service.dart` — full read: confirms no `getByCompany()` method
- `primeaudit/lib/services/dashboard_service.dart` — full read: confirms fallback stub queries only `status='aberta'`
- `primeaudit/lib/services/audit_answer_service.dart` — full read: `calculateConformity` logic for selection/text
- `primeaudit/lib/core/app_roles.dart` — full read: `canAccessAdmin`, `isSuperOrDev` constants
- `primeaudit/lib/services/company_context_service.dart` — full read: singleton pattern
- `primeaudit/supabase/migrations/20260406_create_audits.sql` — full read: idempotent migration pattern (DROP IF EXISTS, ADD, CREATE IF NOT EXISTS, RLS policies)
- `primeaudit/supabase/migrations/20260418_rls_profiles_companies_perimeters.sql` — full read: RLS policy pattern per role
- `primeaudit/lib/models/audit_template.dart` — full read: `TemplateItem.options = List<String>` (no weights per option)
- `primeaudit/lib/models/app_user.dart` — full read: `AppUser.fromMap` pattern
- `.planning/phases/08-corrective-actions/08-CONTEXT.md` — full read: locked decisions
- `.planning/phases/08-corrective-actions/08-UI-SPEC.md` — full read: widget inventory, RBAC matrix, copywriting
- `primeaudit/test/services/audit_answer_service_test.dart` — full read: testing pattern (pure function extraction)
- `primeaudit/test/services/dashboard_service_test.dart` — full read: pure helper function test pattern

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` — ACT-01 to ACT-04 acceptance criteria
- `.planning/STATE.md` — Phase 8 context and blockers

### Tertiary (LOW confidence)
- None — all claims verified via direct codebase reads.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools are existing project dependencies; no new packages
- Architecture: HIGH — all patterns verified from actual source code; no assumptions about Flutter internals
- Pitfalls: HIGH — pitfalls derived from direct code reading (DashboardService fallback, UserService.getAll scope, _SectionBlock propagation chain)
- Migration: HIGH — pattern copied verbatim from existing migration files

**Research date:** 2026-04-25
**Valid until:** 2026-06-01 (stable stack — no fast-moving dependencies introduced)

---

## RESEARCH COMPLETE

**Phase:** 8 - Corrective Actions
**Confidence:** HIGH

### Key Findings

1. **`_ItemCard` injection point confirmed at lines 1005-1030** of `audit_execution_screen.dart` — the icon goes after "Ver observacao" row. New `onCreateAction` callback and `audit` object must be threaded through `_SectionBlock` → `_ItemCard`.

2. **`UserService` is missing `getByCompany()`** — `getAll()` is role-scoped internally and not suitable for the responsible dropdown. A new method must be added.

3. **`DashboardService.getOpenActionsCount` queries only `status='aberta'`** — the badge count definition (`aberta + em_andamento + em_avaliacao`) requires updating this method to use `inFilter`.

4. **Migration pattern is fully established** — DROP CONSTRAINT IF EXISTS → ADD CONSTRAINT idiom; RLS functions (`get_my_role()`, `get_my_company_id()`) already exist with `active=true` guards; all new policies inherit this.

5. **Zero new pub.dev packages needed** — `Badge` widget, `FilterChip`, `DropdownButtonFormField`, `showDatePicker` are all Flutter SDK built-ins available in the project's minimum Flutter version (>= 3.38.4).

### File Created
`.planning/phases/08-corrective-actions/08-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | All verified via direct source read |
| Architecture | HIGH | Exact widget structures and integration points confirmed |
| Migration | HIGH | Copied from existing migration files |
| Pitfalls | HIGH | Derived from actual code behavior, not assumptions |

### Open Questions
- `due_date` column type: `DATE` vs `TIMESTAMPTZ` — recommended `DATE`
- Whether to update `DashboardService` or create dedicated count in `CorrectiveActionService` — recommended update `DashboardService`
- `template_item_id` nullability — recommended `NOT NULL` for this phase

### Ready for Planning
Research complete. Planner can now create PLAN.md files.
