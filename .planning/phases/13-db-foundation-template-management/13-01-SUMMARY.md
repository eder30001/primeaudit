---
phase: 13-db-foundation-template-management
plan: 01
subsystem: database
tags: [supabase, postgresql, rls, migrations, sql, seeds, checklist]

# Dependency graph
requires:
  - phase: existing-migrations
    provides: "get_my_role(), get_my_company_id() functions; companies and profiles tables"
provides:
  - "checklist_templates table with RLS: seeds readable by all authenticated, own templates CRUD by creator"
  - "checklist_template_items table with RLS via parent FK subquery"
  - "10 seed templates (5 industrial + 5 transportadora) with hardcoded UUIDs, is_padrao=true"
  - "50 seed items (5 per template) covering yes_no, text, number, date, photo types"
  - "Idempotent migration: re-run via supabase db push is safe (ON CONFLICT DO NOTHING)"
affects: [14-checklist-execution, 13-02-service-layer, 13-03-screens]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Checklist RLS Pattern 2: is_padrao guard — seeds visible to all authenticated; mutations require is_padrao=false AND created_by=auth.uid()"
    - "Checklist RLS Pattern 3: items table RLS via parent FK subquery — no direct created_by on items table"
    - "Seed idempotency: hardcoded UUIDs + ON CONFLICT (id) DO NOTHING for templates; ON CONFLICT DO NOTHING for items"

key-files:
  created:
    - primeaudit/supabase/migrations/20260503_create_checklist_templates.sql
  modified: []

key-decisions:
  - "Seed UUIDs hardcoded (a1b2c3d4-0001-0001-0001-00000000000x, b2c3d4e5-0002-0002-0002-00000000000x) — committed forever, never regenerated"
  - "template_id DEFAULT gen_random_uuid() in ADD COLUMN IF NOT EXISTS — idempotency scaffold only, real rows always supply explicit template_id"
  - "Items table RLS uses subquery via parent FK (not direct created_by) — matches Pattern 3 established in 20260423_rls_template_sections.sql"
  - "ON CONFLICT DO NOTHING for items (no explicit conflict target) — items use gen_random_uuid() PK so re-runs insert no duplicates"

patterns-established:
  - "Pattern: checklist RLS SELECT — (is_padrao = true OR created_by = auth.uid()) instead of company_id scoping"
  - "Pattern: checklist items RLS — subquery via template_id FK to derive ownership"

requirements-completed:
  - TMPLCK-06

# Metrics
duration: 12min
completed: 2026-05-04
---

# Phase 13 Plan 01: DB Foundation (checklist_templates) Summary

**Migration SQL idempotente com 2 tabelas, 5 políticas RLS, 10 seed templates industriais/transportadora e 50 itens seed com tipos forward-compatible com Phase 14**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-04T11:04:03Z
- **Completed:** 2026-05-04T11:16:00Z
- **Tasks:** 2 de 3 completas (Task 3 é checkpoint bloqueante — aguarda `supabase db push`)
- **Files modified:** 1

## Accomplishments

- Migration SQL idempotente criada com padrão estabelecido (CREATE TABLE IF NOT EXISTS + ALTER TABLE ADD COLUMN IF NOT EXISTS)
- 2 tabelas criadas: `checklist_templates` e `checklist_template_items` com FK ON DELETE CASCADE
- 5 políticas RLS por tabela: superuser/dev full; authenticated SELECT seeds/own; INSERT/UPDATE/DELETE own non-seeds apenas
- Policy de items usa subquery via FK (Pattern 3) — não expõe created_by diretamente na tabela filha
- 10 seed templates inseridos com UUIDs hardcoded + ON CONFLICT (id) DO NOTHING (5 industrial + 5 transportadora)
- 50 seed items (5 por template) cobrindo tipos: yes_no, text, number, date, photo

## Task Commits

Commits atômicos por task:

1. **Tasks 1 + 2: Migration SQL (tabelas, RLS, seeds, items)** - `53a1fbf` (feat)

**Nota:** Tasks 1 e 2 foram combinadas num único commit pois o plano prescrevia que Task 2 appenda seeds no mesmo arquivo criado na Task 1.

## Files Created/Modified

- `primeaudit/supabase/migrations/20260503_create_checklist_templates.sql` — Migration idempotente completa: DDL, constraints, indexes, RLS, seeds (10 templates + 50 items)

