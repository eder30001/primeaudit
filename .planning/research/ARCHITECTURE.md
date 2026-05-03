# Architecture Patterns — Checklist Module Integration

**Domain:** Adding a Checklist module to an existing Flutter + Supabase 3-layer app
**Researched:** 2026-05-02
**Overall confidence:** HIGH — based on direct reading of the existing codebase

---

## 1. DB Schema Design

### Naming conventions

The existing tables use `snake_case` with domain prefix groupings:

```
audit_types, audit_templates, template_sections, template_items
audits, audit_answers, audit_item_images
corrective_actions
```

The Checklist module should mirror this: `checklist_` prefix throughout, matching
`audit_` → `checklist_`:

| New Table | Mirror of |
|-----------|-----------|
| `checklist_templates` | `audit_templates` |
| `checklist_sections` | `template_sections` |
| `checklist_items` | `template_items` |
| `checklist_execucoes` | `audits` |
| `checklist_respostas` | `audit_answers` |
| `checklist_item_images` | `audit_item_images` |

Rationale: the audit module uses `template_sections` and `template_items` (not
`audit_sections` / `audit_items`). For Checklist, use the full `checklist_` prefix
on all tables to avoid any join ambiguity and make the module fully self-contained.

### Schema for each table

**`checklist_templates`**

```sql
CREATE TABLE IF NOT EXISTS checklist_templates (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS name        TEXT NOT NULL;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS category    TEXT NOT NULL DEFAULT 'custom';
  -- values: 'industrial', 'transportadora', 'custom'
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS company_id  UUID;
  -- NULL = seed/global (is_padrao = true implies NULL), companyId = empresa-specific clone
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS is_padrao   BOOLEAN NOT NULL DEFAULT false;
  -- true for the 10 seed templates; false for company clones/custom
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS active      BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS created_by  UUID;
  -- NULL for seeds (system-created), auth.uid() for user-created/cloned
ALTER TABLE checklist_templates ADD COLUMN IF NOT EXISTS created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW();
```

The `is_padrao` flag distinguishes the pre-seeded templates (10 templates) from
custom templates created by companies. Seeds have `company_id IS NULL` and
`is_padrao = true`. A company clone will have `company_id = <id>`, `is_padrao = false`,
and can reference `cloned_from UUID` (optional, for tracking clone origin).

Existing pattern precedent: `audit_templates` uses `company_id IS NULL` for global
templates with the query `.or('company_id.is.null,company_id.eq.$companyId')`.
Checklist uses the same pattern for seeds.

**`checklist_sections`** (mirrors `template_sections`)

```sql
CREATE TABLE IF NOT EXISTS checklist_sections (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_sections ADD COLUMN IF NOT EXISTS template_id UUID NOT NULL
  REFERENCES checklist_templates(id) ON DELETE CASCADE;
ALTER TABLE checklist_sections ADD COLUMN IF NOT EXISTS name        TEXT NOT NULL;
ALTER TABLE checklist_sections ADD COLUMN IF NOT EXISTS order_index INT NOT NULL DEFAULT 0;
```

**`checklist_items`** (mirrors `template_items` + adds `photo` response type)

```sql
CREATE TABLE IF NOT EXISTS checklist_items (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_items ADD COLUMN IF NOT EXISTS template_id   UUID NOT NULL
  REFERENCES checklist_templates(id) ON DELETE CASCADE;
ALTER TABLE checklist_items ADD COLUMN IF NOT EXISTS section_id    UUID
  REFERENCES checklist_sections(id) ON DELETE SET NULL;
ALTER TABLE checklist_items ADD COLUMN IF NOT EXISTS question      TEXT NOT NULL;
ALTER TABLE checklist_items ADD COLUMN IF NOT EXISTS guidance      TEXT;
ALTER TABLE checklist_items ADD COLUMN IF NOT EXISTS response_type TEXT NOT NULL DEFAULT 'yes_no';
  -- reuses: 'ok_nok', 'yes_no', 'scale_1_5', 'percentage', 'text', 'selection'
  -- new type: 'photo' (answer is a storage path or empty)
ALTER TABLE checklist_items ADD COLUMN IF NOT EXISTS required      BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE checklist_items ADD COLUMN IF NOT EXISTS weight        INT NOT NULL DEFAULT 1;
ALTER TABLE checklist_items ADD COLUMN IF NOT EXISTS order_index   INT NOT NULL DEFAULT 0;
ALTER TABLE checklist_items ADD COLUMN IF NOT EXISTS options       TEXT[];
  -- used only for response_type = 'selection'
```

