# Research Summary - PrimeAudit v1.2 Checklist Module

**Synthesized:** 2026-05-02  
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md, PROJECT.md

---

## Executive Summary

PrimeAudit v1.2 adds an independent Checklist module alongside the existing Audit module. Both share the template-to-execution-to-history structure but serve different audiences: checklists are lighter (no perimeter hierarchy, no CAPA linkage), faster to fill, and aimed at transport and industrial field workers who need a quick printable inspection record. Research confirms the module can be built largely by cloning established Audit patterns, with five genuinely new surfaces: template category system, clone operation, three new response types (number, date, signature), and PDF export.

The recommended approach is five sequential phases that respect hard data dependencies and preserve the existing Audit flow untouched. Only two existing files change: one drawer entry in home_screen.dart and three lines in pubspec.yaml. All other work is additive.

Highest-risk surfaces: PDF generation (UI-thread blocking, expired signed URLs, Android FileProvider), template cloning (orphaned section FK references), and RLS for global seed templates (NULL company_id in Postgres). All three have well-understood mitigations in PITFALLS.md. Seed migration idempotency also requires hardcoded UUIDs with ON CONFLICT DO NOTHING.

---

## Key Findings

### Stack (from STACK.md)

New packages for pubspec.yaml:

| Package | Version | Role |
|---------|---------|------|
| pdf | ^3.11.3 | Pure-Dart PDF builder; Flutter-like widget API; MIT license |
| printing | ^5.14.2 | Printing.sharePdf() covers email and WhatsApp in one call; no share_plus needed |
| signature | ^9.0.0 | Canvas widget; toPngBytes() returns Uint8List directly into pw.MemoryImage |

No new packages needed for: date picker (showDatePicker built-in), numeric input (TextInputType.number), multiple choice (Checkbox/ChoiceChip), file sharing (printing covers it), photos (image_picker present).

Packages to avoid: share_plus (redundant), syncfusion_* (commercial license), flutter_form_builder (violates state constraint), hand_signature (overkill), whatsapp_share2 (brittle).

Version confidence: pdf HIGH, printing HIGH, signature 9.0.0 MEDIUM -- verify with flutter pub outdated.

---

### Features (from FEATURES.md)

**Table stakes for v1.2:**

| Feature | Reuse from Audit |
|---------|------------------|
| Template library with 3 tabs (Industrial / Transportadora / Meus) | Partial -- new table, same query pattern |
| CRUD for custom templates | Partial -- clone service logic |
| Clone template | None -- new service method |
| Execution identification header (responsavel, local, data, numero) | None -- new DB columns |
| All existing response types | Direct reuse |
| Text observation + photo per item | Direct reuse |
| Auto-save draft | Direct reuse (_failedSaves retry pattern) |
| History list with conformity badge | Direct reuse (AuditsScreen pattern) |
| Close/finalize checklist | Direct reuse (encerrar pattern) |
| Drawer entry Checklist | One ListTile |

New response types not in Audit module:
- number: TextFormField with TextInputType.number; trivial
- date: showDatePicker(); trivial
- signature: signature package canvas at finalization; medium complexity

Differentiators for v1.2: 10 seed templates pre-loaded, digital signature at close, sequential checklist number per company, PDF export via platform share sheet.

Defer to v1.3: conditional fields, QR/NFC, multi-period trend reports, corrective action integration for NOK items, full offline mode.

Anti-features (do NOT build): conditional smart fields, full offline sync, two-step supervisor approval, mandatory CAPA on NOK, advanced graph overlays.

Conformity calculation: number and date types excluded from denominator by response-type derivation in the calculation function.

---

### Architecture (from ARCHITECTURE.md)

**DB naming:** full checklist_ prefix on all new tables.

| New Table | Mirrors |
|-----------|---------|
| checklist_templates | audit_templates |
| checklist_sections | template_sections |
| checklist_items | template_items |
| checklist_execucoes | audits |
| checklist_respostas | audit_answers |
| checklist_item_images | audit_item_images |

Key schema decisions:
- checklist_templates.is_padrao BOOLEAN distinguishes seeds (true) from company clones (false)
- checklist_templates.category TEXT: industrial, transportadora, custom
- checklist_execucoes Portuguese domain names: responsavel_id, local, numero, conformidade_pct, data_aplicacao
- checklist_respostas UNIQUE (execucao_id, item_id) for upsert semantics
- Storage: **separate checklist-images bucket** (not audit-images) to avoid FK coupling; path {companyId}/checklist/{execucaoId}/{itemId}/{uuid}.jpg

