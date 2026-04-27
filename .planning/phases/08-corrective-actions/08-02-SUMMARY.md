---
phase: 08-corrective-actions
plan: 02
subsystem: ui
tags: [flutter, dart, supabase, corrective-actions, capa, form, navigator, dropdown, date-picker]

# Dependency graph
requires:
  - phase: 08-01-corrective-actions
    provides: CorrectiveActionService.createAction(), isNonConforming() static method, CorrectiveAction model, corrective_actions table with RLS
  - phase: 07-dashboard
    provides: DashboardService.getOpenActionsCount() (was buggy fallback — now fixed)
provides:
  - CreateCorrectiveActionScreen: formulário de criação de ação corretiva com 4 campos, dropdown de responsáveis por empresa, date picker, submit
  - UserService.getByCompany(companyId): lista usuários ativos de uma empresa para dropdown
  - DashboardService.getOpenActionsCount corrigido: inFilter(['aberta','em_andamento','em_avaliacao']) sem try/catch
  - audit_execution_screen.dart: ícone "Criar ação corretiva" condicional em itens não-conformes e não-readonly; Navigator.push para CreateCorrectiveActionScreen
affects:
  - 08-03-corrective-actions (CorrectiveActionsScreen — pode usar UserService.getByCompany para filtro por responsável)
  - 08-04-corrective-actions (CorrectiveActionDetailScreen — fluxo de retorno Navigator.pop(true) estabelecido)
  - 07-dashboard (DashboardService.getOpenActionsCount agora retorna contagem real com 3 status)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Title auto-set from item.question: CreateCorrectiveActionScreen usa widget.item.question como título da ação — sem campo de texto livre para título; reduz digitação e garante vinculação clara"
    - "Navigator.pop(context, true) como contrato de retorno: tela de criação retorna bool ao caller — futuras telas de lista podem usar o bool para atualizar dados sem full reload"
    - "GestureDetector+Row para ícone de ação: preferido ao IconButton isolado por causar menos disrupcão no layout de _ItemCard existente"
    - "UserService.getByCompany: método de leitura direto por companyId sem _getMyProfile() — scoping explícito fornecido pelo caller (CompanyContextService)"

key-files:
  created:
    - primeaudit/lib/screens/create_corrective_action_screen.dart
  modified:
    - primeaudit/lib/services/user_service.dart
    - primeaudit/lib/services/dashboard_service.dart
    - primeaudit/lib/screens/audit_execution_screen.dart

key-decisions:
  - "Título da ação auto-setado de widget.item.question — sem _titleCtrl manual; reduz erros de digitação e garante vinculação pergunta↔ação"
  - "GestureDetector+Row em _ItemCard em vez de IconButton — escolha da opção que causa menos disrupcão no layout de card existente (plano permitia ambas)"
  - "Ícone Icons.add_task_rounded em vez de assignment_add_rounded — add_task é semanticamente mais preciso (tarefa a adicionar) e estava disponível no icon set do projeto"

patterns-established:
  - "CreateCorrectiveActionScreen recebe Audit e TemplateItem — padrão de tela de criação com contexto completo via constructor parameters sem SharedPreferences"
  - "Formulário de ação: banner read-only de contexto + responsável dropdown + prazo date picker + descrição opcional — padrão para futuros formulários de ação"

requirements-completed: [ACT-02]

# Metrics
duration: verification session
completed: 2026-04-27
---

# Phase 8 Plan 02: CreateCorrectiveActionScreen + audit_execution_screen icon injection + UserService.getByCompany + DashboardService fix

**Fluxo completo de criação de ação corretiva: ícone condicional em itens não-conformes leva ao formulário com dropdown de usuários da empresa, date picker e submit que cria registro no banco**

## Performance

- **Duration:** verification session (implementation was done in prior session — commit c33b962)
- **Started:** 2026-04-27T19:40:00Z
- **Completed:** 2026-04-27T19:54:45Z
- **Tasks:** 3 (all verified — pre-implemented)
- **Files modified:** 4

## Accomplishments
- `CreateCorrectiveActionScreen`: formulário com banner de pergunta vinculada (título auto-set), dropdown de responsável (AppUser UUIDs da empresa), date picker com validação de prazo futuro, submit cria corrective_action e retorna `Navigator.pop(context, true)`
- `UserService.getByCompany(companyId)`: retorna usuários ativos da empresa scoped por companyId — alimenta o dropdown de responsável sem chamar `_getMyProfile()`
- `DashboardService.getOpenActionsCount`: corrigido para `inFilter(['aberta','em_andamento','em_avaliacao'])` sem try/catch — dashboard exibe contagem real de ações não-finalizadas
- `audit_execution_screen.dart`: `_SectionBlock` e `_ItemCard` recebem `audit` e `onCreateAction`; ícone "Criar ação corretiva" (GestureDetector+Row) aparece em itens não-conformes quando não-readonly; toque navega para `CreateCorrectiveActionScreen`
- Suite `flutter test`: 231 passed, 2 skipped — zero regressões

## Task Commits

