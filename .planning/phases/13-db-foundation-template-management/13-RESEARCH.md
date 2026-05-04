# Phase 13: DB Foundation + Template Management — Research

**Researched:** 2026-05-03
**Domain:** Flutter + Supabase — new independent checklist template module (DB schema, RLS, service layer, screens, seed data)
**Confidence:** HIGH

---

## Summary

Phase 13 introduces a brand-new `checklist_templates` module that is explicitly decoupled from the
existing `audit_templates` / `template_sections` / `template_items` system. The decision is locked
(STATE.md v1.2): zero changes to AuditTemplateService, AuditAnswerService, or AuditExecutionScreen.
This means two parallel template systems will coexist in the database with no shared foreign keys.

The DB work requires two new tables (`checklist_templates`, `checklist_template_items`), one
idempotent migration following the established pattern (CREATE TABLE IF NOT EXISTS + ALTER TABLE ADD
COLUMN IF NOT EXISTS + DROP/ADD constraints), RLS policies for seed visibility (global) vs.
owned-template CRUD, and 10 seed rows inserted with hardcoded UUIDs + ON CONFLICT DO NOTHING.

The Flutter work requires one new screens subdirectory (`lib/screens/checklist/`), two new screen
files, one new service file, one new model file, and a single-line addition to `home_screen.dart`'s
drawer. No new packages are required — every widget used is Flutter SDK built-in.

The most complex interaction in this phase is the **clone flow**: a template's items must be copied
atomically (template row first, then items) to avoid orphan FK violations. Because Supabase
PostgREST does not expose transactions, the clone must be implemented as sequential awaited
Dart calls with a rollback-on-error delete of the new template header if items insertion fails.

**Primary recommendation:** Implement in 3 waves — (1) DB migration + seeds, (2) Dart model +
service layer + unit tests, (3) Screens. The drawer entry is a one-liner and should be included
in Wave 3.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Template persistence (CRUD) | Database (Supabase/PostgREST) | — | Tables own source of truth |
| Seed templates | Database (migration) | — | Seeds are SQL data, not app logic |
| RLS enforcement | Database (Supabase) | — | App-side guards are defense-in-depth only |
| Template list (per category/tab) | API (PostgREST query) | — | Filtered by `category` column |
| Ownership filter ("Meus checklists") | API (PostgREST query) | — | Filtered by `created_by = auth.uid()` |
| Clone atomicity | API (Dart sequential calls) | — | PostgREST has no client-exposed transactions |
| App-side owner guard (no delete on seeds) | Frontend (Flutter widget) | Database (RLS) | UI guard for UX; RLS is the safety net |
| Navigation (drawer entry) | Frontend (Flutter widget) | — | Drawer is stateful widget in home_screen.dart |
| State management | Frontend (setState only) | — | CLAUDE.md: no BLoC/Riverpod |
| Item type support (Sim/Não, texto, etc.) | Database (column `item_type`) | Frontend (display) | Type stored as string; Phase 14 drives rendering |

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TMPLCK-01 | Usuário vê templates listados por categoria (Industrial / Transportadora / Meus checklists) | `checklist_templates.category` column + 3-tab TabBar with per-tab PostgREST filter |
| TMPLCK-02 | Usuário cria template customizado com nome, categoria, descrição e lista de itens | `ChecklistTemplateService.createTemplate()` + `createItems()` sequence; Form screen documented in UI-SPEC |
| TMPLCK-03 | Usuário edita template customizado existente (itens, ordem, metadados) | `updateTemplate()` + `updateItems()` (delete old items, re-insert); edit mode in form screen |
| TMPLCK-04 | Usuário exclui template customizado que criou | `deleteTemplate()` with CASCADE on items; is_padrao guard in widget and RLS |
| TMPLCK-05 | Usuário clona qualquer template (seed ou próprio) como base para novo | Sequential: insert new header → insert copied items; rollback on item failure |
| TMPLCK-06 | 10 templates seed pré-definidos disponíveis após migration (is_padrao = true, company_id IS NULL) | SQL INSERT with hardcoded UUIDs + ON CONFLICT DO NOTHING; 5 Industrial + 5 Transportadora seeds |
| NAV-01 | Entrada "Checklist" visível no drawer de navegação principal (acessível por todos os perfis) | Single `_drawerItem` call in `_buildDrawer()` — no AppRole guard |
</phase_requirements>

---

## Standard Stack

### Core (no new packages — all already in pubspec.lock)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `supabase_flutter` | 2.12.2 | PostgREST queries, auth.uid() for RLS | Already declared — primary backend SDK |
| `flutter` SDK | >=3.38.4 | All UI widgets (TabBar, FAB, BottomSheet, etc.) | Project stack |
| `flutter_test` SDK | bundled | Unit tests for model fromMap + service pure logic | Already in dev_dependencies |

[VERIFIED: primeaudit/pubspec.lock — all packages above are present and locked]

### No New Packages Required

All widgets needed (TabBar, TabBarView, FloatingActionButton.extended, showModalBottomSheet,
AlertDialog, PopupMenuButton, DropdownButtonFormField) are Flutter SDK built-ins.
[VERIFIED: 13-UI-SPEC.md — Flutter Component Library Safety table explicitly states no third-party UI packages]

---

