---
phase: 08-corrective-actions
verified: 2026-04-27T21:00:00Z
status: human_needed
score: 3/4 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Abrir auditoria em execucao, responder item como nao-conforme (ex: ok_nok = nok) e verificar se o link 'Criar acao corretiva' aparece abaixo do item. Tocar no link e verificar se a tela Nova Acao Corretiva abre com o banner da pergunta, dropdown de responsavel preenchido e date picker funcionando."
    expected: "Tela abre com a pergunta vinculada exibida como banner read-only. O titulo da acao e preenchido automaticamente com o texto da pergunta (sem campo de titulo manual). Responsavel e selecionavel via dropdown de usuarios da empresa. Prazo e selecionavel via date picker. Submeter cria a acao e retorna para a tela de execucao."
    why_human: "SC-1 diz 'preenche titulo, responsavel e prazo' mas a implementacao substitui o campo de titulo por banner read-only com o texto da pergunta. O desvio e intencional (documentado em 08-02-SUMMARY.md) mas requer validacao humana para confirmar que a UX atinge o objetivo do requisito mesmo sem campo de titulo manual."
  - test: "Abrir acao corretiva em status 'em_avaliacao' como auditor nao-responsavel que NAO criou a acao e verificar se os botoes 'Aprovar' e 'Rejeitar' aparecem."
    expected: "Botoes NAO devem aparecer — a implementacao restringe aprovacao/rejeicao ao CRIADOR da acao, nao a qualquer auditor. O ROADMAP diz 'Auditor pode mover apenas para aprovada e rejeitada' (implicando qualquer auditor) mas o codigo implementa 'apenas o criador pode mover para aprovada e rejeitada'."
    why_human: "Desvio de RBAC em relacao ao SC-3 do ROADMAP: 'Auditor pode mover apenas para aprovada e rejeitada' foi implementado como 'criador (nao-responsavel) pode mover para aprovada e rejeitada'. Um auditor sem vinculo com a acao (nem responsavel, nem criador) nao ve botoes de aprovacao — conforme testes unitarios confirmam. Decisao documentada em STATE.md como 'criador como avaliador, Decisions v1.1'. Requer validacao do Product Owner se o desvio e aceitavel."
---

# Phase 8: Corrective Actions — Verification Report

**Phase Goal:** Auditores criam acoes corretivas vinculadas a perguntas e admins gerenciam o fluxo de status CAPA completo
**Verified:** 2026-04-27T21:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| #   | Truth                                                                                                                                                                            | Status          | Evidence                                                                                                                                     |
|-----|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| SC1 | Na tela de execucao, o auditor toca em um icone por pergunta, preenche titulo, responsavel e prazo, e a acao e criada vinculada aquela pergunta e auditoria                      | ? UNCERTAIN     | Icone e navegacao verificados em audit_execution_screen.dart. Titulo e auto-set de item.question, sem campo manual — desvio requer validacao humana |
| SC2 | A tela de acoes corretivas exibe a lista com status atual, com filtros por responsavel e por status funcionando                                                                   | ✓ VERIFIED      | corrective_actions_screen.dart: FilterChips por status (5 opcoes), DropdownButton por responsavel, RefreshIndicator, getActions() wired        |
| SC3 | O status de uma acao segue o fluxo CAPA; Admin move qualquer estado; Responsavel move para em_andamento e em_avaliacao; Auditor move para aprovada e rejeitada; transicoes bloqueadas na UI | ? UNCERTAIN     | Implementado com restricao a CRIADOR (nao qualquer auditor) para aprovacao/rejeicao — desvio documentado requer validacao do PO              |
| SC4 | Um badge com a contagem de acoes abertas e visivel na navegacao principal e atualiza quando o estado muda                                                                         | ✓ VERIFIED      | home_screen.dart: Badge widget Material 3, _drawerItem com badgeCount, getOpenActionsCount via CorrectiveActionService, .then(_loadDashboard) |