**`checklist_execucoes`** (mirrors `audits` but simpler — no audit_type, no perimeter)

```sql
CREATE TABLE IF NOT EXISTS checklist_execucoes (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS template_id      UUID NOT NULL
  REFERENCES checklist_templates(id) ON DELETE RESTRICT;
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS company_id       UUID NOT NULL
  REFERENCES companies(id) ON DELETE RESTRICT;
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS responsavel_id   UUID NOT NULL
  REFERENCES profiles(id) ON DELETE RESTRICT;
  -- "responsavel" is the person filling the checklist (equivalent to auditor_id)
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS local            TEXT;
  -- free-text location field (no perimeter hierarchy required)
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS numero           TEXT;
  -- free-text reference/sequence number entered by the user
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS status           TEXT NOT NULL DEFAULT 'rascunho';
  -- values: 'rascunho', 'em_andamento', 'concluido', 'cancelado'
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS conformidade_pct NUMERIC(5,2);
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS signature_path   TEXT;
  -- Storage path for the captured signature image (PNG)
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS completed_at     TIMESTAMPTZ;
ALTER TABLE checklist_execucoes ADD COLUMN IF NOT EXISTS data_aplicacao   DATE;
  -- the "date" field in the execution identification step
```

Note: Use Portuguese field names (`responsavel_id`, `local`, `numero`, `conformidade_pct`,
`data_aplicacao`) where the domain concept is Brazilian. Keep technical IDs and
timestamps in English following existing conventions (`company_id`, `created_at`, etc.).

**`checklist_respostas`** (mirrors `audit_answers`)

```sql
CREATE TABLE IF NOT EXISTS checklist_respostas (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_respostas ADD COLUMN IF NOT EXISTS execucao_id UUID NOT NULL
  REFERENCES checklist_execucoes(id) ON DELETE CASCADE;
ALTER TABLE checklist_respostas ADD COLUMN IF NOT EXISTS item_id     UUID NOT NULL
  REFERENCES checklist_items(id) ON DELETE RESTRICT;
ALTER TABLE checklist_respostas ADD COLUMN IF NOT EXISTS resposta    TEXT NOT NULL;
ALTER TABLE checklist_respostas ADD COLUMN IF NOT EXISTS observacao  TEXT;
ALTER TABLE checklist_respostas ADD COLUMN IF NOT EXISTS respondido_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Unique constraint: one answer per item per execution (same upsert pattern as audit_answers)
ALTER TABLE checklist_respostas DROP CONSTRAINT IF EXISTS checklist_respostas_unique;
ALTER TABLE checklist_respostas ADD CONSTRAINT checklist_respostas_unique
  UNIQUE (execucao_id, item_id);
```

**`checklist_item_images`** (mirrors `audit_item_images`)

```sql
CREATE TABLE IF NOT EXISTS checklist_item_images (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY
);
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS execucao_id  UUID NOT NULL
  REFERENCES checklist_execucoes(id) ON DELETE CASCADE;
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS item_id      UUID NOT NULL
  REFERENCES checklist_items(id) ON DELETE RESTRICT;
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS company_id   UUID NOT NULL
  REFERENCES companies(id) ON DELETE RESTRICT;
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS storage_path TEXT NOT NULL;
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS created_by   UUID NOT NULL
  REFERENCES profiles(id) ON DELETE RESTRICT;
ALTER TABLE checklist_item_images ADD COLUMN IF NOT EXISTS created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW();
```

Images reuse the same `audit-images` Storage bucket. The path convention changes
to `{companyId}/checklist/{execucaoId}/{itemId}/{uuid}.jpg` — the `checklist/`
segment ensures no path collision with the existing `{companyId}/{auditId}/...` paths,
and the existing Storage RLS policy (which only checks `(storage.foldername(name))[1] =
get_my_company_id()`) continues to work without modification.

### RLS patterns

Follow the exact three-policy pattern already established in `20260406_create_audits.sql`
and `20260427_create_audit_item_images.sql`:

