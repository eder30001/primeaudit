# Roadmap: PrimeAudit — Features & UX (v1.1)

## Overview

Esta milestone adiciona as funcionalidades core que tornam o app utilizável em produção. A ordem das fases reflete dependências técnicas: templates primeiro (zero dependências novas), depois dashboard (requer a tabela corrective_actions para exibir ações abertas), depois ações corretivas (tabela core que notificações e dashboard dependem), depois imagens (depende de bucket Storage e da tela de execução com ações), depois relatórios (depende de dados existentes), depois notificações (depende de ações corretivas) e por fim a refatoração de navegação (cosmética, entregável depois que os destinos existem).

---

## Phases

- [ ] **Phase 6: Templates** - Corrigir ordenação e habilitar reordenação manual de perguntas no builder
- [x] **Phase 7: Dashboard** - Exibir indicadores reais de auditorias e ações no dashboard
- [ ] **Phase 8: Corrective Actions** - Criar, listar e gerenciar ações corretivas com fluxo de status CAPA
- [ ] **Phase 9: Images** - Anexar e visualizar fotos por pergunta durante a execução da auditoria
- [ ] **Phase 10: Reports** - Filtrar e visualizar relatórios de auditorias concluídas com gráficos
- [ ] **Phase 11: Notifications** - Central de notificações in-app, email automático e push FCM
- [ ] **Phase 12: Navigation Refactor** - FAB expandível nas telas principais, drawer simplificado

---

## Phase Details

### Phase 6: Templates
**Goal**: Perguntas respeitam a ordem correta em todas as telas e o admin pode reordená-las por drag & drop com persistência
**Depends on**: Nothing (v1.0 Phase 4 already delivered batch upsert backend)
**Requirements**: TMPL-01, TMPL-02
**Success Criteria** (what must be TRUE):
  1. Na tela de execução de auditoria, as perguntas aparecem na ordem definida por `order_index`, sem embaralhamento
  2. No template builder, o admin pode arrastar uma pergunta para cima ou para baixo e a nova ordem é salva no banco após soltar
  3. Após reordenar e fechar o template builder, reabrir o template mostra a nova ordem persistida
**Plans**: 2 plans
  - [x] 06-01-PLAN.md - TMPL-01: Fix item ordering in AuditExecutionScreen._load() (bucket sort by orderIndex after grouping)
  - [x] 06-02-PLAN.md - TMPL-02: Drag & drop reorder in TemplateBuilderScreen (ReorderableListView + reorderItems persistence)
**UI hint**: yes

### Phase 7: Dashboard
**Goal**: Usuário vê indicadores reais de auditorias e ações abertas scoped por empresa, atualizáveis via pull-to-refresh
**Depends on**: Phase 8 (corrective_actions table must exist for open actions count — migration delivered in Phase 8 setup; Phase 7 can be planned in parallel but executed after migration is applied)
**Requirements**: DASH-01, DASH-02, DASH-03
**Success Criteria** (what must be TRUE):
  1. O dashboard exibe cards com: total de auditorias, pendentes, atrasadas e ações em aberto — todos com valores reais do banco, scoped pela empresa ativa
  2. Puxar a tela para baixo (pull-to-refresh) atualiza todos os cards sem navegar para outra tela
  3. Um gráfico mostra a conformidade média por template de auditoria para o período recente
**Plans**: 2 plans
  - [x] 07-01-PLAN.md — fl_chart dependency + DashboardService + unit test scaffold (Wave 1)
  - [x] 07-02-PLAN.md — home_screen.dart: real KPI cards + RefreshIndicator + conformity chart (Wave 2)
**UI hint**: yes

### Phase 8: Corrective Actions
**Goal**: Auditores criam ações corretivas vinculadas a perguntas e admins gerenciam o fluxo de status CAPA completo
**Depends on**: Phase 6 (template item IDs stable), Phase 7 migration (corrective_actions table)
**Requirements**: ACT-01, ACT-02, ACT-03, ACT-04
**Success Criteria** (what must be TRUE):
  1. Na tela de execução, o auditor toca em um ícone por pergunta, preenche título, responsável e prazo, e a ação é criada vinculada àquela pergunta e auditoria
  2. A tela de ações corretivas exibe a lista com status atual, com filtros por responsável e por status funcionando
  3. O status de uma ação segue o fluxo: Admin pode mover para qualquer estado; Responsável pode mover apenas para em_andamento e em_avaliacao; Auditor pode mover apenas para aprovada e rejeitada — transições não permitidas são bloqueadas na UI
  4. Um badge com a contagem de ações abertas é visível na navegação principal e atualiza quando o estado muda
