---
phase: 15-photos-per-item
plan: 02
subsystem: database
tags: [supabase, migration, storage, rls, db-push, blocking]

# Dependency graph
requires:
  - phase: 15-01
    provides: Migration SQL 20260510_create_checklist_item_images.sql
provides:
  - Tabela checklist_item_images ativa no banco remoto Supabase
  - Bucket checklist-images criado e privado no Supabase Storage
  - RLS Pattern 3 (auditor via EXISTS subquery) ativa no banco remoto
  - Policies de Storage para upload/read/delete por company_id ativas
  - NOTIFY pgrst reload schema executado — PostgREST atualizado
affects:
  - 15-03 (UI _ChecklistPhotoStrip pode agora chamar ChecklistImageService sem erro 42P01)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "supabase db push via Scoop CLI (C:\\Users\\eder3\\scoop\\shims\\supabase.exe) para Windows"

key-files:
  created: []
  modified:
    - primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql (registrada em supabase_migrations no banco remoto)

key-decisions:
  - "supabase CLI não está no PATH padrão do PowerShell/Bash — usar caminho absoluto C:\\Users\\eder3\\scoop\\shims\\supabase.exe"
  - "NOTICEs de DROP CONSTRAINT/DROP POLICY IF NOT EXISTS são esperados (primeira aplicação) — não são erros"

# Metrics
duration: 5min
completed: 2026-05-07
---

# Phase 15 Plan 02: supabase db push — Migration Aplicada ao Banco Remoto Summary

**Migration 20260510_create_checklist_item_images.sql aplicada ao banco Supabase remoto via supabase CLI — tabela, bucket e RLS Pattern 3 ativos em produção**

## Performance

- **Duration:** ~5 minutos
- **Started:** 2026-05-07
- **Completed:** 2026-05-07
- **Tasks:** 1
- **Files modified:** 0 (operação de banco remoto, sem alterações em disco)

## Accomplishments

- `supabase db push` executado com sucesso a partir de `primeaudit/`
- Migration `20260510_create_checklist_item_images.sql` aplicada ao banco remoto
- Tabela `checklist_item_images` criada com 6 colunas, 4 FKs (checklist_executions, checklist_template_items, companies, profiles) e 3 indexes
- RLS habilitada: 5 policies (superuser/dev full, adm por empresa, auditor SELECT/INSERT/DELETE via EXISTS subquery)
- Bucket `checklist-images` criado como privado no Supabase Storage
- 3 policies de Storage para authenticated (upload/read/delete por company_id no primeiro segmento do path)
- `NOTIFY pgrst, 'reload schema'` executado — PostgREST recarregou o schema
- Verificação final confirmou: "Remote database is up to date."

## Task Commits

1. **Task 1: supabase db push** — Operação de banco remoto; sem commits de código (migration já commitada em `3c85824` do plano 15-01)

## Files Created/Modified

Nenhum arquivo local criado ou modificado. Esta task aplica o arquivo de migration já existente ao banco remoto.

## Decisions Made

- Supabase CLI localizado em `C:\Users\eder3\scoop\shims\supabase.exe` (instalado via Scoop) — não está no PATH padrão do bash/PowerShell neste ambiente
- NOTICEs de `DROP CONSTRAINT IF NOT EXISTS` e `DROP POLICY IF NOT EXISTS` são informativos e esperados na primeira aplicação (objetos ainda não existiam)
- Saída "Finished supabase db push." confirma conclusão bem-sucedida; segunda execução retornou "Remote database is up to date." como verificação adicional

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Supabase CLI não encontrado no PATH**
- **Found during:** Task 1 — ao tentar `supabase status`
- **Issue:** O bash e PowerShell padrões não têm `supabase` no PATH neste ambiente Windows
- **Fix:** Localizado o executável em `C:\Users\eder3\scoop\shims\supabase.exe` via busca de sistema de arquivos; usado caminho absoluto para execução
- **Files modified:** Nenhum
- **Commit:** N/A (não gerou commit de código)

## Issues Encountered

- Supabase CLI instalado via Scoop mas não no PATH padrão — resolvido com caminho absoluto
- Comando `supabase status` falha com Docker não disponível (comportamento normal em ambiente sem instância local — o db push ao remoto funciona independentemente)

## Known Stubs

Nenhum. Esta task é puramente operacional (aplicação de migration ao banco remoto).

## Threat Flags

Nenhum novo surface introduzido. A migration aplicada é exatamente o SQL revisado em Plan 15-01.

## Next Phase Readiness

- Banco remoto pronto: tabela `checklist_item_images` + bucket `checklist-images` + RLS ativa
- `ChecklistImageService` pode agora chamar o banco remoto sem erro 42P01
- Plan 15-03 (UI _ChecklistPhotoStrip + widget tests completos) pode prosseguir sem bloqueios
- Nenhum bloqueio identificado

---

## Self-Check: PASSED

Files verified present:
- `primeaudit/supabase/migrations/20260510_create_checklist_item_images.sql` - FOUND (migration já commitada em 15-01)

Operação verificada:
- Primeira execução: "Applying migration 20260510_create_checklist_item_images.sql... Finished supabase db push."
- Segunda execução (verificação): "Remote database is up to date." — confirma migration registrada em supabase_migrations

---
*Phase: 15-photos-per-item*
*Completed: 2026-05-07*