## Architecture Patterns

### System Architecture Diagram

```
[Drawer tap: "Checklist"]
        |
        v
[ChecklistTemplatesScreen]
  |-- TabController (3 tabs)
  |     |-- Tab 0: Industrial   --> PostgREST: category='industrial'
  |     |-- Tab 1: Transportadora --> PostgREST: category='transportadora'
  |     `-- Tab 2: Meus checklists --> PostgREST: created_by=auth.uid()
  |
  |-- FAB "Novo checklist"
  |     `--> [ChecklistTemplateFormScreen] (create mode)
  |               |-- save --> ChecklistTemplateService.createTemplate()
  |               |         + ChecklistTemplateService.createItems()
  |               `-- pop + refresh _load()
  |
  `-- _ChecklistTemplateCard (per template)
        |-- is_padrao == true --> tap/icon --> _CloneBottomSheet
        |     `-- confirm --> ChecklistTemplateService.cloneTemplate()
        |                     (sequential: create header → create items)
        |                     --> pop + SnackBar "Acesse Meus checklists"
        |
        `-- created_by == userId --> PopupMenuButton
              |-- Editar --> ChecklistTemplateFormScreen (edit mode)
              |     `-- save --> updateTemplate() + delete/re-insert items
              |-- Clonar --> _CloneBottomSheet
              `-- Excluir --> AlertDialog confirm --> deleteTemplate()
                              (CASCADE deletes items)

[Database Layer]
  checklist_templates (id, name, category, description, is_padrao,
                       company_id, created_by, created_at)
  checklist_template_items (id, template_id FK CASCADE, description,
                             item_type, order_index, created_at)
  RLS: seeds readable by all authenticated; owned templates CRUD by creator
```

### Recommended Project Structure

```
primeaudit/
├── lib/
│   ├── models/
│   │   └── checklist_template.dart       # ChecklistTemplate + ChecklistTemplateItem
│   ├── services/
│   │   └── checklist_template_service.dart  # CRUD + clone logic
│   └── screens/
│       └── checklist/                    # NEW subdirectory (mirrors screens/templates/)
│           ├── checklist_templates_screen.dart      # List + tabs + FAB
│           └── checklist_template_form_screen.dart  # Create/edit form
└── supabase/migrations/
    └── 20260503_create_checklist_templates.sql   # Tables + RLS + seeds
```

### Pattern 1: Migration File Structure (established project pattern)

**What:** Idempotent SQL migration — CREATE TABLE IF NOT EXISTS, ALTER TABLE ADD COLUMN IF NOT EXISTS, DROP/ADD constraints, DROP/CREATE policies, INSERT ON CONFLICT DO NOTHING, NOTIFY pgrst.

**When to use:** All DB schema changes in this project.

```sql
-- Source: primeaudit/supabase/migrations/20260406_create_audits.sql (established pattern)
-- =============================================================================
-- Migracao: checklist_templates e checklist_template_items (TMPLCK-01..06)
-- Data: 2026-05-03
-- Idempotente: pode ser executado multiplas vezes sem erro.
-- =============================================================================

-- 1. Tabela principal
CREATE TABLE IF NOT EXISTS checklist_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS name         TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS category     TEXT        NOT NULL DEFAULT 'industrial';
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS description  TEXT;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS is_padrao    BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS company_id   UUID;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS created_by   UUID;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 2. Constraints
ALTER TABLE checklist_templates DROP CONSTRAINT IF EXISTS checklist_templates_category_check;
ALTER TABLE checklist_templates ADD CONSTRAINT checklist_templates_category_check
  CHECK (category IN ('industrial', 'transportadora'));

ALTER TABLE checklist_templates DROP CONSTRAINT IF EXISTS checklist_templates_company_id_fkey;
ALTER TABLE checklist_templates ADD CONSTRAINT checklist_templates_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL;

ALTER TABLE checklist_templates DROP CONSTRAINT IF EXISTS checklist_templates_created_by_fkey;
ALTER TABLE checklist_templates ADD CONSTRAINT checklist_templates_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- 3. Items table
CREATE TABLE IF NOT EXISTS checklist_template_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS template_id  UUID        NOT NULL;
ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS description  TEXT        NOT NULL DEFAULT '';
ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS item_type    TEXT        NOT NULL DEFAULT 'yes_no';
ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS order_index  INTEGER     NOT NULL DEFAULT 0;
ALTER TABLE checklist_template_items ADD COLUMN IF NOT EXISTS created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE checklist_template_items DROP CONSTRAINT IF EXISTS checklist_template_items_template_id_fkey;
ALTER TABLE checklist_template_items ADD CONSTRAINT checklist_template_items_template_id_fkey
  FOREIGN KEY (template_id) REFERENCES checklist_templates(id) ON DELETE CASCADE;

ALTER TABLE checklist_template_items DROP CONSTRAINT IF EXISTS checklist_template_items_item_type_check;
ALTER TABLE checklist_template_items ADD CONSTRAINT checklist_template_items_item_type_check
  CHECK (item_type IN ('yes_no', 'text', 'number', 'date', 'multiple_choice', 'photo'));

-- 4. Indexes
CREATE INDEX IF NOT EXISTS idx_checklist_templates_category   ON checklist_templates (category);
CREATE INDEX IF NOT EXISTS idx_checklist_templates_created_by ON checklist_templates (created_by);
CREATE INDEX IF NOT EXISTS idx_checklist_template_items_template ON checklist_template_items (template_id, order_index);

-- ... (RLS + seeds follow)
NOTIFY pgrst, 'reload schema';
```