**Score:** 2/4 roadmap SCs fully verified, 2 uncertain pending human decision

### Must-Have Truths from PLAN Frontmatter

#### Wave 1 (08-01-PLAN)

| #  | Truth                                                                                      | Status      | Evidence                                                                                                                                                   |
|----|--------------------------------------------------------------------------------------------|-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1  | Tabela corrective_actions existe no banco com RLS habilitado e scoping por company_id      | ✓ VERIFIED  | 20260425_create_corrective_actions.sql: CREATE TABLE IF NOT EXISTS, 5 RLS policies (DROP POLICY IF EXISTS + CREATE POLICY), NOTIFY pgrst                   |
| 2  | CorrectiveAction.fromMap() parseia todos os campos incluindo joins de profiles e audits     | ✓ VERIFIED  | corrective_action.dart L117-134: parseia 14 campos incluindo profiles join (responsibleName) e audits join (linkedAuditTitle). Tests passam (59/59)         |
| 3  | CorrectiveActionStatus.fromDb() mapeia todos os 6 valores de DB para enum                  | ✓ VERIFIED  | corrective_action.dart L70-79: fromDb com switch para 6 valores + fallback aberta. Tests cubrem todos os casos                                             |
| 4  | CorrectiveActionService.isNonConforming() retorna correto para todos os tipos de resposta   | ✓ VERIFIED  | corrective_action_service.dart L85-103: ok_nok, yes_no, scale_1_5, percentage, text, selection. Tests passam (15 casos)                                    |
| 5  | CorrectiveActionService.canTransitionTo() aplica RBAC corretamente                         | ? UNCERTAIN | Service implementa RBAC baseado em criador (nao role auditor puro). Tests passam para logica implementada, mas RBAC diverge de SC-3 do ROADMAP              |
| 6  | Tests unitarios passam sem Supabase client                                                  | ✓ VERIFIED  | flutter test: 59 testes de model + service passam (exit code 0)                                                                                            |

#### Wave 2 (08-02-PLAN)

| #  | Truth                                                                                                                    | Status      | Evidence                                                                                                                              |
|----|--------------------------------------------------------------------------------------------------------------------------|-------------|---------------------------------------------------------------------------------------------------------------------------------------|
| 7  | Durante execucao de auditoria, o auditor ve icone de acao em itens com resposta nao-conforme                             | ✓ VERIFIED  | audit_execution_screen.dart L1056-1074: GestureDetector condicional com CorrectiveActionService.isNonConforming()                      |
| 8  | Tocar no icone abre CreateCorrectiveActionScreen via Navigator.push                                                      | ✓ VERIFIED  | audit_execution_screen.dart L597-608: Navigator.push(MaterialPageRoute) com CreateCorrectiveActionScreen                              |
| 9  | O formulario tem campos titulo (obrigatorio), responsavel (dropdown), prazo (date picker), descricao (opcional)          | ? UNCERTAIN | Campo titulo nao existe como TextFormField — titulo e auto-setado de widget.item.question. 3 de 4 campos presentes como form fields    |
| 10 | Responsavel e sempre um usuario do sistema — UUID, nao texto livre                                                       | ✓ VERIFIED  | create_corrective_action_screen.dart L199-223: DropdownButtonFormField com AppUser IDs de UserService.getByCompany                    |
| 11 | Submissao bem-sucedida cria registro em corrective_actions e retorna para tela de execucao                               | ✓ VERIFIED  | create_corrective_action_screen.dart L106-118: _service.createAction() seguido de Navigator.pop(context, true)                        |
| 12 | DashboardService.getOpenActionsCount usa inFilter para aberta+em_andamento+em_avaliacao                                  | ✓ VERIFIED  | dashboard_service.dart L14-15: .inFilter('status', ['aberta', 'em_andamento', 'em_avaliacao'])                                        |