Four dedicated services:
- ChecklistTemplateService: CRUD + clone
- ChecklistExecutionService: CRUD + upsertResposta + calculateConformidade
- ChecklistImageService: mirrors ImageService; upload independent of answers
- ChecklistPdfService: pure function returning Uint8List; no BuildContext

Photo strategy: duplicate _ImageStrip/ImageService pattern. No shared extraction under setState constraint. Refactor when state management is upgraded.

PDF layer: ChecklistPdfService in lib/services/. Screen calls Printing.sharePdf() in one line.

Modified existing files (only 2):
- lib/screens/home_screen.dart: add Checklist ListTile to drawer
- primeaudit/pubspec.yaml: add 3 new packages

Zero changes to AuditTemplateService, AuditAnswerService, ImageService, AuditExecutionScreen, corrective actions, or dashboard.

---

### Pitfalls (from PITFALLS.md)

**Critical -- will cause bugs or crashes if ignored:**

| # | Pitfall | Phase | Prevention |
|---|---------|-------|------------|
| 1 | pdf.save() freezes UI thread with embedded photos | REP-01 | compute() isolate + pre-resize photos to max 800x800 px |
| 2 | Signed URLs expire before PDF builder downloads images | REP-01 | Re-fetch fresh URLs immediately before PDF layout; never reuse cached URLs |
| 3 | Template clone leaves orphaned sectionId on items | TMPLCK-05 | Build oldToNew section UUID map; await sections before inserting items |
| 4 | Auto-save race condition on free-text/number fields | EXEC-05 | Debounce onChanged 600-800 ms; flush on dispose() |
| 5 | Polymorphic item cards lose state on parent setState | EXEC-02 | key: ValueKey(item.id) on every _ItemCard and _SectionBlock |
| 6 | RLS blocks auditors from seeing global seed templates | TMPLCK-06 | SELECT policy: company_id IS NULL OR company_id = get_my_company_id() |
| 7 | Android FileProvider missing for PDF sharing | REP-02 | Add provider to AndroidManifest.xml + file_provider_paths.xml; clean temp PDFs on startup |

**Moderate -- will degrade quality if ignored:**

| # | Pitfall | Phase | Prevention |
|---|---------|-------|------------|
| 8 | Signature PNG bloats PDF | EXEC-06 | Fixed canvas size + toPngBytes(pixelRatio: 2.0) |
| 9 | Seed migration duplicates templates on re-run | TMPLCK-06 | Hardcode UUIDs + ON CONFLICT (id) DO NOTHING |
| 10 | Clone inherits active=false and company_id=NULL | TMPLCK-05 | Force active=true, company_id=activeCompanyId |
| 11 | BuildContext invalid in PDF builder after screen disposal | REP-01 | Extract context values before compute(); guard .then() with if (mounted) |
| 12 | Missing NOTIFY pgrst reload schema in migrations | All DB | Last line of every migration -- non-negotiable |
| 13 | _TextAnswer controller stale after async draft load | EXEC-05 | Load all drafts before building widget tree |

Integration risks:
- Do NOT reuse AuditAnswerService -- different FK constraints and upsert conflict key
- Capture activeCompanyId in initState not in callbacks
- Use separate checklist-images bucket -- avoids FK coupling with audit_item_images
- Drawer entry requires role != anonymous RBAC guard

---

## Implications for Roadmap

5-phase build order with clear hard dependencies. Phases A-E map to PROJECT.md requirement identifiers.

### Phase A -- DB Foundation + Template CRUD

**Rationale:** Everything downstream depends on templates existing in the DB.

**Delivers:** All 6 checklist tables + RLS + indexes + 10 seed templates; ChecklistTemplateService (CRUD + clone); ChecklistHomeScreen, ChecklistTemplateDetailScreen, ChecklistTemplateBuilderScreen; drawer entry with RBAC guard.

**Covers:** TMPLCK-01 through TMPLCK-06, NAV-01

**Pitfalls:** #3 (clone sectionId), #6 (RLS seeds), #9 (seed idempotency), #10 (clone inherits bad values), #12 (NOTIFY pgrst)

**Validation gate:** Create template, clone seed, browse 3 category tabs as auditor role.

### Phase B -- Execution + Auto-save

**Rationale:** Core Value delivery. _failedSaves retry queue is the most critical behavior; validate before photos or signature.

