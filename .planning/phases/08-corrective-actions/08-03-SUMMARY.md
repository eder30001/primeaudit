---
phase: 08-corrective-actions
plan: 03
subsystem: ui
tags: [flutter, dart, supabase, corrective-actions, capa, listview, filterchip, dropdown, refreshindicator]

# Dependency graph
requires:
  - phase: 08-01-corrective-actions
    provides: CorrectiveActionService.getActions(), CorrectiveAction model with isOverdue/status.isFinal, corrective_actions table with RLS
  - phase: 08-02-corrective-actions
    provides: CorrectiveActionDetailScreen (navigation target), UserService.getByCompany, CompanyContextService.activeCompanyId
provides:
  - CorrectiveActionsScreen: tela de listagem ACT-01 com FilterChips por status (5 opções) e DropdownButton por responsável, card de ação com chip de status colorido, pull-to-refresh, estados loading/error/empty contextualizados
  - CorrectiveActionStatusChip (public): chip de status CAPA reutilizável na tela de detalhe (Wave 4)
affects:
  - 08-04-corrective-actions (CorrectiveActionDetailScreen usa CorrectiveActionStatusChip deste arquivo; home_screen.dart drawer item aponta para CorrectiveActionsScreen)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "FilterChip horizontal scroll para filtros de status: enum _StatusFilter com 5 valores incluindo grupos ('Em aberto' = aberta+emAndamento+emAvaliacao, 'Finalizadas' = status.isFinal) — padrão de enum-filter reutilizável"
    - "Filtro híbrido DB+Dart: em_andamento e em_avaliacao passam dbValue para o serviço; grupos abertas/finalizadas/todas aplicam filtro Dart-side — reduz queries múltiplas a custo de payload ligeiramente maior"
    - "CorrectiveActionStatusChip público (sem underscore): chip de status exportável para reuso na tela de detalhe sem duplicação de código"
    - "Navigator.push().then((_) => _load()): padrão de reload automático ao retornar do detalhe — garante dados frescos sem necessidade de callback explícito"

key-files:
  created: []
  modified:
    - primeaudit/lib/screens/corrective_actions_screen.dart

key-decisions:
  - "CorrectiveActionStatusChip definida como classe pública (sem underscore) em vez de _StatusChip privada — Wave 4 (CorrectiveActionDetailScreen) reutiliza o chip sem duplicação; plano especificava que o executor decidisse com base no que causasse menos disrupcão"
  - "Filtro 'Em aberto' agrupa aberta+emAndamento+emAvaliacao no Dart-side (statusFilter=null para query) — evita múltiplas queries paralelas; volumes esperados são baixos (dezenas a centenas de ações)"

patterns-established:
  - "DropdownButton para filtro de responsável: aparece somente se _responsibles.isNotEmpty — lista deduplicada de MapEntry<userId, name> extraída de _actions carregadas"
  - "Empty state dual: hasFilter distingue 'sem ações nenhuma' de 'filtro sem resultado' com copywriting distinto por contexto"

requirements-completed: [ACT-01]

# Metrics
duration: verification session (~5min)
completed: 2026-04-27
---

# Phase 8 Plan 03: CorrectiveActionsScreen Summary

**Tela de listagem CAPA com FilterChips de status (5 opções incluindo grupos), DropdownButton por responsável, card com chip colorido e borda vermelha para vencidas, pull-to-refresh e estados contextualizados**

## Performance

- **Duration:** verification session (~5 min)
- **Started:** 2026-04-27T19:58:34Z
- **Completed:** 2026-04-27T20:03:00Z
- **Tasks:** 1 (pre-implemented — verification only)
- **Files modified:** 1

## Accomplishments
- `CorrectiveActionsScreen`: listagem completa de ações corretivas com filtros por status (5 FilterChips horizontais incluindo grupos "Em aberto" e "Finalizadas") e responsável (DropdownButton condicional)
- `_ActionCard`: card com título, `CorrectiveActionStatusChip` colorido, ícone de responsável, data de prazo em vermelho quando vencida, auditoria vinculada opcional — borda vermelha quando `action.isOverdue`
- `CorrectiveActionStatusChip` (pública): chip de status CAPA reutilizável na Wave 4 (CorrectiveActionDetailScreen)
- `RefreshIndicator` chamando `_load()` no pull-to-refresh; estados loading/error/empty com copywriting diferenciado por contexto
- Suite `flutter test`: 231 passed, 2 skipped — zero regressões