```
1. superuser_dev_<table>_full         USING + WITH CHECK: role IN ('superuser','dev')
2. adm_<table>_company                USING + WITH CHECK: role = 'adm' AND company_id = get_my_company_id()
3. auditor_<table>_select_company     FOR SELECT: role = 'auditor' AND company_id = get_my_company_id()
4. auditor_<table>_insert_own         FOR INSERT: role = 'auditor' AND company_id = get_my_company_id() AND responsavel_id/created_by = auth.uid()
5. auditor_<table>_update_own         FOR UPDATE: role = 'auditor' AND responsavel_id/created_by = auth.uid()
```

For `checklist_templates` (has `is_padrao` seeds with `company_id IS NULL`), mirror
the `authenticated_audit_templates_select` pattern:

```sql
CREATE POLICY "authenticated_checklist_templates_select" ON checklist_templates FOR SELECT
  USING (
    get_my_role() IS NOT NULL
    AND (company_id IS NULL OR company_id = get_my_company_id())
  );
```

For `checklist_items` and `checklist_sections` (no direct `company_id`), use the
subquery pattern from `template_items`:

```sql
CREATE POLICY "adm_checklist_items_company" ON checklist_items
  USING (
    get_my_role() = 'adm'
    AND EXISTS (
      SELECT 1 FROM checklist_templates t
      WHERE t.id = checklist_items.template_id
        AND t.company_id = get_my_company_id()
    )
  )
  WITH CHECK ( ... same ... );
```

### Seed templates

The 10 seed templates should be inserted via a dedicated migration
`<date>_checklist_seed_templates.sql`. Use
`INSERT ... ON CONFLICT DO NOTHING` with a unique constraint on `(name, is_padrao)`
filtered where `is_padrao = true` to make the seed idempotent. Seeds have
`company_id = NULL`, `is_padrao = true`, `created_by = NULL`.

The app reads seeds with the same `.or('company_id.is.null,company_id.eq.$companyId')`
filter used for `audit_templates`. This surfaces seeds to every company without
duplicating rows — each company sees the originals. When a user clones a seed, a
new row is created with `company_id = <their company>` and `is_padrao = false`.

---

## 2. Service Layer

### Split by concern: two services

The existing codebase splits at a natural seam: `AuditTemplateService` manages the
definition side (types, templates, sections, items), while `AuditAnswerService` manages
execution-time answers plus the conformity calculation. The same split applies here.

**`ChecklistTemplateService`** — `lib/services/checklist_template_service.dart`

Manages: `checklist_templates`, `checklist_sections`, `checklist_items`.

```
getTemplates({String? companyId, String? category}) -> List<ChecklistTemplate>
getTemplate(String id)                               -> ChecklistTemplate
createTemplate({...})                                -> ChecklistTemplate
updateTemplate(String id, {...})                     -> void
cloneTemplate(String templateId, String companyId)   -> ChecklistTemplate
toggleTemplate(String id, bool active)               -> void
deleteTemplate(String id)                            -> void
getSections(String templateId)                       -> List<ChecklistSection>
createSection(...)                                   -> ChecklistSection
updateSection(...)                                   -> void
deleteSection(...)                                   -> void
getItems(String templateId)                          -> List<ChecklistItem>
createItem({...})                                    -> ChecklistItem
updateItem(String id, {...})                         -> void
deleteItem(String id)                                -> void
```

The `cloneTemplate` method deep-copies template + sections + items in sequential
service calls (PostgREST does not support multi-statement transactions from the
Flutter client). Risk: partial clone on network failure. For MVP, partial clones
are visible in the template list and can be deleted by the user. If atomicity is
required later, implement a Supabase Edge Function (deferred).

**`ChecklistExecutionService`** — `lib/services/checklist_execution_service.dart`

Manages: `checklist_execucoes`, `checklist_respostas`.

```
getExecucoes({String? companyId, String? status, DateTime? from, DateTime? to})
  -> List<ChecklistExecucao>
getExecucao(String id)              -> ChecklistExecucao
createExecucao({...})               -> ChecklistExecucao
updateStatus(String id, String status, {double? conformidadePct}) -> void
finalizeExecucao(String id, double conformidade, {String? signaturePath}) -> void
deleteExecucao(String id)           -> void
getRespostas(String execucaoId)     -> List<ChecklistResposta>
upsertResposta({...})               -> void
  -- onConflict: 'execucao_id,item_id' (same as audit_answers upsert)
deleteResposta(String execucaoId, String itemId) -> void
static double calculateConformidade(List<ChecklistItem> items, Map<String,String> respostas)
  -- same weighted algorithm as AuditAnswerService.calculateConformity
```