#### Wave 3 (08-03-PLAN)

| #  | Truth                                                                                   | Status     | Evidence                                                                                                            |
|----|-----------------------------------------------------------------------------------------|------------|---------------------------------------------------------------------------------------------------------------------|
| 13 | Usuario ve lista de acoes corretivas com status, responsavel e prazo                    | ✓ VERIFIED | corrective_actions_screen.dart: _ActionCard exibe title, CorrectiveActionStatusChip, responsavel, dueDate            |
| 14 | Filtro por status funciona via FilterChips horizontais com opcao 'Todos'               | ✓ VERIFIED | corrective_actions_screen.dart L167-195: _StatusFilter enum, SingleChildScrollView com FilterChip por valor         |
| 15 | Filtro por responsavel funciona via DropdownButton horizontal com opcao 'Todos'         | ✓ VERIFIED | corrective_actions_screen.dart L198-229: DropdownButton<String?> com null = todos, _responsibles list               |
| 16 | Card de acao exibe status chip colorido, nome do responsavel, prazo (vermelho se vencido)| ✓ VERIFIED | corrective_actions_screen.dart L340-438: isOverdue check com AppColors.error para borda e texto de prazo             |
| 17 | Pull-to-refresh atualiza a lista                                                        | ✓ VERIFIED | corrective_actions_screen.dart L310-322: RefreshIndicator com onRefresh: _load                                      |
| 18 | Estado vazio com mensagem especifica por contexto                                       | ✓ VERIFIED | corrective_actions_screen.dart L276-307: hasFilter check, 'Nenhuma acao corretiva' vs 'Nenhuma acao encontrada'      |
| 19 | Estado de erro com botao Tentar novamente                                               | ✓ VERIFIED | corrective_actions_screen.dart L241-272: OutlinedButton.icon com _load, 'Tentar novamente'                           |
| 20 | Tocar em um card navega para CorrectiveActionDetailScreen                               | ✓ VERIFIED | corrective_actions_screen.dart L116-126: Navigator.push para CorrectiveActionDetailScreen com .then(_load)           |

#### Wave 4 (08-04-PLAN)

| #  | Truth                                                                                                                 | Status     | Evidence                                                                                                                                  |
|----|-----------------------------------------------------------------------------------------------------------------------|------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| 21 | Tela de detalhe exibe info completa: titulo, status, responsavel, prazo, auditoria vinculada, criada por, criacao     | ✓ VERIFIED | corrective_action_detail_screen.dart L300-352: _buildInfoCard com todos os campos                                                         |
| 22 | Botoes de transicao aparecem APENAS para roles autorizados (RBAC matrix)                                              | ✓ VERIFIED | corrective_action_detail_screen.dart L426-503: _buildTransitionButtons com CorrectiveActionService.canTransitionTo()                      |
| 23 | Transicoes destrutivas (cancelada, rejeitada) pedem confirmacao via AlertDialog                                       | ✓ VERIFIED | corrective_action_detail_screen.dart L100-114: _confirm() para cancelada e rejeitada com destructive:true                                 |
| 24 | Role bloqueado nao ve botao — NUNCA desabilita e mostra erro                                                          | ✓ VERIFIED | corrective_action_detail_screen.dart L429-435: botao adicionado apenas se canTransitionTo() retorna true — sem disable                    |
| 25 | Badge com contagem de acoes abertas aparece no drawer quando count > 0                                                | ✓ VERIFIED | home_screen.dart L318-321: Badge(label: Text('$badgeCount')) quando badgeCount > 0                                                       |
| 26 | Drawer tem item 'Acoes Corretivas' entre Auditorias e posicao futura de Relatorios                                    | ✓ VERIFIED | home_screen.dart L258-274: item 'Acoes Corretivas' com Icons.assignment_late_outlined e badgeCount: _openActions                          |
| 27 | Badge atualiza ao voltar para HomeScreen via _loadDashboard()                                                         | ✓ VERIFIED | home_screen.dart L272: .then((_) => _loadDashboard())                                                                                    |

