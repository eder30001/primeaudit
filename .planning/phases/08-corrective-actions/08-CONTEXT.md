# Phase 8: Corrective Actions - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Criar o fluxo completo de ações corretivas: auditor cria ação vinculada a uma pergunta não-conforme durante a execução, tela de listagem com filtros, fluxo de status CAPA com RBAC por role, e badge de contagem na navegação principal.

Não inclui notificações por email/push (Phase 11) nem imagens (Phase 9).

</domain>

<decisions>
## Implementation Decisions

### Criação da Ação — Entry Point

- **D-01:** O ícone de "criar ação" aparece **apenas em itens com resposta não-conforme**. Lógica por tipo:
  - `ok_nok` → resposta `nok`
  - `yes_no` → resposta `no`
  - `scale_1_5` → score ≤ 2
  - `text` → ícone sempre visível (sem avaliação automática de conformidade)
  - `selection` e `percentage` → Claude decide o limiar razoável alinhado com a lógica de conformidade existente em `AuditAnswerService.calculateConformity()`

### Criação da Ação — Formulário

- **D-02:** O formulário de criação abre em **nova tela** via `Navigator.push` (não bottom sheet, não modal).
- **D-03:** Campos do formulário:
  - Título — texto, obrigatório
  - Responsável — dropdown de usuários da empresa ativa via `UserService`, obrigatório
  - Prazo — date picker, obrigatório
  - Descrição/Observação — texto livre, opcional
- **D-04:** Responsável é sempre um usuário do sistema (não texto livre) — habilita notificações na Phase 11.

### Claude's Discretion

- **Tela de listagem (ACT-01):** Claude decide layout do card (campos visíveis), estilo dos filtros (chips recomendados, padrão Material 3), acesso via drawer e/ou card "Ações abertas" do dashboard.
- **Fluxo de status CAPA (ACT-03):** Claude decide UX de transição (tela de detalhe vs bottom sheet), como comunicar bloqueios de role (SnackBar é o padrão do app), e quais botões de ação exibir condicionalmente por role.
- **Badge (ACT-04):** Claude decide posição (drawer item recomendado dado que FAB vem na Phase 12) e definição de "aberta" para a contagem (sugestão: `aberta + em_andamento + em_avaliacao` = todas as não-finalizadas). Badge deve atualizar via `initState` de cada tela relevante — sem Realtime nesta milestone.
- **Migration:** Claude cria migration idempotente para tabela `corrective_actions` com RLS adequado. Campos mínimos: `id`, `audit_id`, `template_item_id`, `title`, `description`, `responsible_user_id`, `due_date`, `status`, `company_id`, `created_by`, `created_at`, `updated_at`.
- **Status CAPA (6 estados):** `aberta → em_andamento → em_avaliacao → aprovada / rejeitada / cancelada`. Transições bloqueadas por role na UI; RLS não precisa bloquear (UI é suficiente nesta milestone).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requisitos
- `.planning/REQUIREMENTS.md` §ACT — ACT-01 a ACT-04: critérios de aceitação completos

### Tela de execução (ponto de integração principal)
- `primeaudit/lib/screens/audit_execution_screen.dart` — tela a modificar para adicionar o ícone de ação por item; 1529 linhas, entender estrutura de `_sections` e `_allItems` antes de planejar

### Navegação e badge
- `primeaudit/lib/screens/home_screen.dart` — badge na navegação e card "Ações abertas" (D-04 já implementado com fallback 0 via Phase 7)

### Usuários e roles
- `primeaudit/lib/services/user_service.dart` — para popular dropdown de responsável
- `primeaudit/lib/core/app_roles.dart` — `AppRole.canAccessAdmin()`, `AppRole.isSuperOrDev()` — checks de role para transições de status
- `primeaudit/lib/services/company_context_service.dart` — scoping de empresa para queries

### Padrões do app
- `primeaudit/lib/screens/audits_screen.dart` — exemplo de tela de listagem com filtros existente
- `primeaudit/lib/services/dashboard_service.dart` — padrão de queries Supabase com scoping por empresa (Phase 7)

### Migrations existentes
- `primeaudit/supabase/migrations/` — padrão idempotente YYYYMMDD_description.sql a seguir

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_drawerItem()` em `home_screen.dart` — widget de item do drawer; reutilizar para adicionar item "Ações Corretivas" com badge
- `UserService` — já existe, lista usuários da empresa; usar para o dropdown de responsável
- `CompanyContextService.instance.activeCompanyId` — fonte de verdade para scoping
- `AppRole.canAccessAdmin()` e `AppRole.isSuperOrDev()` — checks de role já usados no app

### Established Patterns
- `setState()` + `_isLoading` + `_error` — padrão de todas as telas
- Services instanciados localmente: `final _xService = XService()`
- `_load()` chamado em `initState()`, try/catch na tela (não no service)
- `ScaffoldMessenger.showSnackBar()` com `SnackBarBehavior.floating` — feedback de erro e bloqueio
- `Navigator.push(MaterialPageRoute(...))` — navegação padrão entre telas

### Integration Points
- `audit_execution_screen.dart` — adicionar ícone condicional no widget de item (onde respostas são renderizadas)
- `home_screen.dart` — ativar query real de `corrective_actions` (substitui fallback 0 do Phase 7) e adicionar item de navegação no drawer
- `corrective_actions` tabela — nova, requer migration + RLS + `CorrectiveActionService` novo

</code_context>

<specifics>
## Specific Ideas

- Responsável deve ser um usuário do sistema (não texto livre) — decisão explícita do usuário para garantir compatibilidade com notificações na Phase 11.
- Prazo é obrigatório (alinhado com critério de sucesso ACT-02 no ROADMAP.md).
- O formulário de criação abre em nova tela — o auditor navega para fora da execução, preenche e volta. Considerar pré-preencher o contexto da pergunta (nome do item) no título ou como campo read-only para referência.

</specifics>

<deferred>
## Deferred Ideas

- **Notificações por atribuição** — email/push ao responsável quando ação é criada. Phase 11.
- **Prazo vencendo — alerta** — notificação automática quando prazo se aproxima. Requer cron job, fora do escopo (ver REQUIREMENTS.md Out of Scope).
- **Edição de ação por qualquer auditor** — apenas responsável, auditor verificador e admin podem editar (já em Out of Scope em REQUIREMENTS.md).
- **Filtro por pergunta vinculada** — filtrar ações pela pergunta específica. Complexidade extra; filtros por status e responsável (ACT-01) são suficientes nesta fase.

</deferred>

---

*Phase: 08-corrective-actions*
*Context gathered: 2026-04-25*