## Decisions Made

- Seeds inseridos com `created_by = NULL` e `company_id = NULL` — visíveis a todos os usuários autenticados (Pitfall 4 evitado)
- `template_id` coluna em `checklist_template_items` usa `DEFAULT gen_random_uuid()` apenas para satisfazer `NOT NULL` durante ADD COLUMN IF NOT EXISTS — não afeta rows reais
- `ON CONFLICT DO NOTHING` para items (sem target explícito) — seguro pois PK é `gen_random_uuid()` e re-runs não geram UUIDs duplicados
- Item types escolhidos compatíveis com Phase 14 EXEC-02: `yes_no`, `text`, `number`, `date`, `multiple_choice`, `photo`

## Deviations from Plan

### Desvio de Verificação (cosmético — sem impacto funcional)

**1. [Verificação] grep -c "is_padrao = true OR created_by = auth.uid" retorna 1, não >= 2**
- **Encontrado durante:** Verificação pós-criação
- **Situação:** A tabela `checklist_templates` tem a policy com `(is_padrao = true OR created_by = auth.uid())` na linha 90. A tabela `checklist_template_items` usa o mesmo padrão mas via alias: `(t.is_padrao = true OR t.created_by = auth.uid())` na linha 128. O grep exato do plano não capta o alias `t.`.
- **Impacto:** Zero — ambas as policies implementam o guard correto. A verificação do plano era um check de sanidade; o comportamento de segurança está correto em ambas as tabelas.
- **Ação:** Nenhuma alteração necessária. Documentado aqui para rastreabilidade.

---

**Total desvios:** 1 (desvio de verificação cosmético — sem impacto funcional)
**Impacto no plano:** Nenhum — segurança implementada corretamente nas duas tabelas.

## Known Stubs

Nenhum stub. A migration não tem código Dart — é SQL puro com dados reais (seeds com nomes e descrições completos).

## Threat Flags

Nenhum. Todas as ameaças do threat register do plano foram mitigadas:
- T-13-01: DELETE de seeds bloqueado por `is_padrao = false` na policy DELETE
- T-13-02: SELECT de templates alheios bloqueado por `is_padrao = true OR created_by = auth.uid()`
- T-13-03: UPDATE/DELETE de templates alheios bloqueado por `created_by = auth.uid() AND is_padrao = false`
- T-13-04: Items só graváveis quando parent template pertence ao caller e não é seed
- T-13-05: `get_my_role() IS NOT NULL` usa active=true guard de 20260418_fix_active_guard.sql

## User Setup Required

**Task 3 (checkpoint:human-action) pendente — migration precisa ser aplicada ao Supabase:**

```powershell
cd primeaudit
supabase db push
```

Após o push, verificar no Supabase Dashboard:
1. Table Editor → tabelas `checklist_templates` e `checklist_template_items` existem
2. Table Editor → checklist_templates → 10 rows com is_padrao=true
3. Authentication → RLS → policies existem nas duas tabelas

Se `supabase db push` pedir interação, definir token primeiro:
```powershell
$env:SUPABASE_ACCESS_TOKEN = "seu-token"
supabase db push
```

## Next Phase Readiness

- Migration pronta para push; após push, Phase 13 Plan 02 (Service Layer + Model Dart) pode iniciar
- Phase 14 (Checklist Execution Engine) depende das tabelas existirem no banco
- UUIDs dos seeds hardcoded são estáveis — Phase 14 pode referenciar os templates por UUID se necessário

## Self-Check

- [x] Arquivo criado: `primeaudit/supabase/migrations/20260503_create_checklist_templates.sql` — FOUND
- [x] Commit `53a1fbf` existe no repositório
- [x] `grep -c "CREATE TABLE IF NOT EXISTS checklist_templates"` retorna 1
- [x] `grep -c "ON DELETE CASCADE"` retorna 1
- [x] `grep -c "ON CONFLICT"` retorna 5
- [x] Arquivo termina com `NOTIFY pgrst, 'reload schema';`
- [x] 10 seeds de templates com UUIDs hardcoded presentes
- [x] 50 seeds de items presentes (25 industrial + 25 transportadora)

## Self-Check: PASSED

---

*Phase: 13-db-foundation-template-management*
*Plan: 01*
*Completed: 2026-05-04 (Tasks 1-2; Task 3 aguarda supabase db push)*