[VERIFIED: pattern sourced from primeaudit/supabase/migrations/20260406_create_audits.sql and 20260427_create_audit_item_images.sql]

### Pattern 2: RLS Policy Structure for Checklist Templates

**What:** Seed templates (`is_padrao = true`) readable by all authenticated users; owned templates (`created_by = auth.uid()`) writable only by their creator; seeds protected from mutation.

**When to use:** `checklist_templates` and `checklist_template_items` tables.

```sql
-- Source: established pattern from 20260418_rls_profiles_companies_perimeters.sql

ALTER TABLE checklist_templates ENABLE ROW LEVEL SECURITY;

-- superuser/dev: full access (maintain seeds, admin)
DROP POLICY IF EXISTS "superuser_dev_checklist_templates_full" ON checklist_templates;
CREATE POLICY "superuser_dev_checklist_templates_full" ON checklist_templates
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- authenticated: SELECT seeds (is_padrao=true) OR own templates
DROP POLICY IF EXISTS "authenticated_checklist_templates_select" ON checklist_templates;
CREATE POLICY "authenticated_checklist_templates_select" ON checklist_templates FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND (is_padrao = true OR created_by = auth.uid())
  );

-- authenticated: INSERT own templates (not seeds)
DROP POLICY IF EXISTS "authenticated_checklist_templates_insert" ON checklist_templates;
CREATE POLICY "authenticated_checklist_templates_insert" ON checklist_templates FOR INSERT
  WITH CHECK (
    get_my_role() IS NOT NULL
    AND is_padrao = false
    AND created_by = auth.uid()
  );

-- authenticated: UPDATE own non-seed templates
DROP POLICY IF EXISTS "authenticated_checklist_templates_update" ON checklist_templates;
CREATE POLICY "authenticated_checklist_templates_update" ON checklist_templates FOR UPDATE
  USING  (get_my_role() IS NOT NULL AND is_padrao = false AND created_by = auth.uid())
  WITH CHECK (get_my_role() IS NOT NULL AND is_padrao = false AND created_by = auth.uid());

-- authenticated: DELETE own non-seed templates
DROP POLICY IF EXISTS "authenticated_checklist_templates_delete" ON checklist_templates;
CREATE POLICY "authenticated_checklist_templates_delete" ON checklist_templates FOR DELETE
  USING (get_my_role() IS NOT NULL AND is_padrao = false AND created_by = auth.uid());
```

[VERIFIED: RLS function signatures `get_my_role()` and `get_my_company_id()` exist in primeaudit/supabase/migrations/20260418_fix_active_guard.sql]

### Pattern 3: Checklist Template Items — RLS via parent FK

**What:** Items table has no `created_by` — ownership is derived from parent template.

```sql
ALTER TABLE checklist_template_items ENABLE ROW LEVEL SECURITY;

-- superuser/dev: full access
DROP POLICY IF EXISTS "superuser_dev_checklist_template_items_full" ON checklist_template_items;
CREATE POLICY "superuser_dev_checklist_template_items_full" ON checklist_template_items
  USING (get_my_role() IN ('superuser', 'dev'))
  WITH CHECK (get_my_role() IN ('superuser', 'dev'));

-- SELECT: items of seeds OR of user's own templates
DROP POLICY IF EXISTS "authenticated_checklist_template_items_select" ON checklist_template_items;
CREATE POLICY "authenticated_checklist_template_items_select" ON checklist_template_items FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_templates t
      WHERE t.id = checklist_template_items.template_id
        AND (t.is_padrao = true OR t.created_by = auth.uid())
    )
  );

-- INSERT/UPDATE/DELETE: only items of own non-seed templates
DROP POLICY IF EXISTS "authenticated_checklist_template_items_write" ON checklist_template_items;
CREATE POLICY "authenticated_checklist_template_items_write" ON checklist_template_items
  USING (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_templates t
      WHERE t.id = checklist_template_items.template_id
        AND t.is_padrao = false
        AND t.created_by = auth.uid()
    )
  )
  WITH CHECK (
    get_my_role() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM checklist_templates t
      WHERE t.id = checklist_template_items.template_id
        AND t.is_padrao = false
        AND t.created_by = auth.uid()
    )
  );
```

[VERIFIED: subquery-via-FK pattern sourced from 20260423_rls_template_sections.sql and 20260418_rls_profiles_companies_perimeters.sql template_items section]

### Pattern 4: Dart Model with fromMap Factory

**What:** Plain Dart class, named constructor with required parameters, `fromMap` factory for
Supabase deserialization, no code generation, optional computed getters.

