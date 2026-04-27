---
phase: 08-corrective-actions
plan: 04
subsystem: ui
tags: [flutter, dart, supabase, corrective-actions, capa, rbac, badge, drawer, material3]

# Dependency graph
requires:
  - phase: 08-01-corrective-actions
    provides: CorrectiveActionService.canTransitionTo (static), CorrectiveActionService.updateStatus, CorrectiveActionService.getOpenActionsCount, CorrectiveAction model with status.isFinal/isOverdue
  - phase: 08-03-corrective-actions
    provides: CorrectiveActionsScreen (drawer navigation target), CorrectiveActionStatusChip (public chip reused in detail screen)
provides:
  - CorrectiveActionDetailScreen (ACT-03): tela de detalhe com info card completo, chip de status, botoes RBAC-gated via canTransitionTo(), AlertDialog para transicoes destrutivas, campo inline de acao tomada, alterar responsavel, excluir acao
  - home_screen.dart badge (ACT-04): _drawerItem com badgeCount suportando Material 3 Badge widget, item "Acoes Corretivas" no drawer com badge real, getOpenActionsCount via CorrectiveActionService
  - Suite completa flutter test: 231 passed, 2 skipped — zero regressoes
affects:
  - 09-images (audit_execution_screen.dart modificado em Phase 8; corrective_action_detail_screen.dart e ponto de entrada CAPA completo)
  - 11-notifications (acoes corretivas completas sao prerequisito para notificacoes de atribuicao)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Material 3 Badge widget (flutter SDK >= 3.7.0): Badge(label: Text('$count'), child: iconWidget) — sem pacote externo, disponivel no SDK"
    - "pop(context, true) como sinal de reload: Navigator.pop(context, true) no sucesso de transicao; caller usa .then((result) => if(result == true) _load()) — padrao de reload lazy sem callback explicito"
    - "Campo inline de acao tomada: TextField controlado por _resolutionCtrl, obrigatorio ao enviar para em_avaliacao, repassado como resolutionNotes no updateStatus — validacao Dart-side antes de chamar servico"
    - "badgeCount = 0 como default no _drawerItem: Badge renderizado condicionalmente (badgeCount > 0) — item sem badge nao tem overhead de widget extra"

key-files:
  created:
    - primeaudit/lib/screens/corrective_action_detail_screen.dart
  modified:
    - primeaudit/lib/screens/home_screen.dart

key-decisions:
  - "CorrectiveActionDetailScreen importa CorrectiveActionStatusChip de corrective_actions_screen.dart via show — reusa chip publico da Wave 3 sem duplicacao de codigo"
  - "Campo 'acao tomada' (resolutionNotes) inline na tela de detalhe em vez de dialog — responsavel preenche antes de submeter, validacao Dart-side obriga preenchimento para transicao em_avaliacao"
  - "_confirm() unificado com parametro destructive: bool para reusar o mesmo AlertDialog para cancelada e rejeitada — pattern mais limpo que _confirmCancel/_confirmReject separados"
  - "Badge atualiza via .then((_) => _loadDashboard()) no drawer item de Acoes Corretivas — mesmo padrao de auditorias; sem stream/realtime; count e eventual-consistent ao voltar para home"

patterns-established:
  - "RBAC-gated buttons: nenhum botao desabilitado — botao nao aparece se canTransitionTo() retorna false; usuario sem permissao ve mensagem de texto"
  - "AlertDialog destructive com foregroundColor: AppColors.error no botao Confirmar — padrao consistente com _confirmEncerrar em audits_screen.dart"

requirements-completed: [ACT-03, ACT-04]

# Metrics
duration: 13min (verification session)
completed: 2026-04-27
---

# Phase 8 Plan 04: CorrectiveActionDetailScreen + Badge + Drawer Summary

**Tela de detalhe CAPA com RBAC de transicao de status (canTransitionTo), campo inline de acao tomada, badge Material 3 com contagem real de acoes abertas no drawer de home_screen.dart**

