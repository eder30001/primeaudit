# Feature Landscape: Checklist Module (v1.2)

**Domain:** Industrial inspection & transport checklist app (Flutter + Supabase)
**Researched:** 2026-05-02
**Scope:** New Checklist module added to PrimeAudit — lighter than Audit, for field inspectors, truck drivers, warehouse workers.

---

## Table Stakes

Features that field users expect. Missing any of these makes the product feel incomplete or untrustworthy.

| Feature | Why Expected | Complexity | Reuse from Audit Module |
|---------|--------------|------------|------------------------|
| Template library with categories | Users need to find the right form quickly; category tabs (Industrial / Transportadora / Meus) are the standard pattern in GoAudits, iAuditor | Low | Partial — AuditTemplate + AuditTemplateService exist; need new `checklist_templates` table scoped differently |
| CRUD for custom templates | Field teams need to create their own forms; read-only seed library alone is not enough | Medium | Partial — TemplateSection/TemplateItem models and service logic can be cloned; new entities needed |
| Clone template | Starting from blank is rare; cloning a seed and adjusting is the universal workflow in SafetyCulture, GoAudits | Low-Medium | None currently — new service method needed |
| Execution identification header | Every industrial checklist form requires: Responsavel (person), Local/Equipamento (location), Data (date), Numero (sequential ID). Mandatory in Brazilian fleet inspection (CONTRAN) and ISO 9001 field forms | Low | None — Audits use auditor from profile + perimeter; Checklist needs free-text fields in the execution header |
| Sim / Nao response per item | The baseline response type; all transport and industrial checklists use pass/fail | Trivial | yes_no widget exists in AuditExecutionScreen — directly reusable |
| Text observation per item | Inspectors always need to describe non-conformities; required by ISO/OSHA inspection standards | Trivial | `_observations` map + _TextAnswer widget exist — directly reusable |
| Photo per item | Visual evidence is standard in all industrial inspection apps (iAuditor, GoFormz, FastField); especially critical for vehicle condition checks | Low | ImageService + image_picker already integrated in Phase 9 |
| Autosave draft during execution | Core Value of PrimeAudit — no data loss; iAuditor and FastField both save per-item; losing a 30-item truck inspection is unacceptable | Low | _saveAnswer + _PendingSave retry pattern exists — reusable |
| Checklist history list | Users need to retrieve past records; audit trail is required for compliance | Low | AuditsScreen pattern directly reusable |
| Conformity indicator in history | Pass rate (items OK / total items) at a glance; standard KPI for compliance managers | Low | calculateConformity() in AuditAnswerService — reusable |
| Close/finalize checklist | Explicit finalization locks the record; prevents accidental edits | Low | AuditService encerrar pattern — reusable |
| Drawer entry "Checklist" | Module discovery; users won't use what they can't find | Trivial | HomeScreen drawer — add one entry |

---

## Response Types Beyond Sim/Nao

All types below are expected in industrial inspection apps for v1.2. The existing Audit execution screen already implements several; all can be reused or lightly adapted.

| Type | Use Case | Widget Pattern | Reuse Status |
|------|----------|----------------|--------------|
| `yes_no` (Sim/Nao) | Standard pass/fail (pneus OK?, extintor presente?) | Two large tap targets, green/red, icon + label | EXISTS — _TwoOptionButtons with yes/no |
| `ok_nok` (Conforme/Nao Conforme) | Quality conformity language | Same widget, different labels | EXISTS |
| `text` (Texto livre) | Open descriptions, odometer, observations | Multiline TextField, debounced save | EXISTS — _TextAnswer |
| `number` (Numero) | Mileage (KM), pressure readings, temperatures, quantities | TextFormField with keyboardType: number, validation min/max | NEW TYPE — needs widget; Flutter TextFormField trivial |
| `date` (Data) | Date of last maintenance, expiry dates, last occurrence | showDatePicker(), stores ISO8601 string | NEW TYPE — Flutter built-in showDatePicker, trivial |
| `selection` (Selecao multipla) | Vehicle type, shift, category, pre-defined option lists | Chip row or DropdownButton | EXISTS — _SelectionAnswer with options list |
| `scale_1_5` (Escala) | Condition rating for equipment/environment | Row of 5 numbered buttons | EXISTS — _ScaleButtons |
| `percentage` (Percentual) | Fill level, completion %, load capacity | Slider 0-100 | EXISTS — _PercentageSlider |
| `signature` (Assinatura) | Final sign-off by inspector/driver at checklist close | Full-screen canvas modal, saves PNG to Supabase Storage | NEW — hand_signature or signature package; medium complexity |