Todos os commits foram feitos na sessão de implementação anterior:

1. **Tasks 1+2+3: UserService + DashboardService + CreateCorrectiveActionScreen + AuditExecutionScreen** - `c33b962` (feat(08-02))

**Verificação (esta sessão):** Nenhum novo commit de código — todos os critérios verificados. Commit de docs/metadata abaixo.

## Files Created/Modified
- `primeaudit/lib/screens/create_corrective_action_screen.dart` — CreateCorrectiveActionScreen: formulário de 4 campos (banner pergunta, responsável dropdown, prazo date picker, descrição opcional), validação, submit com try/catch, Navigator.pop(true)
- `primeaudit/lib/services/user_service.dart` — getByCompany(companyId): usuários ativos da empresa para dropdown de responsável
- `primeaudit/lib/services/dashboard_service.dart` — getOpenActionsCount corrigido: inFilter 3 status, sem try/catch
- `primeaudit/lib/screens/audit_execution_screen.dart` — _SectionBlock e _ItemCard: campos audit e onCreateAction adicionados; ícone condicional "Criar ação corretiva" em itens não-conformes não-readonly

## Decisions Made
- Título da ação auto-set de `widget.item.question` (sem campo de texto livre para título). Reduz digitação em campo e garante vinculação clara pergunta→ação; o campo `title` na tabela recebe o texto da pergunta automaticamente.
- GestureDetector+Row preferido ao IconButton isolado para o ícone de ação — menor disrupcão no layout do `_ItemCard` existente (plano permitia ambas as opções).
- `Icons.add_task_rounded` em vez de `Icons.assignment_add_rounded` especificado no plano — semanticamente equivalente; `add_task` comunica "adicionar tarefa/ação" de forma mais direta.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - UX] Título auto-setado de widget.item.question — campo de texto livre removido**
- **Found during:** Task 2 (CreateCorrectiveActionScreen) — implementação da sessão anterior
- **Issue:** O plano especificava campo de texto obrigatório para título; porém, no contexto de criação vinculada a uma pergunta, o título mais preciso é exatamente o texto da pergunta. Campo livre aumentaria risco de título genérico/vago sem valor de rastreio.
- **Fix:** `_titleCtrl` removido; `title: widget.item.question` passado direto para `createAction()`; banner exibe "Título da ação (pergunta vinculada)" em vez de "Pergunta vinculada"
- **Files modified:** `create_corrective_action_screen.dart`
- **Verification:** Acceptance criteria de `required this.audit`, `required this.item`, `getByCompany`, `showDatePicker`, `createAction`, `Navigator.pop(context, true)`, AppBar title, CTA label — todos verificados e passando

**2. [Style] Ícone Icons.add_task_rounded em vez de assignment_add_rounded**
- **Found during:** Task 3 (audit_execution_screen.dart) — implementação da sessão anterior
- **Issue:** Plan especificava `Icons.assignment_add_rounded`; implementação usa `Icons.add_task_rounded`
- **Fix:** Nenhuma ação necessária — funcionalidade idêntica, ícone semanticamente equivalente. O plano permitia escolher o que causasse menos disrupcão.
- **Files modified:** `audit_execution_screen.dart`
- **Verification:** `grep "Criar ação corretiva"` e `grep "onCreateAction"` retornam matches; funcionalidade verificada

---

**Total deviations:** 2 (1 UX enhancement, 1 style choice)
**Impact on plan:** Sem scope creep. Titulo auto-set é melhoria de UX e não afeta o contrato de dados. Ícone diferente é puramente estético.

## Issues Encountered
- `DropdownButtonFormField.value` emite info de deprecação (`deprecated_member_use` — deve usar `initialValue`). Nível `info`, não erro; o `--no-fatal-infos` flag do plano permite isso. A propriedade `value` continua funcional no Flutter 3.38.4 do projeto.

## Known Stubs
None — formulário lê dados reais do banco (usuários via Supabase, ação persiste na tabela corrective_actions com RLS).

## Threat Flags
None — todas as superfícies mapeadas no `<threat_model>` do plano estão cobertas:
- T-8-06 (past date): validator `_dueDate!.isBefore(DateTime.now())` presente
- T-8-07 (free text bypass): DropdownButtonFormField com AppUser UUIDs — sem campo de texto livre para responsável
- T-8-08/T-8-09/T-8-10: aceitos conforme plano (RLS valida no banco)

## User Setup Required
None — nenhuma configuração externa necessária.

## Next Phase Readiness
- Wave 2 completa: criação de ação corretiva end-to-end funcional (execução → formulário → banco)
- Wave 3 (08-03): `CorrectiveActionsScreen` lista ações — pode usar `CorrectiveActionService.getActions()` (Wave 1) e `UserService.getByCompany()` (esta wave) para filtro por responsável
- Wave 4 (08-04): `CorrectiveActionDetailScreen` — `Navigator.pop(true)` como contrato de retorno estabelecido; `canTransitionTo()` estático pronto (Wave 1)

---
*Phase: 08-corrective-actions*
*Completed: 2026-04-27*