## Performance

- **Duration:** 13 min (verification session — implementacao pre-existente)
- **Started:** 2026-04-27T20:00:44Z
- **Completed:** 2026-04-27T20:13:46Z
- **Tasks:** 2 (verificacao de criterios de aceitacao pre-implementados)
- **Files modified:** 2 (corrective_action_detail_screen.dart, home_screen.dart — ja commitados)

## Accomplishments
- `CorrectiveActionDetailScreen`: info card com todos os campos (titulo, responsavel, prazo, descricao, acao tomada, auditoria vinculada, criado em), `CorrectiveActionStatusChip` centralizado, botoes RBAC-gated via `CorrectiveActionService.canTransitionTo()`, AlertDialog com `foregroundColor: AppColors.error` para cancelada e rejeitada, pop(context, true) no sucesso para recarregar lista
- Campo inline "Acao tomada" (`_resolutionCtrl`): editavel pelo responsavel em `emAndamento`; obrigatorio para transicao `em_avaliacao`; repassado como `resolutionNotes` no `updateStatus`
- Botoes adicionais: alterar responsavel (criador/admin), excluir acao (criador/admin via AppBar icon) com AlertDialog de confirmacao
- `home_screen.dart`: `_drawerItem` suporta `badgeCount` com `Badge` do Flutter Material 3 SDK; item "Acoes Corretivas" inserido entre Auditorias e Relatorios; `_loadDashboard()` usa `_correctiveActionService.getOpenActionsCount(companyId)` substituindo `DashboardService`; `.then((_) => _loadDashboard())` ao retornar de `CorrectiveActionsScreen` atualiza badge
- Suite `flutter test`: 231 passed, 2 skipped — zero regressoes confirmadas

## Task Commits

Implementacao foi feita em sessao anterior (commit ea4660d). Esta sessao realizou verificacao dos criterios de aceitacao:

1. **Task 1: CorrectiveActionDetailScreen (ACT-03)** — pré-implementada; todos os greps de criterios de aceitacao passaram
2. **Task 2: home_screen.dart badge + drawer (ACT-04) + suite** — pré-implementada; todos os criterios passaram; flutter test 231 passed

**Verificacao (esta sessao):** Nenhum novo commit de codigo — todos os criterios de aceitacao verificados contra implementacao existente.

## Files Created/Modified
- `primeaudit/lib/screens/corrective_action_detail_screen.dart` — CorrectiveActionDetailScreen: info card, chip de status, botoes RBAC-gated, campo inline acao tomada, alterar responsavel, excluir, AlertDialog destructive
- `primeaudit/lib/screens/home_screen.dart` — _drawerItem com badgeCount + Badge widget Material 3, item "Acoes Corretivas" no drawer, _correctiveActionService.getOpenActionsCount(), .then(_loadDashboard)

## Decisions Made
- `CorrectiveActionStatusChip` importada de `corrective_actions_screen.dart` via `show` — reusa chip publico da Wave 3, sem duplicar codigo
- Campo "acao tomada" inline em vez de dialog — UX mais fluida; responsavel preenche antes de submeter, validacao bloqueia transicao em_avaliacao se vazio
- `_confirm()` unificado com parametro `destructive: bool` — reutiliza AlertDialog para cancelada e rejeitada com diferencial visual via foregroundColor

## Deviations from Plan

None - plan executed exactly as written. A implementacao ja incluia funcionalidades adicionais alem do especificado no plano (campo inline de acao tomada, botao de alterar responsavel, botao de excluir acao) — estas foram adicionadas na sessao anterior seguindo os requisitos do 08-UI-SPEC.md e os padroes de RBAC refinados (criador como avaliador, definido em Decisions v1.1 do STATE.md).

## Issues Encountered