**Notes on new types:**
- `number`: Needs new `responseType: 'number'` case in the execution switch. Optionally supports `min`/`max` bounds in the template item. Trivial to add.
- `date`: Needs new `responseType: 'date'` case. Flutter's `showDatePicker()` is built-in. Store as `YYYY-MM-DD` string. Trivial to add.
- `signature`: Different from per-item types — it is a global sign-off at the end of execution, not per-item. Store as PNG uploaded to Supabase Storage (same pattern as audit item photos). The `signature` pub.dev package (pure Dart, MIT) is the simplest choice; `hand_signature` provides smoother stroke rendering. Either works; `signature` has fewer dependencies.

---

## Template Management UX Patterns

Based on iAuditor / GoAudits / SafetyCulture patterns and the existing TemplateBuilder in PrimeAudit.

### Category Tabs (TMPLCK-01)

The standard pattern is three tabs on the template list screen:
1. **Industrial** — seed templates: equipment inspection, warehouse safety, EPI check, fire safety, electrical panel, forklift
2. **Transportadora** — seed templates: pre-trip vehicle, truck cabin, load securing, tires/brakes, driver documentation, emergency kit
3. **Meus Checklists** — company-scoped templates created or cloned by the user's company

This matches the `company_id IS NULL` vs `company_id = X` pattern already in AuditTemplate. Seeds have `company_id = NULL` and a `category` column (`industrial` | `transportadora`). Custom templates have `company_id = X` and `category = 'custom'`.

**Dependency:** Requires new `checklist_templates` table (separate from `audit_templates`) or a `module: 'checklist'` column on the existing table. Separate table is cleaner — avoids polluting audit template queries with checklist-specific columns like `category`.

### Clone Flow (TMPLCK-05)

Pattern from GoAudits: user taps "Usar este template" on a seed, then picks "Usar diretamente" or "Clonar e personalizar". For v1.2, cloning is the primary path (direct use works too — no copy needed if you just want to run the seed).

Clone UX: Long-press or swipe action on a template card shows "Clonar". App creates a copy under the company's namespace. Name gets suffix " (copia)" by default and opens the TemplateBuilder immediately. Medium complexity due to batch inserts of sections + items with new UUIDs, but no novel patterns.

### Template Builder (TMPLCK-02/03/04)

The existing `TemplateBuilderScreen` handles sections and items. For the Checklist module this screen can be reused almost entirely with two additions:
1. New response types (`number`, `date`) in the type picker dropdown
2. Category picker (industrial / transportadora / custom) shown only on template creation

---

## Execution Flow — Identification Header (EXEC-01)

Every industrial checklist form has a structured header collected before the item list begins. Based on Brazilian fleet inspection standards and iAuditor templates:

**Required header fields:**
| Field | Type | Notes |
|-------|------|-------|
| Responsavel | Text (free) | Who is performing the inspection; pre-filled from logged-in user's full_name but editable (drivers may hand off the device) |
| Local / Equipamento | Text (free) | Location name, equipment tag, vehicle plate, or warehouse zone |
| Data | Date | Defaults to today; editable for back-dated records |
| Numero / Codigo | Text | Sequential ID, work order number, or vehicle fleet ID; optional but expected in transport context |
| Observacao geral | Text (free, multiline) | Overall notes before starting; optional |