**Delivers:** ChecklistExecutionService; ChecklistExecutionScreen with all response types including new number and date, debounced text save, progress bar, finalize flow.

**Covers:** EXEC-01, EXEC-02, EXEC-03, EXEC-05

**Pitfalls:** #4 (debounce 600-800 ms), #5 (ValueKey on item cards), #13 (drafts before widget tree)

**Validation gate:** Fill all response types, lose WiFi, reconnect, finalize, verify conformidade_pct.

### Phase C -- Photos per Item

**Rationale:** Photos are fully independent of answer saving. Building after stable execution tests the independence boundary cleanly.

**Delivers:** ChecklistImageService; _ChecklistImageStrip widget; separate checklist-images Storage bucket; path {companyId}/checklist/{execucaoId}/{itemId}/{uuid}.jpg.

**Covers:** EXEC-04

**Integration risk:** Confirm separate checklist-images bucket creation step.

**Validation gate:** Upload failure shows error without blocking finalization; thumbnails display correctly.

### Phase D -- Digital Signature

**Rationale:** Finalization-step extension of Phase B; storage path required by Phase E PDF.

**Delivers:** signature package in pubspec; _SignatureStep modal; PNG to Storage; signature_path in checklist_execucoes.

**Covers:** EXEC-06

**Pitfalls:** #8 (fixed canvas + pixelRatio: 2.0)

**Validation gate:** Capture signature, verify signature_path in DB and PNG in Storage.

### Phase E -- History + PDF Export

**Rationale:** PDF requires B + C + D. History requires executions. Both purely additive.

**Delivers:** ChecklistPdfService; ChecklistHistoricoScreen with filters; ChecklistHistoricoDetailScreen; full PDF report (header + items table + photo grid + signature block); Printing.sharePdf share flow.

**Covers:** HIST-01, HIST-02, HIST-03, REP-01, REP-02

**Pitfalls:** #1 (compute() + photo resize), #2 (re-fetch signed URLs), #7 (Android FileProvider + cleanup), #11 (extract context before compute())

**Validation gate:** Generate PDF from completed checklist with photos and signature, share to WhatsApp, verify all content renders correctly.

---

### Research Flags

| Phase | Needs Phase Research? | Notes |
|-------|-----------------------|-------|
| A -- DB + Template CRUD | No | Patterns mirrored from existing migrations and AuditTemplateService |
| B -- Execution + Auto-save | No | Direct mirror of AuditExecutionScreen; all patterns established |
| C -- Photos | No | Direct mirror of ImageService; trivial adaptation |
| D -- Signature | No | Trivial package API; one function call for export |
| E -- History + PDF | YES | PDF in compute(), image pre-fetching, Android FileProvider, iOS file flush are non-trivial; warrants phase-specific plan |

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Stack additions | HIGH | pdf/printing confirmed on pub.dev; signature 9.0.0 MEDIUM -- verify after pub get |
| Feature scope | HIGH | Direct codebase cross-reference |
| Architecture decisions | HIGH | Direct reading of 7 existing migration and service files |
| DB schema | HIGH | Mirrors established patterns; RLS copy-adapt from existing SQL |
| Pitfalls | HIGH | Backed by Flutter issue tracker and Supabase docs |
| Seed template content | MEDIUM | Industry examples; item counts are estimates |

Gaps to address during planning:
- Verify signature latest version after flutter pub get
- Check if image_picker Phase 9 already declared FileProvider in AndroidManifest.xml (avoid duplicate)
- Confirm checklist-images bucket creation step (migration SQL or Supabase dashboard)
- Decide if Phase E should split into 5a (History) and 5b (PDF/Export) given PDF complexity

---

## Sources (Aggregated)

**HIGH confidence:**
- Direct codebase: AuditExecutionScreen, AuditTemplateService, AuditAnswerService, ImageService, migrations 20260406/20260418/20260427
- pub.dev: pdf, printing, signature, hand_signature
- Supabase docs: RLS NULL comparison, idempotent migrations
- Flutter issue tracker: #100451, #62307 (ListView keys), #60160 (MemoryImage heap)
- Android Developers: FileProvider docs
- plus_plugins #1299: share_plus temp file accumulation

**MEDIUM confidence:**
- GoAudits, SafetyCulture/iAuditor product docs -- feature patterns
- FTQ360 dashboard docs -- filter patterns
- Brazilian fleet inspection references (Prolog App, SafetyCulture PT) -- seed template content

---

*Research synthesis for PrimeAudit v1.2 Checklist module -- 2026-05-02*
