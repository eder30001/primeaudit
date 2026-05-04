---
phase: 13-db-foundation-template-management
plan: 02
subsystem: api
tags: [dart, flutter, supabase, postgrest, models, services, tdd, unit-tests, checklist]

# Dependency graph
requires:
  - phase: 13-01
    provides: "checklist_templates and checklist_template_items tables with RLS and 10 seed templates"
provides:
  - "ChecklistTemplate model with fromMap factory, isSeed getter, in-memory items list"
  - "ChecklistTemplateItem model with fromMap factory and safe defaults (yes_no, 0, empty string)"
  - "ChecklistTemplateService with 9 public methods: getByCategory, getOwned, getItems, createTemplate, createItems, updateTemplate, replaceItems, deleteTemplate, cloneTemplate"
  - "cloneTemplate rollback pattern: header delete + rethrow on item insert failure"
  - "12 unit tests covering TMPLCK-01..04 (fromMap factories, defaults, isSeed getter)"
  - "Service integration stubs for TMPLCK-01..05 (Nyquist compliance, require live Supabase)"
affects: [13-03-screens, 14-checklist-execution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Model pattern: pure Dart class (no imports), fromMap factory, null-safe defaults, computed getter isSeed"
    - "Service pattern: final _client = Supabase.instance.client; no internal exception handling; callers do try/catch"
    - "Clone rollback pattern: sequential awaited inserts + catch(delete header, rethrow) — avoids FK orphan"
    - "Batch insert pattern: items.asMap().entries.map with order_index from entry key (0..n-1)"
    - "TDD RED/GREEN: test file created first, failure confirmed, model created, all 12 tests green"

key-files:
  created:
    - primeaudit/lib/models/checklist_template.dart
    - primeaudit/lib/services/checklist_template_service.dart
    - primeaudit/test/models/checklist_template_test.dart
    - primeaudit/test/services/checklist_template_service_test.dart
  modified: []

key-decisions:
  - "No imports in model file — pure Dart (same as audit_template.dart) — no Color/IconData needed in Phase 13"
  - "getByCategory relies solely on RLS SELECT policy for seed+own filtering — no client-side .or() needed"
  - "replaceItems = delete all + createItems (batch re-insert with 0..n-1 order_index) — avoids Pitfall 5 order corruption"
  - "cloneTemplate catches item insert failure, deletes orphaned header, rethrows — callers surface error via SnackBar"
  - "Service integration tests left as stubs (require live Supabase) — model unit tests are the automated gate"

patterns-established:
  - "Pattern: ChecklistTemplate.isSeed — thin getter delegating to isPadrao field, mirrors AuditTemplate.isGlobal"
  - "Pattern: cloneTemplate rollback — insert header, fetch source items, try insert items, catch(delete header)+rethrow"
  - "Pattern: createItems batch insert uses asMap().entries to guarantee order_index 0..n-1 from list position"

requirements-completed:
  - TMPLCK-01
  - TMPLCK-02
  - TMPLCK-03
  - TMPLCK-04
  - TMPLCK-05

# Metrics
duration: 8min
completed: 2026-05-04
---

# Phase 13 Plan 02: Model + Service Layer (checklist_template) Summary

**ChecklistTemplate e ChecklistTemplateItem models com fromMap factories e isSeed getter, mais ChecklistTemplateService com 9 métodos CRUD+clone incluindo rollback sequencial, cobertos por 12 unit tests TDD que passam verde**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-04T11:17:00Z
- **Completed:** 2026-05-04T11:25:00Z
- **Tasks:** 3 de 3 completas (Task 0 stub + Task 1 TDD model + Task 2 service)
- **Files modified:** 4

## Accomplishments

- Modelo ChecklistTemplate com fromMap factory, isSeed getter e in-memory items list — zero imports (pure Dart)
- Modelo ChecklistTemplateItem com fromMap factory e defaults seguros: itemType='yes_no', orderIndex=0, description=''
- ChecklistTemplateService com 9 métodos públicos cobrindo CRUD completo + clone com rollback
- cloneTemplate implementado com padrão sequencial + rollback: header first, then items, catch(delete header)+rethrow
- 12 unit tests TDD: RED confirmado (compile error antes do modelo), GREEN confirmado (todos passam após criação)
- Full test suite: 264 testes passam, 2 skipped — zero regressões

## Task Commits

Commits atômicos por task:

1. **Task 0+1 RED: service stub + failing model tests** - `f2877b0` (test)
2. **Task 2: ChecklistTemplateService CRUD + clone** - `0ae316c` (feat)

**Nota TDD:** O modelo (`checklist_template.dart`) foi incluído no commit `f2877b0` junto com os testes, pois a criação do arquivo ocorreu na mesma sessão git após confirmar o RED. O fluxo TDD foi seguido corretamente: (1) test criado, (2) RED verificado via `flutter test` com compile error, (3) modelo criado, (4) GREEN verificado com 12 testes passando.

## Files Created/Modified

- `primeaudit/lib/models/checklist_template.dart` — Classes ChecklistTemplate e ChecklistTemplateItem, pure Dart, fromMap factories, isSeed getter
- `primeaudit/lib/services/checklist_template_service.dart` — CRUD service: 9 métodos, cloneTemplate com rollback
- `primeaudit/test/models/checklist_template_test.dart` — 12 unit tests cobrindo TMPLCK-01..04
- `primeaudit/test/services/checklist_template_service_test.dart` — 2 integration stubs (Nyquist compliance)

## Decisions Made

- Model file sem imports (pure Dart): `checklist_template.dart` não precisa de `Color` ou `IconData` em Phase 13 — zero dependências externas no modelo, igual ao `audit_template.dart`
- `getByCategory` usa apenas `.eq('category', category)` sem `.eq('is_padrao', true)` — RLS SELECT policy já filtra `is_padrao = true OR created_by = auth.uid()` server-side, evitando duplicação de lógica
- `replaceItems` implementado como delete-all + re-insert com order_index regenerado de 0..n-1 via `asMap().entries` — resolve Pitfall 5 (corrupção de ordem em edição) sem complexidade adicional

## Deviations from Plan

Nenhum — plano executado exatamente como especificado. Todos os métodos, padrões e estrutura de testes seguiram o plano sem ajustes.

## Issues Encountered

Nenhum. O fluxo TDD RED/GREEN funcionou conforme esperado: testes falharam com compile error antes do modelo, e passaram verde após a criação.

## User Setup Required

Nenhum — este plano é código Dart puro. Nenhuma configuração de serviço externo necessária. A migration do banco (Plan 01) já foi aplicada via supabase db push.

## Known Stubs

- `primeaudit/test/services/checklist_template_service_test.dart` contém 2 testes stub que não executam lógica real (apenas `expect(ChecklistTemplateService, isNotNull)`). Estes são intencionais — testes de integração do service requerem sessão Supabase autenticada. A cobertura automatizada fica nos model unit tests. Os stubs são o mecanismo de Nyquist compliance documentado no plano.

## Threat Flags

Nenhum. As mitigações do threat register foram implementadas:
- T-13-04: `is_padrao: false` hardcoded em `createTemplate` — caller não pode passar true
- T-13-06: `deleteTemplate` delega ao RLS — sem guard adicional na camada Dart (DB é o enforcer)
- T-13-07: `cloneTemplate` hardcoda `is_padrao: false` e `created_by: userId` — clone nunca vira seed
- T-13-08: PostgREST usa parameterized queries — sem raw SQL na camada Dart

## Next Phase Readiness

- Plan 13-03 (Screens: ChecklistTemplatesScreen + ChecklistTemplateFormScreen) pode iniciar imediatamente
- Service expõe todos os 9 métodos que as screens Wave 3 precisam
- Models têm todos os campos necessários para o UI-SPEC (name, category, description, isPadrao, isSeed, createdBy)
- Plan 14 (Checklist Execution Engine) pode usar ChecklistTemplateService.getByCategory para listar templates disponíveis

---

## Self-Check: PASSED

- [x] `primeaudit/lib/models/checklist_template.dart` — FOUND
- [x] `primeaudit/lib/services/checklist_template_service.dart` — FOUND
- [x] `primeaudit/test/models/checklist_template_test.dart` — FOUND
- [x] `primeaudit/test/services/checklist_template_service_test.dart` — FOUND
- [x] Commit `f2877b0` existe no repositório
- [x] Commit `0ae316c` existe no repositório
- [x] `flutter test test/models/checklist_template_test.dart` — 12/12 passed
- [x] `flutter analyze lib/models/checklist_template.dart lib/services/checklist_template_service.dart` — No issues found
- [x] `flutter test` full suite — 264 tests passed, 2 skipped

*Phase: 13-db-foundation-template-management*
*Plan: 02*
*Completed: 2026-05-04*