```dart
// Source: primeaudit/lib/models/audit_template.dart (established pattern)
class ChecklistTemplate {
  final String id;
  final String name;
  final String category;    // 'industrial' | 'transportadora'
  final String? description;
  final bool isPadrao;
  final String? companyId;
  final String? createdBy;
  final DateTime createdAt;
  List<ChecklistTemplateItem> items; // populated in-memory after load

  ChecklistTemplate({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.isPadrao,
    this.companyId,
    this.createdBy,
    required this.createdAt,
    this.items = const [],
  });

  factory ChecklistTemplate.fromMap(Map<String, dynamic> map) {
    return ChecklistTemplate(
      id: map['id'],
      name: map['name'],
      category: map['category'] ?? 'industrial',
      description: map['description'],
      isPadrao: map['is_padrao'] ?? false,
      companyId: map['company_id'],
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']).toLocal(),
    );
  }

  bool get isSeed => isPadrao;
}

class ChecklistTemplateItem {
  final String id;
  final String templateId;
  final String description;
  final String itemType;  // 'yes_no' | 'text' | 'number' | 'date' | 'multiple_choice' | 'photo'
  final int orderIndex;

  ChecklistTemplateItem({
    required this.id,
    required this.templateId,
    required this.description,
    required this.itemType,
    required this.orderIndex,
  });

  factory ChecklistTemplateItem.fromMap(Map<String, dynamic> map) {
    return ChecklistTemplateItem(
      id: map['id'],
      templateId: map['template_id'],
      description: map['description'] ?? '',
      itemType: map['item_type'] ?? 'yes_no',
      orderIndex: map['order_index'] ?? 0,
    );
  }
}
```

[VERIFIED: follows exact pattern from primeaudit/lib/models/audit_template.dart]

### Pattern 5: Service Layer

**What:** Plain Dart class holding `final _client = Supabase.instance.client`, exposing Future methods, no exception handling internally.

```dart
// Source: primeaudit/lib/services/audit_template_service.dart (established pattern)
class ChecklistTemplateService {
  final _client = Supabase.instance.client;

  Future<List<ChecklistTemplate>> getByCategory(String category) async {
    final data = await _client
        .from('checklist_templates')
        .select()
        .eq('category', category)
        .eq('is_padrao', true)
        .order('name');
    return (data as List).map((e) => ChecklistTemplate.fromMap(e)).toList();
  }

  Future<List<ChecklistTemplate>> getOwned() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _client
        .from('checklist_templates')
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => ChecklistTemplate.fromMap(e)).toList();
  }

  // getItems, createTemplate, createItems, updateTemplate, deleteTemplate, cloneTemplate
}
```

[VERIFIED: service pattern from primeaudit/lib/services/audit_template_service.dart]

### Pattern 6: Clone Flow (Sequential, No Transaction)

**What:** Deep-copy a template and all its items sequentially. Template header must exist before
items (FK constraint). If item insertion fails, delete the orphaned template header.

```dart
// Source: STATE.md v1.2 decisions — "Clone sequencial: criar seções antes de itens para evitar FK órfão (Pitfall #3)"
Future<ChecklistTemplate> cloneTemplate(ChecklistTemplate source) async {
  final userId = _client.auth.currentUser!.id;

  // Step 1: create header (non-seed, owned by current user)
  final newTemplateResult = await _client
      .from('checklist_templates')
      .insert({
        'name': '${source.name} (cópia)',
        'category': source.category,
        'description': source.description,
        'is_padrao': false,
        'created_by': userId,
      })
      .select()
      .single();
  final newTemplate = ChecklistTemplate.fromMap(newTemplateResult);

  // Step 2: fetch source items
  final sourceItems = await getItems(source.id);

  // Step 3: insert items sequentially; rollback header on failure
  try {
    if (sourceItems.isNotEmpty) {
      final itemMaps = sourceItems.asMap().entries.map((e) => {
        'template_id': newTemplate.id,
        'description': e.value.description,
        'item_type': e.value.itemType,
        'order_index': e.key,
      }).toList();
      await _client.from('checklist_template_items').insert(itemMaps);
    }
    return newTemplate;
  } catch (e) {
    // Rollback: delete orphaned header (CASCADE removes any partial items)
    await _client.from('checklist_templates').delete().eq('id', newTemplate.id);
    rethrow;
  }
}
```