## Task Commits

Implementação foi feita na sessão anterior (parte do trabalho de Phase 8). Esta sessão realizou verificação:

1. **Task 1: CorrectiveActionsScreen — verificação de critérios de aceitação** — pré-implementada; todos os greps e análise passaram

**Verificação (esta sessão):** Nenhum novo commit de código — todos os critérios de aceitação verificados. Commit de docs/metadata abaixo.

## Files Created/Modified
- `primeaudit/lib/screens/corrective_actions_screen.dart` — CorrectiveActionsScreen com enum _StatusFilter (5 valores), extension _StatusFilterLabel, filtros FilterChip+DropdownButton, _ActionCard, CorrectiveActionStatusChip público, RefreshIndicator, estados loading/error/empty

## Decisions Made
- `CorrectiveActionStatusChip` definida como classe pública (sem underscore) em vez de `_StatusChip` privada — decisão do executor conforme plano: escolha que cause menos disrupcão. Wave 4 pode importar e reutilizar sem duplicação de código.
- Filtro híbrido DB+Dart: grupos "Em aberto" e "Finalizadas" aplicam filtro Dart-side com `statusFilter=null` na query; "Em andamento" e "Em avaliação" passam `dbValue` diretamente. Volumes esperados por empresa são baixos — aceitável.

## Deviations from Plan

None - plan executed exactly as written. A única variação foi que `_StatusChip` foi implementada como `CorrectiveActionStatusChip` (pública) em vez de `_StatusChip` (privada) — o próprio plano indicava que o executor deveria decidir com base no que causasse menos disrupcão, portanto não é um desvio mas uma decisão prevista.

## Issues Encountered
None — arquivo já estava implementado e compilando limpo. `flutter analyze` retornou "No issues found!" e `flutter test` passou com 231 testes.

## Known Stubs
None — tela busca dados reais de `CorrectiveActionService.getActions()` via Supabase com RLS. Filtros funcionais. Navegação para `CorrectiveActionDetailScreen` implementada.

## Threat Flags
None — todas as superfícies mapeadas no `<threat_model>` do plano estão cobertas:
- T-8-11 (companyId no Dart + RLS no banco): `CompanyContextService.instance.activeCompanyId` usado na query; RLS `auditor_corrective_actions_select` é a camada de segurança real — aceito conforme plano
- T-8-12 (filtro Dart-side por responsável): todos os responsáveis no dropdown são da mesma empresa (dados vêm do RLS scoped); sem cross-company leakage — aceito conforme plano
- T-8-13 (sem paginação): volumes esperados são baixos — aceito conforme plano

## User Setup Required
None — nenhuma configuração externa necessária.

## Next Phase Readiness
- Wave 3 completa: listagem de ações corretivas end-to-end funcional com filtros
- Wave 4 (08-04): `CorrectiveActionDetailScreen` pode importar `CorrectiveActionStatusChip` deste arquivo; `CorrectiveActionsScreen` aguarda entrada no drawer de `home_screen.dart` (Wave 4 badge + drawer item = ACT-04)
- Requirement ACT-01 completo

## Self-Check: PASSED
- `primeaudit/lib/screens/corrective_actions_screen.dart` — FOUND (466 lines)
- `class CorrectiveActionsScreen` — FOUND
- `enum _StatusFilter` — FOUND
- `FilterChip` — FOUND
- `DropdownButton` — FOUND
- `RefreshIndicator` — FOUND
- `CorrectiveActionDetailScreen` — FOUND (navigation)
- `Nenhuma ação corretiva` — FOUND (empty state)
- `Nenhuma ação encontrada` — FOUND (filter empty state)
- `Tentar novamente` — FOUND (error state)
- `isOverdue` — FOUND (card border)
- `flutter analyze` — No issues found!
- `flutter test` — 231 passed, 2 skipped

---
*Phase: 08-corrective-actions*
*Completed: 2026-04-27*