### Required Artifacts

| Artifact                                                                   | Expected                                   | Status       | Details                                                                              |
|----------------------------------------------------------------------------|--------------------------------------------|--------------|--------------------------------------------------------------------------------------|
| `primeaudit/supabase/migrations/20260425_create_corrective_actions.sql`    | Migration idempotente com RLS              | ✓ VERIFIED   | CREATE TABLE IF NOT EXISTS, 11 ADD COLUMN IF NOT EXISTS, 5 DROP POLICY/CREATE POLICY |
| `primeaudit/lib/models/corrective_action.dart`                             | CorrectiveAction model + status enum       | ✓ VERIFIED   | 6 status values, fromDb, isFinal, isOverdue, fromMap com joins                       |
| `primeaudit/lib/services/corrective_action_service.dart`                   | CRUD + static isNonConforming + canTransitionTo | ✓ VERIFIED | createAction, updateStatus, getActions, getOpenActionsCount, 2 static methods        |
| `primeaudit/lib/screens/create_corrective_action_screen.dart`              | Formulario de criacao                      | ✓ VERIFIED   | Responsavel dropdown, date picker, submit wired — titulo auto-set (desvio)           |
| `primeaudit/lib/screens/corrective_actions_screen.dart`                    | Lista com filtros                          | ✓ VERIFIED   | FilterChips, Dropdown responsavel, RefreshIndicator, estados loading/error/empty     |
| `primeaudit/lib/screens/corrective_action_detail_screen.dart`              | Detalhe com RBAC transitions               | ✓ VERIFIED   | canTransitionTo() gating, AlertDialog destructive, pop(true), campos completos       |
| `primeaudit/test/models/corrective_action_test.dart`                       | Unit tests para model                      | ✓ VERIFIED   | 19 testes (fromMap, fromDb x8, isFinal x6, isOverdue x3) — passam                   |
| `primeaudit/test/services/corrective_action_service_test.dart`             | Unit tests para static methods             | ✓ VERIFIED   | 40 testes (isNonConforming x15, canTransitionTo x25) — passam                       |

### Key Link Verification

| From                                  | To                                              | Via                                          | Status       | Details                                                                         |
|---------------------------------------|-------------------------------------------------|----------------------------------------------|--------------|---------------------------------------------------------------------------------|
| audit_execution_screen._ItemCard      | create_corrective_action_screen.dart            | Navigator.push em onCreateAction             | ✓ WIRED      | L597-608: CreateCorrectiveActionScreen instanciada com audit e item             |
| create_corrective_action_screen.dart  | user_service.dart getByCompany                  | _userService.getByCompany(companyId)         | ✓ WIRED      | L67: chamada em _load()                                                         |
| create_corrective_action_screen.dart  | corrective_action_service.dart createAction     | _service.createAction()                      | ✓ WIRED      | L106: chamada em _save()                                                        |
| corrective_actions_screen.dart        | corrective_action_service.dart getActions       | _service.getActions()                        | ✓ WIRED      | L69-73: chamada em _load() com companyId, statusFilter, responsibleFilter       |
| corrective_actions_screen.dart        | corrective_action_detail_screen.dart            | Navigator.push em _openDetail()              | ✓ WIRED      | L116-125: push com .then(_load)                                                 |
| corrective_action_detail_screen.dart  | corrective_action_service.dart updateStatus     | _service.updateStatus()                      | ✓ WIRED      | L119-122: chamada em _doTransition() com resolutionNotes opcional               |
| corrective_action_detail_screen.dart  | corrective_action_service.dart canTransitionTo  | CorrectiveActionService.canTransitionTo()    | ✓ WIRED      | L430-434: chamada em _buildTransitionButtons()                                  |
| home_screen.dart _loadDashboard       | corrective_action_service.dart getOpenActionsCount | _correctiveActionService.getOpenActionsCount | ✓ WIRED   | L95: substituiu DashboardService.getOpenActionsCount                            |
| home_screen.dart drawer               | corrective_actions_screen.dart                  | Navigator.push em drawer item                | ✓ WIRED      | L264-272: CorrectiveActionsScreen com currentUserId e currentUserRole            |