**Plans**: 4 plans
  - [ ] 08-01-PLAN.md — Wave 1: Migration SQL (corrective_actions + RLS) + supabase db push [BLOCKING] + CorrectiveAction model + CorrectiveActionService (CRUD + static isNonConforming + static canTransitionTo) + unit test stubs
  - [ ] 08-02-PLAN.md — Wave 2: CreateCorrectiveActionScreen (form D-02/D-03) + audit_execution_screen.dart icon injection (D-01) + UserService.getByCompany + DashboardService fix
  - [ ] 08-03-PLAN.md — Wave 3: CorrectiveActionsScreen list with FilterChip status filters + responsible dropdown + RefreshIndicator + empty/error states (ACT-01)
  - [ ] 08-04-PLAN.md — Wave 4: CorrectiveActionDetailScreen (ACT-03 RBAC transitions) + home_screen.dart badge + drawer item (ACT-04) + full test suite
**UI hint**: yes

### Phase 9: Images
**Goal**: Auditores anexam fotos por pergunta durante a execução e as miniaturas aparecem inline no checklist
**Depends on**: Phase 8 (audit_execution_screen already modified; Storage bucket migration in Phase 8 setup)
**Requirements**: IMG-01, IMG-02, IMG-03
**Success Criteria** (what must be TRUE):
  1. Em qualquer pergunta durante a execução, o auditor toca em um botão de câmera e escolhe câmera ou galeria — a foto é carregada no Supabase Storage e associada àquela pergunta e auditoria
  2. Miniaturas das fotos anexadas aparecem inline no card da pergunta, sem navegar para outra tela
  3. O auditor pode anexar mais de uma foto por pergunta e todas as miniaturas são exibidas
  4. Um upload com falha exibe indicador de erro no card da pergunta sem bloquear o salvamento das respostas
**Plans**: TBD
**UI hint**: yes

### Phase 10: Reports
**Goal**: Usuário filtra auditorias concluídas por data e template e vê conformidade em lista e gráfico
**Depends on**: Phase 7 (DashboardService patterns established; fl_chart package added in Phase 7 for DASH-03)
**Requirements**: REP-01, REP-02, REP-03, REP-04
**Success Criteria** (what must be TRUE):
  1. Na tela de relatórios, o usuário seleciona um intervalo de datas e a lista atualiza mostrando apenas auditorias concluídas nesse período
  2. O usuário seleciona um template específico e a lista filtra corretamente, podendo combinar filtro de data e template simultaneamente
  3. Cada auditoria na lista exibe o percentual de conformidade calculado
  4. Um gráfico de barras mostra a conformidade média agrupada por template para os dados filtrados
**Plans**: TBD
**UI hint**: yes

### Phase 11: Notifications
**Goal**: Usuário recebe notificações in-app quando ações são atribuídas a ele, com email automático e suporte a push FCM
**Depends on**: Phase 8 (corrective_actions table and creation flow must exist; notifications table migration delivered in Phase 8 setup)
**Requirements**: NOTIF-01, NOTIF-02, NOTIF-03
**Success Criteria** (what must be TRUE):
  1. Um ícone de sino no AppBar exibe badge com a contagem de notificações não lidas; tocar no ícone abre a central de notificações com a lista de mensagens
  2. Quando uma ação corretiva é atribuída a um responsável, esse responsável recebe um email automático com o título da ação e prazo (sem ação do auditor que criou a ação)
  3. Com o app em background ou fechado, o responsável recebe uma push notification FCM quando uma ação é atribuída a ele
**Plans**: TBD
**UI hint**: yes

### Phase 12: Navigation Refactor
**Goal**: A navegação principal usa FAB expandível nas telas principais e o drawer fica restrito a Perfil e Configurações
**Depends on**: Phase 11 (all destination screens exist: Dashboard, Auditorias, Ações, Relatórios, Notificações)
**Requirements**: NAV-01, NAV-02
**Success Criteria** (what must be TRUE):
  1. Nas telas principais, um FAB expandível dá acesso a Dashboard, Auditorias, Ações Corretivas, Relatórios e Notificações — cada destino abre a tela correspondente
  2. O menu lateral (drawer) exibe apenas Perfil e Configurações — os demais itens de navegação foram removidos do drawer
  3. O FAB não cobre o último item das listas nas telas que o exibem
**Plans**: TBD
**UI hint**: yes

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 6. Templates | 0/2 | Not started | - |
| 7. Dashboard | 2/2 | Complete | 2026-04-25 |
| 8. Corrective Actions | 0/4 | Planned | - |
| 9. Images | 0/? | Not started | - |
| 10. Reports | 0/? | Not started | - |
| 11. Notifications | 0/? | Not started | - |
| 12. Navigation Refactor | 0/? | Not started | - |

---

## v1.0 Phase Archive

| Phase | Status | Completed |
|-------|--------|-----------|
| 1. Data Integrity | Complete | 2026-04-17 |
| 2. Security | Complete | — |
| 3. Test Coverage | Complete | — |
| 4. Performance | Complete | — |
| 5. Server Config | Deferred to v2 | — |