[ASSUMED: Supabase PostgREST does not expose client-side transactions — this is the established pattern for atomic multi-table inserts in this codebase, as evidenced by STATE.md Pitfall #3 note and existing clone patterns in audit module]

### Pattern 7: Drawer Entry

**What:** One new `_drawerItem` call inserted between "Auditorias" and "Ações Corretivas" in `home_screen.dart`. No AppRole guard (visible to all).

```dart
// Source: primeaudit/lib/screens/home_screen.dart _buildDrawer() — established _drawerItem pattern
_drawerItem(
  icon: Icons.checklist_rounded,
  title: 'Checklist',
  onTap: () => _navigate(ChecklistTemplatesScreen()),
),
```

The `ChecklistTemplatesScreen` constructor requires no parameters (it reads the current user from
`Supabase.instance.client.auth.currentUser` internally via the service).

[VERIFIED: _drawerItem signature and _navigate method confirmed in home_screen.dart lines 394-422]

### Pattern 8: Tab Screen with TabController

**What:** `StatefulWidget` with `TickerProviderStateMixin`, `TabController` initialized in `initState`, 3-tab `TabBar` in AppBar bottom.

```dart
// Source: primeaudit/lib/screens/audits_screen.dart — tab pattern reference (from UI-SPEC)
class ChecklistTemplatesScreen extends StatefulWidget { ... }

class _ChecklistTemplatesScreenState extends State<ChecklistTemplatesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  // ...

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
```

[VERIFIED: TickerProviderStateMixin pattern confirmed in 13-UI-SPEC.md component inventory]

### Anti-Patterns to Avoid

- **Sharing tables with audit module:** Do NOT add columns to `audit_templates` or `template_items`. Checklist module uses its own tables. [VERIFIED: STATE.md v1.2 — "zero alterações em AuditTemplateService"]
- **Client-side filtering for RLS-owned data:** Do not load all templates and filter in Dart — use server-side column filter (`created_by = auth.uid()` via PostgREST). [VERIFIED: established service pattern]
- **Creating items before template header:** FK constraint on `template_id` will reject items if the parent template does not exist yet. [VERIFIED: schema FK is `ON DELETE CASCADE`, so header must come first]
- **Using state management libraries:** No BLoC/Riverpod/Provider. Use `setState` only. [VERIFIED: CLAUDE.md constraint]
- **Hardcoded UUID collision risk:** Seed UUIDs must be chosen once and committed — regenerating them in a re-run would create duplicates if `ON CONFLICT DO NOTHING` is accidentally omitted. [ASSUMED: standard Supabase seeding practice]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Seed idempotency | Custom "check if row exists" logic | `INSERT ... ON CONFLICT DO NOTHING` | Single SQL idiom, zero Dart code |
| Template ownership enforcement | App-only is_padrao check | RLS policy (`is_padrao = false AND created_by = auth.uid()`) | DB enforces even if UI has bugs |
| Delete cascade of items | Explicit loop deleting items before template | `ON DELETE CASCADE` FK on `checklist_template_items.template_id` | DB handles it atomically |
| Item re-ordering | Drag-and-drop + order_index update | Static `order_index` from insertion order | Drag-and-drop was cancelled in v1.1 for audit module; same decision applies here (OUT OF SCOPE in REQUIREMENTS.md) |
| Batch insert | Loop of individual inserts | Single `insert(List<Map>)` call to PostgREST | PostgREST accepts array; fewer round-trips |

**Key insight:** The combination of `ON DELETE CASCADE` + RLS `WITH CHECK` guards means most
"what if the user deletes a seed?" scenarios are handled at the DB layer without any Dart logic.

---

## Seed Template Design

### Volume and Distribution

- 10 seeds total: 5 `category = 'industrial'`, 5 `category = 'transportadora'`
- All: `is_padrao = true`, `company_id = NULL`, `created_by = NULL`
- All inserted with hardcoded UUIDs + `ON CONFLICT (id) DO NOTHING`

[VERIFIED: REQUIREMENTS.md TMPLCK-06 — "10 templates seed pré-definidos disponíveis após migration (is_padrao = true, company_id IS NULL)"]
[VERIFIED: STATE.md v1.2 — "Seed templates com UUIDs hardcoded + ON CONFLICT DO NOTHING — idempotência da migration"]

### Item Type Vocabulary (for Phase 14 forward-compatibility)

The `item_type` column in `checklist_template_items` must use the string values Phase 14 (EXEC-02) will read:

| item_type value | Display | Phase 14 widget |
|-----------------|---------|-----------------|
| `yes_no` | Sim / Não | Toggle / Radio |
| `text` | Texto livre | TextField |
| `number` | Número | TextField(numeric) |
| `date` | Data | DatePicker |
| `multiple_choice` | Múltipla escolha | CheckboxGroup |
| `photo` | Foto | ImagePicker |

[VERIFIED: REQUIREMENTS.md EXEC-02 — "Usuário responde itens com todos os tipos suportados: Sim/Não, texto, número, data, múltipla escolha, foto"]
[ASSUMED: exact string values for item_type (`yes_no`, `text`, etc.) — consistent with `response_type` vocabulary in existing `template_items` table (ok_nok, yes_no, text, etc.) but the checklist items use a subset tailored to checklist context]

### Sample Seed Item Counts

Each seed template should have 3–8 items to demonstrate realistic content without migration bloat.
[ASSUMED: no explicit count mandated by requirements — 5 items per seed is a reasonable default]

---

## Common Pitfalls

### Pitfall 1: FK Orphan in Clone (CRITICAL)

**What goes wrong:** Items inserted with `template_id` pointing to a header that does not yet exist (or was rolled back) causes a FK violation and partial data.

**Why it happens:** Multi-table insert without transactions — if step 2 (items) fails after step 1 (header) succeeds, the header is stranded.

**How to avoid:** Always: (1) insert header, (2) capture new header `id`, (3) insert items with that id, (4) catch any exception from step 3 and `DELETE` the header row. `ON DELETE CASCADE` ensures no item orphans after header delete.

**Warning signs:** SnackBar "Erro ao clonar" with a 409 Conflict or FK violation error in the Supabase dashboard.

[VERIFIED: STATE.md v1.2 — "Clone sequencial: criar seções antes de itens para evitar FK órfão (Pitfall #3)"]

### Pitfall 2: RLS Blocks Seed Visibility for Auditors

**What goes wrong:** Auditor taps "Industrial" tab and sees empty list even though seeds exist.

**Why it happens:** Missing or misconfigured SELECT policy — the SELECT policy for `checklist_templates` must explicitly allow `is_padrao = true` rows for all authenticated users, not just adm/superuser.

**How to avoid:** The SELECT policy must use `is_padrao = true OR created_by = auth.uid()` (not AND). Do not copy the `audit_types` pattern which used `company_id IS NULL` — seeds here use `is_padrao` flag.

**Warning signs:** Empty tabs for all users except superuser/dev who have a blanket policy.

[VERIFIED: RLS pattern cross-referenced with 20260418_rls_profiles_companies_perimeters.sql authenticated_audit_types_select]

### Pitfall 3: TabController Not Disposed

**What goes wrong:** Memory leak and potential "setState after dispose" errors when navigating away.

**Why it happens:** `TickerProviderStateMixin` requires explicit `_tabController.dispose()` in `dispose()`.

**How to avoid:** Always override `dispose()` and call `_tabController.dispose()` before `super.dispose()`.

**Warning signs:** Flutter debug warnings about leaked TabController.

[VERIFIED: Flutter SDK TabController lifecycle requirement — standard Flutter development knowledge]

### Pitfall 4: Seed Created_By Must Be NULL (Not Current User)

**What goes wrong:** Seeds inserted with `created_by = auth.uid()` of the developer running the migration are visible only to that developer in the "Meus checklists" tab — not as global seeds.

**Why it happens:** Confusing "who ran the migration" with "who owns the template".

**How to avoid:** Seeds must be inserted with `created_by = NULL` and `is_padrao = true`. The SELECT RLS policy checks `is_padrao = true` for public visibility.

**Warning signs:** Seeds appear in "Meus checklists" instead of the category tabs.

[VERIFIED: REQUIREMENTS.md TMPLCK-06 — "is_padrao = true, company_id IS NULL"]

### Pitfall 5: Edit Flow Corrupts Item Order

**What goes wrong:** Editing a template that deletes and re-inserts items may corrupt order_index if the re-insertion is not re-indexed from 0.

**Why it happens:** UI may remove items from an in-memory list and the remaining items keep their original indices (e.g., items at positions 0, 2, 4 after deletions).

**How to avoid:** When saving edits, use `asMap().entries` to regenerate `order_index` from 0..n-1 based on current list position, not stored values.

**Warning signs:** Items display in wrong order after an edit that removed the middle item.

[ASSUMED: based on known UI list management patterns]

### Pitfall 6: PostgREST Schema Cache Miss After Migration

**What goes wrong:** App returns 400/404 for new tables immediately after migration.

**Why it happens:** Supabase PostgREST caches the schema and does not see new tables until it reloads.

**How to avoid:** Always include `NOTIFY pgrst, 'reload schema';` as the last line of the migration. [VERIFIED: all existing migrations end with this line]

---

## Code Examples

### Query: Category Tab (e.g., Industrial)

```dart
// Source: primeaudit/lib/services/audit_template_service.dart (adapted pattern)
Future<List<ChecklistTemplate>> getByCategory(String category) async {
  final data = await _client
      .from('checklist_templates')
      .select()
      .eq('category', category)
      .eq('is_padrao', true)
      .order('name');
  return (data as List).map((e) => ChecklistTemplate.fromMap(e)).toList();
}
```

Note: The "Industrial" and "Transportadora" tabs show seeds (`is_padrao = true`). If user-owned
templates in those categories should also appear, remove the `.eq('is_padrao', true)` filter and
add a combined OR filter. The UI-SPEC is ambiguous — the tab descriptions say "seeds + own" but
the empty-state copy for those tabs suggests seeds are the primary content. **[ASSUMED]** —
recommend clarifying with user before coding. The safest implementation per the UI-SPEC text
("Templates with category == 'industrial' (seeds + own)") is to include both seeds and own
templates in category tabs.

### Query: Meus Checklists Tab

```dart
Future<List<ChecklistTemplate>> getOwned() async {
  final userId = _client.auth.currentUser?.id;
  if (userId == null) return [];
  final data = await _client
      .from('checklist_templates')
      .select()
      .eq('created_by', userId)
      .order('created_at', ascending: false);
  return (data as List).map((e) => ChecklistTemplate.fromMap(e)).toList();
}
```

[VERIFIED: PostgREST `.eq()` filter pattern from audit_template_service.dart]

### Query: Items for a Template

```dart
Future<List<ChecklistTemplateItem>> getItems(String templateId) async {
  final data = await _client
      .from('checklist_template_items')
      .select()
      .eq('template_id', templateId)
      .order('order_index');
  return (data as List).map((e) => ChecklistTemplateItem.fromMap(e)).toList();
}
```

[VERIFIED: identical pattern to AuditTemplateService.getItems()]

### Drawer Entry (home_screen.dart)

```dart
// Source: primeaudit/lib/screens/home_screen.dart — _buildDrawer() children list
// Insert AFTER the "Auditorias" _drawerItem and BEFORE "Ações Corretivas"
_drawerItem(
  icon: Icons.checklist_rounded,
  title: 'Checklist',
  onTap: () => _navigate(ChecklistTemplatesScreen()),
),
```

Import to add at top of home_screen.dart:
```dart
import 'checklist/checklist_templates_screen.dart';
```

[VERIFIED: _drawerItem signature confirmed from home_screen.dart lines 394-423; import path follows project structure]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `supabase_flutter` 1.x (unauthenticated PostgREST) | `supabase_flutter` 2.x — `auth.currentUser` always available | v2 SDK | No need to pass userId as a parameter; use `_client.auth.currentUser?.id` directly |
| Single template system (audit_templates) | Two parallel template systems (audit + checklist) | v1.2 decision | Zero coupling; different DB tables, services, models, screens |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Category tabs (Industrial, Transportadora) show both seeds AND own user templates (not seeds-only) | Code Examples — Category Tab | Wrong tab content; user sees own templates mixed into seed tabs or misses them |
| A2 | `item_type` string values: `yes_no`, `text`, `number`, `date`, `multiple_choice`, `photo` — chosen to match Phase 14 vocabulary | Seed Template Design | Phase 14 would need to remap string values if different |
| A3 | Each seed template has ~5 items (3–8 range acceptable) | Seed Template Design | Too few items makes seeds feel thin; too many bloats migration |
| A4 | Clone of a template does NOT include `category` user override — clone inherits source category | Clone Flow | Cloned template appears in wrong tab if category differs |
| A5 | Supabase PostgREST `insert(List<Map>)` (batch insert) is available in supabase_flutter 2.12.x | Don't Hand-Roll | Must fall back to loop of individual inserts if batch returns incorrect data |

**Assumptions A1 and A2 have the highest risk and should be confirmed before implementation.**

---

## Open Questions (RESOLVED)

1. **Category tab content: seeds only, or seeds + own?**
   - What we know: UI-SPEC says "Templates with category == 'industrial' (seeds + own)" but the empty state for those tabs reads "Os templates padrão serão carregados em breve" — implying seeds are the only expected content.
   - What's unclear: Should a user who creates a template with category=industrial see it in the Industrial tab AND in Meus checklists, or only in Meus checklists?
   - Recommendation: Default to seeds-only in category tabs for clean UX; "Meus checklists" is the user's personal list. Confirm before coding.
   - **RESOLVED:** Category tabs (Industrial, Transportadora) show seeds AND own user templates in that category. The service  uses  and relies on the RLS SELECT policy () to filter naturally. Own templates with a matching category appear in both the category tab and "Meus checklists".

2. **Seed content: what are the 10 actual template names and items?**
   - What we know: 5 Industrial + 5 Transportadora; categories and count are locked.
   - What's unclear: Exact names and items are not specified in any planning artifact.
   - Recommendation: Planner must define seed content in PLAN.md or ask user. Placeholders (e.g., "Inspeção de EPI Industrial") will suffice for the migration if user doesn't specify.
   - **RESOLVED:** Seed names and items are defined in Plan 13-01 Task 2. Industrial seeds: "Inspeção de EPI e Segurança do Trabalho", "Auditoria de 5S Industrial", "Inspeção de Máquinas e Equipamentos", "Checklist de Manutenção Preventiva", "Inspeção de Riscos Elétricos". Transportadora seeds: "Vistoria de Veículo Leve", "Vistoria de Veículo Pesado / Caminhão", "Checklist de Carregamento e Embalagem", "Inspeção de Motorista e Documentação", "Auditoria de Processo de Entrega". Each seed has 5 items with hardcoded UUIDs.

3. **Edit mode: delete all items and re-insert, or diff/patch?**
   - What we know: Phase 13 items are simple (description + type); no item IDs are tracked in the form UI.
   - What's unclear: If the form doesn't surface item IDs, the simplest edit strategy is delete-all-items + re-insert.
   - Recommendation: Delete + re-insert is simpler and safe (CASCADE FK means no orphans). Confirm this is acceptable for v1.2.
   - **RESOLVED:** Delete-all + re-insert via  in Plan 13-02. The service method deletes all existing items for the template then batch-inserts the new list with  re-indexed 0..n-1. This avoids diff/patch complexity for v1.2 (Pitfall 5 handled by  indexing).

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All screens | Assumed available (project active) | >=3.38.4 | — |
| Supabase project | RLS + migration | Assumed available (existing phases deployed) | Cloud | — |
| `supabase_flutter` pkg | Service layer | Available (in pubspec.lock) | 2.12.2 | — |
| Dart SDK | Dart files | Assumed available | >=3.11.4 | — |

Step 2.6: No new external tools introduced. All dependencies are already present in the project.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled Flutter SDK) |
| Config file | none — run via `flutter test` |
| Quick run command | `flutter test test/models/checklist_template_test.dart -r compact` |
| Full suite command | `flutter test -r compact` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TMPLCK-01 | `ChecklistTemplate.fromMap` parses category, name, isPadrao | unit | `flutter test test/models/checklist_template_test.dart -r compact` | ❌ Wave 0 |
| TMPLCK-02 | `ChecklistTemplateItem.fromMap` parses description, itemType, orderIndex defaults | unit | `flutter test test/models/checklist_template_test.dart -r compact` | ❌ Wave 0 |
| TMPLCK-03 | `ChecklistTemplate.isSeed` returns true when isPadrao=true | unit | `flutter test test/models/checklist_template_test.dart -r compact` | ❌ Wave 0 |
| TMPLCK-04 | `ChecklistTemplate.fromMap` sets isPadrao=false default when key absent | unit | `flutter test test/models/checklist_template_test.dart -r compact` | ❌ Wave 0 |
| TMPLCK-05 | Clone flow (sequential service calls) | manual-only | — | N/A — requires live Supabase |
| TMPLCK-06 | Seeds visible after migration | manual-only | — | N/A — requires live DB |
| NAV-01 | Drawer entry visible (smoke) | manual-only | — | N/A — requires device/emulator |