### Data-Flow Trace (Level 4)

| Artifact                           | Data Variable | Source                                  | Produces Real Data | Status       |
|------------------------------------|---------------|-----------------------------------------|--------------------|--------------|
| corrective_actions_screen.dart     | _actions      | _service.getActions() → Supabase query  | Yes                | ✓ FLOWING    |
| corrective_action_detail_screen.dart| _action      | Passed via constructor from list screen | Yes (from DB)      | ✓ FLOWING    |
| home_screen.dart badge             | _openActions  | _correctiveActionService.getOpenActionsCount() → inFilter DB query | Yes | ✓ FLOWING |
| create_corrective_action_screen.dart| _users       | _userService.getByCompany() → profiles DB query | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior                                | Command                                                                                                  | Result                      | Status   |
|-----------------------------------------|----------------------------------------------------------------------------------------------------------|-----------------------------|----------|
| Model tests pass without Supabase       | `flutter test test/models/corrective_action_test.dart`                                                   | 19 passed                   | ✓ PASS   |
| Service static tests pass               | `flutter test test/services/corrective_action_service_test.dart`                                         | 40 passed                   | ✓ PASS   |
| isNonConforming('ok_nok','nok') = true  | Static test verified via test suite                                                                       | Pass                        | ✓ PASS   |
| canTransitionTo admin bypass            | Static test: adm can cancel/approve any action                                                            | Pass                        | ✓ PASS   |
| Migration file contains RLS + idempotent patterns | grep patterns in SQL file                                                                        | 5 DROP POLICY + CREATE POLICY found | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plans        | Description                                                                                          | Status         | Evidence                                                                                             |
|-------------|---------------------|------------------------------------------------------------------------------------------------------|----------------|------------------------------------------------------------------------------------------------------|
| ACT-01      | 08-03-PLAN.md       | Usuario ve lista de acoes corretivas com status e filtros por responsavel e status                    | ✓ SATISFIED    | corrective_actions_screen.dart: FilterChips, dropdown, card com chip colorido, RefreshIndicator       |
| ACT-02      | 08-02-PLAN.md       | Auditor pode criar acao vinculada a pergunta durante execucao, definindo responsavel e prazo          | ? NEEDS HUMAN  | Icone e navegacao funcionam; titulo auto-set (desvio de SC-1 "preenche titulo") — validacao humana necessaria |
| ACT-03      | 08-04-PLAN.md       | Status segue fluxo CAPA com 6 estados; RBAC por role para transicoes                                 | ? NEEDS HUMAN  | RBAC implementado com criador/responsavel (nao role generico auditor) — desvio de SC-3 requer validacao PO |
| ACT-04      | 08-04-PLAN.md       | Badge com contagem de acoes abertas visivel na navegacao principal                                    | ✓ SATISFIED    | home_screen.dart: Badge Material 3, _openActions real via getOpenActionsCount, atualiza via _loadDashboard |

**Orphaned requirements:** Nenhum — todos os 4 IDs declarados nos PLANs constam em REQUIREMENTS.md.

**Note:** REQUIREMENTS.md ainda marca ACT-01, ACT-03, ACT-04 como Pending (checkboxes sem tick). Isso indica que o documento nao foi atualizado pos-implementacao — as implementacoes existem e funcionam.

### Anti-Patterns Found