Why two services rather than one: The template side has no runtime coupling to
execution. Keeping them separate mirrors the existing `AuditTemplateService` /
`AuditAnswerService` split, stays consistent with the flat `services/` directory
structure, and makes each service unit-testable in isolation — consistent with the
existing test suite that tests `DashboardService`, `calculateConformity`, and role
helpers independently.

---

## 3. Shared Components — Photo Upload

### Do not extract a shared widget for MVP

The existing photo upload widget (`_ImageStrip` and related private classes in
`audit_execution_screen.dart`) is tightly coupled to `AuditItemImage`, `ImageService`,
and the `audit_item_images` data model. Extracting it into a shared component requires
abstracting away the type differences (`AuditItemImage` vs `ChecklistItemImage`) and
parameterizing the service calls — which under the `setState` constraint (no
Riverpod/BLoC) adds complexity without proportional benefit for a single new callsite.

**Recommended approach:** Duplicate the pattern. Create `ChecklistImageService`
mirroring `ImageService`, operating on `checklist_item_images`. The image widget
inside `checklist_execution_screen.dart` is a private `_ChecklistImageStrip` that
mirrors `_ImageStrip` in `audit_execution_screen.dart`.

**Storage:** Reuse the existing `audit-images` bucket with path
`{companyId}/checklist/{execucaoId}/{itemId}/{uuid}.jpg`. The existing Storage RLS
policy checks only `(storage.foldername(name))[1] = get_my_company_id()::text`, so
it covers checklist paths without modification.

**Future refactor:** When state management is upgraded to Riverpod/BLoC, extract
a shared `ImagePickerWidget` parameterized by callbacks. That belongs to the state
management milestone.

### Preserve upload independence from answer saving

`ChecklistImageService.uploadImage` throws on failure; the execution screen's
`_saveResposta` catches errors independently and never awaits image upload. Same
architecture as `audit_execution_screen.dart` lines 272–303.

---

## 4. PDF Generation — Layer Placement

### Use `pdf` + `printing` packages

- `pdf` (pub.dev/packages/pdf): pure Dart PDF document builder with a Flutter-like
  widget API (Widget, Column, Row, Table, MemoryImage). No native dependencies.
  Stable at 3.x. Apache 2.0 license.
- `printing` (pub.dev/packages/printing): wraps platform share mechanisms.
  `Printing.sharePdf(bytes: bytes, filename: ...)` opens the native share sheet
  on Android and iOS, covering WhatsApp, email, Files, and any system share target.
  No separate URL launcher or email package needed for export.

### Layer placement: a dedicated `ChecklistPdfService`

PDF generation belongs in the service layer, not a utility or screen. Rationale:
(1) it operates on domain objects (`ChecklistExecucao`, `ChecklistResposta`,
`ChecklistItem`) — it is business logic; (2) it returns a `Uint8List` that the
screen passes directly to `Printing.sharePdf` in a one-liner; (3) it can be
smoke-tested without Flutter widgets (assert byte count > 0 for a known input).

```dart
// lib/services/checklist_pdf_service.dart
class ChecklistPdfService {
  Future<Uint8List> generateRelatorio({
    required ChecklistExecucao execucao,
    required List<ChecklistItem> items,
    required Map<String, String> respostas,
    required Map<String, String> observacoes,
    Uint8List? signatureBytes,
    List<ChecklistItemImage> imagens = const [],
  });
}
```

The screen calls:
```dart
final bytes = await _pdfService.generateRelatorio(...);
await Printing.sharePdf(bytes: bytes, filename: 'checklist_${execucao.numero}.pdf');
```

### New pubspec dependencies to add

```yaml
pdf: ^3.11.0        # pure Dart PDF builder
printing: ^5.13.2   # share/print/preview wrapper
signature: ^5.4.0   # digital signature capture canvas
```