**UX pattern:** Show header as Step 1 of execution before the item list. Two-step flow: (1) fill header, tap "Iniciar Checklist" → (2) item list with autosave. This differs from Audit which collects header during multi-step creation; for Checklist the header is lighter and collected at execution start.

**Storage:** Store header fields as columns on the `checklist_executions` table, not as checklist items. This makes filter queries trivial (no JSON parsing, direct column equality/ILIKE).

---

## History and Reporting (HIST-01/02/03)

### Filter Set

Based on industry patterns (FTQ360 dashboard, iAuditor history, Xenia reports):

| Filter | Type | Priority |
|--------|------|----------|
| Data range | Date range picker (from/to), with presets: Hoje, Ultimos 7 dias, Ultimo mes | HIGH — most used filter |
| Template / Tipo | Dropdown from available templates | HIGH |
| Responsavel | Text search against `responsavel` field (ILIKE) | MEDIUM |
| Local | Text search against `local` field (ILIKE) | MEDIUM |
| Status | Enum chips: Rascunho / Em andamento / Concluido | MEDIUM |
| Conformidade minima | Optional min% threshold slider | LOW — useful for compliance managers, not field workers |

**Sticky filters:** Remember last-used filter state in widget memory (no SharedPreferences needed — session scope sufficient). Standard UX in GoAudits and FTQ360.

### Conformity Indicator

The existing `calculateConformity()` in AuditAnswerService applies directly: items with `yes_no` treat "yes" as conforming; `ok_nok` treats "ok" as conforming. Per-item weight is used. Show as colored badge (green >= 80%, orange 50-79%, red < 50%) on each history card — same visual language as the Audit module.

**Critical decision on number/date types:** `number` and `date` response types have no correct/incorrect answer. These types should be excluded from the conformity denominator. Implementation options: (a) mark `contributes_to_conformity: false` as a boolean column on `checklist_items`, or (b) derive it from response type in the calculation function. Option (b) is simpler and sufficient for v1.2.

### History KPIs (above the list)

Show three KPIs in a row above the history list:
1. Total de checklists (within filtered range)
2. Conformidade media % (filtered range, excludes non-conformity types)
3. Nao conformidades (total item count with nok/no responses across all filtered checklists)

---

## PDF Report Layout (REP-01/02)

Based on GoFormz, GoAudits, and FastField report conventions. Use `pdf` + `printing` packages (both MIT-licensed, pub.dev official packages).

### Recommended Layout (A4 portrait)

**Page Header (repeats on every page):**
- Left: Company name (or logo image if stored in Supabase Storage)
- Center: "RELATORIO DE CHECKLIST" + template name
- Right: Checklist number + date

**Report Header Block (page 1 only):**
- Two-column grid: Responsavel | Local/Equipamento | Data | Numero
- Horizontal rule separator

**Summary Block (page 1):**
- Conformidade geral: large percentage text with color (green/orange/red)
- Stat row: Total itens | Conformes | Nao conformes | N/A
- Visual progress bar

**Items Table (page 1+, auto-paginates via MultiPage):**
- Grouped by section
- Section name as bold header row with shaded background
- Per item row: #num | Question text | Response | Observation
- Non-conforming items: light red row background for visual scanning
- Response rendered as readable text ("Sim", "Nao", "Conforme", numeric value, date string)

**Photos Block (after item table, paginated):**
- 2-column grid of photos
- Each photo labeled with item question text and capture timestamp
- MultiPage handles automatic pagination

**Signature Block (last page):**
- Full-width bordered box: "Assinatura do Responsavel"
- Signature PNG rendered inline (from Supabase Storage URL)
- Name + date/time of signature below image

**Footer (every page):**
- "Gerado por PrimeAudit" | Page X of Y | Generation timestamp

**Package recommendation:** `pdf` (v3.x) + `printing` (v5.x), both MIT-licensed with no commercial restrictions. Syncfusion requires community license registration — not worth the friction for this scope. HIGH confidence based on official pub.dev packages.

---

## Differentiators