| File                                                           | Line | Pattern                                        | Severity    | Impact                                                                                 |
|----------------------------------------------------------------|------|------------------------------------------------|-------------|----------------------------------------------------------------------------------------|
| `corrective_action_detail_screen.dart`                         | 159  | Deprecated `value:` em DropdownButtonFormField  | Info        | Lint info, nao erro — funcionalidade nao afetada. Documentado em 08-04-SUMMARY.md      |
| `create_corrective_action_screen.dart`                         | 109  | `title: widget.item.question` (sem campo livre) | Warning     | Desvio intencional de SC-1 ("preenche titulo"). Documentado em 08-02-SUMMARY.md        |

Sem TODOs, stubs de retorno null, ou handlers vazios encontrados nos arquivos core da phase.

### Human Verification Required

#### 1. Validar desvio de titulo em CreateCorrectiveActionScreen (SC-1 / ACT-02)

**Test:** Abrir uma auditoria em execucao, responder um item como nao-conforme (ex: ok_nok = nok). Verificar se o link "Criar acao corretiva" aparece. Tocar para abrir a tela Nova Acao Corretiva.

**Expected:** O titulo da acao e preenchido automaticamente com o texto da pergunta — sem campo de texto livre para titulo. Responsavel e selecionavel via dropdown de usuarios. Prazo e selecionavel. Submeter cria a acao.

**Why human:** SC-1 diz "preenche titulo, responsavel e prazo". A implementacao remove o campo de titulo manual e usa o texto da pergunta diretamente como titulo. Isso e um desvio intencional documentado (key-decision em 08-02-SUMMARY.md: "Titulo da acao auto-setado de widget.item.question — sem _titleCtrl manual"). O PO/Product Owner deve confirmar se essa UX e aceitavel ou se um campo de titulo manual e necessario.

#### 2. Validar RBAC de aprovacao/rejeicao — SC-3 (ACT-03)

**Test:** Criar uma acao corretiva com Usuario A como criador e Usuario B como responsavel. Fazer login como Usuario C (auditor da mesma empresa, sem vinculo com a acao). Abrir a acao em status em_avaliacao.

**Expected (por ROADMAP SC-3):** "Auditor pode mover apenas para aprovada e rejeitada" — implica qualquer auditor da empresa pode aprovar/rejeitar.

**Expected (por implementacao):** Usuario C NAO ve botoes de Aprovar/Rejeitar — apenas o criador (Usuario A) ve esses botoes.

**Why human:** A implementacao usa `isCreator` (criador da acao) ao inves de `role == auditor` para gates de aprovacao/rejeicao. Isso e um desvio documentado em STATE.md como "criador como avaliador, Decisions v1.1". O ROADMAP SC-3 diz "Auditor pode mover" genericamente mas a implementacao restringe ao criador especifico. O PO deve decidir se o RBAC refinado (criador) e o comportamento correto ou se qualquer auditor da empresa deve poder aprovar.

### Gaps Summary

Sem gaps bloqueantes — todos os artefatos existem, sao substantivos e estao conectados. Os dois itens de validacao humana sao desvios intencionais de design que o time decidiu no andamento da implementacao, documentados em SUMMARYs. A decisao de aceitar ou nao esses desvios pertence ao Product Owner, nao ao verificador.

**Desvio 1 (titulo):** A tela de criacao nao tem campo de titulo manual — usa o texto da pergunta. SC-1 menciona "preenche titulo" mas o comportamento e funcionalmente equivalente (acao vinculada a pergunta com titulo derivado da pergunta). Risco baixo de regress de requisito.

**Desvio 2 (RBAC auditor):** O ROADMAP diz "Auditor pode mover para aprovada e rejeitada" mas a implementacao diz "Criador (nao-responsavel) pode mover". Isso significa que um auditor aleatorio da empresa nao pode avaliar acoes que nao criou — restricao mais rigorosa do que o especificado. Dependendo do caso de uso real (auditores como avaliadores independentes vs. auditor-criador como dono do processo), isso pode ou nao ser o comportamento desejado.

---

_Verified: 2026-04-27T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