`signature` (pub.dev/packages/signature): actively maintained, returns `Uint8List`
PNG from `SignatureController.toPngBytes()` — embeds directly into `pdf` via
`pw.MemoryImage(bytes)`. It is the most downloaded signature package on pub.dev
with consistent updates through 2024-2025.

`hand_signature` is an alternative with smoother Bezier strokes but has fewer
downloads and less active maintenance. Use `signature` for lower dependency risk.

---

## 5. Navigation: Drawer Entry

Modify `lib/screens/home_screen.dart`. Add a `ListTile` for "Checklist" in
`_buildDrawer` between "Acoes Corretivas" and "Perfil". Push
`ChecklistHomeScreen` (`lib/screens/checklist/checklist_home_screen.dart`).

Only `home_screen.dart` is modified in existing files for navigation.

---

## 6. New vs Modified Components

### New files

```
lib/models/
  checklist_template.dart       — ChecklistTemplate, ChecklistSection, ChecklistItem
  checklist_execucao.dart       — ChecklistExecucao, ChecklistStatus enum
  checklist_resposta.dart       — ChecklistResposta
  checklist_item_image.dart     — ChecklistItemImage (mirrors AuditItemImage)

lib/services/
  checklist_template_service.dart   — CRUD + clone
  checklist_execution_service.dart  — CRUD + upsertResposta + calculateConformidade
  checklist_image_service.dart      — mirrors ImageService
  checklist_pdf_service.dart        — generates PDF Uint8List

lib/screens/checklist/
  checklist_home_screen.dart              — tab view: Seeds | Meus Templates | Historico
  checklist_template_detail_screen.dart   — view/edit template sections+items
  checklist_template_builder_screen.dart  — create/edit custom template
  checklist_execution_screen.dart         — fill checklist, auto-save, finalize
  checklist_historico_screen.dart         — history list with filters
  checklist_historico_detail_screen.dart  — read-only view + PDF export button

supabase/migrations/
  <date>_create_checklist_tables.sql      — 5 tables + indexes + RLS (one file)
  <date>_checklist_seed_templates.sql     — INSERT seeds (idempotent)
```

### Modified files (minimal surface area)

```
lib/screens/home_screen.dart    — add "Checklist" ListTile to drawer
pubspec.yaml                    — add pdf, printing, signature packages
```

No changes to: `AuditTemplateService`, `AuditAnswerService`, `ImageService`,
`AuditExecutionScreen`, corrective actions, or dashboard — all existing flows
are untouched.

---

## 7. Suggested Phase Build Order

Phase ordering respects hard dependencies and the "no broken intermediate state"
principle used in v1.1.

### Phase A — DB Foundation + Template CRUD

**Deliverables:**
- Migration: all 5 checklist tables + RLS + seed templates
- Models: `ChecklistTemplate`, `ChecklistSection`, `ChecklistItem`
- Service: `ChecklistTemplateService` (full CRUD + clone)
- Screens: `ChecklistHomeScreen`, `ChecklistTemplateDetailScreen`,
  `ChecklistTemplateBuilderScreen`
- Drawer entry in `HomeScreen`

**Why first:** Everything downstream depends on templates existing in the DB.
Seeds can be validated in the UI immediately. No execution logic needed yet.

**Validation gate:** Can create a custom template, clone a seed, add sections
and items, browse the three categories.

### Phase B — Execution + Auto-save

**Deliverables:**
- Models: `ChecklistExecucao`, `ChecklistResposta`
- Service: `ChecklistExecutionService` (createExecucao, upsertResposta,
  calculateConformidade, finalizeExecucao)
- Screen: `ChecklistExecutionScreen` with all response types, auto-save retry
  queue, progress bar, finalize flow (mirrors `AuditExecutionScreen`)

**Why second:** Core value delivery — the answer-saving retry queue (the
`_failedSaves` map pattern) is the most critical behavior. Build and validate
the execution loop before adding photo upload or signature.

**Validation gate:** Start execution, answer items of all types, lose WiFi and
reconnect (retry triggers), finalize and verify `conformidade_pct` persisted.

### Phase C — Photos per Item

**Deliverables:**
- Model: `ChecklistItemImage`
- Service: `ChecklistImageService`
- Widget: `_ChecklistImageStrip` inside `ChecklistExecutionScreen`
- Storage path: `{companyId}/checklist/{execucaoId}/{itemId}/{uuid}.jpg`