Features that go beyond standard expectations — valuable but not blocking v1.2 launch.

| Feature | Value Proposition | Complexity | Scope Recommendation |
|---------|-------------------|------------|---------------------|
| 10 seed templates pre-loaded | Zero setup for new companies; truck drivers start on Day 1 | Medium — SQL migration with rich data | v1.2 — already planned (TMPLCK-06) |
| Digital signature at close | Legal accountability; drivers/inspectors sign off on their inspection | Medium — signature package + Storage upload + PDF embed | v1.2 — already planned (EXEC-06) |
| PDF export via WhatsApp/email | Field workers share reports immediately with supervisors on the spot | Low-Medium — share_plus package or url_launcher with mailto: | v1.2 — already planned (REP-02) |
| Sequential checklist number | Compliance audit trail — "checklist numero 0042 de maio"; required for formal inspection records | Low — auto-increment per company in DB | v1.2 — worth adding, trivial |
| Conditional fields (show/hide based on prior response) | iAuditor "Smart Fields" — avoids showing irrelevant items (e.g., show "plate number" only if vehicle type = caminhao) | High — logic engine in execution screen | DEFER to v1.3 |
| Offline execution with sync | Differentiator for transport field work (no signal in warehouses/trucks on route) | Very High — conflict resolution, sync queue, schema migration | DEFER — out of scope per PROJECT.md |
| QR code / NFC for equipment identification | Scan equipment tag → auto-fill Local field | Medium | DEFER — v1.3 |
| Multi-period consolidated report | Trend analysis, repeated inspection comparison | High | DEFER — v2 |

---

## Anti-Features

Features to explicitly NOT build in v1.2.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Conditional fields (smart fields) | Execution engine complexity multiplies test surface; prone to edge-case bugs; iAuditor took years to stabilize this | Ship without; use guidance text per item as compensation |
| Full offline mode | Requires sync queue, conflict resolution, schema migration — a milestone of its own | Silently retry on reconnect (existing _PendingSave pattern covers network blips) |
| Integrate Checklist into Audit flow | The two modules serve different use cases; shared DB tables would couple unrelated schemas | Keep separate tables, separate module entry |
| Advanced graph reports in history | fl_chart works but adding trend lines, multi-checklist overlays inflates scope | Show simple conformity badge per card; KPI row above list is sufficient for v1.2 |
| Two-step supervisor approval | Adds CAPA-like state machine complexity; not requested | Single executor + digital signature is sufficient for this milestone |
| Mandatory corrective action creation on NOK | Audit module links NOK to CAPA; for Checklist this is too heavy | Allow optional "add observation" per NOK item; corrective actions integration is v1.3 |

---

## Feature Dependencies

```
Seed templates (TMPLCK-06)
    └── required before: Execution (EXEC-01), History (HIST-01), Demo/onboarding

Template CRUD (TMPLCK-02/03/04)
    └── required before: Clone (TMPLCK-05) — clone is a specialized create operation

Execution identification header (EXEC-01)
    └── required before: History filters (HIST-01/02) — filtered columns must exist in DB

Response types: number + date (EXEC-02)
    └── required before: PDF report — report must render all response types correctly

Autosave draft (EXEC-05)
    └── parallel with: all execution features — same _saveAnswer pattern, no additional dependencies

Photo per item (EXEC-04)
    └── depends on: ImageService (already built in Phase 9) — trivial integration
    └── required before: PDF report with photos (REP-01)

Signature (EXEC-06)
    └── required before: PDF report signature block (REP-01)
    └── depends on: Supabase Storage (already configured in Phase 9)

PDF generation (REP-01)
    └── depends on: all execution features complete, signature available, photos available
    └── required before: Export/share (REP-02)

History list (HIST-01)
    └── required before: Conformity indicators (HIST-03), filter controls (HIST-02)
```

---

## MVP Recommendation

Build in this order:

1. **Template management** (TMPLCK-01 to 06) — unblocks everything else; seed templates enable demo immediately without custom setup
2. **Execution with all response types + autosave** (EXEC-01 to 05) — core value; autosave is non-negotiable per Core Value principle
3. **History with filters and conformity** (HIST-01 to 03) — closes the compliance loop; supervisors need to see records
4. **Signature + PDF export** (EXEC-06, REP-01, REP-02) — differentiating features; add last when execution is stable and tested

Defer to v1.3:
- Conditional fields (smart fields)
- Multi-period trend reports
- QR/NFC equipment identification
- Full offline mode
- Corrective action integration for checklist non-conformities

---

## Seed Template Examples (TMPLCK-06)

10 templates covering both categories. These inform the DB migration data:

**Industrial (5):**
1. Inspecao de EPI — verifica capacete, luvas, botas, oculos, colete; ~15 items yes/no
2. Vistoria de Empilhadeira — bateria, freios, garfo, sinalizacao, extintores; ~20 items yes/no + scale
3. Inspecao de Racking / Prateleiras — danos estruturais, capacidade, sinalizacao; ~12 items ok/nok + photo
4. Checklist de Seguranca Eletrica — quadro eletrico, aterramento, cabos, etiquetagem; ~18 items ok/nok
5. Inspecao de Area de Armazenagem — limpeza, organizacao, saidas de emergencia, sinalizacao; ~15 items ok/nok + text

**Transportadora (5):**
1. Checklist Pre-Viagem (Caminhao) — documentacao (CRLV, CNH), extintor, triangulo, pneus, luzes, freios, oleo; ~25 items yes/no + number (km)
2. Vistoria de Carroceria / Bau — vedacao, fechamentos, estado estrutural, lonas; ~12 items ok/nok + photo
3. Conferencia de Carga — volumes, amarracao, peso estimado, lacre; ~10 items yes/no + number + text
4. Checklist Pos-Viagem — avarias, combustivel, documentacao, ocorrencias; ~15 items yes/no + text
5. Inspecao de Pneus e Rodagem — pressao (number), profundidade de sulco (number), danos visuais (ok/nok + photo); ~8 items mixed types

---

## Sources

- [GoAudits Template Management Help](https://support.goaudits.com/en/articles/4493455-choose-customize-or-create-audit-templates) — MEDIUM confidence (support article)
- [SafetyCulture iAuditor Template Features](https://public-library.safetyculture.io/) — MEDIUM confidence (product site)
- [Inspectly360 Fleet Vehicle Inspection Checklist](https://www.inspectly360.com/checklists/transport-logistics-warehousing/fleet-vehicle-inspection-checklist/) — MEDIUM confidence
- [GoAudits Pre-Trip Inspection Apps Review](https://goaudits.com/blog/pre-trip-inspection-apps-software/) — MEDIUM confidence
- [pdf Dart package](https://pub.dev/packages/pdf) — HIGH confidence (official pub.dev)
- [printing Flutter package](https://pub.dev/packages/printing) — HIGH confidence (official pub.dev)
- [signature Flutter package](https://pub.dev/packages/signature) — HIGH confidence (official pub.dev)
- [hand_signature Flutter package](https://pub.dev/packages/hand_signature) — HIGH confidence (official pub.dev)
- [FTQ360 Activity Dashboard — filter patterns](https://support.ftq360.com/hc/en-us/articles/115004966787-Activity-Dashboard) — MEDIUM confidence
- Brazilian fleet inspection: [Prolog App — Inspecao de Caminhao](https://prologapp.com/blog/inspecao-de-caminhao-truck/) — MEDIUM confidence
- [SafetyCulture Checklist Veicular (PT)](https://safetyculture.com/library/transport-and-logistics/check-list-veicular-mjd7vowzvypggeuw) — MEDIUM confidence
- PrimeAudit codebase — direct code analysis: AuditExecutionScreen, AuditTemplateService, AuditAnswerService, ImageService — HIGH confidence

---

*Research: Features for PrimeAudit v1.2 Checklist module — 2026-05-02*