Nenhum. O arquivo `corrective_action_detail_screen.dart` apresenta 1 info de lint (deprecated `value` no `DropdownButtonFormField` — linha 159) que e emitido pelo flutter analyze sem `--no-fatal-infos`. Trata-se do parametro `value:` do DropdownButtonFormField (valor selecionado atual) sendo deprecado em favor de `initialValue:` na versao 3.33+. Nao e um erro de compilacao e nao afeta funcionalidade; foi executado com `--no-fatal-infos` conforme especificado no plano.

## Known Stubs
None — tela busca dados reais via CorrectiveActionService; todas as transicoes de status chamam updateStatus no Supabase; badge usa getOpenActionsCount real.

## Threat Flags
Nenhuma superficie nova alem do mapeado no `<threat_model>` do plano:
- T-8-14 (Elevation of Privilege — auditor tentando aprovar status aberta): `canTransitionTo()` verifica role E status atual; UI nao renderiza botao "Aprovar" fora de `emAvaliacao` — mitigado
- T-8-15 (Elevation of Privilege — responsavel tentando cancelar): `canTransitionTo('cancelada')` retorna false para responsavel e auditor; UI nao renderiza botao — mitigado
- T-8-16 (Tampering — updateStatus com newStatus invalido): CHECK constraint no banco rejeita valores fora do enum — aceito conforme plano
- T-8-17 (Elevation of Privilege — RLS UPDATE policy): RLS cobre company scope; UI e camada de enforcement de status nesta milestone — aceito
- T-8-18 (Information Disclosure — badge count visivel a todos): intencional, count por empresa scoped por RLS — aceito

## User Setup Required
None — nenhuma configuracao externa necessaria.

## Next Phase Readiness
- Phase 8 COMPLETA: todos os 4 requirements (ACT-01, ACT-02, ACT-03, ACT-04) entregues
- Fluxo CAPA completo: criacao (Wave 2) → listagem com filtros (Wave 3) → detalhe com transicoes RBAC (Wave 4) → badge na navegacao (Wave 4)
- Phase 9 (Images) pode iniciar: `audit_execution_screen.dart` ja foi modificado na Phase 8 (injecao do icone de acao); a tela esta pronta para receber o icone de camera por pergunta
- Blockers resolvidos: `_openActions=0` do Phase 7 agora usa dado real via `_correctiveActionService.getOpenActionsCount()`

## Self-Check: PASSED
- `primeaudit/lib/screens/corrective_action_detail_screen.dart` — FOUND
- `class CorrectiveActionDetailScreen` — FOUND (grep: 1 match)
- `CorrectiveActionService.canTransitionTo` — FOUND (grep: 1 match)
- `_doTransition` — FOUND (grep: 3 matches)
- `_confirm` — FOUND (grep: 4 matches)
- `Cancelar acao corretiva` — FOUND (dialog title)
- `rejeitada` — FOUND (grep: 3 matches)
- `Navigator.pop(context, true)` — FOUND (grep: 3 matches)
- `Iniciar acao` — FOUND (grep: 2 matches)
- `Aprovar` — FOUND
- `badgeCount` — FOUND in home_screen.dart (grep: 4 matches)
- `Badge(` — FOUND in home_screen.dart (grep: 1 match)
- `CorrectiveActionsScreen` — FOUND in home_screen.dart
- `Acoes Corretivas` (Ações Corretivas) — FOUND in home_screen.dart
- `assignment_late_outlined` — FOUND in home_screen.dart
- `_correctiveActionService.getOpenActionsCount` — FOUND in home_screen.dart
- DashboardService.getOpenActionsCount NOT called — CONFIRMED (grep: 0 matches)
- `flutter analyze corrective_action_detail_screen.dart` — 1 info (deprecated DropdownButtonFormField.value), 0 errors
- `flutter analyze home_screen.dart` — No issues found!
- `flutter test` — 231 passed, 2 skipped — EXIT CODE 0

---
*Phase: 08-corrective-actions*
*Completed: 2026-04-27*