**Why third:** Photos are fully independent of answer saving. Adding them after
execution is stable ensures the independence boundary is tested cleanly.

**Validation gate:** Photo upload failure shows error without blocking finalization;
multiple images per item display as thumbnails; signed URLs render correctly.

### Phase D — Digital Signature

**Deliverables:**
- `signature` package added to pubspec
- `_SignatureStep` widget at finalization in `ChecklistExecutionScreen`
- Signature PNG uploaded to `{companyId}/checklist/signatures/{execucaoId}.png`
- `signature_path` saved to `checklist_execucoes`

**Why fourth:** Signature only appears at the finalization step, after all items
are answered. Build it as an extension of Phase B's finalization flow, once photos
(Phase C) are stable.

**Validation gate:** Signature captured, exported as PNG, uploaded, `signature_path`
visible in DB.

### Phase E — Historico + PDF

**Deliverables:**
- `pdf` + `printing` packages added to pubspec
- Service: `ChecklistPdfService`
- Screens: `ChecklistHistoricoScreen`, `ChecklistHistoricoDetailScreen`
- PDF report: header (template name, responsavel, local, data), items table with
  respostas and observacoes, photos embedded, signature at bottom
- Share via `Printing.sharePdf` (native share sheet)

**Why last:** PDF requires completed executions (Phase B), photos (Phase C),
and signature path (Phase D) to produce a complete report. History screen
requires executions to exist. Both are pure additions — zero risk to existing flows.

**Validation gate:** Generate PDF from a completed checklist, share to WhatsApp,
verify all items, photos, and signature render correctly.

### Summary table

| Phase | Hard Dependencies | Risk to Existing Flows | Complexity |
|-------|-------------------|----------------------|------------|
| A — DB + Template CRUD | none | none | medium |
| B — Execution + Auto-save | Phase A | none | high |
| C — Photos | Phase B | none | medium |
| D — Signature | Phase B | none | low |
| E — Historico + PDF | B + C + D | none | medium |

---

## 8. Key Architectural Constraints (Enforced by Existing Patterns)

1. **No shared DI**: Services instantiated locally — `final _svc = ChecklistTemplateService()`
   inside each `StatefulWidget`, same as every other service in the codebase.

2. **No BLoC/Riverpod**: All state in `StatefulWidget` + `setState`. The execution
   screen follows `AuditExecutionScreen`'s exact `_answers`, `_failedSaves`,
   `_retrying` map pattern.

3. **Error handling in callers, not services**: Services throw; screens catch.
   `_saveResposta` is the one exception — silent catch for auto-save, same as
   `_saveAnswer` in `AuditExecutionScreen`.

4. **Idempotent migrations**: All SQL uses `CREATE TABLE IF NOT EXISTS`,
   `ADD COLUMN IF NOT EXISTS`, `DROP CONSTRAINT IF EXISTS`, `DROP POLICY IF EXISTS`
   before re-creating.

5. **PostgREST schema reload**: Every migration ends with
   `NOTIFY pgrst, 'reload schema';`.

---

## Sources

- Direct reading: `primeaudit/supabase/migrations/20260406_create_audits.sql` — RLS three-policy pattern, idempotent migration pattern, trigger pattern
- Direct reading: `primeaudit/supabase/migrations/20260418_rls_profiles_companies_perimeters.sql` — global/company RLS, subquery pattern for indirect company_id
- Direct reading: `primeaudit/supabase/migrations/20260427_create_audit_item_images.sql` — Storage bucket, image RLS, path convention
- Direct reading: `primeaudit/lib/services/audit_template_service.dart` — service split by concern, getTemplates with global OR pattern
- Direct reading: `primeaudit/lib/services/audit_answer_service.dart` — upsert with onConflict, calculateConformity algorithm
- Direct reading: `primeaudit/lib/services/image_service.dart` — upload-independent-of-answer pattern, storage path convention
- Direct reading: `primeaudit/lib/screens/audit_execution_screen.dart` — _failedSaves retry queue, _saveAnswer catch, finalize guard
- Web search: [pdf | Dart package](https://pub.dev/packages/pdf)
- Web search: [printing | Flutter package](https://pub.dev/packages/printing)
- Web search: [signature | Flutter package](https://pub.dev/packages/signature)