**Note:** Service layer tests require a live Supabase connection (like existing `audit_answer_service_test.dart` which mocks at the service boundary). Pure model tests are unit-testable without Supabase.

### Sampling Rate

- Per task commit: `flutter test test/models/checklist_template_test.dart -r compact`
- Per wave merge: `flutter test -r compact`
- Phase gate: Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/models/checklist_template_test.dart` — covers TMPLCK-01, TMPLCK-02, TMPLCK-03, TMPLCK-04 (model fromMap + defaults + isSeed getter)

*(Existing test infrastructure: flutter_test framework present, existing test files as reference — no new framework setup needed)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (indirectly) | `get_my_role() IS NOT NULL` guard in all RLS policies — unauthenticated requests return NULL role and are blocked |
| V3 Session Management | no | Session managed by Supabase Auth — no Phase 13 changes |
| V4 Access Control | yes | RLS `created_by = auth.uid()` + `is_padrao = false` for mutations; widget-level guard for delete button |
| V5 Input Validation | yes | Form validators (required fields, category dropdown enum); DB CHECK constraint on `category` and `item_type` columns |
| V6 Cryptography | no | No new crypto introduced |

### Known Threat Patterns for Flutter + Supabase RLS

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| User deletes another user's template by forging UUID | Tampering | RLS DELETE policy: `created_by = auth.uid()` — server rejects even if UUID is known |
| User mutates seed template | Tampering | RLS UPDATE/DELETE policy: `is_padrao = false` required |
| Inactive user accesses checklist templates | Elevation of privilege | `get_my_role() IS NOT NULL` uses `active = true` guard (from 20260418_fix_active_guard.sql) |
| Client bypasses is_padrao widget guard | Tampering | Defense-in-depth: DB RLS enforces same rule independently |
| SQL injection via template name | Tampering | PostgREST parameterized queries — no raw SQL in Dart service layer |

---

## Project Constraints (from CLAUDE.md)

These directives are MANDATORY and override any research recommendation:

1. **Stack lock:** Flutter + Dart + Supabase only — no new frameworks or alternatives
2. **State management lock:** No BLoC, Riverpod, or Provider — `setState` only
3. **Migration pattern:** Idempotent SQL (CREATE TABLE IF NOT EXISTS, ALTER ADD COLUMN IF NOT EXISTS, DROP/ADD constraints, DROP/CREATE policies)
4. **No breaking existing flows:** AuditTemplateService, AuditAnswerService, AuditExecutionScreen must not be modified
5. **Naming conventions:** Files `snake_case`, classes `PascalCase`, methods `camelCase`, private `_prefix`; screens suffixed `_screen.dart`, services `_service.dart`
6. **Service pattern:** `final _client = Supabase.instance.client`; no internal exception handling; callers do try/catch
7. **Model pattern:** `factory fromMap`, no `toMap`, no code generation
8. **Error surfacing:** `ScaffoldMessenger.showSnackBar` with `SnackBarBehavior.floating`

[VERIFIED: all constraints from CLAUDE.md]

---

## Sources

### Primary (HIGH confidence)
- `primeaudit/supabase/migrations/*.sql` — all 11 migration files read and cross-referenced for patterns (idempotency, RLS structure, NOTIFY pgrst)
- `primeaudit/lib/services/audit_template_service.dart` — service layer pattern
- `primeaudit/lib/models/audit_template.dart` — model fromMap pattern
- `primeaudit/lib/screens/home_screen.dart` — drawer _drawerItem pattern
- `primeaudit/lib/screens/templates/audit_templates_screen.dart` — card/form/delete patterns
- `.planning/phases/13-db-foundation-template-management/13-UI-SPEC.md` — complete UI contract
- `.planning/REQUIREMENTS.md` — requirement definitions
- `.planning/STATE.md` — locked v1.2 decisions
- `CLAUDE.md` — project constraints

### Secondary (MEDIUM confidence)
- `primeaudit/test/models/audit_template_test.dart` — test file structure reference for new model tests
- `primeaudit/test/services/audit_answer_service_test.dart` — service test pattern reference

### Tertiary (LOW confidence)
- Item type string values (`yes_no`, `text`, `number`, `date`, `multiple_choice`, `photo`) — inferred from EXEC-02 requirement text and existing `response_type` vocabulary in `template_items` table

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all verified in pubspec.lock
- DB schema design: HIGH — follows established migration and RLS patterns exactly
- Architecture: HIGH — mirrors existing module structure
- Seed content (names/items): LOW — not specified in any artifact; planner must define
- Clone atomicity: HIGH — pattern locked in STATE.md; sequential with rollback
- Pitfalls: HIGH — sourced from existing migrations and STATE.md decisions

**Research date:** 2026-05-03
**Valid until:** 2026-06-03 (stable stack; supabase_flutter 2.x API unlikely to change)
